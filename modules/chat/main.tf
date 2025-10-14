# API Gateway for WebSocket chat
resource "aws_apigatewayv2_api" "chat" {
  name                       = "${var.project_name}-${var.environment}-chat"
  protocol_type              = "WEBSOCKET"
  route_selection_expression = "$request.body.action"

  tags = var.tags
}

# WebSocket routes
resource "aws_apigatewayv2_route" "connect" {
  api_id    = aws_apigatewayv2_api.chat.id
  route_key = "$connect"
  target    = "integrations/${aws_apigatewayv2_integration.connect.id}"
}

resource "aws_apigatewayv2_route" "disconnect" {
  api_id    = aws_apigatewayv2_api.chat.id
  route_key = "$disconnect"
  target    = "integrations/${aws_apigatewayv2_integration.disconnect.id}"
}

resource "aws_apigatewayv2_route" "message" {
  api_id    = aws_apigatewayv2_api.chat.id
  route_key = "message"
  target    = "integrations/${aws_apigatewayv2_integration.message.id}"
}

# Lambda integrations
resource "aws_apigatewayv2_integration" "connect" {
  api_id           = aws_apigatewayv2_api.chat.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.chat_connect.invoke_arn
}

resource "aws_apigatewayv2_integration" "disconnect" {
  api_id           = aws_apigatewayv2_api.chat.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.chat_disconnect.invoke_arn
}

resource "aws_apigatewayv2_integration" "message" {
  api_id           = aws_apigatewayv2_api.chat.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.chat_message.invoke_arn
}

# Lambda function source code
data "archive_file" "chat_connect" {
  type        = "zip"
  output_path = "chat_connect.zip"

  source {
    content  = <<EOF
import json
import boto3

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('${var.connections_table_name}')

def handler(event, context):
    connection_id = event['requestContext']['connectionId']
    
    try:
        table.put_item(
            Item={
                'connection_id': connection_id,
                'expires_at': int(context.get_remaining_time_in_millis() / 1000) + 3600
            }
        )
        return {'statusCode': 200}
    except Exception as e:
        return {'statusCode': 500, 'body': str(e)}
EOF
    filename = "index.py"
  }
}

data "archive_file" "chat_disconnect" {
  type        = "zip"
  output_path = "chat_disconnect.zip"

  source {
    content  = <<EOF
import json
import boto3

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('${var.connections_table_name}')

def handler(event, context):
    connection_id = event['requestContext']['connectionId']
    
    try:
        table.delete_item(Key={'connection_id': connection_id})
        return {'statusCode': 200}
    except Exception as e:
        return {'statusCode': 500, 'body': str(e)}
EOF
    filename = "index.py"
  }
}

data "archive_file" "chat_message" {
  type        = "zip"
  output_path = "chat_message.zip"

  source {
    content  = <<EOF
import json
import boto3
from datetime import datetime

dynamodb = boto3.resource('dynamodb')
connections_table = dynamodb.Table('${var.connections_table_name}')
messages_table = dynamodb.Table('${var.messages_table_name}')

apigw = boto3.client('apigatewaymanagementapi',
    endpoint_url=f"https://{event['requestContext']['domainName']}/{event['requestContext']['stage']}")

def handler(event, context):
    try:
        body = json.loads(event['body'])
        
        # Store message
        messages_table.put_item(
            Item={
                'stream_id': body['streamId'],
                'timestamp': datetime.now().isoformat(),
                'user_id': body['userId'],
                'username': body['username'],
                'message': body['message'],
                'expires_at': int(datetime.now().timestamp()) + 86400
            }
        )
        
        # Broadcast to all connections
        connections = connections_table.scan()['Items']
        
        for connection in connections:
            try:
                apigw.post_to_connection(
                    ConnectionId=connection['connection_id'],
                    Data=json.dumps({
                        'type': 'message',
                        'id': f"{body['streamId']}-{datetime.now().timestamp()}",
                        'userId': body['userId'],
                        'username': body['username'],
                        'message': body['message'],
                        'timestamp': datetime.now().isoformat(),
                        'streamId': body['streamId']
                    })
                )
            except:
                # Remove stale connection
                connections_table.delete_item(Key={'connection_id': connection['connection_id']})
        
        return {'statusCode': 200}
    except Exception as e:
        return {'statusCode': 500, 'body': str(e)}
EOF
    filename = "index.py"
  }
}

# Lambda functions for chat
resource "aws_lambda_function" "chat_connect" {
  filename         = data.archive_file.chat_connect.output_path
  function_name    = "${var.project_name}-${var.environment}-chat-connect"
  role             = var.lambda_role_arn
  handler          = "index.handler"
  runtime          = "python3.9"
  timeout          = 30
  source_code_hash = data.archive_file.chat_connect.output_base64sha256

  environment {
    variables = {
      CONNECTIONS_TABLE = var.connections_table_name
    }
  }

  tags = var.tags
}

resource "aws_lambda_function" "chat_disconnect" {
  filename         = data.archive_file.chat_disconnect.output_path
  function_name    = "${var.project_name}-${var.environment}-chat-disconnect"
  role             = var.lambda_role_arn
  handler          = "index.handler"
  runtime          = "python3.9"
  timeout          = 30
  source_code_hash = data.archive_file.chat_disconnect.output_base64sha256

  environment {
    variables = {
      CONNECTIONS_TABLE = var.connections_table_name
    }
  }

  tags = var.tags
}

resource "aws_lambda_function" "chat_message" {
  filename         = data.archive_file.chat_message.output_path
  function_name    = "${var.project_name}-${var.environment}-chat-message"
  role             = var.lambda_role_arn
  handler          = "index.handler"
  runtime          = "python3.9"
  timeout          = 30
  source_code_hash = data.archive_file.chat_message.output_base64sha256

  environment {
    variables = {
      CONNECTIONS_TABLE = var.connections_table_name
      MESSAGES_TABLE    = var.messages_table_name
    }
  }

  tags = var.tags
}

# API Gateway deployment
resource "aws_apigatewayv2_deployment" "chat" {
  api_id = aws_apigatewayv2_api.chat.id

  depends_on = [
    aws_apigatewayv2_route.connect,
    aws_apigatewayv2_route.disconnect,
    aws_apigatewayv2_route.message
  ]
}

resource "aws_apigatewayv2_stage" "chat" {
  api_id        = aws_apigatewayv2_api.chat.id
  deployment_id = aws_apigatewayv2_deployment.chat.id
  name          = var.environment

  tags = var.tags
}