terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "Terraform"
    }
  }
}

# Random password for JWT secret
resource "random_password" "jwt_secret" {
  length  = 64
  special = true
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Local values
locals {
  common_tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}

# Storage module
module "storage" {
  source = "./modules/storage"
  
  project_name         = var.project_name
  environment          = var.environment
  s3_lifecycle_days    = var.s3_lifecycle_days
  dynamodb_billing_mode = var.dynamodb_billing_mode
  tags                 = local.common_tags
}

# Security module
module "security" {
  source = "./modules/security"
  
  project_name         = var.project_name
  environment          = var.environment
  s3_bucket_arn        = module.storage.s3_bucket_arn
  downloads_table_arn  = module.storage.downloads_table_arn
  rate_limits_table_arn = module.storage.rate_limits_table_arn
  tags                 = local.common_tags
}

# Compute module
module "compute" {
  source = "./modules/compute"
  
  project_name         = var.project_name
  environment          = var.environment
  lambda_role_arn      = module.security.lambda_role_arn
  s3_bucket_name       = module.storage.s3_bucket_name
  downloads_table_name = module.storage.downloads_table_name
  jwt_secret_key       = random_password.jwt_secret.result
  lambda_timeout       = var.lambda_timeout
  lambda_memory_size   = var.lambda_memory_size
  log_retention_days   = var.log_retention_days
  tags                 = local.common_tags
}

# Networking module
module "networking" {
  source = "./modules/networking"
  
  project_name              = var.project_name
  environment               = var.environment
  lambda_function_name      = module.compute.lambda_function_name
  lambda_function_invoke_arn = module.compute.lambda_function_invoke_arn
  log_retention_days        = var.log_retention_days
  tags                      = local.common_tags
}

# Store secrets in Parameter Store
resource "aws_ssm_parameter" "jwt_secret" {
  name  = "/${var.project_name}/${var.environment}/jwt-secret"
  type  = "SecureString"
  value = random_password.jwt_secret.result
  
  tags = local.common_tags
}