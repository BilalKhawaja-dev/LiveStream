# Outputs for Kinesis Firehose Module

# Firehose Delivery Stream Outputs
output "streaming_logs_delivery_stream_name" {
  description = "Name of the streaming logs Firehose delivery stream"
  value       = aws_kinesis_firehose_delivery_stream.streaming_logs.name
}

output "streaming_logs_delivery_stream_arn" {
  description = "ARN of the streaming logs Firehose delivery stream"
  value       = aws_kinesis_firehose_delivery_stream.streaming_logs.arn
}

output "application_logs_delivery_stream_name" {
  description = "Name of the application logs Firehose delivery stream"
  value       = aws_kinesis_firehose_delivery_stream.application_logs.name
}

output "application_logs_delivery_stream_arn" {
  description = "ARN of the application logs Firehose delivery stream"
  value       = aws_kinesis_firehose_delivery_stream.application_logs.arn
}

output "infrastructure_logs_delivery_stream_name" {
  description = "Name of the infrastructure logs Firehose delivery stream"
  value       = aws_kinesis_firehose_delivery_stream.infrastructure_logs.name
}

output "infrastructure_logs_delivery_stream_arn" {
  description = "ARN of the infrastructure logs Firehose delivery stream"
  value       = aws_kinesis_firehose_delivery_stream.infrastructure_logs.arn
}

# IAM Role Output
output "firehose_delivery_role_arn" {
  description = "ARN of the Firehose delivery IAM role"
  value       = aws_iam_role.firehose_delivery_role.arn
}

# Consolidated Outputs
output "delivery_stream_names" {
  description = "Map of all Firehose delivery stream names"
  value = {
    streaming_logs      = aws_kinesis_firehose_delivery_stream.streaming_logs.name
    application_logs    = aws_kinesis_firehose_delivery_stream.application_logs.name
    infrastructure_logs = aws_kinesis_firehose_delivery_stream.infrastructure_logs.name
  }
}

output "delivery_stream_arns" {
  description = "Map of all Firehose delivery stream ARNs"
  value = {
    streaming_logs      = aws_kinesis_firehose_delivery_stream.streaming_logs.arn
    application_logs    = aws_kinesis_firehose_delivery_stream.application_logs.arn
    infrastructure_logs = aws_kinesis_firehose_delivery_stream.infrastructure_logs.arn
  }
}

# Enhanced Firehose Outputs
output "enhanced_streaming_logs_delivery_stream_name" {
  description = "Name of the enhanced streaming logs Firehose delivery stream"
  value       = aws_kinesis_firehose_delivery_stream.enhanced_streaming_logs.name
}

output "enhanced_streaming_logs_delivery_stream_arn" {
  description = "ARN of the enhanced streaming logs Firehose delivery stream"
  value       = aws_kinesis_firehose_delivery_stream.enhanced_streaming_logs.arn
}

# Alarm Outputs
output "firehose_alarm_names" {
  description = "Map of Firehose CloudWatch alarm names"
  value = var.enable_firehose_alarms ? {
    delivery_errors  = aws_cloudwatch_metric_alarm.firehose_delivery_errors[0].alarm_name
    delivery_success = aws_cloudwatch_metric_alarm.firehose_delivery_success[0].alarm_name
  } : {}
}