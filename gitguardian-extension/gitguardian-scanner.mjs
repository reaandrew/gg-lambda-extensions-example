import { SSMClient, GetParameterCommand } from '@aws-sdk/client-ssm';
import fetch from 'node-fetch';

const MAX_MB = 1;
const MAX_DOC_SIZE = MAX_MB * 1024 * 1024;
const MAX_DOCS = 20;
const GG_ENDPOINT = 'https://api.gitguardian.com/v1/multiscan';

export class GitGuardianScanner {
    constructor() {
        this.ssmClient = new SSMClient();
        this.apiKey = null;
    }

    async getApiKey() {
        if (this.apiKey) {
            return this.apiKey;
        }

        const ssmKeyPath = process.env.GITGUARDIAN_SSM_KEY_PATH || '/gitguardian/apikey';
        
        try {
            const command = new GetParameterCommand({
                Name: ssmKeyPath,
                WithDecryption: true
            });

            const response = await this.ssmClient.send(command);
            this.apiKey = response.Parameter.Value;
            return this.apiKey;
        } catch (error) {
            console.error('[GitGuardian:Scanner] Failed to get API key:', error);
            throw error;
        }
    }

    buildDocuments(raw, filename = "response.txt") {
        if (Buffer.byteLength(raw, 'utf8') <= MAX_DOC_SIZE) {
            return [{ filename, document: raw }];
        }

        // Simple chunking for large content
        const chunkSize = MAX_DOC_SIZE - 1000; // Leave some buffer
        const chunks = [];
        for (let i = 0; i < raw.length; i += chunkSize) {
            chunks.push(raw.substring(i, i + chunkSize));
        }

        if (chunks.length > MAX_DOCS) {
            throw new Error(`Content would need ${chunks.length} chunks (>${MAX_DOCS}); aborting.`);
        }

        return chunks.map((doc, i) => ({
            filename: `${filename}.part${i}`,
            document: doc,
        }));
    }

    async scanContent(content, filename = "response.txt") {
        try {
            const apiKey = await this.getApiKey();
            const docs = this.buildDocuments(content, filename);

            const response = await fetch(GG_ENDPOINT, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${apiKey}`,
                },
                body: JSON.stringify(docs),
            });

            if (!response.ok) {
                const txt = await response.text().catch(() => response.statusText);
                throw new Error(`GitGuardian API error ${response.status}: ${txt}`);
            }

            return await response.json();
        } catch (error) {
            console.error('[GitGuardian:Scanner] Scan failed:', error.message);
            throw error;
        }
    }

    redactSensitiveContent(content, scanResults) {
        if (!scanResults || scanResults.length === 0) {
            return {
                content,
                redactions: []
            };
        }

        let redactedContent = content;
        const redactions = [];
        const processedRanges = new Set();

        // Collect all matches from all scan results
        const allMatches = scanResults.flatMap(result => {
            if (!result.policy_breaks) return [];
            
            return result.policy_breaks.flatMap(policyBreak => {
                if (!policyBreak.matches) return [];
                
                return policyBreak.matches.map(match => ({
                    ...match,
                    type: policyBreak.type,
                    start: match.index_start || match.start,
                    end: (match.index_end || match.end) + 1,
                    policy: policyBreak.policy
                }));
            });
        }).sort((a, b) => b.start - a.start); // Sort by start position in reverse order

        // Apply redactions
        for (const match of allMatches) {
            if (match.start === undefined || match.end === undefined) {
                continue;
            }

            const rangeKey = `${match.start}-${match.end}`;
            if (processedRanges.has(rangeKey)) {
                continue;
            }
            processedRanges.add(rangeKey);

            const before = redactedContent.substring(0, match.start);
            const after = redactedContent.substring(match.end);
            const original = content.substring(match.start, match.end);
            
            redactedContent = before + '[REDACTED]' + after;

            redactions.push({
                type: match.type,
                start: match.start,
                end: match.end,
                original,
                policy: match.policy
            });
        }

        return {
            content: redactedContent,
            redactions
        };
    }

    async scanAndRedact(content, filename = "response.txt") {
        try {
            console.log('[GitGuardian:Scanner] Scanning content for sensitive data');
            const scanResults = await this.scanContent(content, filename);
            
            console.log(`[GitGuardian:Scanner] Scan completed, found ${scanResults.length} result(s)`);
            
            const result = this.redactSensitiveContent(content, scanResults);
            
            if (result.redactions.length > 0) {
                console.log(`[GitGuardian:Scanner] Redacted ${result.redactions.length} sensitive item(s)`);
            }
            
            return result;
        } catch (error) {
            console.error('[GitGuardian:Scanner] Scan and redact failed:', error);
            // Return original content if scanning fails
            return {
                content,
                redactions: [],
                error: error.message
            };
        }
    }
}