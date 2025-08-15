#!/usr/bin/env node

import { ExtensionsApiClient } from './extensions-api-client.mjs'
import { RuntimeApiProxy } from './runtime-api-proxy.mjs'

console.log('[LRAP:index] starting...');

process.on('SIGINT', () => process.exit(0));
process.on('SIGTERM', () => process.exit(0));

new RuntimeApiProxy().start();
new ExtensionsApiClient().bootstrap();