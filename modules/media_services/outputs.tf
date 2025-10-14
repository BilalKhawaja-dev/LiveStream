output "media_bucket_id" {
  description = "Media storage bucket ID"
  value       = aws_s3_bucket.media_storage.id
}

output "media_bucket_arn" {
  description = "Media storage bucket ARN"
  value       = aws_s3_bucket.media_storage.arn
}

output "cdn_domain_name" {
  description = "CloudFront distribution domain name"
  value       = var.enable_cdn ? aws_cloudfront_distribution.media_cdn[0].domain_name : ""
}

output "cdn_distribution_id" {
  description = "CloudFront distribution ID"
  value       = var.enable_cdn ? aws_cloudfront_distribution.media_cdn[0].id : ""
}

output "rtmp_endpoint" {
  description = "RTMP endpoint for streaming"
  value       = var.enable_streaming ? aws_medialive_input.rtmp_input[0].destinations[0].url : ""
}

output "medialive_channel_id" {
  description = "MediaLive channel ID"
  value       = var.enable_streaming ? aws_medialive_channel.streaming_channel[0].id : ""
}