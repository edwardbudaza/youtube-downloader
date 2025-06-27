# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.project_name}-${var.environment}-api"
  retention_in_days = var.log_retention_days
  
  tags = var.tags
}

# Lambda function
resource "aws_lambda_function" "api" {
  function_name = "${var.project_name}-${var.environment}-api"
  role          = var.lambda_role_arn
  handler       = "lambda_function.handler"
  runtime       = "python3.11"
  timeout       = var.lambda_timeout
  memory_size   = var.lambda_memory_size
  
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  
  depends_on = [aws_cloudwatch_log_group.lambda]
  
  environment {
    variables = {
      S3_BUCKET_NAME       = var.s3_bucket_name
      DOWNLOADS_TABLE_NAME = var.downloads_table_name
      JWT_SECRET_KEY       = var.jwt_secret_key
      TOKEN_EXPIRY_HOURS   = "24"
      LOG_LEVEL           = var.environment == "prod" ? "INFO" : "DEBUG"
      ENVIRONMENT         = var.environment
    }
  }
  
  # Dead letter queue
  dead_letter_config {
    target_arn = aws_sqs_queue.dlq.arn
  }
  
  tags = var.tags
}

# Create a placeholder Lambda deployment package
data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/lambda_placeholder.zip"
  
  source {
    content = templatefile("${path.module}/placeholder_lambda.py", {
      project_name = var.project_name
      environment  = var.environment
    })
    filename = "lambda_function.py"
  }
}

# Lambda function alias for versioning
resource "aws_lambda_alias" "api" {
  name             = var.environment
  description      = "${var.environment} environment alias"
  function_name    = aws_lambda_function.api.function_name
  function_version = aws_lambda_function.api.version
}

# Dead Letter Queue
resource "aws_sqs_queue" "dlq" {
  name                      = "${var.project_name}-${var.environment}-lambda-dlq"
  message_retention_seconds = 1209600 # 14 days
  
  tags = var.tags
}

# Lambda function URL (alternative to API Gateway for simple use cases)
# resource "aws_lambda_function_url" "api" {
#   function_name      = aws_lambda_function.api.function_name
#   authorization_type = "NONE"
#   
#   cors {
#     allow_credentials = false
#     allow_origins     = ["*"]
#     allow_methods     = ["*"]
#     allow_headers     = ["date", "keep-alive"]
#     expose_headers    = ["date", "keep-alive"]
#     max_age          = 86400
#   }
# }

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${var.project_name}-${var.environment}-lambda-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "This metric monitors lambda errors"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    FunctionName = aws_lambda_function.api.function_name
  }
  
  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "lambda_duration" {
  alarm_name          = "${var.project_name}-${var.environment}-lambda-duration"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Average"
  threshold           = "${var.lambda_timeout * 1000 * 0.8}" # 80% of timeout
  alarm_description   = "This metric monitors lambda duration"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    FunctionName = aws_lambda_function.api.function_name
  }
  
  tags = var.tags
}

# SNS topic for alerts
resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-${var.environment}-alerts"
  
  tags = var.tags
}

# Lambda layer for dependencies (optional optimization)
resource "aws_lambda_layer_version" "dependencies" {
  filename   = data.archive_file.layer_zip.output_path
  layer_name = "${var.project_name}-${var.environment}-dependencies"

  compatible_runtimes = ["python3.11"]
  
  source_code_hash = data.archive_file.layer_zip.output_base64sha256
}

data "archive_file" "layer_zip" {
  type        = "zip"
  output_path = "${path.module}/layer_placeholder.zip"
  
  source {
    content  = "# Placeholder for Lambda layer"
    filename = "python/placeholder.py"
  }
}