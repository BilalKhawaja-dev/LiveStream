# Lambda Functions Module for Streaming Platform Business Logic

# Data sources
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# Lambda Layer for shared dependencies
resource "aws_lambda_layer_version" "shared_dependencies" {
  filename    = "${path.module}/layers/shared-dependencies.zip"
  layer_name  = "${var.project_name}-${var.environment}-shared-dependencies"
  description = "Shared dependencies for streaming platform Lambda functions"

  compatible_runtimes = ["python3.9", "python3.10"]

  depends_on = [data.archive_file.shared_dependencies_layer]
}

# Create shared dependencies layer
data "archive_file" "shared_dependencies_layer" {
  type        = "zip"
  source_dir  = "${path.module}/layers/python_layer"
  output_path = "${path.module}/layers/shared-dependencies.zip"
}

# Authentication Handler Lambda
resource "aws_lambda_function" "auth_handler" {
  filename      = "${path.module}/functions/auth_handler.zip"
  function_name = "${var.project_name}-${var.environment}-auth-handler"
  role          = aws_iam_role.lambda_auth_role.arn
  handler       = "auth_handler.lambda_handler"
  runtime       = "python3.9"
  timeout       = 30
  memory_size   = 256

  layers = [aws_lambda_layer_version.shared_dependencies.arn]

  environment {
    variables = {
      COGNITO_USER_POOL_ID = var.cognito_user_pool_id
      COGNITO_CLIENT_ID    = var.cognito_client_id
      JWT_SECRET_ARN       = var.jwt_secret_arn
      AURORA_CLUSTER_ARN   = var.aurora_cluster_arn
      AURORA_SECRET_ARN    = var.aurora_secret_arn
      ENVIRONMENT          = var.environment
      LOG_LEVEL            = var.log_level
    }
  }

  # Remove VPC config for auth handler to improve cold start performance
  # vpc_config {
  #   subnet_ids         = var.private_subnet_ids
  #   security_group_ids = [var.lambda_security_group_id]
  # }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_auth_vpc,
    aws_cloudwatch_log_group.auth_handler
  ]

  tags = var.tags
}

# Streaming Management Lambda
resource "aws_lambda_function" "streaming_handler" {
  filename      = "${path.module}/functions/streaming_handler.zip"
  function_name = "${var.project_name}-${var.environment}-streaming-handler"
  role          = aws_iam_role.lambda_streaming_role.arn
  handler       = "streaming_handler.lambda_handler"
  runtime       = "python3.9"
  timeout       = 300
  memory_size   = 512

  layers = [aws_lambda_layer_version.shared_dependencies.arn]

  environment {
    variables = {
      AURORA_CLUSTER_ARN      = var.aurora_cluster_arn
      AURORA_SECRET_ARN       = var.aurora_secret_arn
      DYNAMODB_STREAMS_TABLE  = var.dynamodb_streams_table
      MEDIALIVE_ROLE_ARN      = var.medialive_role_arn
      S3_MEDIA_BUCKET         = var.s3_media_bucket
      CLOUDFRONT_DISTRIBUTION = var.cloudfront_distribution_id
      ENVIRONMENT             = var.environment
      LOG_LEVEL               = var.log_level
    }
  }

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.lambda_security_group_id]
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_streaming_vpc,
    aws_cloudwatch_log_group.streaming_handler
  ]

  tags = var.tags
}

# Payment Processing Lambda - DISABLED FOR DEVELOPMENT
# Removed to simplify development workflow
# Users will be manually assigned Bronze/Silver/Gold tiers via admin portal

# Support Ticket Management Lambda
resource "aws_lambda_function" "support_handler" {
  filename      = "${path.module}/functions/support_handler.zip"
  function_name = "${var.project_name}-${var.environment}-support-handler"
  role          = aws_iam_role.lambda_support_role.arn
  handler       = "support_handler.lambda_handler"
  runtime       = "python3.9"
  timeout       = 60
  memory_size   = 512

  layers = [aws_lambda_layer_version.shared_dependencies.arn]

  environment {
    variables = {
      AURORA_CLUSTER_ARN     = var.aurora_cluster_arn
      AURORA_SECRET_ARN      = var.aurora_secret_arn
      DYNAMODB_TICKETS_TABLE = var.dynamodb_tickets_table
      BEDROCK_MODEL_ID       = var.bedrock_model_id
      SNS_TOPIC_ARN          = var.support_notifications_topic_arn
      ENVIRONMENT            = var.environment
      LOG_LEVEL              = var.log_level
    }
  }

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.lambda_security_group_id]
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_support_vpc,
    aws_cloudwatch_log_group.support_handler
  ]

  tags = var.tags
}

# Analytics Handler Lambda
resource "aws_lambda_function" "analytics_handler" {
  filename      = "${path.module}/functions/analytics_handler.zip"
  function_name = "${var.project_name}-${var.environment}-analytics-handler"
  role          = aws_iam_role.lambda_analytics_role.arn
  handler       = "analytics_handler.lambda_handler"
  runtime       = "python3.9"
  timeout       = 300
  memory_size   = 1024

  layers = [aws_lambda_layer_version.shared_dependencies.arn]

  environment {
    variables = {
      AURORA_CLUSTER_ARN       = var.aurora_cluster_arn
      AURORA_SECRET_ARN        = var.aurora_secret_arn
      DYNAMODB_ANALYTICS_TABLE = var.dynamodb_analytics_table
      ATHENA_DATABASE          = var.athena_database_name
      ATHENA_WORKGROUP         = var.athena_workgroup_name
      S3_RESULTS_BUCKET        = var.athena_results_bucket
      ENVIRONMENT              = var.environment
      LOG_LEVEL                = var.log_level
    }
  }

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.lambda_security_group_id]
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_analytics_vpc,
    aws_cloudwatch_log_group.analytics_handler
  ]

  tags = var.tags
}

# Content Moderation Lambda
resource "aws_lambda_function" "moderation_handler" {
  filename      = "${path.module}/functions/moderation_handler.zip"
  function_name = "${var.project_name}-${var.environment}-moderation-handler"
  role          = aws_iam_role.lambda_moderation_role.arn
  handler       = "moderation_handler.lambda_handler"
  runtime       = "python3.9"
  timeout       = 60
  memory_size   = 512

  layers = [aws_lambda_layer_version.shared_dependencies.arn]

  environment {
    variables = {
      REKOGNITION_MIN_CONFIDENCE = var.rekognition_confidence_threshold
      COMPREHEND_MIN_CONFIDENCE  = var.comprehend_confidence_threshold
      AURORA_CLUSTER_ARN         = var.aurora_cluster_arn
      AURORA_SECRET_ARN          = var.aurora_secret_arn
      SNS_TOPIC_ARN              = var.moderation_notifications_topic_arn
      ENVIRONMENT                = var.environment
      LOG_LEVEL                  = var.log_level
    }
  }

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.lambda_security_group_id]
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_moderation_vpc,
    aws_cloudwatch_log_group.moderation_handler
  ]

  tags = var.tags
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "auth_handler" {
  name              = "/aws/lambda/${var.project_name}-${var.environment}-auth-handler"
  retention_in_days = var.log_retention_days
  # Temporarily disable KMS encryption to avoid dependency issues
  # kms_key_id        = var.kms_key_arn

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "streaming_handler" {
  name              = "/aws/lambda/${var.project_name}-${var.environment}-streaming-handler"
  retention_in_days = var.log_retention_days
  # Temporarily disable KMS encryption to avoid dependency issues
  # kms_key_id        = var.kms_key_arn

  tags = var.tags
}

# Payment handler log group - DISABLED FOR DEVELOPMENT

resource "aws_cloudwatch_log_group" "support_handler" {
  name              = "/aws/lambda/${var.project_name}-${var.environment}-support-handler"
  retention_in_days = var.log_retention_days
  # Temporarily disable KMS encryption to avoid dependency issues
  # kms_key_id        = var.kms_key_arn

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "analytics_handler" {
  name              = "/aws/lambda/${var.project_name}-${var.environment}-analytics-handler"
  retention_in_days = var.log_retention_days
  # Temporarily disable KMS encryption to avoid dependency issues
  # kms_key_id        = var.kms_key_arn

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "moderation_handler" {
  name              = "/aws/lambda/${var.project_name}-${var.environment}-moderation-handler"
  retention_in_days = var.log_retention_days
  # Temporarily disable KMS encryption to avoid dependency issues
  # kms_key_id        = var.kms_key_arn

  tags = var.tags
}

# Create Lambda deployment packages
data "archive_file" "auth_handler" {
  type        = "zip"
  source_file = "${path.module}/functions/auth_handler.py"
  output_path = "${path.module}/functions/auth_handler.zip"
}

data "archive_file" "streaming_handler" {
  type        = "zip"
  source_file = "${path.module}/functions/streaming_handler.py"
  output_path = "${path.module}/functions/streaming_handler.zip"
}

# Payment handler archive - DISABLED FOR DEVELOPMENT

data "archive_file" "support_handler" {
  type        = "zip"
  source_file = "${path.module}/functions/support_handler.py"
  output_path = "${path.module}/functions/support_handler.zip"
}

data "archive_file" "analytics_handler" {
  type        = "zip"
  source_file = "${path.module}/functions/analytics_handler.py"
  output_path = "${path.module}/functions/analytics_handler.zip"
}

data "archive_file" "moderation_handler" {
  type        = "zip"
  source_file = "${path.module}/functions/moderation_handler.py"
  output_path = "${path.module}/functions/moderation_handler.zip"
}

# IAM Roles for Lambda Functions

# Authentication Lambda IAM Role
resource "aws_iam_role" "lambda_auth_role" {
  name = "${var.project_name}-${var.environment}-lambda-auth-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# Streaming Lambda IAM Role
resource "aws_iam_role" "lambda_streaming_role" {
  name = "${var.project_name}-${var.environment}-lambda-streaming-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# Payment Lambda IAM Role - DISABLED FOR DEVELOPMENT

# Support Lambda IAM Role
resource "aws_iam_role" "lambda_support_role" {
  name = "${var.project_name}-${var.environment}-lambda-support-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# Analytics Lambda IAM Role
resource "aws_iam_role" "lambda_analytics_role" {
  name = "${var.project_name}-${var.environment}-lambda-analytics-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# Moderation Lambda IAM Role
resource "aws_iam_role" "lambda_moderation_role" {
  name = "${var.project_name}-${var.environment}-lambda-moderation-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# IAM Policy Attachments - VPC Access
resource "aws_iam_role_policy_attachment" "lambda_auth_vpc" {
  role       = aws_iam_role.lambda_auth_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_streaming_vpc" {
  role       = aws_iam_role.lambda_streaming_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Payment Lambda VPC policy - DISABLED FOR DEVELOPMENT

resource "aws_iam_role_policy_attachment" "lambda_support_vpc" {
  role       = aws_iam_role.lambda_support_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_analytics_vpc" {
  role       = aws_iam_role.lambda_analytics_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_moderation_vpc" {
  role       = aws_iam_role.lambda_moderation_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Custom IAM Policies for each Lambda function
resource "aws_iam_role_policy" "lambda_auth_policy" {
  name = "${var.project_name}-${var.environment}-lambda-auth-policy"
  role = aws_iam_role.lambda_auth_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cognito-idp:AdminInitiateAuth",
          "cognito-idp:AdminCreateUser",
          "cognito-idp:AdminSetUserPassword",
          "cognito-idp:AdminUpdateUserAttributes",
          "cognito-idp:AdminGetUser",
          "cognito-idp:ListUsers"
        ]
        Resource = "arn:aws:cognito-idp:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:userpool/${var.cognito_user_pool_id}"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = var.jwt_secret_arn
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = var.kms_key_arn
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_streaming_policy" {
  name = "${var.project_name}-${var.environment}-lambda-streaming-policy"
  role = aws_iam_role.lambda_streaming_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "rds-data:ExecuteStatement",
          "rds-data:BatchExecuteStatement",
          "rds-data:BeginTransaction",
          "rds-data:CommitTransaction",
          "rds-data:RollbackTransaction"
        ]
        Resource = var.aurora_cluster_arn
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = "arn:aws:dynamodb:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/${var.dynamodb_streams_table}"
      },
      {
        Effect = "Allow"
        Action = [
          "medialive:CreateChannel",
          "medialive:StartChannel",
          "medialive:StopChannel",
          "medialive:DeleteChannel",
          "medialive:DescribeChannel",
          "medialive:ListChannels"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "arn:aws:s3:::${var.s3_media_bucket}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "cloudfront:CreateInvalidation"
        ]
        Resource = "arn:aws:cloudfront::${data.aws_caller_identity.current.account_id}:distribution/${var.cloudfront_distribution_id}"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = var.aurora_secret_arn
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = var.kms_key_arn
      }
    ]
  })
}

# Payment Lambda IAM Policy - DISABLED FOR DEVELOPMENT

resource "aws_iam_role_policy" "lambda_support_policy" {
  name = "${var.project_name}-${var.environment}-lambda-support-policy"
  role = aws_iam_role.lambda_support_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "rds-data:ExecuteStatement",
          "rds-data:BatchExecuteStatement",
          "rds-data:BeginTransaction",
          "rds-data:CommitTransaction",
          "rds-data:RollbackTransaction"
        ]
        Resource = var.aurora_cluster_arn
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = "arn:aws:dynamodb:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/${var.dynamodb_tickets_table}"
      },
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel"
        ]
        Resource = "arn:aws:bedrock:${data.aws_region.current.name}::foundation-model/${var.bedrock_model_id}"
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = var.support_notifications_topic_arn != "" ? var.support_notifications_topic_arn : "*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = var.aurora_secret_arn
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = var.kms_key_arn
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_analytics_policy" {
  name = "${var.project_name}-${var.environment}-lambda-analytics-policy"
  role = aws_iam_role.lambda_analytics_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "rds-data:ExecuteStatement",
          "rds-data:BatchExecuteStatement",
          "rds-data:BeginTransaction",
          "rds-data:CommitTransaction",
          "rds-data:RollbackTransaction"
        ]
        Resource = var.aurora_cluster_arn
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = "arn:aws:dynamodb:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/${var.dynamodb_analytics_table}"
      },
      {
        Effect = "Allow"
        Action = [
          "athena:StartQueryExecution",
          "athena:GetQueryExecution",
          "athena:GetQueryResults",
          "athena:StopQueryExecution"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "arn:aws:s3:::${var.athena_results_bucket}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "glue:GetDatabase",
          "glue:GetTable",
          "glue:GetPartitions"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = var.aurora_secret_arn
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = var.kms_key_arn
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_moderation_policy" {
  name = "${var.project_name}-${var.environment}-lambda-moderation-policy"
  role = aws_iam_role.lambda_moderation_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "rekognition:DetectModerationLabels",
          "rekognition:DetectText",
          "rekognition:DetectFaces"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "comprehend:DetectSentiment",
          "comprehend:DetectToxicContent",
          "comprehend:DetectPiiEntities"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "rds-data:ExecuteStatement",
          "rds-data:BatchExecuteStatement",
          "rds-data:BeginTransaction",
          "rds-data:CommitTransaction",
          "rds-data:RollbackTransaction"
        ]
        Resource = var.aurora_cluster_arn
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = var.moderation_notifications_topic_arn != "" ? var.moderation_notifications_topic_arn : "*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = var.aurora_secret_arn
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = var.kms_key_arn
      }
    ]
  })
} # JWT
# JWT Middleware Lambda for API Gateway Authorization
resource "aws_lambda_function" "jwt_middleware" {
  filename      = "${path.module}/functions/jwt_middleware.zip"
  function_name = "${var.project_name}-${var.environment}-jwt-middleware"
  role          = aws_iam_role.lambda_auth_role.arn
  handler       = "jwt_middleware.lambda_handler"
  runtime       = "python3.9"
  timeout       = 30
  memory_size   = 256

  source_code_hash = data.archive_file.jwt_middleware.output_base64sha256

  # Remove VPC config for JWT middleware to improve performance
  # vpc_config {
  #   subnet_ids         = var.private_subnet_ids
  #   security_group_ids = [var.lambda_security_group_id]
  # }

  environment {
    variables = {
      LOG_LEVEL                   = var.log_level
      COGNITO_USER_POOL_ID        = var.cognito_user_pool_id
      COGNITO_USER_POOL_CLIENT_ID = var.cognito_client_id
      # AWS_REGION is automatically available as environment variable
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_auth_vpc,
    aws_cloudwatch_log_group.jwt_middleware,
  ]

  tags = var.tags
}

# Archive JWT middleware function
data "archive_file" "jwt_middleware" {
  type        = "zip"
  source_file = "${path.module}/functions/jwt_middleware.py"
  output_path = "${path.module}/functions/jwt_middleware.zip"
}

# CloudWatch Log Group for JWT middleware
resource "aws_cloudwatch_log_group" "jwt_middleware" {
  name              = "/aws/lambda/${var.project_name}-${var.environment}-jwt-middleware"
  retention_in_days = var.log_retention_days
  # Temporarily disable KMS encryption to avoid dependency issues
  # kms_key_id        = var.kms_key_arn

  tags = var.tags
}