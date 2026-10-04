output "peering_connection_id" {
  description = "ID de la conexión de peering"
  value       = aws_vpc_peering_connection.this.id
}
