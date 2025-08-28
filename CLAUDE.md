# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

### Build and Deployment
```bash
make build              # Build Lambda function and extension layer packages
make deploy             # Full deployment (init + apply Terraform)
make terraform-init     # Initialize Terraform
make terraform-apply    # Apply Terraform configuration (builds first)
make terraform-destroy  # Destroy all AWS resources
make permissions        # Set executable permissions on scripts
```

### Testing
```bash
make test               # Test deployed Lambda via ALB endpoints (uses jq for formatting)
```

### Cleanup
```bash
make clean              # Remove build artifacts (*.zip, layer-build/, node_modules)
```

## Architecture

This is an AWS Lambda extension demonstration project that automatically scans and redacts sensitive information from Lambda responses using GitGuardian, without modifying the Lambda function code.

### Key Components

1. **Lambda Function** (`function/`): Simple Node.js handler returning AWS credentials for demonstration
2. **Runtime Extension** (`extension/`): Express-based proxy server that intercepts Lambda responses, scans with GitGuardian API, and redacts sensitive data
3. **Extension Layer**: Packaged extension deployed as Lambda layer with runtime compatibility for `nodejs18.x` and `nodejs20.x`
4. **GitGuardian Integration** (`extension/gitguardian.mjs`): Custom wrapper for GitGuardian API with chunking, scanning, and redaction logic
5. **AWS Parameter Store**: Securely stores GitGuardian API key at `/ara/gitguardian/apikey/scan`

### How Extensions Work

1. Extension starts as separate process alongside Lambda function using `extension-launcher.sh`
2. Wrapper script (`wrapper-script.sh`) redirects `AWS_LAMBDA_RUNTIME_API` to extension's proxy server (port 9009)
3. Extension intercepts `/runtime/invocation/*/response` calls and scans response content with GitGuardian
4. Sensitive data is replaced with "REDACTED" before forwarding to actual Lambda Runtime API
5. Modified responses include scan metadata showing redaction statistics

### Extension Architecture

- **Runtime API Proxy** (`runtime-api-proxy.mjs`): Express server intercepting Lambda runtime calls, integrating GitGuardian scanning, Google homepage fetching, and Parameter Store access
- **Extensions API Client** (`extensions-api-client.mjs`): Registers extension with Lambda runtime for lifecycle management
- **GitGuardian Module** (`gitguardian.mjs`): Handles content scanning, chunking for large responses, and intelligent redaction with position-based replacement

### Infrastructure

- **Terraform** (`terraform/`): Deploys dual Lambda functions (with/without extension), ALB with path routing, VPC networking, and IAM policies for Parameter Store access
- **ALB Routing**: `/without-extension` shows raw responses, `/with-extension` shows redacted responses
- **Compatible Runtimes**: Extension layer works with Node.js runtimes only - Python lambdas would need separate Python extension implementation

## Development Notes

- Extension uses ES modules (`.mjs` files with `"type": "module"` in package.json)
- Build process creates `function.zip` and `extension-layer.zip` packages
- Extension binary must be executable and in `extensions/` directory
- Runtime API proxy runs on port 9009 (configurable via `LRAP_LISTENER_PORT`)
- GitGuardian API key is cached in extension process to avoid repeated Parameter Store calls
- Extension gracefully handles API failures without breaking Lambda function execution