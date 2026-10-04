locals {
  common_tags = {
    Project     = "sentinel-split"
    Environment = var.environment
    Owner       = var.owner_name
    ManagedBy   = "terraform"
  }

  # El rol del pipeline solo puede gestionar roles eks-<owner>-* (en minúsculas)
  iam_owner = lower(var.owner_name)
}

########################################
# Redes
########################################

module "network_gateway" {
  source = "./modules/networking"

  name         = "vpc-gateway"
  cidr_block   = var.vpc_gateway_cidr
  azs          = var.availability_zones
  cluster_name = var.gateway_cluster_name
  tags         = local.common_tags
}

module "network_backend" {
  source = "./modules/networking"

  name         = "vpc-backend"
  cidr_block   = var.vpc_backend_cidr
  azs          = var.availability_zones
  cluster_name = var.backend_cluster_name
  tags         = local.common_tags
}

########################################
# Peering gateway <-> backend (rutas en ambos sentidos)
########################################

module "peering" {
  source = "./modules/peering"

  name                      = "sentinel-gateway-backend"
  requester_vpc_id          = module.network_gateway.vpc_id
  requester_vpc_cidr        = module.network_gateway.vpc_cidr_block
  requester_route_table_ids = module.network_gateway.private_route_table_ids
  accepter_vpc_id           = module.network_backend.vpc_id
  accepter_vpc_cidr         = module.network_backend.vpc_cidr_block
  accepter_route_table_ids  = module.network_backend.private_route_table_ids
  tags                      = local.common_tags
}

########################################
# Clusters EKS (uno por VPC)
########################################

module "eks_gateway" {
  source = "./modules/eks"

  cluster_name    = var.gateway_cluster_name
  iam_role_prefix = "eks-${local.iam_owner}-gateway"
  subnet_ids      = module.network_gateway.private_subnet_ids
  tags            = local.common_tags
}

module "eks_backend" {
  source = "./modules/eks"

  cluster_name    = var.backend_cluster_name
  iam_role_prefix = "eks-${local.iam_owner}-backend"
  subnet_ids      = module.network_backend.private_subnet_ids
  tags            = local.common_tags

  # Solo la VPC gateway (vía peering) puede llegar a los NodePorts del backend
  node_ingress_cidrs = [module.network_gateway.vpc_cidr_block]

  depends_on = [module.peering]
}
