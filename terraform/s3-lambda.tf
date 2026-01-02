# S3 Bucket
resource "aws_s3_bucket" "main" {
  bucket = "${var.project_name}-bucket-${random_string.suffix.result}"

  tags = {
    Name = "${var.project_name}-bucket"
  }
}

resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# Lambda Function
resource "aws_lambda_function" "s3_processor" {
  filename         = "${path.module}/../lambda/lambda_function.zip"
  function_name    = "${var.project_name}-s3-processor"
  role            = aws_iam_role.lambda_role.arn
  handler         = "lambda_function.lambda_handler"
  source_code_hash = filebase64sha256("${path.module}/../lambda/lambda_function.zip")
  runtime         = "python3.11"
  timeout         = 60

  environment {
    variables = {
      KAFKA_BOOTSTRAP_SERVERS = "${aws_instance.k8s_master.private_ip}:9092"
      KAFKA_TOPIC            = "s3-events"
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
}

# S3 Bucket Notification
resource "aws_s3_bucket_notification" "main" {
  bucket = aws_s3_bucket.main.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.s3_processor.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.allow_s3]
}

# Lambda Permission for S3
resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowExecutionFromS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.s3_processor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.main.arn
}