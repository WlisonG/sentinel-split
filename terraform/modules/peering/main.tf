# Rangos de las dos VPCs como enteros, para detectar solapamientos
# (Terraform no tiene cidrcontains, así que se calcula a mano).
locals {
  requester_start = sum([for i, o in split(".", cidrhost(var.requester_vpc_cidr, 0)) : tonumber(o) * pow(256, 3 - i)])
  requester_end   = local.requester_start + pow(2, 32 - tonumber(split("/", var.requester_vpc_cidr)[1])) - 1
  accepter_start  = sum([for i, o in split(".", cidrhost(var.accepter_vpc_cidr, 0)) : tonumber(o) * pow(256, 3 - i)])
  accepter_end    = local.accepter_start + pow(2, 32 - tonumber(split("/", var.accepter_vpc_cidr)[1])) - 1
  cidrs_overlap   = local.requester_start <= local.accepter_end && local.accepter_start <= local.requester_end
}

# Misma cuenta y región: auto_accept evita un recurso de aceptación aparte.
resource "aws_vpc_peering_connection" "this" {
  vpc_id      = var.requester_vpc_id
  peer_vpc_id = var.accepter_vpc_id
  auto_accept = true

  tags = merge(var.tags, { Name = var.name })

  lifecycle {
    precondition {
      condition     = !local.cidrs_overlap
      error_message = "Los CIDR de las dos VPCs se solapan; el peering no es posible."
    }
  }
}

# count y no for_each: los IDs de las route tables solo se conocen tras el apply.
resource "aws_route" "requester_to_accepter" {
  count = length(var.requester_route_table_ids)

  route_table_id            = var.requester_route_table_ids[count.index]
  destination_cidr_block    = var.accepter_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.this.id
}

resource "aws_route" "accepter_to_requester" {
  count = length(var.accepter_route_table_ids)

  route_table_id            = var.accepter_route_table_ids[count.index]
  destination_cidr_block    = var.requester_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.this.id
}
