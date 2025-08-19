# GitGuardian Lambda Examples

This directory contains Lambda functions demonstrating GitGuardian secret detection scenarios.

## Structure

```
gitguardian/
└── examples/
    └── without_extension/    # Lambda that returns sample GitHub token (no extension)
        └── handler.py        # Python Lambda handler
```

## Lambda Functions

### 1. Without Extension (`/gitguardian/without-extension`)

A Python Lambda function that returns a sample GitHub personal access token for demonstration purposes. This Lambda runs without the GitGuardian extension, showing what happens when secrets are exposed without protection.

**Endpoint**: `http://<ALB_DNS>/gitguardian/without-extension`

**Response**:
```json
{
  "message": "Sample GitHub access token for GitGuardian detection demo",
  "token_type": "GitHub Personal Access Token (Classic)",
  "sample_token": "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",
  "warning": "This is a demonstration token only. Never expose real credentials.",
  "detection_info": {
    "detector": "github_access_token",
    "format": "ghp_ prefix followed by 36 alphanumeric characters",
    "documentation": "https://docs.gitguardian.com/secrets-detection/secrets-detection-engine/detectors/specifics/github_access_token"
  }
}
```

## Deployment

The Lambda functions are automatically built and deployed via Terraform:

```bash
# Build all Lambda functions
make build

# Deploy to AWS
make deploy

# Test the deployed function
curl http://<ALB_DNS>/gitguardian/without-extension
```

## Important Notes

- **Sample Tokens Only**: All tokens in these examples are fake samples for demonstration purposes
- **Never Use Real Credentials**: These examples are designed to show how GitGuardian detects secrets
- **Educational Purpose**: Used to demonstrate the difference between protected and unprotected Lambda functions

## Future Examples

Planned additions:
- `with_extension/` - Lambda with GitGuardian extension for automatic secret detection
- Other credential types (AWS keys, API tokens, etc.)