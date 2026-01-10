# Random suffix for unique S3 bucket name
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# S3 Bucket
resource "aws_s3_bucket" "main" {
  bucket = "${var.project_name}-bucket-${random_id.bucket_suffix.hex}"

  tags = {
    Name = "${var.project_name}-s3-bucket"
  }
}

# Lambda Function
resource "aws_lambda_function" "s3_processor" {
  filename      = "${path.module}/../lambda/lambda_function.zip"
  function_name = "${var.project_name}-s3-processor"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.11"
  timeout       = 60

  source_code_hash = filebase64sha256("${path.module}/../lambda/lambda_function.zip")

  environment {
    variables = {
      KAFKA_BOOTSTRAP_SERVERS = "${aws_instance.k8s_master.private_ip}:9092"
      KAFKA_TOPIC            = "api-events"
    }
  }

  vpc_config {
    subnet_ids         = aws_subnet.public[*].id
    security_group_ids = [aws_security_group.k8s_nodes.id]
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic,
    aws_iam_role_policy.lambda_custom
  ]

  tags = {
    Name = "${var.project_name}-lambda-function"
  }
}

# Lambda permission for S3 to invoke the function
resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowExecutionFromS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.s3_processor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.main.arn
}

# S3 bucket notification to trigger Lambda
resource "aws_s3_bucket_notification" "main" {
  bucket = aws_s3_bucket.main.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.s3_processor.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.allow_s3]
}

# Add random provider requirement
terraform {
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}