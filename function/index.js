exports.handler = async (event, context) => {
    console.log('[handler] incoming event', JSON.stringify(event));
    
    const sampleGithubToken = "ghp_" + "R3m0v3M3B3f0r3C0mm1tt1ngTh1sT0k3n12345";
    
    const response = {
        statusCode: 200,
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({
            message: "Sample GitHub access token for GitGuardian detection demo",
            text: "github_token: 368ac3edf9e850d1c0ff9d6c526496f8237ddf19",
            apikey: "368ac3edf9e850d1c0ff9d6c526496f8237ddf19",
            token_type: "GitHub Personal Access Token (Classic)",
            sample_token: sampleGithubToken,
            warning: "This is a demonstration token only. Never expose real credentials.",
            detection_info: {
                detector: "github_access_token",
                format: "ghp_ prefix followed by 36 alphanumeric characters",
                documentation: "https://docs.gitguardian.com/secrets-detection/secrets-detection-engine/detectors/specifics/github_access_token"
            }
        })
    };
    
    return response;
};