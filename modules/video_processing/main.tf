# Video Processing Module - Video upload, transcoding, and CDN delivery

# S3 bucket for video uploads
resource "aws_s3_bucket" "video_uploads" {
  bucket = "${var.project_name}-${var.environment}-video-uploads"
  tags = merge(var.tags, {
    Service = "video-processing"
    Type    = "s3-bucket"
  })
}

resource "aws_s3_bucket_versioning" "video_uploads_versioning" {
  bucket = aws_s3_bucket.video_uploads.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "video_uploads_encryption" {
  bucket = aws_s3_bucket.video_uploads.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# S3 bucket for processed videos
resource "aws_s3_bucket" "processed_videos" {
  bucket = "${var.project_name}-${var.environment}-processed-videos"
  tags = merge(var.tags, {
    Service = "video-processing"
    Type    = "s3-bucket"
  })
}

resource "aws_s3_bucket_versioning" "processed_videos_versioning" {
  bucket = aws_s3_bucket.processed_videos.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "processed_videos_encryption" {
  bucket = aws_s3_bucket.processed_videos.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# CloudFront distribution for video delivery
resource "aws_cloudfront_distribution" "video_cdn" {
  origin {
    domain_name = aws_s3_bucket.processed_videos.bucket_regional_domain_name
    origin_id   = "S3-${aws_s3_bucket.processed_videos.id}"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.video_oai.cloudfront_access_identity_path
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-${aws_s3_bucket.processed_videos.id}"
    compress               = true
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = merge(var.tags, {
    Service = "video-processing"
    Type    = "cloudfront-distribution"
  })
}

resource "aws_cloudfront_origin_access_identity" "video_oai" {
  comment = "OAI for video CDN"
}

# Lambda function for presigned URL generation
resource "aws_lambda_function" "presigned_url_generator" {
  filename         = data.archive_file.presigned_url_generator.output_path
  function_name    = "${var.project_name}-${var.environment}-video-presigned-url-generator"
  role             = aws_iam_role.presigned_url_generator_role.arn
  handler          = "presigned_url_generator.lambda_handler"
  runtime          = "python3.9"
  timeout          = 30
  memory_size      = 256
  source_code_hash = data.archive_file.presigned_url_generator.output_base64sha256

  environment {
    variables = {
      UPLOAD_BUCKET    = aws_s3_bucket.video_uploads.bucket
      PROCESSED_BUCKET = aws_s3_bucket.processed_videos.bucket
      CDN_DOMAIN       = aws_cloudfront_distribution.video_cdn.domain_name
    }
  }

  tags = merge(var.tags, {
    Service = "video-processing"
    Type    = "lambda-function"
  })
}

# Lambda function for video processing
resource "aws_lambda_function" "video_processor" {
  filename         = data.archive_file.video_processor.output_path
  function_name    = "${var.project_name}-${var.environment}-video-processor"
  role             = aws_iam_role.video_processor_role.arn
  handler          = "video_processor.lambda_handler"
  runtime          = "python3.9"
  timeout          = 900
  memory_size      = 3008
  source_code_hash = data.archive_file.video_processor.output_base64sha256

  environment {
    variables = {
      UPLOAD_BUCKET      = aws_s3_bucket.video_uploads.bucket
      PROCESSED_BUCKET   = aws_s3_bucket.processed_videos.bucket
      MEDIACONVERT_ROLE  = aws_iam_role.mediaconvert_role.arn
      MEDIACONVERT_QUEUE = aws_media_convert_queue.video_queue.arn
      VIDEOS_TABLE       = var.videos_table_name
    }
  }

  tags = merge(var.tags, {
    Service = "video-processing"
    Type    = "lambda-function"
  })
}

# S3 event notification for video processing
resource "aws_s3_bucket_notification" "video_upload_notification" {
  bucket = aws_s3_bucket.video_uploads.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.video_processor.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "uploads/"
    filter_suffix       = ".mp4"
  }

  depends_on = [aws_lambda_permission.allow_s3_video_processor]
}

resource "aws_lambda_permission" "allow_s3_video_processor" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.video_processor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.video_uploads.arn
}

# MediaConvert queue for video transcoding
resource "aws_media_convert_queue" "video_queue" {
  name = "${var.project_name}-${var.environment}-video-queue"

  tags = merge(var.tags, {
    Service = "video-processing"
    Type    = "mediaconvert-queue"
  })
}

# IAM roles and policies
resource "aws_iam_role" "presigned_url_generator_role" {
  name = "${var.project_name}-${var.environment}-video-presigned-url-generator-role"

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

  tags = merge(var.tags, {
    Service = "video-processing"
    Type    = "iam-role"
  })
}

resource "aws_iam_role_policy" "presigned_url_generator_policy" {
  name = "${var.project_name}-${var.environment}-video-presigned-url-generator-policy"
  role = aws_iam_role.presigned_url_generator_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject"
        ]
        Resource = [
          "${aws_s3_bucket.video_uploads.arn}/*",
          "${aws_s3_bucket.processed_videos.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role" "video_processor_role" {
  name = "${var.project_name}-${var.environment}-video-processor-role"

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

  tags = merge(var.tags, {
    Service = "video-processing"
    Type    = "iam-role"
  })
}

resource "aws_iam_role_policy" "video_processor_policy" {
  name = "${var.project_name}-${var.environment}-video-processor-policy"
  role = aws_iam_role.video_processor_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          "${aws_s3_bucket.video_uploads.arn}/*",
          "${aws_s3_bucket.processed_videos.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "mediaconvert:CreateJob",
          "mediaconvert:GetJob",
          "mediaconvert:ListJobs"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = aws_iam_role.mediaconvert_role.arn
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:GetItem"
        ]
        Resource = var.videos_table_arn
      }
    ]
  })
}

resource "aws_iam_role" "mediaconvert_role" {
  name = "${var.project_name}-${var.environment}-mediaconvert-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "mediaconvert.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Service = "video-processing"
    Type    = "iam-role"
  })
}

resource "aws_iam_role_policy" "mediaconvert_policy" {
  name = "${var.project_name}-${var.environment}-mediaconvert-policy"
  role = aws_iam_role.mediaconvert_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = [
          "${aws_s3_bucket.video_uploads.arn}/*",
          "${aws_s3_bucket.processed_videos.arn}/*"
        ]
      }
    ]
  })
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "presigned_url_generator_logs" {
  name              = "/aws/lambda/${aws_lambda_function.presigned_url_generator.function_name}"
  retention_in_days = 7
  tags = merge(var.tags, {
    Service = "video-processing"
    Type    = "log-group"
  })
}

resource "aws_cloudwatch_log_group" "video_processor_logs" {
  name              = "/aws/lambda/${aws_lambda_function.video_processor.function_name}"
  retention_in_days = 7
  tags = merge(var.tags, {
    Service = "video-processing"
    Type    = "log-group"
  })
}

# Data sources for Lambda deployment packages
data "archive_file" "presigned_url_generator" {
  type        = "zip"
  output_path = "${path.module}/presigned_url_generator.zip"
  source_file = "${path.module}/functions/presigned_url_generator.py"
}

data "archive_file" "video_processor" {
  type        = "zip"
  output_path = "${path.module}/video_processor.zip"
  source_file = "${path.module}/functions/video_processor.py"
}