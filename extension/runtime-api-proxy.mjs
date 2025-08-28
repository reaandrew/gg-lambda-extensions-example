import express from 'express'
const RUNTIME_API_ENDPOINT = process.env.LRAP_RUNTIME_API_ENDPOINT || process.env.AWS_LAMBDA_RUNTIME_API;
const LISTENER_PORT = process.env.LRAP_LISTENER_PORT || 9009;
const RUNTIME_API_URL = `http://${RUNTIME_API_ENDPOINT}/2018-06-01/runtime`;

export class RuntimeApiProxy {
    async start() {
        console.info(`[RuntimeApiProxy] Starting proxy RUNTIME_API_ENDPOINT=${RUNTIME_API_ENDPOINT} LISTENER_PORT=${LISTENER_PORT}`)
        const listener = express()
        listener.use(express.json())
        listener.use(this.logIncomingRequest)
        listener.get('/2018-06-01/runtime/invocation/next', this.handleNext);
        listener.post('/2018-06-01/runtime/invocation/:requestId/response', this.handleResponse);
        listener.post('/2018-06-01/runtime/init/error', this.handleInitError);
        listener.post('/2018-06-01/runtime/invocation/:requestId/error', this.handleInvokeError);
        listener.use((_, res) => res.status(404).send());
        listener.listen(LISTENER_PORT)
    }

    async handleNext(_, res){
        console.log('[RuntimeApiProxy] handleNext')
        
        const nextEvent = await fetch(`${RUNTIME_API_URL}/invocation/next`);
        const eventPayload = await nextEvent.json();
        
        eventPayload['extension-processed']=true;

        nextEvent.headers.forEach((value, key)=>{
            res.set(key, value);
        });

        return res.send(eventPayload)
    }

    async handleResponse(req, res) {
        const requestId = req.params.requestId
        console.log(`[RuntimeApiProxy] handleResponse requestid=${requestId}`)

        const responseJson = req.body;

        if (responseJson && responseJson.body) {
            try {
                const bodyObj = JSON.parse(responseJson.body);
                
                // Add extension processing marker
                bodyObj.extension_processed = true;
                bodyObj.processed_by = "Lambda Runtime API Proxy Extension";
                
                // If there's sensitive data, add a note about it being detected
                if (bodyObj.apikey || bodyObj.sample_token) {
                    bodyObj.extension_note = "Extension detected potential sensitive data in response";
                }
                
                responseJson.body = JSON.stringify(bodyObj);
            } catch (e) {
                console.log('[RuntimeApiProxy] Could not parse response body as JSON');
            }
        }

        responseJson['extension-processed']=true;

        const resp = await fetch(`${RUNTIME_API_URL}/invocation/${requestId}/response`, {
                method: 'POST',
                body: JSON.stringify(responseJson),
            },
        )

        console.log('[RuntimeApiProxy] handleResponse posted')
        return res.status(resp.status).json(await resp.json())
    }

    async handleInitError(req, res) {
        console.log(`[RuntimeApiProxy] handleInitError`)

        const resp = await fetch(`${RUNTIME_API_URL}/init/error`, {
            method: 'POST',
            headers: req.headers,
            body: JSON.stringify(req.body),
        })

        console.log('[RuntimeApiProxy] handleInitError posted')
        return res.status(resp.status).json(await resp.json())
    }

    async handleInvokeError(req, res) {
        const requestId = req.params.requestId
        console.log(`[RuntimeApiProxy] handleInvokeError requestid=${requestId}`)
        
        const resp = await fetch(`${RUNTIME_API_URL}/invocation/${requestId}/error`, {
            method: 'POST',
            headers: req.headers,
            body: JSON.stringify(req.body),
        });

        console.log('[RuntimeApiProxy] handleInvokeError posted')
        return res.status(resp.status).json(await resp.json());
    }

    logIncomingRequest(req, _, next) {
        console.log(`[RuntimeApiProxy] ${req.method} ${req.originalUrl}`);
        next();
    }
}