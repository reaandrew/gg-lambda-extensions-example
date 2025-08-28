const EXTENSIONS_API_ENDPOINT = process.env.AWS_LAMBDA_RUNTIME_API;
const EXTENSIONS_API_URL = `http://${EXTENSIONS_API_ENDPOINT}/2020-01-01/extension`;

export class ExtensionsApiClient {
    constructor() {
        this.extensionId = null;
    }

    async register() {
        console.log('[ExtensionsApiClient] Registering extension');
        
        const response = await fetch(`${EXTENSIONS_API_URL}/register`, {
            method: 'POST',
            headers: {
                'Lambda-Extension-Name': 'runtime-api-proxy-extension',
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                events: ['INVOKE', 'SHUTDOWN']
            })
        });

        if (!response.ok) {
            throw new Error(`Failed to register extension: ${response.status} ${response.statusText}`);
        }

        this.extensionId = response.headers.get('Lambda-Extension-Identifier');
        console.log(`[ExtensionsApiClient] Extension registered with ID: ${this.extensionId}`);
        
        return this.extensionId;
    }

    async next() {
        console.log('[ExtensionsApiClient] Waiting for next event');
        
        const response = await fetch(`${EXTENSIONS_API_URL}/event/next`, {
            method: 'GET',
            headers: {
                'Lambda-Extension-Identifier': this.extensionId
            }
        });

        if (!response.ok) {
            throw new Error(`Failed to get next event: ${response.status} ${response.statusText}`);
        }

        const event = await response.json();
        console.log(`[ExtensionsApiClient] Received event: ${JSON.stringify(event)}`);
        
        return event;
    }
}