output "gateway_vpc_id" {
  description = "ID de vpc-gateway"
  value       = module.network_gateway.vpc_id
}

output "backend_vpc_id" {
  description = "ID de vpc-backend"
  value       = module.network_backend.vpc_id
}

output "gateway_nat_public_ip" {
  description = "IP pública de salida de vpc-gateway"
  value       = module.network_gateway.nat_public_ip
}

output "backend_nat_public_ip" {
  description = "IP pública de salida de vpc-backend"
  value       = module.network_backend.nat_public_ip
}
