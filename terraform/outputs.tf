output "gateway_cluster_name" {
  description = "Nombre del cluster EKS del gateway"
  value       = module.eks_gateway.cluster_name
}

output "backend_cluster_name" {
  description = "Nombre del cluster EKS del backend"
  value       = module.eks_backend.cluster_name
}

output "gateway_vpc_cidr" {
  description = "CIDR de vpc-gateway (se usa para restringir el backend)"
  value       = module.network_gateway.vpc_cidr_block
}

output "backend_vpc_cidr" {
  description = "CIDR de vpc-backend"
  value       = module.network_backend.vpc_cidr_block
}

output "vpc_ids" {
  description = "IDs de las VPCs"
  value = {
    gateway = module.network_gateway.vpc_id
    backend = module.network_backend.vpc_id
  }
}

output "peering_connection_id" {
  description = "ID del VPC peering"
  value       = module.peering.peering_connection_id
}

output "nat_public_ips" {
  description = "IPs de salida (NAT) de cada VPC"
  value = {
    gateway = module.network_gateway.nat_public_ip
    backend = module.network_backend.nat_public_ip
  }
}
