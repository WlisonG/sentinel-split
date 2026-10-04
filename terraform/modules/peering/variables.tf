variable "name" {
  type        = string
  description = "Nombre lógico del peering (tag Name)"
}

variable "requester_vpc_id" {
  type        = string
  description = "VPC que solicita el peering"
}

variable "requester_vpc_cidr" {
  type        = string
  description = "CIDR de la VPC solicitante"
}

variable "requester_route_table_ids" {
  type        = list(string)
  description = "Route tables de la VPC solicitante que recibirán la ruta hacia la VPC aceptante"
}

variable "accepter_vpc_id" {
  type        = string
  description = "VPC que acepta el peering (misma cuenta y región)"
}

variable "accepter_vpc_cidr" {
  type        = string
  description = "CIDR de la VPC aceptante"
}

variable "accepter_route_table_ids" {
  type        = list(string)
  description = "Route tables de la VPC aceptante que recibirán la ruta hacia la VPC solicitante"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags comunes"
}
