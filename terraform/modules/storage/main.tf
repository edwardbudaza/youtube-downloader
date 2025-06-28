# Random suffix for bucket name
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# S3 Bucket for downloads
resource "aws_s3_bucket" "downloads" {
  bucket        = "${var.project_name}-${var.environment}-downloads-${random_id.bucket_suffix.hex}"
  force_destroy = var.environment != "prod"
  tags          = var.tags
}

# S3 Bucket Versioning
resource "aws_s3_bucket_versioning" "downloads" {
  bucket = aws_s3_bucket.downloads.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 Bucket Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "downloads" {
  bucket = aws_s3_bucket.downloads.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# S3 Bucket Public Access Block
resource "aws_s3_bucket_public_access_block" "downloads" {
  bucket = aws_s3_bucket.downloads.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 Bucket Lifecycle Configuration
resource "aws_s3_bucket_lifecycle_configuration" "downloads" {
  bucket = aws_s3_bucket.downloads.id

  rule {
    id     = "auto-delete-old-downloads"
    status = "Enabled"

    filter {
      prefix = "downloads/"
    }

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

# DynamoDB Table for Downloads Tracking
resource "aws_dynamodb_table" "downloads" {
  name           = "${var.project_name}-${var.environment}-downloads"
  billing_mode   = var.dynamodb_billing_mode
  hash_key       = "download_id"
  
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

  # Global Secondary Index for user queries
  global_secondary_index {
    name            = "user-downloads-index"
    hash_key        = "user_id"
    range_key       = "created_at"
    projection_type = "ALL"
    read_capacity   = var.dynamodb_billing_mode == "PROVISIONED" ? 5 : null
    write_capacity  = var.dynamodb_billing_mode == "PROVISIONED" ? 5 : null
  }

  # TTL for automatic cleanup
  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  # Point-in-time recovery for production
  point_in_time_recovery {
    enabled = var.environment == "prod"
  }

  tags = var.tags
}

# DynamoDB Table for Rate Limiting
resource "aws_dynamodb_table" "rate_limits" {
  name           = "${var.project_name}-${var.environment}-rate-limits"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "user_id"
  
  attribute {
    name = "user_id"
    type = "S"
  }

  # TTL for automatic cleanup
  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }

  tags = var.tags
}