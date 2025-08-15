// Use the original runtime API endpoint, not the proxied one
const AWS_LAMBDA_RUNTIME_API = process.env.LRAP_RUNTIME_API_ENDPOINT || process.env.AWS_LAMBDA_RUNTIME_API;
const EXTENSIONS_API_ENDPOINT = `http://${AWS_LAMBDA_RUNTIME_API}/2020-01-01/extension`;

export class ExtensionsApiClient {
    constructor(){
        this.extensionId = null;
    }

    async bootstrap(){
        console.info(`[LRAP:ExtensionsApiClient] bootstrap `);
        await this.register();
        await this.next();
    }

    async register() {
        console.info(`[LRAP:ExtensionsApiClient] register endpoint=${EXTENSIONS_API_ENDPOINT}`);
        const res = await fetch(`${EXTENSIONS_API_ENDPOINT}/register`, {
            method: 'POST',
            body: JSON.stringify({
                events: [], // Don't register for events to avoid blocking
            }),
            headers: {
                'Content-Type': 'application/json',
                'Lambda-Extension-Name': 'nodejs-example-lambda-runtime-api-proxy-extension'
            }
        });

        if (!res.ok) {
            console.error('[LRAP:ExtensionsApiClient] register failed:', await res.text());
        } else {
            this.extensionId = res.headers.get('lambda-extension-identifier');
            console.info(`[LRAP:ExtensionsApiClient] register success extensionId=${this.extensionId}`);
        }
    }

    async next(){
        console.info('[LRAP:ExtensionsApiClient] next waiting...');
        const res = await fetch(`${EXTENSIONS_API_ENDPOINT}/event/next`, {
            method: 'GET',
            headers: {
                'Content-Type': 'application/json',
                'Lambda-Extension-Identifier': this.extensionId
            }
        });
    
        if (!res.ok) {
            console.error('[LRAP:ExtensionsApiClient] next failed', await res.text());
            return null;
        } else {
            const event = await res.json();
            console.info('[LRAP:ExtensionsApiClient] next success');
            return event;
        }
    }
}