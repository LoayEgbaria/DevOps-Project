# --- DATA SOURCES: AUTOMATIC ZIPPING ---

# Zips the Python logic for the Lambda
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambda/lambda_function.py"
  output_path = "${path.module}/../lambda/lambda_function.zip"
}

# Zips the kafka-python library for the Layer
data "archive_file" "lambda_layer_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/layer"
  output_path = "${path.module}/../lambda/kafka_layer.zip"
}

# --- RESOURCES ---

# Random string for unique bucket naming
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# S3 Bucket
resource "aws_s3_bucket" "main" {
  bucket = "${var.project_name}-bucket-${random_string.suffix.result}"

  tags = {
    Name = "${var.project_name}-bucket"
  }
}

# Kafka Library Layer
resource "aws_lambda_layer_version" "kafka_layer" {
  filename            = data.archive_file.lambda_layer_zip.output_path
  layer_name          = "kafka-python-layer"
  compatible_runtimes = ["python3.11"]
  source_code_hash    = data.archive_file.lambda_layer_zip.output_base64sha256
}

# Lambda Function
resource "aws_lambda_function" "s3_processor" {
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  
  function_name    = "${var.project_name}-s3-processor"
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.11"
  timeout          = 60

  # Connects Lambda to the Kafka broker on the EC2 Master Private IP
  environment {
    variables = {
      KAFKA_BOOTSTRAP_SERVERS = "${aws_instance.k8s_master.private_ip}:9092"
      KAFKA_TOPIC             = var.kafka_topic_name
    }
  }

  # Places Lambda inside the VPC so it can "see" the EC2 instances
  vpc_config {
    subnet_ids         = aws_subnet.public[*].id
    security_group_ids = [aws_security_group.k8s_nodes.id]
  }

  # Attaches the Kafka library layer
  layers = [aws_lambda_layer_version.kafka_layer.arn]

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic,
    aws_iam_role_policy.lambda_custom
  ]
}

# S3 Trigger Permission
resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowExecutionFromS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.s3_processor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.main.arn
}

# S3 Bucket Notification configuration
resource "aws_s3_bucket_notification" "main" {
  bucket = aws_s3_bucket.main.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.s3_processor.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.allow_s3]
}