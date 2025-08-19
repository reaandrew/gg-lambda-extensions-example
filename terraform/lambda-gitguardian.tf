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