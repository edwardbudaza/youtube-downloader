output "s3_bucket_name" {
  description = "S3 bucket name"
  value       = aws_s3_bucket.downloads.bucket
}

output "s3_bucket_arn" {
  description = "S3 bucket ARN"
  value       = aws_s3_bucket.downloads.arn
}

output "s3_bucket_domain_name" {
  description = "S3 bucket domain name"
  value       = aws_s3_bucket.downloads.bucket_domain_name
}

output "downloads_table_name" {
  description = "DynamoDB downloads table name"
  value       = aws_dynamodb_table.downloads.name
}

output "downloads_table_arn" {
  description = "DynamoDB downloads table ARN"
  value       = aws_dynamodb_table.downloads.arn
}

output "rate_limits_table_name" {
  description = "DynamoDB rate limits table name"
  value       = aws_dynamodb_table.rate_limits.name
}

output "rate_limits_table_arn" {
  description = "DynamoDB rate limits table ARN"
  value       = aws_dynamodb_table.rate_limits.arn
}