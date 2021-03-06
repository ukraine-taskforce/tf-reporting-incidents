#Enable account API Gateway logging
data "aws_iam_policy_document" "apigateway_logs_assume_role_policy" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["apigateway.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "apigateway_cloudwatch_role" {
  path               = "/"
  name               = "ApiGatewayLogsRole"
  assume_role_policy = data.aws_iam_policy_document.apigateway_logs_assume_role_policy.json
}

resource "aws_iam_role_policy_attachment" "apigateway_cloudwatch_policy" {
  role       = aws_iam_role.apigateway_cloudwatch_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

resource "aws_api_gateway_account" "apigateway_cloudwatch_account" {
  depends_on          = [aws_iam_role_policy_attachment.apigateway_cloudwatch_policy]
  cloudwatch_role_arn = aws_iam_role.apigateway_cloudwatch_role.arn
}

# Create API Gateway
resource "aws_api_gateway_rest_api" "reporting-incidents" {
  name = "reporting-incidents"
}

resource "aws_cloudwatch_log_group" "reporting-incidents-log-group" {
  name              = "/aws/api_gtw/${aws_api_gateway_rest_api.reporting-incidents.name}"
  retention_in_days = 30
}

resource "aws_api_gateway_deployment" "reporting-incidents-deployment" {
  rest_api_id       = aws_api_gateway_rest_api.reporting-incidents.id
  stage_description = timestamp()
  description       = "Created with terraform deployment on ${timestamp()}"

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_integration.reporting-incidents_incident-post_integration,
    aws_api_gateway_integration.reporting-incidents_incident-get_mock-integration,
    aws_api_gateway_integration.reporting-incidents_incident-get_integration,
    aws_api_gateway_integration.reporting-incidents_cors-options-mock-incident_integration,
    aws_api_gateway_integration.reporting-incidents_cors-options-incident_integration,
    aws_api_gateway_integration_response.reporting-incidents_incident-post-response_integration_200,
    aws_api_gateway_integration_response.reporting-incidents_incident-mock-get-response_integration_200,
    aws_api_gateway_method.reporting-incidents_get-mock-incident,
    aws_api_gateway_method_response.reporting-incidents_incident-mock-get-response_200,
    aws_api_gateway_rest_api.reporting-incidents
  ]
}

resource "aws_api_gateway_stage" "reporting-incidents-stage" {
  deployment_id = aws_api_gateway_deployment.reporting-incidents-deployment.id
  rest_api_id   = aws_api_gateway_rest_api.reporting-incidents.id
  stage_name    = "live"

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.reporting-incidents-log-group.arn
    format          = "{\"requestId\":\"$context.requestId\", \"ip\": \"$context.identity.sourceIp\", \"caller\":\"$context.identity.caller\", \"user\":\"$context.identity.user\",\"requestTime\":\"$context.requestTime\", \"httpMethod\":\"$context.httpMethod\",\"resourcePath\":\"$context.resourcePath\", \"status\":\"$context.status\",\"protocol\":\"$context.protocol\", \"responseLength\":\"$context.responseLength\"}"
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_deployment.reporting-incidents-deployment,
  ]
}

resource "aws_api_gateway_resource" "reporting-incidents_api-resource" {
  parent_id   = aws_api_gateway_rest_api.reporting-incidents.root_resource_id
  path_part   = "api"
  rest_api_id = aws_api_gateway_rest_api.reporting-incidents.id
}

resource "aws_api_gateway_resource" "reporting-incidents_v1-resource" {
  parent_id   = aws_api_gateway_resource.reporting-incidents_api-resource.id
  path_part   = "v1"
  rest_api_id = aws_api_gateway_rest_api.reporting-incidents.id
}

resource "aws_api_gateway_resource" "reporting-incidents_incident-resource" {
  parent_id   = aws_api_gateway_resource.reporting-incidents_v1-resource.id
  path_part   = "incident"
  rest_api_id = aws_api_gateway_rest_api.reporting-incidents.id
}

resource "aws_api_gateway_method" "reporting-incidents_post-incident" {
  authorization = "NONE"
  http_method   = "POST"
  resource_id   = aws_api_gateway_resource.reporting-incidents_incident-resource.id
  rest_api_id   = aws_api_gateway_rest_api.reporting-incidents.id
}

resource "aws_api_gateway_method_settings" "reporting-incidents_method-settings" {
  depends_on = [
    aws_api_gateway_stage.reporting-incidents-stage,
    aws_api_gateway_account.apigateway_cloudwatch_account
  ]

  rest_api_id = aws_api_gateway_rest_api.reporting-incidents.id
  stage_name  = aws_api_gateway_stage.reporting-incidents-stage.stage_name
  method_path = "*/*"

  settings {
    caching_enabled        = false
    cache_data_encrypted   = true
    metrics_enabled        = true
    logging_level          = "INFO"
    data_trace_enabled     = true
    throttling_rate_limit  = 10000
    throttling_burst_limit = 5000
  }
}

resource "aws_api_gateway_integration" "reporting-incidents_incident-post_integration" {
  http_method             = aws_api_gateway_method.reporting-incidents_post-incident.http_method
  resource_id             = aws_api_gateway_resource.reporting-incidents_incident-resource.id
  rest_api_id             = aws_api_gateway_rest_api.reporting-incidents.id
  type                    = "AWS"
  integration_http_method = "POST"
  credentials             = aws_iam_role.apiSQS.arn
  uri                     = "arn:aws:apigateway:eu-central-1:sqs:path/${aws_sqs_queue.reporting-incidents_sqs.name}"

  request_parameters = {
    "integration.request.header.Content-Type" = "'application/x-www-form-urlencoded'"
  }

  request_templates = {
    "application/json" = "Action=SendMessage&MessageBody=$input.body"
  }
}

resource "aws_api_gateway_method_response" "reporting-incidents_incident-post-response_200" {
  rest_api_id = aws_api_gateway_rest_api.reporting-incidents.id
  resource_id = aws_api_gateway_resource.reporting-incidents_incident-resource.id
  http_method = aws_api_gateway_method.reporting-incidents_post-incident.http_method
  status_code = "200"
}

resource "aws_api_gateway_integration_response" "reporting-incidents_incident-post-response_integration_200" {
  rest_api_id = aws_api_gateway_rest_api.reporting-incidents.id
  resource_id = aws_api_gateway_resource.reporting-incidents_incident-resource.id
  http_method = aws_api_gateway_method.reporting-incidents_post-incident.http_method
  status_code = aws_api_gateway_method_response.reporting-incidents_incident-post-response_200.status_code

  response_templates = {
    "application/json" = <<EOF
{
  "message": "success"
}
EOF
  }

  depends_on = [
    aws_api_gateway_integration.reporting-incidents_incident-post_integration
  ]
}

# Endpoint to return MOCK incidents
resource "aws_api_gateway_resource" "reporting-incidents_incident-mock-resource" {
  parent_id   = aws_api_gateway_resource.reporting-incidents_incident-resource.id
  path_part   = "mock"
  rest_api_id = aws_api_gateway_rest_api.reporting-incidents.id
}

resource "aws_api_gateway_method" "reporting-incidents_get-mock-incident" {
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.api-gateway-authorizer.id
  http_method   = "GET"
  resource_id   = aws_api_gateway_resource.reporting-incidents_incident-mock-resource.id
  rest_api_id   = aws_api_gateway_rest_api.reporting-incidents.id
}

resource "aws_api_gateway_integration" "reporting-incidents_incident-get_mock-integration" {
  http_method             = aws_api_gateway_method.reporting-incidents_get-mock-incident.http_method
  resource_id             = aws_api_gateway_resource.reporting-incidents_incident-mock-resource.id
  rest_api_id             = aws_api_gateway_rest_api.reporting-incidents.id
  type                    = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "reporting-incidents_incident-mock-get-response_200" {
  rest_api_id = aws_api_gateway_rest_api.reporting-incidents.id
  resource_id = aws_api_gateway_resource.reporting-incidents_incident-mock-resource.id
  http_method = aws_api_gateway_method.reporting-incidents_get-mock-incident.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

data "template_file" "reporting-incidents_incident-mock-get-response_template" {
  template = file("../testdata/testdata.json")
}

resource "aws_api_gateway_integration_response" "reporting-incidents_incident-mock-get-response_integration_200" {
  rest_api_id = aws_api_gateway_rest_api.reporting-incidents.id
  resource_id = aws_api_gateway_resource.reporting-incidents_incident-mock-resource.id
  http_method = aws_api_gateway_method.reporting-incidents_get-mock-incident.http_method
  status_code = aws_api_gateway_method_response.reporting-incidents_incident-mock-get-response_200.status_code

  response_templates = {
    "application/json" = data.template_file.reporting-incidents_incident-mock-get-response_template.rendered
  }

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }

  depends_on = [
    aws_api_gateway_integration.reporting-incidents_incident-get_mock-integration
  ]
}

# Endpoint to return real incidents
resource "aws_api_gateway_method" "reporting-incidents_get-incident" {
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.api-gateway-authorizer.id
  http_method   = "GET"
  resource_id   = aws_api_gateway_resource.reporting-incidents_incident-resource.id
  rest_api_id   = aws_api_gateway_rest_api.reporting-incidents.id
}

resource "aws_api_gateway_integration" "reporting-incidents_incident-get_integration" {
  http_method             = aws_api_gateway_method.reporting-incidents_get-incident.http_method
  resource_id             = aws_api_gateway_resource.reporting-incidents_incident-resource.id
  rest_api_id             = aws_api_gateway_rest_api.reporting-incidents.id
  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  credentials             = aws_iam_role.apiSQS.arn
  uri                     = aws_lambda_function.reportsOnIncidents_readIncident_lambdaFn.invoke_arn
}

resource "aws_api_gateway_method_response" "reporting-incidents_incident-get-response_200" {
  rest_api_id = aws_api_gateway_rest_api.reporting-incidents.id
  resource_id = aws_api_gateway_resource.reporting-incidents_incident-resource.id
  http_method = aws_api_gateway_method.reporting-incidents_get-incident.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

# Enable CORS on GET Incident endpoint
resource "aws_api_gateway_method" "reporting-incidents_cors-options-incident" {
  rest_api_id   = aws_api_gateway_rest_api.reporting-incidents.id
  resource_id   = aws_api_gateway_resource.reporting-incidents_incident-resource.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_method_response" "reporting-incidents_cors-options-incident_resource" {
  depends_on = [
    aws_api_gateway_method.reporting-incidents_cors-options-incident,
  ]

  rest_api_id = aws_api_gateway_rest_api.reporting-incidents.id
  resource_id = aws_api_gateway_resource.reporting-incidents_incident-resource.id
  http_method = aws_api_gateway_method.reporting-incidents_cors-options-incident.http_method
  status_code = "200"

  response_models = {
    "application/json" = "Empty"
  }

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration" "reporting-incidents_cors-options-incident_integration" {
  depends_on = [
    aws_api_gateway_method.reporting-incidents_cors-options-incident,
  ]

  rest_api_id          = aws_api_gateway_rest_api.reporting-incidents.id
  resource_id          = aws_api_gateway_resource.reporting-incidents_incident-resource.id
  http_method          = aws_api_gateway_method.reporting-incidents_cors-options-incident.http_method
  type                 = "MOCK"
  passthrough_behavior = "WHEN_NO_MATCH"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_integration_response" "reporting-incidents_cors-options-incident_integration-response" {
  depends_on = [
    aws_api_gateway_method_response.reporting-incidents_cors-options-incident_resource,
  ]

  rest_api_id = aws_api_gateway_rest_api.reporting-incidents.id
  resource_id = aws_api_gateway_resource.reporting-incidents_incident-resource.id
  http_method = aws_api_gateway_method.reporting-incidents_cors-options-incident.http_method
  status_code = aws_api_gateway_method_response.reporting-incidents_cors-options-incident_resource.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'OPTIONS,GET'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }

  response_templates = {
    "application/json" = ""
  }
}

# Enable CORS on Mock endpoint
resource "aws_api_gateway_method" "reporting-incidents_cors-options-mock-incident" {
  rest_api_id   = aws_api_gateway_rest_api.reporting-incidents.id
  resource_id   = aws_api_gateway_resource.reporting-incidents_incident-mock-resource.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_method_response" "reporting-incidents_cors-options-mock_resource" {
  depends_on = [
    aws_api_gateway_method.reporting-incidents_cors-options-mock-incident,
  ]

  rest_api_id = aws_api_gateway_rest_api.reporting-incidents.id
  resource_id = aws_api_gateway_resource.reporting-incidents_incident-mock-resource.id
  http_method = aws_api_gateway_method.reporting-incidents_cors-options-mock-incident.http_method
  status_code = "200"

  response_models = {
    "application/json" = "Empty"
  }

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration" "reporting-incidents_cors-options-mock-incident_integration" {
  depends_on = [
    aws_api_gateway_method.reporting-incidents_cors-options-mock-incident,
  ]

  rest_api_id          = aws_api_gateway_rest_api.reporting-incidents.id
  resource_id          = aws_api_gateway_resource.reporting-incidents_incident-mock-resource.id
  http_method          = aws_api_gateway_method.reporting-incidents_cors-options-mock-incident.http_method
  type                 = "MOCK"
  passthrough_behavior = "WHEN_NO_MATCH"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_integration_response" "reporting-incidents_cors-options-mock-incident_integration-response" {
  depends_on = [
    aws_api_gateway_method_response.reporting-incidents_cors-options-mock_resource,
  ]

  rest_api_id = aws_api_gateway_rest_api.reporting-incidents.id
  resource_id = aws_api_gateway_resource.reporting-incidents_incident-mock-resource.id
  http_method = aws_api_gateway_method.reporting-incidents_cors-options-mock-incident.http_method
  status_code = aws_api_gateway_method_response.reporting-incidents_cors-options-mock_resource.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'OPTIONS,GET'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }

  response_templates = {
    "application/json" = ""
  }
}

# Api Gateway - BOT State
resource "aws_apigatewayv2_api" "bot-client-api" {
  name          = "api-${random_id.id.hex}"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "bot-client-api" {
  api_id           = aws_apigatewayv2_api.bot-client-api.id
  integration_type = "AWS_PROXY"

  integration_method     = "POST"
  integration_uri        = aws_lambda_function.bot-client-lambda.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "bot-client-api-webhook" {
  api_id    = aws_apigatewayv2_api.bot-client-api.id
  route_key = "POST /${random_id.random_path.hex}/webhook/{proxy+}"

  target = "integrations/${aws_apigatewayv2_integration.bot-client-api.id}"
}

resource "aws_apigatewayv2_route" "bot-client-api-send_message" {
  api_id    = aws_apigatewayv2_api.bot-client-api.id
  route_key = "POST /${random_id.random_path.hex}/send_message/{proxy+}"
  authorization_type = "AWS_IAM"

  target = "integrations/${aws_apigatewayv2_integration.bot-client-api.id}"
}

resource "aws_apigatewayv2_stage" "bot-client-api" {
  api_id      = aws_apigatewayv2_api.bot-client-api.id
  name        = "$default"
  auto_deploy = true
}
