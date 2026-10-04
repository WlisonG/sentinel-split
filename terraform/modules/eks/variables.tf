variable "cluster_name" {
  type        = string
  description = "Nombre del cluster EKS (ej. eks-gateway). Debe empezar por eks-"

  validation {
    condition     = startswith(var.cluster_name, "eks-")
    error_message = "El nombre del cluster debe empezar por eks-."
  }
}

variable "iam_role_prefix" {
  type        = string
  description = "Prefijo de los roles IAM (ej. eks-wilson-gateway). Debe empezar por eks-"

  validation {
    condition     = startswith(var.iam_role_prefix, "eks-")
    error_message = "Solo se pueden crear roles IAM con prefijo eks- (restricción de la cuenta)."
  }
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnets privadas (mínimo 2 AZ) para el control plane y los nodos"

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "EKS necesita subnets en al menos 2 zonas de disponibilidad."
  }
}

variable "cluster_version" {
  type        = string
  default     = "1.33"
  description = "Versión de Kubernetes. Verifica que siga soportada: aws eks describe-cluster-versions"
}

variable "node_instance_types" {
  type        = list(string)
  default     = ["t3.medium"]
  description = "Tipos de instancia del node group"
}

variable "node_desired_size" {
  type        = number
  default     = 2
  description = "Nodos deseados"
}

variable "node_min_size" {
  type        = number
  default     = 1
  description = "Nodos mínimos"
}

variable "node_max_size" {
  type        = number
  default     = 3
  description = "Nodos máximos"
}

variable "endpoint_public_access" {
  type        = bool
  default     = true
  description = "Endpoint público de la API. Necesario para que los runners de GitHub puedan hacer kubectl"
}

variable "public_access_cidrs" {
  type        = list(string)
  default     = ["0.0.0.0/0"]
  description = "CIDR con acceso al endpoint público (los runners de GitHub usan rangos amplios y cambiantes)"
}

variable "node_ingress_cidrs" {
  type        = list(string)
  default     = []
  description = "CIDR externos (ej. la VPC peered) autorizados a llegar a los NodePorts del cluster"
}

variable "node_ingress_port" {
  type        = number
  default     = 30080
  description = "NodePort fijo del Service que se abre a node_ingress_cidrs (mínimo privilegio: un solo puerto)"
}

variable "log_retention_days" {
  type        = number
  default     = 7
  description = "Retención de los logs del control plane"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags comunes. No se aplican a roles IAM (no hay iam:TagRole en esta cuenta)"
}
