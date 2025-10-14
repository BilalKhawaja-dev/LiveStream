# Outputs for Support System Module

# Lambda Functions
output "ticket_filter_function_name" {
  description = "Ticket filter Lambda function name"
  value       = aws_lambda_function.ticket_filter.function_name
}

output "ai_support_function_name" {
  description = "AI support Lambda function name"
  value       = aws_lambda_function.ai_support.function_name
}

# SNS Topics
output "sns_topic_arns" {
  description = "Map of SNS topic ARNs for support categories"
  value = {
    general   = aws_sns_topic.support_general.arn
    technical = aws_sns_topic.support_technical.arn
    billing   = aws_sns_topic.support_billing.arn
    urgent    = aws_sns_topic.support_urgent.arn
  }
}

# Configuration Summary
output "support_system_configuration" {
  description = "Support system configuration summary"
  value = {
    functions = {
      ticket_filter = aws_lambda_function.ticket_filter.function_name
      ai_support    = aws_lambda_function.ai_support.function_name
    }

    categories = ["general", "technical", "billing", "urgent"]

    features = [
      "Smart ticket filtering",
      "AI-powered responses",
      "Automatic routing",
      "Email notifications",
      "Performance monitoring"
    ]
  }
}