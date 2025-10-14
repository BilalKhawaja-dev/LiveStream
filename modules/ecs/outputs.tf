# Outputs for ECS Module

# ECS Cluster
output "cluster_id" {
  description = "ECS cluster ID"
  value       = aws_ecs_cluster.main.id
}

output "cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.main.name
}

output "cluster_arn" {
  description = "ECS cluster ARN"
  value       = aws_ecs_cluster.main.arn
}

# Service Discovery
output "service_discovery_namespace_id" {
  description = "Service discovery namespace ID"
  value       = aws_service_discovery_private_dns_namespace.main.id
}

output "service_discovery_namespace_name" {
  description = "Service discovery namespace name"
  value       = aws_service_discovery_private_dns_namespace.main.name
}

output "service_discovery_services" {
  description = "Map of service discovery service details"
  value = {
    for k, v in aws_service_discovery_service.services : k => {
      id   = v.id
      arn  = v.arn
      name = v.name
    }
  }
}

# ECS Services
output "ecs_services" {
  description = "Map of ECS service details"
  value = {
    for k, v in aws_ecs_service.services : k => {
      id            = v.id
      name          = v.name
      cluster       = v.cluster
      desired_count = v.desired_count
    }
  }
}

output "ecs_service_names" {
  description = "List of ECS service names"
  value       = [for service in aws_ecs_service.services : service.name]
}

output "ecs_service_arns" {
  description = "Map of ECS service ARNs"
  value = {
    for k, v in aws_ecs_service.services : k => v.id
  }
}

# Task Definitions
output "task_definitions" {
  description = "Map of ECS task definition details"
  value = {
    for k, v in aws_ecs_task_definition.services : k => {
      arn      = v.arn
      family   = v.family
      revision = v.revision
    }
  }
}

# Target Groups (managed by ALB module)
output "target_group_arns_used" {
  description = "Map of target group ARNs used by ECS services"
  value       = var.target_group_arns
}

# Security Groups
output "ecs_security_group_id" {
  description = "Security group ID for ECS services"
  value       = aws_security_group.ecs_services.id
}

# IAM Roles
output "task_execution_role_arn" {
  description = "ECS task execution role ARN"
  value       = aws_iam_role.ecs_task_execution.arn
}

output "task_role_arn" {
  description = "ECS task role ARN"
  value       = aws_iam_role.ecs_task.arn
}

# Auto Scaling
output "autoscaling_targets" {
  description = "Map of auto scaling target details"
  value = {
    for k, v in aws_appautoscaling_target.services : k => {
      resource_id        = v.resource_id
      scalable_dimension = v.scalable_dimension
      min_capacity       = v.min_capacity
      max_capacity       = v.max_capacity
    }
  }
}

# CloudWatch Log Groups
output "log_groups" {
  description = "Map of CloudWatch log group names"
  value = {
    for k, v in aws_cloudwatch_log_group.services : k => v.name
  }
}

output "exec_log_group_name" {
  description = "CloudWatch log group name for ECS Exec"
  value       = aws_cloudwatch_log_group.ecs_exec.name
}

# Configuration Summary
output "ecs_configuration_summary" {
  description = "Summary of ECS configuration"
  value = {
    cluster_name              = aws_ecs_cluster.main.name
    total_services            = length(local.frontend_apps)
    container_insights        = var.enable_container_insights
    service_discovery_enabled = true
    auto_scaling_enabled      = true
    spot_instances_enabled    = var.enable_spot_instances

    services = {
      for k, v in local.frontend_apps : k => {
        port          = v.port
        cpu           = v.cpu
        memory        = v.memory
        desired_count = v.desired_count
        priority      = v.priority
      }
    }

    capacity_providers = {
      fargate = {
        base   = var.fargate_base_capacity
        weight = var.fargate_weight
      }
      fargate_spot = {
        base   = var.fargate_spot_base_capacity
        weight = var.fargate_spot_weight
      }
    }

    auto_scaling = {
      min_capacity        = var.min_capacity
      max_capacity        = var.max_capacity
      cpu_target_value    = var.cpu_target_value
      memory_target_value = var.memory_target_value
      scale_in_cooldown   = var.scale_in_cooldown
      scale_out_cooldown  = var.scale_out_cooldown
    }
  }
}

# Service URLs (for internal communication)
output "service_urls" {
  description = "Internal service URLs for service-to-service communication"
  value = {
    for k, v in local.frontend_apps : k => "http://${k}.${aws_service_discovery_private_dns_namespace.main.name}:${v.port}"
  }
}