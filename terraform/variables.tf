########################################
# General
########################################

variable "aws_region" {
  type        = string
  default     = "eu-west-1"
  description = "Región principal de AWS (la política de la cuenta solo permite eu-west-1)"

  validation {
    condition     = var.aws_region == "eu-west-1"
    error_message = "Esta cuenta solo permite operar en eu-west-1."
  }
}

variable "environment" {
  type        = string
  default     = "production"
  description = "Entorno de ejecución"
}

variable "owner_name" {
  type        = string
  default     = "wilson"
  description = "Identificador del candidato para evitar colisiones (cuenta compartida)"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,19}$", var.owner_name))
    error_message = "owner_name debe ir en minúsculas, números o guiones (2-20 caracteres): se usa en nombres de roles y buckets."
  }
}

########################################
# Red
########################################

variable "vpc_gateway_cidr" {
  type        = string
  default     = "10.0.0.0/16"
  description = "CIDR de vpc-gateway (no debe solaparse con vpc-backend, o el peering falla)"

  validation {
    condition     = can(cidrhost(var.vpc_gateway_cidr, 0))
    error_message = "vpc_gateway_cidr debe ser un CIDR válido."
  }
}

variable "vpc_backend_cidr" {
  type        = string
  default     = "10.1.0.0/16"
  description = "CIDR de vpc-backend (no debe solaparse con vpc-gateway)"

  validation {
    condition     = can(cidrhost(var.vpc_backend_cidr, 0))
    error_message = "vpc_backend_cidr debe ser un CIDR válido."
  }
}

variable "availability_zones" {
  type        = list(string)
  default     = ["eu-west-1a", "eu-west-1b"]
  description = "AZs donde se crean las subnets (mínimo 2)"

  validation {
    condition     = length(var.availability_zones) >= 2
    error_message = "Se necesitan al menos 2 zonas de disponibilidad."
  }
}

########################################
# EKS
########################################

variable "gateway_cluster_name" {
  type        = string
  default     = "eks-gateway"
  description = "Nombre del cluster EKS del gateway (nombre exigido por el enunciado)"
}

variable "backend_cluster_name" {
  type        = string
  default     = "eks-backend"
  description = "Nombre del cluster EKS del backend (nombre exigido por el enunciado)"
}

variable "kubernetes_version" {
  type        = string
  default     = null
  description = "Versión de Kubernetes. null = versión por defecto vigente de EKS"
}

variable "node_instance_type" {
  type        = string
  default     = "t3.medium"
  description = "Tipo de instancia de los managed node groups (t3.small solo admite 11 pods por nodo)"
}

variable "node_ami_type" {
  type        = string
  default     = "AL2023_x86_64_STANDARD"
  description = "AMI de los nodos, explícita para no depender de SSM (ssm:* no está permitido)"
}

variable "node_min_size" {
  type        = number
  default     = 1
  description = "Mínimo de nodos por cluster"
}

variable "node_desired_size" {
  type        = number
  default     = 2
  description = "Nodos deseados por cluster (2 = uno por AZ; baja a 1 para reducir costos)"

  validation {
    condition     = var.node_desired_size >= var.node_min_size && var.node_desired_size <= var.node_max_size
    error_message = "node_desired_size debe estar entre node_min_size y node_max_size."
  }
}

variable "node_max_size" {
  type        = number
  default     = 3
  description = "Máximo de nodos por cluster"
}

########################################
# Aplicación
########################################

variable "backend_node_port" {
  type        = number
  default     = 30080
  description = "NodePort fijo del Service del backend; es el único puerto que abre el security group"

  validation {
    condition     = var.backend_node_port >= 30000 && var.backend_node_port <= 32767
    error_message = "backend_node_port debe estar en el rango NodePort 30000-32767."
  }
}
