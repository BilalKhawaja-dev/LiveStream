# Lambda function for media processing
# Handles file uploads, thumbnail generation, and transcoding triggers

# Lambda function for media processing
resource "aws_lambda_function" "media_processor" {
  filename      = "${path.module}/functions/media_processor.zip"
  function_name = "${var.project_name}-${var.environment}-media-processor"
  role          = aws_iam_role.media_processor.arn
  handler       = "media_processor.lambda_handler"
  runtime       = "python3.9"
  timeout       = 300 # 5 minutes
  memory_size   = 1024

  environment {
    variables = {
      MEDIA_BUCKET      = aws_s3_bucket.media_content.bucket
      PROCESSED_BUCKET  = aws_s3_bucket.processed_media.bucket
      CLOUDFRONT_DOMAIN = var.enable_cloudfront ? aws_cloudfront_distribution.media_distribution[0].domain_name : ""
      ENVIRONMENT       = var.environment
      LOG_LEVEL         = "INFO"
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.media_processor_basic,
    aws_cloudwatch_log_group.media_processor,
    data.archive_file.media_processor
  ]

  tags = var.tags
}

# Archive file for media processor
data "archive_file" "media_processor" {
  type        = "zip"
  source_file = "${path.module}/functions/media_processor.py"
  output_path = "${path.module}/functions/media_processor.zip"
}

# IAM role for media processor Lambda
resource "aws_iam_role" "media_processor" {
  name = "${var.project_name}-${var.environment}-media-processor-role"

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

# Basic execution role attachment
resource "aws_iam_role_policy_attachment" "media_processor_basic" {
  role       = aws_iam_role.media_processor.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# S3 permissions for media processor
resource "aws_iam_role_policy" "media_processor_s3" {
  name = "${var.project_name}-${var.environment}-media-processor-s3-policy"
  role = aws_iam_role.media_processor.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:GetObjectVersion"
        ]
        Resource = [
          "${aws_s3_bucket.media_content.arn}/*",
          "${aws_s3_bucket.processed_media.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.media_content.arn,
          aws_s3_bucket.processed_media.arn
        ]
      }
    ]
  })
}

# CloudFront invalidation permissions
resource "aws_iam_role_policy" "media_processor_cloudfront" {
  count = var.enable_cloudfront ? 1 : 0

  name = "${var.project_name}-${var.environment}-media-processor-cloudfront-policy"
  role = aws_iam_role.media_processor.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudfront:CreateInvalidation"
        ]
        Resource = aws_cloudfront_distribution.media_distribution[0].arn
      }
    ]
  })
}

# CloudWatch log group for media processor
resource "aws_cloudwatch_log_group" "media_processor" {
  name              = "/aws/lambda/${var.project_name}-${var.environment}-media-processor"
  retention_in_days = var.log_retention_days

  tags = var.tags
}

# S3 bucket notification for media processing
resource "aws_s3_bucket_notification" "media_content_notification" {
  bucket = aws_s3_bucket.media_content.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.media_processor.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "uploads/"
    filter_suffix       = ""
  }

  depends_on = [aws_lambda_permission.media_processor_s3]
}

# Lambda permission for S3 to invoke media processor
resource "aws_lambda_permission" "media_processor_s3" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.media_processor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.media_content.arn
}

# Pre-signed URL generator Lambda
resource "aws_lambda_function" "presigned_url_generator" {
  filename      = "${path.module}/functions/presigned_url_generator.zip"
  function_name = "${var.project_name}-${var.environment}-media-presigned-url-generator"
  role          = aws_iam_role.presigned_url_generator.arn
  handler       = "presigned_url_generator.lambda_handler"
  runtime       = "python3.9"
  timeout       = 30
  memory_size   = 256

  environment {
    variables = {
      MEDIA_BUCKET = aws_s3_bucket.media_content.bucket
      ENVIRONMENT  = var.environment
      LOG_LEVEL    = "INFO"
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.presigned_url_generator_basic,
    aws_cloudwatch_log_group.presigned_url_generator,
    data.archive_file.presigned_url_generator
  ]

  tags = var.tags
}

# Archive file for presigned URL generator
data "archive_file" "presigned_url_generator" {
  type        = "zip"
  source_file = "${path.module}/functions/presigned_url_generator.py"
  output_path = "${path.module}/functions/presigned_url_generator.zip"
}

# IAM role for presigned URL generator
resource "aws_iam_role" "presigned_url_generator" {
  name = "${var.project_name}-${var.environment}-media-presigned-url-generator-role"

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

resource "aws_iam_role_policy_attachment" "presigned_url_generator_basic" {
  role       = aws_iam_role.presigned_url_generator.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# S3 permissions for presigned URL generator
resource "aws_iam_role_policy" "presigned_url_generator_s3" {
  name = "${var.project_name}-${var.environment}-media-presigned-url-generator-s3-policy"
  role = aws_iam_role.presigned_url_generator.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl"
        ]
        Resource = "${aws_s3_bucket.media_content.arn}/uploads/*"
      }
    ]
  })
}

# CloudWatch log group for presigned URL generator
resource "aws_cloudwatch_log_group" "presigned_url_generator" {
  name              = "/aws/lambda/${var.project_name}-${var.environment}-media-presigned-url-generator"
  retention_in_days = var.log_retention_days

  tags = var.tags
}