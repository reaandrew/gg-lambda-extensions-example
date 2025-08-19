data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

resource "aws_subnet" "public" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index + 1}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]

  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-subnet-${count.index + 1}"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

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

resource "aws_lb_target_group" "lambda" {
  name        = "hw-ext-lambda-tg"
  target_type = "lambda"
}

resource "aws_lb_target_group_attachment" "lambda" {
  target_group_arn = aws_lb_target_group.lambda.arn
  target_id        = aws_lambda_function.hello_world.arn
  depends_on       = [aws_lambda_permission.alb]
}

# Target group for Lambda without extension
resource "aws_lb_target_group" "lambda_no_extension" {
  name        = "hw-no-ext-lambda-tg"
  target_type = "lambda"
}

resource "aws_lb_target_group_attachment" "lambda_no_extension" {
  target_group_arn = aws_lb_target_group.lambda_no_extension.arn
  target_id        = aws_lambda_function.no_extension.arn
  depends_on       = [aws_lambda_permission.alb_no_extension]
}

resource "aws_lb_listener" "main" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Please use /with-extension or /no-extension paths"
      status_code  = "200"
    }
  }
}

# Listener rule for function with extension
resource "aws_lb_listener_rule" "with_extension" {
  listener_arn = aws_lb_listener.main.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lambda.arn
  }

  condition {
    path_pattern {
      values = ["/with-extension", "/with-extension/*"]
    }
  }
}

# Listener rule for function without extension
resource "aws_lb_listener_rule" "no_extension" {
  listener_arn = aws_lb_listener.main.arn
  priority     = 200

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lambda_no_extension.arn
  }

  condition {
    path_pattern {
      values = ["/no-extension", "/no-extension/*"]
    }
  }
}

output "alb_dns_name" {
  value       = aws_lb.main.dns_name
  description = "DNS name of the Application Load Balancer"
}

output "curl_command_with_extension" {
  value       = "curl http://${aws_lb.main.dns_name}/with-extension"
  description = "Command to test the Lambda function with extension"
}

output "curl_command_no_extension" {
  value       = "curl http://${aws_lb.main.dns_name}/no-extension"
  description = "Command to test the Lambda function without extension"
}

output "curl_command_gitguardian_without_extension" {
  value       = "curl http://${aws_lb.main.dns_name}/gitguardian/without-extension"
  description = "Command to test the GitGuardian example Lambda without extension"
}

output "curl_command_gitguardian_with_extension" {
  value       = "curl http://${aws_lb.main.dns_name}/gitguardian/with-extension"
  description = "Command to test the GitGuardian example Lambda with extension"
}