# IAM Role for Lambda
resource "aws_iam_role" "lambda_role" {
  name               = "${var.project_name}-${var.environment}-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
  tags               = var.tags
}

# IAM Policy Document for Lambda Assume Role
data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# Attach Basic Lambda Execution Policy
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# IAM Policy Document for Lambda Permissions
data "aws_iam_policy_document" "lambda_policy" {
  # CloudWatch Logs Permissions
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["arn:aws:logs:*:*:*"]
  }

  # S3 Permissions
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket"
    ]
    resources = [
      var.s3_bucket_arn,
      "${var.s3_bucket_arn}/*"
    ]
  }

  # DynamoDB Permissions
  statement {
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:DeleteItem",
      "dynamodb:Query",
      "dynamodb:Scan"
    ]
    resources = [
      var.downloads_table_arn,
      "${var.downloads_table_arn}/index/*",
      var.rate_limits_table_arn
    ]
  }

  # SSM Parameter Store Permissions
  statement {
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters"
    ]
    resources = [
      "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/${var.project_name}/${var.environment}/*"
    ]
  }

  # KMS Permissions (if key is provided)
  dynamic "statement" {
    for_each = var.kms_key_arn != "" ? [1] : []
    content {
      effect = "Allow"
      actions = [
        "kms:Decrypt",
        "kms:GenerateDataKey"
      ]
      resources = [var.kms_key_arn]
    }
  }
}

# Custom IAM Policy for Lambda
resource "aws_iam_policy" "lambda_policy" {
  name        = "${var.project_name}-${var.environment}-lambda-policy"
  description = "Policy for YouTube Downloader Lambda function"
  policy      = data.aws_iam_policy_document.lambda_policy.json
  tags        = var.tags
}

# Attach Custom Policy to Lambda Role
resource "aws_iam_role_policy_attachment" "lambda_custom_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

# API Gateway CloudWatch Role
resource "aws_iam_role" "api_gateway_cloudwatch_role" {
  name               = "${var.project_name}-${var.environment}-api-gw-cloudwatch-role"
  description        = "IAM role for API Gateway to write to CloudWatch Logs"
  assume_role_policy = data.aws_iam_policy_document.api_gateway_assume_role.json
  tags               = var.tags
}

# IAM Policy Document for API Gateway Assume Role
data "aws_iam_policy_document" "api_gateway_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["apigateway.amazonaws.com"]
    }
  }
}

# Attach CloudWatch Policy to API Gateway Role
resource "aws_iam_role_policy_attachment" "api_gateway_cloudwatch" {
  role       = aws_iam_role.api_gateway_cloudwatch_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

# KMS Key for Encryption (optional)
resource "aws_kms_key" "main" {
  description             = "${var.project_name} ${var.environment} encryption key"
  deletion_window_in_days = var.environment == "prod" ? 30 : 7
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.kms_policy.json
  tags                    = var.tags
}

# KMS Alias
resource "aws_kms_alias" "main" {
  name          = "alias/${var.project_name}-${var.environment}"
  target_key_id = aws_kms_key.main.key_id
}

# KMS Policy Document
data "aws_iam_policy_document" "kms_policy" {
  # Allow root account full access
  statement {
    sid       = "EnableRootPermissions"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }

  # Allow Lambda role to use the key
  statement {
    sid    = "AllowLambdaUsage"
    effect = "Allow"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.lambda_role.arn]
    }
  }

  # Allow API Gateway to use the key (for logging)
  statement {
    sid    = "AllowAPIGatewayUsage"
    effect = "Allow"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.api_gateway_cloudwatch_role.arn]
    }
  }
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}