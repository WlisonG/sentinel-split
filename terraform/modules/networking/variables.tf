variable "name" {
  type        = string
  description = "Nombre lógico de la VPC (ej. vpc-gateway, vpc-backend)"
}

variable "cidr_block" {
  type        = string
  description = "CIDR de la VPC (debe ser /18 o más grande para alojar las subnets calculadas)"

  validation {
    condition     = can(cidrhost(var.cidr_block, 0)) && tonumber(split("/", var.cidr_block)[1]) <= 18
    error_message = "cidr_block debe ser un CIDR válido con prefijo /18 o menor (ej. 10.0.0.0/16)."
  }
}

variable "azs" {
  type        = list(string)
  description = "Zonas de disponibilidad donde se crean las subnets (mínimo 2). La primera aloja el NAT Gateway"

  validation {
    condition     = length(var.azs) >= 2
    error_message = "Se necesitan al menos 2 zonas de disponibilidad."
  }
}

variable "cluster_name" {
  type        = string
  description = "Nombre del cluster EKS que usará esta VPC; se usa en los tags de las subnets"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags comunes. No se aplican a recursos IAM (no hay iam:TagRole en esta cuenta)"
}
