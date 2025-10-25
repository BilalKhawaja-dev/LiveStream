output "upload_bucket_name" {
  description = "Name of the video upload bucket"
  value       = aws_s3_bucket.video_uploads.bucket
}

output "processed_bucket_name" {
  description = "Name of the processed videos bucket"
  value       = aws_s3_bucket.processed_videos.bucket
}

output "cdn_domain_name" {
  description = "CloudFront distribution domain name"
  value       = aws_cloudfront_distribution.video_cdn.domain_name
}

output "presigned_url_generator_function_name" {
  description = "Name of the presigned URL generator Lambda function"
  value       = aws_lambda_function.presigned_url_generator.function_name
}

output "presigned_url_generator_function_arn" {
  description = "ARN of the presigned URL generator Lambda function"
  value       = aws_lambda_function.presigned_url_generator.arn
}

output "video_processor_function_name" {
  description = "Name of the video processor Lambda function"
  value       = aws_lambda_function.video_processor.function_name
}

output "upload_bucket_arn" {
  description = "ARN of the video upload bucket"
  value       = aws_s3_bucket.video_uploads.arn
}

output "processed_bucket_arn" {
  description = "ARN of the processed videos bucket"
  value       = aws_s3_bucket.processed_videos.arn
}