import express from 'express';
import { GitGuardianScanner } from './gitguardian-scanner.mjs';

const RUNTIME_API_ENDPOINT = process.env.LRAP_RUNTIME_API_ENDPOINT || process.env.AWS_LAMBDA_RUNTIME_API;
const LISTENER_PORT = process.env.LRAP_LISTENER_PORT || 9009;
const RUNTIME_API_URL = `http://${RUNTIME_API_ENDPOINT}/2018-06-01/runtime`;

export class RuntimeApiProxy {
    constructor() {
        this.scanner = new GitGuardianScanner();
    }

    async start() {
        console.info(`[GitGuardian:RuntimeApiProxy] start RUNTIME_API_ENDPOINT=${RUNTIME_API_ENDPOINT} LISTENER_PORT=${LISTENER_PORT}`);
        const listener = express();
        listener.use(express.json());
        listener.use(this.logIncomingRequest);
        listener.get('/2018-06-01/runtime/invocation/next', this.handleNext);
        listener.post('/2018-06-01/runtime/invocation/:requestId/response', this.handleResponse.bind(this));
        listener.post('/2018-06-01/runtime/init/error', this.handleInitError);
        listener.post('/2018-06-01/runtime/invocation/:requestId/error', this.handleInvokeError);
        listener.use((_, res) => res.status(404).send());
        listener.listen(LISTENER_PORT);
    }

    async handleNext(_, res) {
        console.log('[GitGuardian:RuntimeProxy] handleNext');
        
        // Getting the next event from Lambda Runtime API
        const nextEvent = await fetch(`${RUNTIME_API_URL}/invocation/next`);
        
        // Extracting the event payload
        const eventPayload = await nextEvent.json();
        
        // Updating the event payload to mark as processed
        eventPayload['gitguardian-processed'] = true;

        // Copying headers 
        nextEvent.headers.forEach((value, key) => {
            res.set(key, value);
        });

        return res.send(eventPayload);
    }

    async handleResponse(req, res) {
        const requestId = req.params.requestId;
        console.log(`[GitGuardian:RuntimeProxy] handleResponse requestid=${requestId}`);

        // Extracting the handler response
        const responseJson = req.body;

        // Scan and redact the response content
        if (responseJson && responseJson.body) {
            try {
                const bodyObj = JSON.parse(responseJson.body);
                
                // Convert the entire response body to a string for scanning
                const responseContent = JSON.stringify(bodyObj);
                
                // Scan and redact sensitive content
                const { content: redactedContent, redactions, error } = await this.scanner.scanAndRedact(
                    responseContent, 
                    'lambda_response.json'
                );

                if (redactions.length > 0) {
                    console.log(`[GitGuardian:RuntimeProxy] Found and redacted ${redactions.length} sensitive items`);
                    
                    // Parse the redacted content back to JSON and update the response
                    try {
                        const redactedBodyObj = JSON.parse(redactedContent);
                        
                        // Add metadata about redactions
                        redactedBodyObj._gitguardian = {
                            redacted: true,
                            redaction_count: redactions.length,
                            redaction_types: [...new Set(redactions.map(r => r.type))]
                        };
                        
                        responseJson.body = JSON.stringify(redactedBodyObj);
                    } catch (parseError) {
                        console.error('[GitGuardian:RuntimeProxy] Failed to parse redacted content, using string replacement');
                        // If JSON parsing fails, do simple string replacement in the original body
                        let redactedBody = responseJson.body;
                        for (const redaction of redactions) {
                            redactedBody = redactedBody.replace(redaction.original, '[REDACTED]');
                        }
                        responseJson.body = redactedBody;
                    }
                } else {
                    console.log('[GitGuardian:RuntimeProxy] No sensitive content detected');
                }

                if (error) {
                    console.error(`[GitGuardian:RuntimeProxy] Scanning error: ${error}`);
                }

            } catch (e) {
                console.error('[GitGuardian:RuntimeProxy] Error processing response body:', e);
            }
        }

        // Adding marker to show extension processed the response
        responseJson['gitguardian-processed'] = true;

        // Posting the updated response to Lambda Runtime API
        const resp = await fetch(`${RUNTIME_API_URL}/invocation/${requestId}/response`, {
            method: 'POST',
            body: JSON.stringify(responseJson),
        });

        console.log('[GitGuardian:RuntimeProxy] handleResponse posted');
        return res.status(resp.status).json(await resp.json());
    }

    async handleInitError(req, res) {
        console.log('[GitGuardian:RuntimeProxy] handleInitError');

        const resp = await fetch(`${RUNTIME_API_URL}/init/error`, {
            method: 'POST',
            headers: req.headers,
            body: JSON.stringify(req.body),
        });

        console.log('[GitGuardian:RuntimeProxy] handleInitError posted');
        return res.status(resp.status).json(await resp.json());
    }

    async handleInvokeError(req, res) {
        const requestId = req.params.requestId;
        console.log(`[GitGuardian:RuntimeProxy] handleInvokeError requestid=${requestId}`);
        
        const resp = await fetch(`${RUNTIME_API_URL}/invocation/${requestId}/error`, {
            method: 'POST',
            headers: req.headers,
            body: JSON.stringify(req.body),
        });

        console.log('[GitGuardian:RuntimeProxy] handleInvokeError posted');
        return res.status(resp.status).json(await resp.json());
    }

    logIncomingRequest(req, _, next) {
        console.log(`[GitGuardian:RuntimeProxy] logIncomingRequest method=${req.method} url=${req.originalUrl}`);
        next();
    }
}