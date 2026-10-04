output "vpc_id" {
  description = "ID de la VPC"
  value       = aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "CIDR de la VPC"
  value       = aws_vpc.this.cidr_block
}

output "private_subnet_ids" {
  description = "IDs de las subnets privadas, en el orden de var.azs"
  value       = [for az in var.azs : aws_subnet.private[az].id]
}

output "public_subnet_ids" {
  description = "IDs de las subnets públicas, en el orden de var.azs"
  value       = [for az in var.azs : aws_subnet.public[az].id]
}

output "private_route_table_ids" {
  description = "Route tables privadas (lista, para que el peering añada sus rutas)"
  value       = [aws_route_table.private.id]
}

output "nat_gateway_id" {
  description = "ID del NAT Gateway"
  value       = aws_nat_gateway.this.id
}

output "nat_public_ip" {
  description = "IP pública de salida de la VPC"
  value       = aws_eip.nat.public_ip
}
