variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "s3_bucket_arn" {
  description = "ARN of the S3 bucket"
  type        = string
}

variable "downloads_table_arn" {
  description = "ARN of the DynamoDB downloads table"
  type        = string
}

variable "rate_limits_table_arn" {
  description = "ARN of the DynamoDB rate limits table"
  type        = string
  default     = ""
}

variable "kms_key_arn" {
  description = "ARN of the KMS key for encryption"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}