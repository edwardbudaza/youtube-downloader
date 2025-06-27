output "api_gateway_url" {
  description = "API Gateway endpoint URL"
  value       = module.networking.api_gateway_url
}

output "api_gateway_id" {
  description = "API Gateway ID"
  value       = module.networking.api_gateway_id
}

output "lambda_function_name" {
  description = "Lambda function name"
  value       = module.compute.lambda_function_name
}

output "lambda_function_arn" {
  description = "Lambda function ARN"
  value       = module.compute.lambda_function_arn
}

output "s3_bucket_name" {
  description = "S3 bucket name for downloads"
  value       = module.storage.s3_bucket_name
}

output "downloads_table_name" {
  description = "DynamoDB table name for downloads"
  value       = module.storage.downloads_table_name
}

output "cloudwatch_log_group" {
  description = "CloudWatch log group name"
  value       = module.compute.cloudwatch_log_group
}

output "jwt_secret_parameter" {
  description = "SSM parameter name for JWT secret"
  value       = aws_ssm_parameter.jwt_secret.name
  sensitive   = true
}

output "deployment_info" {
  description = "Deployment information"
  value = {
    api_url     = module.networking.api_gateway_url
    environment = var.environment
    region      = var.aws_region
    deployed_at = timestamp()
  }
}