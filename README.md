# Hello World Lambda with Runtime API Proxy Extension

This project demonstrates a Lambda function with a custom runtime extension that modifies the response by adding "Extension Applied" to the message field.

## Architecture

- **Lambda Function**: A simple Node.js function that returns a JSON response with a "Hello World" message
- **Runtime Extension**: Intercepts the Lambda response and appends "Extension Applied" to the message
- **ALB**: Application Load Balancer to provide HTTP endpoint for the Lambda function
- **Infrastructure**: Deployed using Terraform in eu-west-2 region

## Project Structure

```
hello-world-lambda-extension-project/
├── function/                    # Lambda function code
│   ├── index.js                # Main handler
│   └── package.json
├── extension/                   # Extension code
│   ├── index.mjs               # Extension entry point
│   ├── runtime-api-proxy.mjs   # Runtime API proxy implementation
│   ├── extensions-api-client.mjs # Extensions API client
│   └── package.json
├── extensions/                  # Extension launcher scripts
│   └── nodejs-example-lambda-runtime-api-proxy-extension
├── terraform/                   # Infrastructure as Code
│   ├── main.tf                 # Provider configuration
│   ├── lambda.tf               # Lambda and layer resources
│   └── alb.tf                  # ALB and networking resources
├── wrapper-script.sh           # Wrapper script for runtime modification
├── Makefile                    # Build and deployment automation
└── README.md                   # This file
```

## Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform installed (>= 1.0)
- Node.js and npm installed
- Make utility

## Build and Deployment

### Available Make targets:

```bash
make build              # Build Lambda function and extension layer
make deploy             # Full deployment (init + apply Terraform)
make test               # Test the deployed Lambda function
make clean              # Clean build artifacts
make terraform-init     # Initialize Terraform
make terraform-apply    # Apply Terraform configuration
make terraform-destroy  # Destroy all AWS resources
make permissions        # Set executable permissions on scripts
```

### Quick Deployment:

1. Set executable permissions:
```bash
make permissions
```

2. Deploy the infrastructure:
```bash
make deploy
```

This will:
- Build the Lambda function package
- Build the extension layer
- Initialize Terraform
- Deploy all resources to AWS

## Testing

After deployment, test the Lambda function:

```bash
make test
```

Or manually:
```bash
curl http://<alb-dns-name>
```

Expected response:
```json
{
  "message": "Hello World from Lambda! - Extension Applied"
}
```

## How It Works

1. The ALB receives an HTTP request and invokes the Lambda function
2. The Lambda runtime extension intercepts the runtime API calls
3. The Lambda function executes and returns a JSON response with a message field
4. The extension intercepts the response and modifies the message field by appending " - Extension Applied"
5. The modified response is returned through the ALB to the client

## Clean Up

To destroy all created resources:

```bash
make terraform-destroy
```

## Notes

- The extension runs as a separate process alongside the Lambda function
- The wrapper script redirects the Lambda runtime API calls to the extension's proxy server
- The extension modifies responses in the `handleResponse` method of the RuntimeApiProxy class