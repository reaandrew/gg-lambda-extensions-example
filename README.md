# GitGuardian Lambda Extensions Example

This project demonstrates AWS Lambda extensions using a Runtime API proxy that automatically scans and redacts sensitive information from Lambda responses using GitGuardian, without modifying the Lambda function code.

## Architecture

- **Lambda Function**: Node.js function returning AWS credentials for demonstration
- **Runtime Extension**: Intercepts responses, scans with GitGuardian API, and redacts sensitive data 
- **GitGuardian Integration**: Custom wrapper for secret detection and intelligent redaction
- **ALB Routing**: 
  - `/without-extension` → Lambda function showing raw credentials
  - `/with-extension` → Lambda function with GitGuardian redaction applied

## Structure

```
lambda-runtime-api-example/
├── function/           # Lambda function code
│   ├── index.js       # Handler returning AWS credentials
│   └── package.json
├── extension/         # Extension implementation
│   ├── index.mjs      # Main extension entry point
│   ├── extensions-api-client.mjs
│   ├── runtime-api-proxy.mjs  # GitGuardian scanning proxy
│   ├── gitguardian.mjs        # GitGuardian API wrapper
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
{
  "message": "Here is a request with some credentials:",
  "smtp_credentials": {
    "Username": "AKIA2U3XFZXY5Y5K4YCG",
    "Password": "BEFlmwBBXP8fjfWBq1Rtc8JuJUVw9Go3nIC/uwchu/V4"
  },
  "client_id": "AKIA2U3XFZXY5Y5K4YCG",
  "client_secret": "BEFlmwBBXP8fjfWBq1Rtc8JuJUVw9Go3nIC/uwchu/V4"
}
```

**With Extension** (`/with-extension`):
```json
{
  "message": "Here is a request with some credentials:",
  "smtp_credentials": {
    "Username": "REDACTED",
    "Password": "REDACTED"
  },
  "client_id": "REDACTED",
  "client_secret": "REDACTED",
  "extension_processed": true,
  "gitguardian_scan": {
    "scanned": true,
    "redactions_applied": 8,
    "redaction_types": ["AWS SES Keys"],
    "scanned_at": "2025-08-28T12:02:54.443Z"
  }
}
```

## How It Works

1. The extension starts as a separate process alongside the Lambda function
2. The wrapper script redirects `AWS_LAMBDA_RUNTIME_API` to the extension's proxy server (port 9009)
3. The extension intercepts runtime API calls and scans responses with GitGuardian
4. Sensitive data is automatically redacted with "REDACTED" before forwarding to the actual Lambda Runtime API

## Extension Details

- **Runtime API Proxy**: Express server on port 9009 intercepting Lambda runtime calls
- **GitGuardian Integration**: Scans response content and applies intelligent redaction
- **Parameter Store**: Securely fetches GitGuardian API key from `/ara/gitguardian/apikey/scan`
- **Extensions API Client**: Registers with Lambda runtime for lifecycle events
- **Error Handling**: Gracefully handles API failures without breaking Lambda execution

## Prerequisites

- GitGuardian API key stored in AWS Parameter Store at `/ara/gitguardian/apikey/scan`
- AWS credentials configured (recommend using aws-vault)
- Terraform installed
- Node.js and npm