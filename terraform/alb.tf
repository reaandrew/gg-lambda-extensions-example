resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Security group for ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-alb-sg"
  }
}

resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets           = aws_subnet.public[*].id

  enable_deletion_protection = false

  tags = {
    Name = "${var.project_name}-alb"
  }
}

resource "aws_lb_target_group" "lambda_without_extension" {
  name        = "lrap-example-without-ext-tg"
  target_type = "lambda"
}

resource "aws_lb_target_group" "lambda_with_extension" {
  name        = "lrap-example-with-ext-tg"
  target_type = "lambda"
}

resource "aws_lb_target_group_attachment" "lambda_without_extension" {
  target_group_arn = aws_lb_target_group.lambda_without_extension.arn
  target_id        = aws_lambda_function.without_extension.arn
  depends_on       = [aws_lambda_permission.alb_without_extension]
}

resource "aws_lb_target_group_attachment" "lambda_with_extension" {
  target_group_arn = aws_lb_target_group.lambda_with_extension.arn
  target_id        = aws_lambda_function.with_extension.arn
  depends_on       = [aws_lambda_permission.alb_with_extension]
}

resource "aws_lb_listener" "main" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Please use /without-extension or /with-extension paths"
      status_code  = "200"
    }
  }
}

resource "aws_lb_listener_rule" "without_extension" {
  listener_arn = aws_lb_listener.main.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lambda_without_extension.arn
  }

  condition {
    path_pattern {
      values = ["/without-extension", "/without-extension/*"]
    }
  }
}

resource "aws_lb_listener_rule" "with_extension" {
  listener_arn = aws_lb_listener.main.arn
  priority     = 200

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lambda_with_extension.arn
  }

  condition {
    path_pattern {
      values = ["/with-extension", "/with-extension/*"]
    }
  }
}