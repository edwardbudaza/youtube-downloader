variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "s3_lifecycle_days" {
  description = "Days after which S3 objects are deleted"
  type        = number
  default     = 7
}

variable "dynamodb_billing_mode" {
  description = "DynamoDB billing mode"
  type        = string
  default     = "PAY_PER_REQUEST"
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}