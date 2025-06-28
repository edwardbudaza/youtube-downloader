output "s3_bucket_name" {
  description = "Name of the S3 bucket"
  value       = aws_s3_bucket.downloads.bucket
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.downloads.arn
}

output "s3_bucket_domain_name" {
  description = "Domain name of the S3 bucket"
  value       = aws_s3_bucket.downloads.bucket_domain_name
}

output "downloads_table_name" {
  description = "Name of the DynamoDB downloads table"
  value       = aws_dynamodb_table.downloads.name
}

output "downloads_table_arn" {
  description = "ARN of the DynamoDB downloads table"
  value       = aws_dynamodb_table.downloads.arn
}

output "rate_limits_table_name" {
  description = "Name of the DynamoDB rate limits table"
  value       = aws_dynamodb_table.rate_limits.name
}

output "rate_limits_table_arn" {
  description = "ARN of the DynamoDB rate limits table"
  value       = aws_dynamodb_table.rate_limits.arn
}