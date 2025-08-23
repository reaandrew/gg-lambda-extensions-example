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
make test               # Test deployed Lambda via ALB endpoint (uses jq for formatting)
```

### Cleanup
```bash
make clean              # Remove build artifacts (*.zip, layer-build/)
```

## Architecture

This is an AWS Lambda extension demonstration project that modifies Lambda responses using a Runtime API proxy:

1. **Lambda Function** (`function/`): Simple Node.js handler returning JSON with "Hello World" message
2. **Runtime Extension** (`extension/`): Express-based proxy server that intercepts and modifies Lambda responses
3. **Extension Layer**: Packaged extension deployed as Lambda layer, includes wrapper script for runtime API redirection
4. **GitGuardian Examples** (`gitguardian/`): Python Lambda demonstrating secret detection scenarios

### Key Components

- **Runtime API Proxy** (`extension/runtime-api-proxy.mjs`): Intercepts Lambda runtime API calls on port 9009, modifies response messages by appending " - Extension Applied"
- **Extensions API Client** (`extension/extensions-api-client.mjs`): Registers extension with Lambda runtime
- **Wrapper Script** (`wrapper-script.sh`): Redirects `AWS_LAMBDA_RUNTIME_API` to proxy server
- **Terraform** (`terraform/`): Deploys Lambda functions, layers, ALB, and networking in eu-west-2

### How Extensions Work

1. Extension starts as separate process alongside Lambda function
2. Wrapper script sets `AWS_LAMBDA_RUNTIME_API=127.0.0.1:9009` 
3. Lambda runtime calls are redirected to extension's proxy server
4. Extension intercepts `/runtime/invocation/*/response` calls and modifies the response body
5. Modified response is forwarded to actual Lambda runtime API

## Development Notes

- Extension uses ES modules (`.mjs` files with `"type": "module"` in package.json)
- Build process creates two zip packages: `function.zip` and `extension-layer.zip`
- Extension binary must be in `extensions/` directory and be executable
- Runtime API proxy runs on port 9009 (configurable via `LRAP_LISTENER_PORT`)