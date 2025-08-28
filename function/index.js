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