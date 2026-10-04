output "cluster_name" {
  description = "Nombre del cluster"
  value       = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  description = "Endpoint de la API de Kubernetes"
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_security_group_id" {
  description = "Security group del cluster (adjunto a los nodos)"
  value       = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

output "cluster_role_arn" {
  description = "ARN del rol del cluster"
  value       = aws_iam_role.cluster.arn
}

output "node_role_arn" {
  description = "ARN del rol de los nodos"
  value       = aws_iam_role.node.arn
}
