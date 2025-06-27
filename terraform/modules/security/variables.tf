variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "s3_bucket_arn" {
  description = "S3 bucket ARN"
  type        = string
}

variable "downloads_table_arn" {
  description = "DynamoDB downloads table ARN"
  type        = string
}

variable "rate_limits_table_arn" {
  description = "DynamoDB rate limits table ARN"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}