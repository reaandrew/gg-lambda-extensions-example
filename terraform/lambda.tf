data "archive_file" "lambda_function" {
  type        = "zip"
  source_dir  = "${path.module}/../function"
  output_path = "${path.module}/function.zip"
}

data "archive_file" "extension_layer" {
  type        = "zip"
  source_dir  = "${path.module}/../layer-build"
  output_path = "${path.module}/extension-layer.zip"
}

resource "aws_iam_role" "lambda_execution" {
  name = "${var.project_name}-lambda-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda_execution.name
}

resource "aws_iam_role_policy" "ssm_parameter_access" {
  name = "${var.project_name}-ssm-parameter-access"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters"
        ]
        Resource = [
          "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/ara/gitguardian/apikey/scan"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = "ssm.${data.aws_region.current.name}.amazonaws.com"
          }
        }
      }
    ]
  })
}

resource "aws_lambda_layer_version" "extension" {
  layer_name          = "${var.project_name}-extension-layer"
  filename            = data.archive_file.extension_layer.output_path
  source_code_hash    = data.archive_file.extension_layer.output_base64sha256
  compatible_runtimes = ["nodejs18.x", "nodejs20.x"]
  
  depends_on = [data.archive_file.extension_layer]
}

resource "aws_lambda_function" "without_extension" {
  filename         = data.archive_file.lambda_function.output_path
  function_name    = "${var.project_name}-without-extension"
  role            = aws_iam_role.lambda_execution.arn
  handler         = "index.handler"
  runtime         = "nodejs20.x"
  source_code_hash = data.archive_file.lambda_function.output_base64sha256
  timeout         = 30

  depends_on = [data.archive_file.lambda_function]
}

resource "aws_lambda_function" "with_extension" {
  filename         = data.archive_file.lambda_function.output_path
  function_name    = "${var.project_name}-with-extension"
  role            = aws_iam_role.lambda_execution.arn
  handler         = "index.handler"
  runtime         = "nodejs20.x"
  source_code_hash = data.archive_file.lambda_function.output_base64sha256
  timeout         = 30
  
  layers = [aws_lambda_layer_version.extension.arn]
  
  environment {
    variables = {
      AWS_LAMBDA_EXEC_WRAPPER = "/opt/wrapper-script.sh"
    }
  }

  depends_on = [
    data.archive_file.lambda_function,
    aws_lambda_layer_version.extension
  ]
}

resource "aws_lambda_permission" "alb_without_extension" {
  statement_id  = "AllowExecutionFromALB"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.without_extension.function_name
  principal     = "elasticloadbalancing.amazonaws.com"
  source_arn    = aws_lb_target_group.lambda_without_extension.arn
}

resource "aws_lambda_permission" "alb_with_extension" {
  statement_id  = "AllowExecutionFromALB"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.with_extension.function_name
  principal     = "elasticloadbalancing.amazonaws.com"
  source_arn    = aws_lb_target_group.lambda_with_extension.arn
}