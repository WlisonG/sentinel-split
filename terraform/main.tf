locals {
  common_tags = {
    Project     = "sentinel-split"
    Environment = var.environment
    Owner       = var.owner_name
    ManagedBy   = "terraform"
  }
}

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
