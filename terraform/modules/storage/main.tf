# S3 bucket for storing downloaded videos
resource "aws_s3_bucket" "downloads" {
  bucket        = "${var.project_name}-${var.environment}-downloads-${random_id.bucket_suffix.hex}"
  force_destroy = var.environment != "prod"
  
  tags = var.tags
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# S3 bucket versioning
resource "aws_s3_bucket_versioning" "downloads" {
  bucket = aws_s3_bucket.downloads.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 bucket encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "downloads" {
  bucket = aws_s3_bucket.downloads.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# S3 bucket public access block
resource "aws_s3_bucket_public_access_block" "downloads" {
  bucket = aws_s3_bucket.downloads.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 bucket lifecycle configuration
resource "aws_s3_bucket_lifecycle_configuration" "downloads" {
  bucket = aws_s3_bucket.downloads.id

  rule {
    id     = "delete_old_downloads"
    status = "Enabled"

    expiration {
      days = var.s3_lifecycle_days
    }

    noncurrent_version_expiration {
      noncurrent_days = 1
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }
}

# S3 bucket notification for Lambda
resource "aws_s3_bucket_notification" "downloads" {
  bucket = aws_s3_bucket.downloads.id

  # Optional: Add notifications for upload completion
  # lambda_function {
  #   lambda_function_arn = var.lambda_function_arn
  #   events              = ["s3:ObjectCreated:*"]
  # }
}

# DynamoDB table for download tracking
resource "aws_dynamodb_table" "downloads" {
  name           = "${var.project_name}-${var.environment}-downloads"
  billing_mode   = var.dynamodb_billing_mode
  hash_key       = "download_id"
  
  # TTL for automatic cleanup
  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  attribute {
    name = "download_id"
    type = "S"
  }

  attribute {
    name = "user_id"
    type = "S"
  }

  attribute {
    name = "created_at"
    type = "S"
  }

  # GSI for querying by user_id
  global_secondary_index {
    name            = "user-downloads-index"
    hash_key        = "user_id"
    range_key       = "created_at"
    projection_type = "ALL"
  }

  # Point-in-time recovery
  point_in_time_recovery {
    enabled = var.environment == "prod"
  }

  tags = var.tags
}

# DynamoDB table for rate limiting (optional)
resource "aws_dynamodb_table" "rate_limits" {
  name           = "${var.project_name}-${var.environment}-rate-limits"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "user_id"
  
  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }

  attribute {
    name = "user_id"
    type = "S"
  }

  tags = var.tags
}