# Lambda Runtime API Example

This project demonstrates AWS Lambda extensions using a Runtime API proxy that modifies Lambda function responses.

## Architecture

- **Lambda Function**: Simple Node.js function returning `{"message": "hello world"}`
- **Runtime Extension**: Modifies responses to append " - processed by extension"
- **ALB Routing**: 
  - `/without-extension` → Lambda function without extension
  - `/with-extension` → Lambda function with extension layer

## Structure

```
lambda-runtime-api-example/
├── function/           # Lambda function code
│   ├── index.js       # Handler returning "hello world"
│   └── package.json
├── extension/         # Extension implementation
│   ├── index.mjs      # Main extension entry point
│   ├── extensions-api-client.mjs
│   ├── runtime-api-proxy.mjs
│   └── package.json
├── terraform/         # Infrastructure as code
│   ├── main.tf
│   ├── networking.tf
│   ├── alb.tf
│   ├── lambda.tf
│   └── outputs.tf
├── wrapper-script.sh  # Extension bootstrap script
├── Makefile          # Build and deployment commands
└── README.md
```

## Quick Start

1. **Build and Deploy**:
   ```bash
   make deploy
   ```

2. **Test the Functions**:
   ```bash
   make test
   ```

3. **Clean Up**:
   ```bash
   make terraform-destroy
   ```

## Available Commands

```bash
make build              # Build extension layer packages
make deploy             # Full deployment (init + apply)
make terraform-init     # Initialize Terraform
make terraform-apply    # Apply Terraform (builds first)
make terraform-destroy  # Destroy all resources
make test              # Test both endpoints
make clean             # Remove build artifacts
```

## Expected Output

**Without Extension** (`/without-extension`):
```json
{"message": "hello world"}
```

**With Extension** (`/with-extension`):
```json
{"message": "hello world - processed by extension"}
```

## How It Works

1. The extension starts as a separate process alongside the Lambda function
2. The wrapper script redirects `AWS_LAMBDA_RUNTIME_API` to the extension's proxy server (port 9009)
3. The extension intercepts runtime API calls and modifies response messages
4. Modified responses are forwarded to the actual Lambda Runtime API

## Extension Details

- **Runtime API Proxy**: Express server on port 9009 intercepting Lambda runtime calls
- **Extensions API Client**: Registers with Lambda runtime for lifecycle events
- **String Appending**: Adds " - processed by extension" to the message field in responses