#!/usr/bin/env node

import { ExtensionsApiClient } from './extensions-api-client.mjs';
import { RuntimeApiProxy } from './runtime-api-proxy.mjs';

console.log('[GitGuardian:Extension] Starting GitGuardian Lambda Extension...');

process.on('SIGINT', () => {
    console.log('[GitGuardian:Extension] Received SIGINT, exiting...');
    process.exit(0);
});

process.on('SIGTERM', () => {
    console.log('[GitGuardian:Extension] Received SIGTERM, exiting...');
    process.exit(0);
});

// Start the runtime API proxy and extensions API client
new RuntimeApiProxy().start();
new ExtensionsApiClient().bootstrap();