output "alb_dns_name" {
  value       = aws_lb.main.dns_name
  description = "DNS name of the Application Load Balancer"
}

output "without_extension_url" {
  value       = "http://${aws_lb.main.dns_name}/without-extension"
  description = "URL to test the Lambda function without extension"
}

output "with_extension_url" {
  value       = "http://${aws_lb.main.dns_name}/with-extension"
  description = "URL to test the Lambda function with extension"
}

output "curl_without_extension" {
  value       = "curl http://${aws_lb.main.dns_name}/without-extension"
  description = "Command to test the Lambda function without extension"
}

output "curl_with_extension" {
  value       = "curl http://${aws_lb.main.dns_name}/with-extension"
  description = "Command to test the Lambda function with extension"
}