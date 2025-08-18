exports.handler = async (event, context) => {
    console.log('[handler] incoming event', JSON.stringify(event));
    
    const response = {
        statusCode: 200,
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({
            message: 'Test response without extension'
        })
    };
    
    return response;
};