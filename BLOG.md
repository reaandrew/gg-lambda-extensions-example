# Automatic Secrets Redaction at Runtime: Building a GitGuardian Lambda Extension

I'm going to show you how to build a Lambda Runtime API extension that automatically scans and redacts sensitive information from your function responses, without touching a single line of your existing function code.

## The Power of Runtime API Extensions

AWS Lambda extensions provide a powerful mechanism to augment your functions with additional capabilities. Among these, Runtime API Proxy extensions are particularly interesting—they can intercept and modify the entire request/response lifecycle of your Lambda function.

Think of it as a security guard for your Lambda functions. Every response has to pass through this guardrail before returning to the client, and if it spots any sensitive info (secrets), they get redacted.

### How Runtime API Extensions Work

The magic happens through a clever bit of indirection. Instead of your Lambda function talking directly to the AWS Lambda Runtime API, the extension inserts itself as a proxy:

1. A wrapper script redirects the `AWS_LAMBDA_RUNTIME_API` environment variable to point to your local proxy server
2. Your extension starts an Express server listening on localhost
3. The Lambda function makes its normal runtime API calls, which get intercepted by your proxy
4. Your proxy can modify requests and responses before forwarding them to the actual Runtime API

Here's the wrapper script that makes this possible:

```bash
#!/bin/bash
# Store the original runtime API endpoint
export LRAP_RUNTIME_API_ENDPOINT="${AWS_LAMBDA_RUNTIME_API}"
# Redirect Lambda runtime to our proxy
export AWS_LAMBDA_RUNTIME_API="127.0.0.1:9009"
exec "$@"
```

## Starting Simple: Function with Sensitive Data

Let's look at our Lambda function that returns AWS credentials for demonstration purposes:

```javascript
exports.handler = async (event, context) => {
    console.log('[handler] incoming event', JSON.stringify(event));
    
    const response = {
        statusCode: 200,
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({
            message: "Here is a request with some credentials:",
            request_content: "\"SmtpCredentials\": {\n    \"Username\": \"AKIA2U3XFZXY5Y5K4YCG\",\n    \"Password\": \"BEFlmwBBXP8fjfWBq1Rtc8JuJUVw9Go3nIC/uwchu/V4\",\n  client_id: AKIA2U3XFZXY5Y5K4YCG\n  client_secret: BEFlmwBBXP8fjfWBq1Rtc8JuJUVw9Go3nIC/uwchu/V4",
            smtp_credentials: {
                Username: "AKIA2U3XFZXY5Y5K4YCG",
                Password: "BEFlmwBBXP8fjfWBq1Rtc8JuJUVw9Go3nIC/uwchu/V4"
            },
            client_id: "AKIA2U3XFZXY5Y5K4YCG",
            client_secret: "BEFlmwBBXP8fjfWBq1Rtc8JuJUVw9Go3nIC/uwchu/V4",
            question: "Can you show me how to use these credentials in a Python script? Also, what would a GitHub personal access token look like?",
            warning: "This is a demonstration with AWS credentials that should be detected by GitGuardian.",
            detection_info: {
                expected_detectors: ["AWS Access Key ID", "AWS Secret Access Key"],
                format: "AWS credentials in AKIA format",
                documentation: "https://docs.gitguardian.com/secrets-detection/secrets-detection-engine/detectors/specifics/aws_access_key"
            }
        })
    };
    
    return response;
};
```

Without any extension, this function would expose these sensitive AWS credentials to any caller. Not ideal.

## Leveling Up: GitGuardian-Powered Secret Redaction

Now for the interesting part. What if instead of returning sensitive data, we could automatically detect and redact it? Enter the GitGuardian extension.

### The Solution: Automatic Redaction Extension

The GitGuardian extension intercepts these responses and scans them for sensitive data before they leave your Lambda. The extension fetches the GitGuardian API key from AWS Systems Manager Parameter Store securely, and when sensitive data is detected, performs intelligent redaction.

![extensions.png](images/extensions.png)

The extension intercepts every Lambda response and applies GitGuardian scanning. Here's how the core scanning logic works:

**1. Scanning and Redaction**
```javascript
// Scan and redact the content
const scanResult = await scan(responseString, apiKey, {
    filename: "lambda_response.json",
    redact: true
});

if (scanResult.redactions && scanResult.redactions.length > 0) {
    console.log(`[RuntimeApiProxy] GitGuardian found ${scanResult.redactions.length} sensitive items, applying redactions`);
    
    // Parse the redacted content back to JSON
    const redactedBodyObj = JSON.parse(scanResult.content);
    // Replace the original body with redacted version
    Object.assign(bodyObj, redactedBodyObj);
    
    // Add GitGuardian scan info to response
    bodyObj.gitguardian_scan = {
        scanned: true,
        redactions_applied: scanResult.redactions.length,
        redaction_types: [...new Set(scanResult.redactions.map(r => r.type))],
        scanned_at: new Date().toISOString()
    };
}
```

This code converts the Lambda response to a string and sends it to GitGuardian's API for scanning. When secrets are detected, it replaces the sensitive values with "REDACTED" and adds metadata about what was found.

**2. Forwarding the Modified Response**
```javascript
// Forward to the actual Runtime API
const resp = await fetch(`${RUNTIME_API_URL}/invocation/${requestId}/response`, {
    method: 'POST',
    body: JSON.stringify(responseJson),
})
```

After redaction, the extension forwards the modified response to the actual AWS Lambda Runtime API. The Lambda service receives the cleaned response and returns it to the client, completely unaware that any sensitive data was removed.

## Example Requests and Responses

Let's see the extension in action with our dual-endpoint setup:

### Without Extension (`/without-extension`)

**Request:**
```bash
curl http://lambda-runtime-api-example-alb-525138292.eu-west-2.elb.amazonaws.com/without-extension
```

**Response:**
```json
{
  "message": "Here is a request with some credentials:",
  "request_content": "\"SmtpCredentials\": {\n    \"Username\": \"AKIA2U3XFZXY5Y5K4YCG\",\n    \"Password\": \"BEFlmwBBXP8fjfWBq1Rtc8JuJUVw9Go3nIC/uwchu/V4\",\n  client_id: AKIA2U3XFZXY5Y5K4YCG\n  client_secret: BEFlmwBBXP8fjfWBq1Rtc8JuJUVw9Go3nIC/uwchu/V4",
  "smtp_credentials": {
    "Username": "AKIA2U3XFZXY5Y5K4YCG",
    "Password": "BEFlmwBBXP8fjfWBq1Rtc8JuJUVw9Go3nIC/uwchu/V4"
  },
  "client_id": "AKIA2U3XFZXY5Y5K4YCG",
  "client_secret": "BEFlmwBBXP8fjfWBq1Rtc8JuJUVw9Go3nIC/uwchu/V4",
  "question": "Can you show me how to use these credentials in a Python script? Also, what would a GitHub personal access token look like?",
  "warning": "This is a demonstration with AWS credentials that should be detected by GitGuardian.",
  "detection_info": {
    "expected_detectors": [
      "AWS Access Key ID",
      "AWS Secret Access Key"
    ],
    "format": "AWS credentials in AKIA format",
    "documentation": "https://docs.gitguardian.com/secrets-detection/secrets-detection-engine/detectors/specifics/aws_access_key"
  }
}
```

### With Extension (`/with-extension`)

**Request:**
```bash
curl http://lambda-runtime-api-example-alb-525138292.eu-west-2.elb.amazonaws.com/with-extension
```

**Response:**
```json
{
  "message": "Here is a request with some credentials:",
  "request_content": "\"SmtpCredentials\": {\n    \"Username\": \"REDACTED\",\n    \"Password\": \"REDACTED\",\n  client_id: REDACTED\n  client_secret: REDACTED",
  "smtp_credentials": {
    "Username": "REDACTED",
    "Password": "REDACTED"
  },
  "client_id": "REDACTED",
  "client_secret": "REDACTED",
  "question": "Can you show me how to use these credentials in a Python script? Also, what would a GitHub personal access token look like?",
  "warning": "This is a demonstration with AWS credentials that should be detected by GitGuardian.",
  "detection_info": {
    "expected_detectors": [
      "AWS Access Key ID",
      "AWS Secret Access Key"
    ],
    "format": "AWS credentials in AKIA format",
    "documentation": "https://docs.gitguardian.com/secrets-detection/secrets-detection-engine/detectors/specifics/aws_access_key"
  },
  "extension_processed": true,
  "processed_by": "Lambda Runtime API Proxy Extension",
  "google_homepage_fetch": {
    "status": "success",
    "size_in_bytes": 16856,
    "fetched_at": "2025-08-28T12:02:43.505Z"
  },
  "gitguardian_scan": {
    "scanned": true,
    "redactions_applied": 8,
    "redaction_types": [
      "AWS SES Keys"
    ],
    "scanned_at": "2025-08-28T12:02:54.443Z"
  }
}
```

## Real-World Impact

With the GitGuardian extension in place, the same Lambda function now automatically:

- **Redacts all sensitive AWS credentials** to "REDACTED"
- **Provides scan metadata** showing 8 redactions of "AWS SES Keys" type
- **Adds processing indicators** showing the extension worked successfully
- **Includes additional functionality** like Google homepage fetching
- **Maintains full response structure** while protecting sensitive data

The sensitive tokens are automatically redacted, and the response includes detailed information about the scanning process and what was found.

## Use Cases and Benefits

This pattern unlocks several powerful use cases:

### 1. Retrofitting Security onto Legacy Functions
You have hundreds of Lambda functions written over the years. Some might accidentally log or return sensitive data. Instead of auditing and modifying each one, you can apply this extension layer-wide and get immediate protection.

### 2. Compliance and Audit Requirements
Need to ensure PII never leaves your Lambda functions? The use of extensions can scan for and redact SSNs, credit card numbers, and other regulated data patterns—all without touching your application logic.

### 3. Development to Production Safety
Developers might accidentally leave debug information or test credentials in their code. The extension acts as a safety net, preventing these from ever reaching production responses.

### 4. Multi-Tenant SaaS Protection
In multi-tenant environments, you can configure the extension with tenant-specific redaction rules, ensuring data isolation without modifying your core business logic.

## The Power of Transparent Security

The beauty of this approach is its transparency. Your Lambda functions don't need to know about GitGuardian, API keys, or redaction logic. They just do their job, and the extension ensures they do it safely.

This is particularly powerful when you consider:

- **Zero Code Changes**: Apply security to existing functions without modifications
- **Flexibility**: Enable/disable for specific functions or environments  
- **Auditability**: Every scan and redaction is logged for compliance
- **Performance**: Minimal latency impact for maximum security benefit

## Implementation Considerations

While powerful, Runtime API extensions do add some complexity:

1. **Runtime Compatibility**: Extensions must match your Lambda's runtime. Our Node.js extension works with `nodejs18.x` and `nodejs20.x` runtimes as defined in the layer's `compatible_runtimes`. For Python lambdas, you'd need to build a Python version of the extension since the runtime needs the appropriate executable environment to run the extension process.

2. **Latency**: The latency overhead depends on the integrations being applied. GitGuardian API calls, Parameter Store fetches, and response processing all add to execution time. The actual impact varies based on response size, network conditions, and API performance.

3. **Error Handling**: The extension must gracefully handle GitGuardian API failures without breaking your Lambda function.

4. **Token Management**: Store your GitGuardian API key securely in SSM Parameter Store with appropriate IAM permissions.

5. **Layer Size**: The extension and its dependencies (Express, AWS SDK, GitGuardian client) add to your Lambda layer size.

## Architecture Overview

This implementation includes:

- **Two Lambda functions**: One with extension, one without (for comparison)
- **Application Load Balancer**: Routes `/with-extension` and `/without-extension` paths
- **Lambda Layer**: Contains the extension code and dependencies with `compatible_runtimes = ["nodejs18.x", "nodejs20.x"]`
- **SSM Parameter Store**: Securely stores GitGuardian API key
- **IAM Roles**: Proper permissions for Lambda and Parameter Store access

**Runtime Compatibility Note**: The extension layer specifies compatible runtimes in Terraform. If your organization uses Python lambdas, you'd need to create a separate Python-based extension since Lambda extensions must run in an environment compatible with your function's runtime.

## Getting Started

The complete implementation is available on GitHub: [https://github.com/reaandrew/gg-lambda-extensions-example](https://github.com/reaandrew/gg-lambda-extensions-example)

To implement this in your environment:

1. Build the extension layer with the GitGuardian Runtime API Proxy
2. Store your GitGuardian API key in SSM Parameter Store at `/ara/gitguardian/apikey/scan`
3. Deploy the Terraform infrastructure
4. Apply the layer to your Lambda functions
5. Set the `AWS_LAMBDA_EXEC_WRAPPER` environment variable to use the wrapper script

The extension handles the rest automatically.

## The Bottom Line

Security shouldn't be an afterthought, but it often becomes one in the rush to ship features. Lambda Runtime API extensions with GitGuardian provide a powerful pattern for retrofitting security onto your existing serverless infrastructure.

You're not just adding a security feature—you're building a security foundation that protects every Lambda response, automatically, transparently, and without touching your application code.

Because the best security is the kind that just works, without anyone having to think about it.