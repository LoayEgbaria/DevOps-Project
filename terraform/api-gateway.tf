# API Gateway REST API
resource "aws_api_gateway_rest_api" "main" {
  name        = "${var.project_name}-api"
  description = "API Gateway for Kafka integration"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

# API Gateway Resource
resource "aws_api_gateway_resource" "events" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "events"
}

# API Gateway Method
resource "aws_api_gateway_method" "post_events" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.events.id
  http_method   = "POST"
  authorization = "NONE"
}

# API Gateway Integration (HTTP Proxy to Kafka REST Proxy would go here)
# For simplicity, we'll create a mock integration
resource "aws_api_gateway_integration" "mock" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.events.id
  http_method = aws_api_gateway_method.post_events.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

# API Gateway Method Response
resource "aws_api_gateway_method_response" "response_200" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.events.id
  http_method = aws_api_gateway_method.post_events.http_method
  status_code = "200"

  response_models = {
    "application/json" = "Empty"
  }
}

# API Gateway Integration Response
# resource "aws_api_gateway_integration_response" "mock_response" {
#   rest_api_id = aws_api_gateway_rest_api.main.id
#   resource_id = aws_api_gateway_resource.events.id
#   http_method = aws_api_gateway_method.post_events.http_method
#   status_code = aws_api_gateway_method_response.response_200.status_code

#   response_templates = {
#     "application/json" = "{\"message\": \"Event received\"}"
#   }

#   depends_on = [aws_api_gateway_integration.mock]
# }
resource "aws_api_gateway_integration" "lambda_link" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.events.id
  http_method             = aws_api_gateway_method.post_events.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.s3_processor.invoke_arn
}

# Give API Gateway permission to call the Lambda
resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.s3_processor.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}

# API Gateway Deployment
resource "aws_api_gateway_deployment" "main" {
  rest_api_id = aws_api_gateway_rest_api.main.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.events.id,
      aws_api_gateway_method.post_events.id,
      aws_api_gateway_integration.mock.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_method.post_events,
    aws_api_gateway_integration.mock
  ]
}

# API Gateway Stage
resource "aws_api_gateway_stage" "prod" {
  deployment_id = aws_api_gateway_deployment.main.id
  rest_api_id   = aws_api_gateway_rest_api.main.id
  stage_name    = "prod"
}