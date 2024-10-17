resource "aws_api_gateway_rest_api" "mediatailor_api" {
  name        = "MediaTailor API"
  description = "API Gateway for MediaTailor Lambda Function"
}

resource "aws_api_gateway_resource" "mediatailor_resource" {
  rest_api_id = aws_api_gateway_rest_api.mediatailor_api.id
  parent_id   = aws_api_gateway_rest_api.mediatailor_api.root_resource_id
  path_part   = "ads"
}

resource "aws_api_gateway_method" "mediatailor_post_method" {
  rest_api_id   = aws_api_gateway_rest_api.mediatailor_api.id
  resource_id   = aws_api_gateway_resource.mediatailor_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.mediatailor_api.id
  resource_id             = aws_api_gateway_resource.mediatailor_resource.id
  http_method             = aws_api_gateway_method.mediatailor_post_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = module.lambda_functions.lambda_function_arn
}


resource "aws_lambda_permission" "api_gateway_permission" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda_functions.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.mediatailor_api.execution_arn}/*/*"
}

resource "aws_api_gateway_deployment" "api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.mediatailor_api.id
  stage_name  = "prod"

  depends_on = [
    aws_api_gateway_integration.lambda_integration
  ]
}

