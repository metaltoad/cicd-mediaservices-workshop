variable "mediatailor_configuration_name" {
  default = ""
}
resource "aws_lambda_function" "mediatailor_ad_insertion" {
  function_name = "mediatailor_ad_insertion"
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.9"
  filename      = "lambda_function.zip"
  role          = aws_iam_role.lambda_exec_role.arn

  timeout      = 60
  memory_size  = 128

  tags = {
    Name = "LambdaMediaTailorAdInsertion"
  }
}

resource "aws_iam_role" "lambda_exec_role" {
  name = "mediatailor_lambda_exec_role"

  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": "sts:AssumeRole",
        "Effect": "Allow",
        "Principal": {
          "Service": "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "lambda_policy" {
  name = "mediatailor_lambda_policy"

  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "mediatailor:GetPlaybackConfiguration",
          "mediatailor:PutPlaybackConfiguration",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        "Resource": "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}


resource "aws_s3_bucket" "lambda_bucket" {
  bucket = "lambda-deployment-bucket"
}

resource "aws_s3_object" "lambda_code" {
  bucket = aws_s3_bucket.lambda_bucket.id
  key    = "lambda_function.zip"
  source = "code/lambdaFunctions/mediatailor_ad_insertion/lambda_function.zip"
}

resource "aws_lambda_function_event_invoke_config" "lambda_invoke_config" {
  function_name               = aws_lambda_function.mediatailor_ad_insertion.function_name
  maximum_retry_attempts      = 2
  maximum_event_age_in_seconds = 60
}


output "lambda_function_arn" {
  value = aws_lambda_function.mediatailor_ad_insertion.arn
}


output "function_name" {
  value = aws_lambda_function.mediatailor_ad_insertion.function_name
}

output "api_invoke_arn" {
  value = aws_lambda_function.mediatailor_ad_insertion.lambda_function_invoke_arn
}