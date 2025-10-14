# VPC Module Outputs

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.main.id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = aws_subnet.private[*].id
}

output "database_subnet_ids" {
  description = "IDs of the database subnets"
  value       = aws_subnet.database[*].id
}

output "aurora_security_group_id" {
  description = "ID of the Aurora security group"
  value       = aws_security_group.aurora.id
}

output "aurora_subnet_group_name" {
  description = "Name of the Aurora DB subnet group"
  value       = aws_db_subnet_group.aurora.name
}

output "ecs_security_group_id" {
  description = "ID of the ECS security group"
  value       = aws_security_group.ecs.id
}

output "public_route_table_id" {
  description = "ID of the public route table"
  value       = aws_route_table.public.id
}

output "private_route_table_id" {
  description = "ID of the private route table"
  value       = aws_route_table.private.id
}

output "database_route_table_id" {
  description = "ID of the database route table"
  value       = aws_route_table.database.id
}

output "nat_gateway_id" {
  description = "ID of the NAT Gateway (if enabled)"
  value       = var.enable_nat_gateway ? aws_nat_gateway.main[0].id : null
}

output "nat_gateway_public_ip" {
  description = "Public IP of the NAT Gateway (if enabled)"
  value       = var.enable_nat_gateway ? aws_eip.nat[0].public_ip : null
}

output "vpc_endpoints" {
  description = "Map of VPC endpoint IDs"
  value = var.enable_vpc_endpoints ? {
    s3       = aws_vpc_endpoint.s3[0].id
    dynamodb = aws_vpc_endpoint.dynamodb[0].id
    ecr_api  = aws_vpc_endpoint.ecr_api[0].id
    ecr_dkr  = aws_vpc_endpoint.ecr_dkr[0].id
    logs     = aws_vpc_endpoint.logs[0].id
  } : {}
}

# Network configuration summary
output "network_configuration" {
  description = "Summary of network configuration"
  value = {
    vpc_id                = aws_vpc.main.id
    vpc_cidr              = aws_vpc.main.cidr_block
    availability_zones    = var.availability_zones
    public_subnets        = length(aws_subnet.public)
    private_subnets       = length(aws_subnet.private)
    database_subnets      = length(aws_subnet.database)
    aurora_security_group = aws_security_group.aurora.id
    aurora_subnet_group   = aws_db_subnet_group.aurora.name
    ecs_security_group    = aws_security_group.ecs.id
    nat_gateway_enabled   = var.enable_nat_gateway
    vpc_endpoints_enabled = var.enable_vpc_endpoints
    cost_optimization     = !var.enable_nat_gateway && var.enable_vpc_endpoints
  }
}