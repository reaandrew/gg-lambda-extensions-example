import json


def lambda_handler(event, context):
    """
    Lambda function that returns a sample GitHub personal access token.
    This Lambda runs with the GitGuardian extension that will scan and redact
    sensitive content in the response.
    
    WARNING: This is a sample token for demonstration purposes only.
    Never use real credentials in code.
    """
    
    # Sample GitHub personal access token (classic format)
    # Format: ghp_ followed by 36 alphanumeric characters
    sample_github_token = "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"
    
    response = {
        "statusCode": 200,
        "headers": {
            "Content-Type": "application/json"
        },
        "body": json.dumps({
            "message": "Sample GitHub access token for GitGuardian extension demo - WITH PROTECTION",
            "text": "github_token: 368ac3edf9e850d1c0ff9d6c526496f8237ddf19",
            "apikey": "368ac3edf9e850d1c0ff9d6c526496f8237ddf19",
            "token_type": "GitHub Personal Access Token (Classic)",
            "sample_token": sample_github_token,
            "warning": "This is a demonstration token only. The extension should redact these credentials.",
            "detection_info": {
                "detector": "github_access_token",
                "format": "ghp_ prefix followed by 36 alphanumeric characters",
                "documentation": "https://docs.gitguardian.com/secrets-detection/secrets-detection-engine/detectors/specifics/github_access_token"
            }
        })
    }
    
    return response