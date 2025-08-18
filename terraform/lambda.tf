resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-lambda-role"

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
  role       = aws_iam_role.lambda_role.name
}

resource "aws_lambda_layer_version" "extension_layer" {
  filename            = "../extension-layer.zip"
  layer_name          = "${var.project_name}-extension-layer"
  compatible_runtimes = ["nodejs18.x", "nodejs20.x"]
  description         = "Lambda Runtime API Proxy Extension Layer"

  depends_on = [null_resource.build_extension_layer]
}

resource "aws_lambda_function" "hello_world" {
  filename         = "../function.zip"
  function_name    = "${var.project_name}-function"
  role            = aws_iam_role.lambda_role.arn
  handler         = "index.handler"
  runtime         = "nodejs20.x"
  timeout         = 30
  memory_size     = 256

  layers = [aws_lambda_layer_version.extension_layer.arn]

  environment {
    variables = {
      AWS_LAMBDA_EXEC_WRAPPER = "/opt/wrapper-script.sh"
      LRAP_LISTENER_PORT      = "9009"
    }
  }

  depends_on = [
    null_resource.build_function,
    aws_iam_role_policy_attachment.lambda_basic
  ]
}

resource "aws_lambda_permission" "alb" {
  statement_id  = "AllowExecutionFromALB"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.hello_world.function_name
  principal     = "elasticloadbalancing.amazonaws.com"
  source_arn    = aws_lb_target_group.lambda.arn
}

resource "null_resource" "build_function" {
  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = <<EOF
      cd ../function
      zip -r ../function.zip .
    EOF
  }
}

resource "null_resource" "build_extension_layer" {
  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = <<EOF
      rm -rf ../layer-build
      mkdir -p ../layer-build/nodejs-example-lambda-runtime-api-proxy-extension
      mkdir -p ../layer-build/extensions
      
      # Copy extension code
      cp -r ../extension/* ../layer-build/nodejs-example-lambda-runtime-api-proxy-extension/
      
      # Install dependencies
      cd ../layer-build/nodejs-example-lambda-runtime-api-proxy-extension
      npm install --production
      
      # Make index.mjs executable
      chmod +x index.mjs
      
      # Copy wrapper script
      cp ../../wrapper-script.sh ../wrapper-script.sh
      chmod +x ../wrapper-script.sh
      
      # Copy extension launcher
      cp ../../extensions/nodejs-example-lambda-runtime-api-proxy-extension ../extensions/
      chmod +x ../extensions/nodejs-example-lambda-runtime-api-proxy-extension
      
      # Create the layer zip
      cd ..
      zip -r ../extension-layer.zip .
    EOF
  }
}

# Lambda function without extension
resource "aws_lambda_function" "no_extension" {
  filename         = "../function-no-extension.zip"
  function_name    = "${var.project_name}-function-no-extension"
  role            = aws_iam_role.lambda_role.arn
  handler         = "index.handler"
  runtime         = "nodejs20.x"
  timeout         = 30
  memory_size     = 256

  # No layers - this function runs without the extension

  depends_on = [
    null_resource.build_function_no_extension,
    aws_iam_role_policy_attachment.lambda_basic
  ]
}

resource "aws_lambda_permission" "alb_no_extension" {
  statement_id  = "AllowExecutionFromALBNoExtension"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.no_extension.function_name
  principal     = "elasticloadbalancing.amazonaws.com"
  source_arn    = aws_lb_target_group.lambda_no_extension.arn
}

resource "null_resource" "build_function_no_extension" {
  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = <<EOF
      cd ../function-no-extension
      zip -r ../function-no-extension.zip .
    EOF
  }
}