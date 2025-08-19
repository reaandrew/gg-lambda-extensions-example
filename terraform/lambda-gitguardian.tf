# GitGuardian example Lambda function without extension
resource "aws_lambda_function" "gitguardian_without_extension" {
  filename         = "../gitguardian-without-extension.zip"
  function_name    = "${var.project_name}-gitguardian-without-ext"
  role            = aws_iam_role.lambda_role.arn
  handler         = "handler.lambda_handler"
  runtime         = "python3.11"
  timeout         = 30
  memory_size     = 256
  source_code_hash = filebase64sha256("../gitguardian-without-extension.zip")

  # No layers - this function runs without the extension

  depends_on = [
    null_resource.build_gitguardian_without_extension,
    aws_iam_role_policy_attachment.lambda_basic
  ]
}

resource "aws_lambda_permission" "alb_gitguardian_without_extension" {
  statement_id  = "AllowExecutionFromALBGitGuardianNoExt"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.gitguardian_without_extension.function_name
  principal     = "elasticloadbalancing.amazonaws.com"
  source_arn    = aws_lb_target_group.lambda_gitguardian_without_extension.arn
}

resource "null_resource" "build_gitguardian_without_extension" {
  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = <<EOF
      cd ../gitguardian/examples/without_extension
      zip -r ../../../gitguardian-without-extension.zip .
    EOF
  }
}

# ALB Target Group for GitGuardian Lambda without extension
resource "aws_lb_target_group" "lambda_gitguardian_without_extension" {
  name        = "gg-no-ext-tg"
  target_type = "lambda"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/gitguardian/without-extension"
    matcher             = "200"
  }
}

resource "aws_lb_target_group_attachment" "lambda_gitguardian_without_extension" {
  target_group_arn = aws_lb_target_group.lambda_gitguardian_without_extension.arn
  target_id        = aws_lambda_function.gitguardian_without_extension.arn
  depends_on       = [aws_lambda_permission.alb_gitguardian_without_extension]
}

# ALB Listener Rule for GitGuardian Lambda without extension
resource "aws_lb_listener_rule" "gitguardian_without_extension" {
  listener_arn = aws_lb_listener.main.arn
  priority     = 103

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lambda_gitguardian_without_extension.arn
  }

  condition {
    path_pattern {
      values = ["/gitguardian/without-extension"]
    }
  }
}

# SSM Parameter for GitGuardian API Key
resource "aws_ssm_parameter" "gitguardian_api_key" {
  name  = "/gitguardian/apikey"
  type  = "SecureString"
  value = "PLACEHOLDER_VALUE"  # This should be set manually after deployment

  lifecycle {
    ignore_changes = [value]  # Ignore changes to the value after initial creation
  }
}

# GitGuardian Extension Layer
resource "aws_lambda_layer_version" "gitguardian_extension_layer" {
  filename            = "../gitguardian-extension-layer.zip"
  layer_name          = "${var.project_name}-gitguardian-extension-layer"
  compatible_runtimes = ["python3.11"]
  source_code_hash    = filebase64sha256("../gitguardian-extension-layer.zip")

  depends_on = [null_resource.build_gitguardian_extension_layer]
}

resource "null_resource" "build_gitguardian_extension_layer" {
  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = <<EOF
      rm -rf ../gitguardian-layer-build
      mkdir -p ../gitguardian-layer-build/gitguardian-extension
      mkdir -p ../gitguardian-layer-build/extensions
      
      # Copy extension code
      cp -r ../gitguardian-extension/* ../gitguardian-layer-build/gitguardian-extension/
      
      # Install dependencies
      cd ../gitguardian-layer-build/gitguardian-extension
      npm install --production
      
      # Make index.mjs executable
      chmod +x index.mjs
      
      # Copy extension launcher
      cp ../../extensions/gitguardian-extension ../extensions/
      chmod +x ../extensions/gitguardian-extension
      
      # Create the layer zip
      cd ..
      zip -r ../gitguardian-extension-layer.zip .
    EOF
  }
}

# GitGuardian example Lambda function WITH extension
resource "aws_lambda_function" "gitguardian_with_extension" {
  filename         = "../gitguardian-without-extension.zip"
  function_name    = "${var.project_name}-gitguardian-with-ext"
  role            = aws_iam_role.lambda_role.arn
  handler         = "handler.lambda_handler"
  runtime         = "python3.11"
  timeout         = 30
  memory_size     = 256
  source_code_hash = filebase64sha256("../gitguardian-without-extension.zip")

  # This function uses the GitGuardian extension layer
  layers = [aws_lambda_layer_version.gitguardian_extension_layer.arn]

  environment {
    variables = {
      GITGUARDIAN_SSM_KEY_PATH = aws_ssm_parameter.gitguardian_api_key.name
    }
  }

  depends_on = [
    null_resource.build_gitguardian_without_extension,
    aws_iam_role_policy_attachment.lambda_basic,
    aws_lambda_layer_version.gitguardian_extension_layer
  ]
}

resource "aws_lambda_permission" "alb_gitguardian_with_extension" {
  statement_id  = "AllowExecutionFromALBGitGuardianWithExt"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.gitguardian_with_extension.function_name
  principal     = "elasticloadbalancing.amazonaws.com"
  source_arn    = aws_lb_target_group.lambda_gitguardian_with_extension.arn
}

# ALB Target Group for GitGuardian Lambda with extension
resource "aws_lb_target_group" "lambda_gitguardian_with_extension" {
  name        = "gg-with-ext-tg"
  target_type = "lambda"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/gitguardian/with-extension"
    matcher             = "200"
  }
}

resource "aws_lb_target_group_attachment" "lambda_gitguardian_with_extension" {
  target_group_arn = aws_lb_target_group.lambda_gitguardian_with_extension.arn
  target_id        = aws_lambda_function.gitguardian_with_extension.arn
  depends_on       = [aws_lambda_permission.alb_gitguardian_with_extension]
}

# ALB Listener Rule for GitGuardian Lambda with extension
resource "aws_lb_listener_rule" "gitguardian_with_extension" {
  listener_arn = aws_lb_listener.main.arn
  priority     = 104

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lambda_gitguardian_with_extension.arn
  }

  condition {
    path_pattern {
      values = ["/gitguardian/with-extension"]
    }
  }
}

# IAM policy for SSM Parameter Store access
resource "aws_iam_role_policy" "lambda_ssm_policy" {
  name = "${var.project_name}-lambda-ssm-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters"
        ]
        Resource = aws_ssm_parameter.gitguardian_api_key.arn
      }
    ]
  })
}