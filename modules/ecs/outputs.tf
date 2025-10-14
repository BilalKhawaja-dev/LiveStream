output "cluster_id" {
  description = "ECS cluster ID"
  value       = aws_ecs_cluster.main.id
}

output "cluster_arn" {
  description = "ECS cluster ARN"
  value       = aws_ecs_cluster.main.arn
}

output "cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.main.name
}

output "ecr_repository_urls" {
  description = "ECR repository URLs"
  value       = { for k, v in aws_ecr_repository.apps : k => v.repository_url }
}

output "service_arns" {
  description = "ECS service ARNs"
  value       = { for k, v in aws_ecs_service.apps : k => v.id }
}

output "task_definition_arns" {
  description = "ECS task definition ARNs"
  value       = { for k, v in aws_ecs_task_definition.apps : k => v.arn }
}