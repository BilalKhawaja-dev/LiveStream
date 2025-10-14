output "websocket_api_endpoint" {
  description = "WebSocket API endpoint"
  value       = "${aws_apigatewayv2_api.chat.api_endpoint}/${aws_apigatewayv2_stage.chat.name}"
}

output "websocket_api_id" {
  description = "WebSocket API ID"
  value       = aws_apigatewayv2_api.chat.id
}