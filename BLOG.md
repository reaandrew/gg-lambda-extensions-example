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

## Starting Simple: Hello World with Extensions

Let's look at a basic example. I have a simple Lambda function that returns a "Hello World" message:

```javascript
exports.handler = async (event, context) => {
    console.log('[handler] incoming event', JSON.stringify(event));
    
    const response = {
        statusCode: 200,
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({
            message: 'Hello World from Lambda!'
        })
    };
    
    return response;
};
```

Without any extension, this function returns exactly what you'd expect. But when I add my Runtime API extension, something interesting happens. The extension's `handleResponse` method intercepts the response and modifies it:

```javascript
async handleResponse(req, res) {
    const requestId = req.params.requestId
    console.log(`[LRAP:RuntimeProxy] handleResponse requestid=${requestId}`)

    // Extracting the handler response
    const responseJson = req.body;

    // Modify the response to add 'Extension Applied' to the message
    if (responseJson && responseJson.body) {
        try {
            const bodyObj = JSON.parse(responseJson.body);
            if (bodyObj.message) {
                bodyObj.message = bodyObj.message + ' - Extension Applied';
                responseJson.body = JSON.stringify(bodyObj);
            }
        } catch (e) {
            console.log('[LRAP:RuntimeProxy] Could not parse response body as JSON');
        }
    }

    // Forward to the actual Runtime API
    const resp = await fetch(`${RUNTIME_API_URL}/invocation/${requestId}/response`, {
        method: 'POST',
        body: JSON.stringify(responseJson),
    })

    return res.status(resp.status).json(await resp.json())
}
```

Now the function returns "Hello World from Lambda! - Extension Applied" without any changes to the original function code. This demonstrates the core capability—we can modify responses transparently.

## Leveling Up: GitGuardian-Powered Secret Redaction

Now for the interesting part. What if instead of appending text, we could automatically detect and redact sensitive information? Enter the GitGuardian extension.

### The Problem: Accidental Secret Exposure

Consider this Lambda function that accidentally returns sensitive information (the text and apiKey has been taken from the detectors page from GitGuardian docs):

```python
def lambda_handler(event, context):
    """
    Lambda function that returns a sample GitHub personal access token.
    WARNING: This is a sample token for demonstration purposes only.
    """
    
    sample_github_token = "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"
    
    response = {
        "statusCode": 200,
        "headers": {
            "Content-Type": "application/json"
        },
        "body": json.dumps({
            "message": "Sample GitHub access token for GitGuardian detection demo",
            "text": "github_token: 368ac3edf9e850d1c0ff9d6c526496f8237ddf19",
            "apikey": "368ac3edf9e850d1c0ff9d6c526496f8237ddf19",
            "sample_token": sample_github_token,
            "warning": "This is a demonstration token only."
        })
    }
    
    return response
```

Without protection, this function would happily return those tokens to any caller. Not ideal.

### The Solution: Automatic Redaction Extension

The GitGuardian extension intercepts these responses and scans them for sensitive data before they leave your Lambda.  The extension fetches the GitGuardian API key from AWS Systems Manager Parameter Store on startup, ensuring credentials are managed securely·  When sensitive data is detected, the extension performs intelligent redaction.

![extensions.png](images/extensions.png)


## Real-World Impact

With the GitGuardian extension in place, that same Lambda function now returns:

```json
{
    "message": "Sample GitHub access token for GitGuardian detection demo",
    "text": "github_token: REDACTED",
    "apikey": "REDACTED",
    "sample_token": "REDACTED",
    "warning": "This is a demonstration token only."
}
```

The sensitive tokens are automatically redacted, and the response includes headers indicating it was scanned and redacted:
- `X-GitGuardian-Scanned: true`
- `X-GitGuardian-Redacted: true`

## Use Cases and Benefits

This pattern unlocks several powerful use cases:

### 1. Retrofitting Security onto Legacy Functions
You have hundreds of Lambda functions written over the years. Some might accidentally log or return sensitive data. Instead of auditing and modifying each one, you can apply this extension layer-wide and get immediate protection.

### 2. Compliance and Audit Requirements
Need to ensure PII never leaves your Lambda functions? The use of extensions can scan for and redact NINOs, SSNs, credit card numbers, and other regulated data patterns—all without touching your application logic.

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

## Implementation Considerations

While powerful, Runtime API extensions do add some complexity:

1. **Latency**: The scanning adds milliseconds to your response time. For most use cases, this is negligible compared to the security benefit.

2. **Error Handling**: The extension must gracefully handle GitGuardian API failures without breaking your Lambda function.

3. **Token Management**: Store your GitGuardian API key securely in SSM Parameter Store with appropriate IAM permissions.

4. **Layer Size**: The extension and its dependencies (Express, AWS SDK, node-fetch) add to your Lambda layer size.

## Getting Started

To implement this in your environment:

1. Build the extension layer with the GitGuardian Runtime API Proxy
2. Store your GitGuardian API key in SSM Parameter Store
3. Apply the layer to your Lambda functions
4. Set the `AWS_LAMBDA_FUNCTION_RUNTIME_API` environment variable to use the wrapper script

The extension handles the rest automatically.

## The Bottom Line

Security shouldn't be an afterthought, but it often becomes one in the rush to ship features. Lambda Runtime API extensions with GitGuardian provide a powerful pattern for retrofitting security onto your existing serverless infrastructure.

You're not just adding a security feature—you're building a security foundation that protects every Lambda response, automatically, transparently, and without touching your application code.

Because the best security is the kind that just works, without anyone having to think about it.