#!/usr/bin/env bash
# Bootstrap idempotente. Se ejecuta SOLO desde GitHub Actions (workflow_dispatch).
#
# Crea lo mínimo que Terraform no puede crearse a sí mismo (huevo y gallina):
#   1) Bucket S3 para el state remoto (privado, versionado, cifrado SSE-S3, solo TLS)
#   2) Rol IAM sentinel-<owner>-github-actions asumible por OIDC desde ESTE repo
#
# Reutiliza el provider OIDC de GitHub que YA existe en la cuenta (no lo crea).
# Todo lo demás (VPCs, peering, EKS) lo gestiona Terraform con ese rol.
set -euo pipefail

REGION="${AWS_REGION:-eu-west-1}"
OWNER_NAME="${OWNER_NAME:-wilson}"
ENV_NAME="${ENV_NAME:-production}"
REPO="${GITHUB_REPOSITORY:?falta GITHUB_REPOSITORY (ejecutar desde GitHub Actions)}"

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
BUCKET="sentinel-tfstate-${OWNER_NAME}-${ACCOUNT_ID}"
ROLE_NAME="sentinel-${OWNER_NAME}-github-actions${ROLE_SUFFIX:-}"
OIDC_ARN="arn:aws:iam::${ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"

echo "==> Cuenta ${ACCOUNT_ID} | región ${REGION} | repo ${REPO}"

# --- 0. El provider OIDC de GitHub debe existir (no tenemos permiso para crearlo)
aws iam get-open-id-connect-provider --open-id-connect-provider-arn "$OIDC_ARN" >/dev/null
echo "==> Provider OIDC de GitHub encontrado"

# --- 1. Bucket de state
if aws s3api head-bucket --bucket "$BUCKET" 2>/dev/null; then
  echo "==> Bucket ${BUCKET} ya existe"
else
  echo "==> Creando bucket ${BUCKET}"
  aws s3api create-bucket --bucket "$BUCKET" --region "$REGION" \
    --create-bucket-configuration "LocationConstraint=${REGION}" >/dev/null
fi

aws s3api put-bucket-versioning --bucket "$BUCKET" \
  --versioning-configuration Status=Enabled

# SSE-S3: kms:* está denegado en esta cuenta
aws s3api put-bucket-encryption --bucket "$BUCKET" \
  --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

aws s3api put-public-access-block --bucket "$BUCKET" \
  --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

BUCKET_POLICY="$(jq -n --arg b "$BUCKET" '{
  Version: "2012-10-17",
  Statement: [{
    Sid: "DenyInsecureTransport",
    Effect: "Deny",
    Principal: "*",
    Action: "s3:*",
    Resource: ["arn:aws:s3:::\($b)", "arn:aws:s3:::\($b)/*"],
    Condition: { Bool: { "aws:SecureTransport": "false" } }
  }]
}')"
aws s3api put-bucket-policy --bucket "$BUCKET" --policy "$BUCKET_POLICY"

# --- 2. Rol OIDC para GitHub Actions
# Trust policy: solo este repo, y solo rama main o el environment indicado.
# OJO: no hay iam:UpdateAssumeRolePolicy, así que debe quedar bien desde la creación.
#
# El token real de GitHub puede traer el sub con los IDs numéricos del dueño y del repo:
#   repo:OWNER@OWNER_ID/REPO@REPO_ID:environment:production
# En vez del formato clásico repo:OWNER/REPO:environment:production.
# Aceptamos ambos (solo para ESTE repo, rama main y este environment). Los IDs vienen
# del contexto de GitHub (OWNER_ID / REPO_ID), no se escriben a mano.
REPO_OWNER="${REPO%%/*}"
REPO_NAME="${REPO#*/}"
SUBJECTS=("repo:${REPO}:ref:refs/heads/main" "repo:${REPO}:environment:${ENV_NAME}")
if [ -n "${OWNER_ID:-}" ] && [ -n "${REPO_ID:-}" ]; then
  ID_PREFIX="repo:${REPO_OWNER}@${OWNER_ID}/${REPO_NAME}@${REPO_ID}"
  SUBJECTS+=("${ID_PREFIX}:ref:refs/heads/main" "${ID_PREFIX}:environment:${ENV_NAME}")
fi
SUBS_JSON="$(printf '%s\n' "${SUBJECTS[@]}" | jq -R . | jq -s .)"
echo "==> Subjects permitidos en la trust policy:"
echo "$SUBS_JSON" | jq -r '.[]' | sed 's/^/    /'

TRUST="$(jq -n --arg oidc "$OIDC_ARN" --argjson subs "$SUBS_JSON" '{
  Version: "2012-10-17",
  Statement: [{
    Effect: "Allow",
    Principal: { Federated: $oidc },
    Action: "sts:AssumeRoleWithWebIdentity",
    Condition: { StringEquals: {
      "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
      "token.actions.githubusercontent.com:sub": $subs
    }}
  }]
}')"

# Permisos del pipeline (mínimo privilegio razonado):
#  - ec2/eks: solo en la región de trabajo
#  - IAM: solo roles eks-<owner>-*, NUNCA su propio rol (sin escalada de privilegios)
#  - AttachRolePolicy: solo las políticas gestionadas de EKS necesarias (no AdministratorAccess)
#  - PassRole: solo hacia eks.amazonaws.com / ec2.amazonaws.com
#  - S3: solo el bucket de state
POLICY="$(jq -n --arg region "$REGION" --arg acct "$ACCOUNT_ID" \
                --arg bucket "$BUCKET" --arg owner "$OWNER_NAME" '{
  Version: "2012-10-17",
  Statement: [
    { Sid: "RegionalNetworkingAndEks", Effect: "Allow",
      Action: ["ec2:*", "eks:*"], Resource: "*",
      Condition: { StringEquals: { "aws:RequestedRegion": $region } } },

    { Sid: "ReadOnlyHelpers", Effect: "Allow",
      Action: ["elasticloadbalancing:Describe*", "autoscaling:Describe*", "logs:DescribeLogGroups"],
      Resource: "*",
      Condition: { StringEquals: { "aws:RequestedRegion": $region } } },

    { Sid: "EksLogGroups", Effect: "Allow", Action: "logs:*",
      Resource: [
        "arn:aws:logs:\($region):\($acct):log-group:/aws/eks/eks-*",
        "arn:aws:logs:\($region):\($acct):log-group:/aws/eks/eks-*:*"
      ] },

    { Sid: "EksRolesLifecycle", Effect: "Allow",
      Action: ["iam:CreateRole", "iam:DeleteRole", "iam:GetRole",
               "iam:ListRolePolicies", "iam:ListAttachedRolePolicies",
               "iam:ListInstanceProfilesForRole"],
      Resource: "arn:aws:iam::\($acct):role/eks-\($owner)-*" },

    { Sid: "AttachOnlyEksManagedPolicies", Effect: "Allow",
      Action: ["iam:AttachRolePolicy", "iam:DetachRolePolicy"],
      Resource: "arn:aws:iam::\($acct):role/eks-\($owner)-*",
      Condition: { ArnEquals: { "iam:PolicyARN": [
        "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy",
        "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController",
        "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
        "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
        "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
        "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly"
      ] } } },

    { Sid: "PassEksRolesToServices", Effect: "Allow",
      Action: "iam:PassRole",
      Resource: "arn:aws:iam::\($acct):role/eks-\($owner)-*",
      Condition: { StringEquals: { "iam:PassedToService": ["eks.amazonaws.com", "ec2.amazonaws.com"] } } },

    { Sid: "StateBucketList", Effect: "Allow",
      Action: ["s3:ListBucket", "s3:GetBucketLocation"],
      Resource: "arn:aws:s3:::\($bucket)" },

    { Sid: "StateObjects", Effect: "Allow",
      Action: ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"],
      Resource: "arn:aws:s3:::\($bucket)/*" }
  ]
}')"

if aws iam get-role --role-name "$ROLE_NAME" >/dev/null 2>&1; then
  echo "==> Rol ${ROLE_NAME} ya existe; verificando trust policy"
  CURRENT="$(aws iam get-role --role-name "$ROLE_NAME" \
    --query 'Role.AssumeRolePolicyDocument' --output json | jq -S -c .)"
  WANTED="$(printf '%s' "$TRUST" | jq -S -c .)"
  if [ "$CURRENT" != "$WANTED" ]; then
    echo "ERROR: la trust policy del rol existente difiere de la esperada." >&2
    echo "No hay iam:UpdateAssumeRolePolicy. Vuelve a ejecutar con ROLE_SUFFIX=-v2 (otro nombre)." >&2
    exit 1
  fi
else
  echo "==> Creando rol ${ROLE_NAME}"
  # Sin --tags: no hay iam:TagRole en esta cuenta
  aws iam create-role --role-name "$ROLE_NAME" \
    --assume-role-policy-document "$TRUST" \
    --description "Rol OIDC de GitHub Actions para el reto Sentinel Split" \
    --max-session-duration 3600 >/dev/null
fi

aws iam put-role-policy --role-name "$ROLE_NAME" \
  --policy-name pipeline-least-privilege --policy-document "$POLICY"

ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"
echo "==> Listo"
echo "    bucket   : ${BUCKET}"
echo "    role_arn : ${ROLE_ARN}"

if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  {
    echo "### Bootstrap OK"
    echo "- Bucket de state: \`${BUCKET}\`"
    echo "- Rol OIDC: \`${ROLE_ARN}\`"
    echo ""
    echo "Siguiente paso: crear la variable de repo \`AWS_ROLE_ARN\` con el ARN del rol."
  } >> "$GITHUB_STEP_SUMMARY"
fi
