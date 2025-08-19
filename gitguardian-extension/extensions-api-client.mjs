import fetch from 'node-fetch';

const EXTENSIONS_API_ENDPOINT = process.env.AWS_LAMBDA_RUNTIME_API;
const EXTENSIONS_API_URL = `http://${EXTENSIONS_API_ENDPOINT}/2020-01-01/extension`;

export class ExtensionsApiClient {
    constructor() {
        this.extensionId = null;
    }

    async bootstrap() {
        console.log('[GitGuardian:ExtensionsApiClient] bootstrap');
        
        try {
            await this.register();
            await this.processEvents();
        } catch (error) {
            console.error('[GitGuardian:ExtensionsApiClient] Error:', error);
        }
    }

    async register() {
        console.log('[GitGuardian:ExtensionsApiClient] register');

        const registerPayload = {
            events: ['INVOKE', 'SHUTDOWN']
        };

        const response = await fetch(`${EXTENSIONS_API_URL}/register`, {
            method: 'POST',
            headers: {
                'Lambda-Extension-Name': 'gitguardian-extension'
            },
            body: JSON.stringify(registerPayload)
        });

        if (!response.ok) {
            console.error('[GitGuardian:ExtensionsApiClient] Failed to register');
            throw new Error(`Failed to register extension: ${response.status}`);
        }

        this.extensionId = response.headers.get('lambda-extension-identifier');
        console.log(`[GitGuardian:ExtensionsApiClient] Registered with ID: ${this.extensionId}`);
    }

    async processEvents() {
        console.log('[GitGuardian:ExtensionsApiClient] processEvents');
        
        while (true) {
            try {
                const event = await this.getNextEvent();
                
                if (event.eventType === 'SHUTDOWN') {
                    console.log('[GitGuardian:ExtensionsApiClient] Received SHUTDOWN event');
                    break;
                } else if (event.eventType === 'INVOKE') {
                    console.log('[GitGuardian:ExtensionsApiClient] Received INVOKE event');
                    // Event processing is handled by the runtime proxy
                }
            } catch (error) {
                console.error('[GitGuardian:ExtensionsApiClient] Error processing events:', error);
                break;
            }
        }
    }

    async getNextEvent() {
        const response = await fetch(`${EXTENSIONS_API_URL}/event/next`, {
            method: 'GET',
            headers: {
                'Lambda-Extension-Identifier': this.extensionId
            }
        });

        if (!response.ok) {
            throw new Error(`Failed to get next event: ${response.status}`);
        }

        return await response.json();
    }
}