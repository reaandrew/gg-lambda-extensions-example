import { ExtensionsApiClient } from './extensions-api-client.mjs';
import { RuntimeApiProxy } from './runtime-api-proxy.mjs';

(async () => {
    console.log('[Extension] Starting extension');
    
    const extensionsClient = new ExtensionsApiClient();
    const runtimeProxy = new RuntimeApiProxy();
    
    try {
        await extensionsClient.register();
        await runtimeProxy.start();
        
        while (true) {
            const event = await extensionsClient.next();
            console.log(`[Extension] Received event: ${event.eventType}`);
            
            if (event.eventType === 'SHUTDOWN') {
                console.log('[Extension] Shutting down');
                break;
            }
        }
    } catch (error) {
        console.error('[Extension] Error:', error);
        process.exit(1);
    }
})();