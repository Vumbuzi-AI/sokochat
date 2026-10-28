import { Type } from '@earendil-works/pi-ai';
import { defineTool, defineExtension } from '@earendil-works/pi-durable';
import type { Turn } from './runtime.ts';

// The model supplies business arguments only. Workspace/conversation/request scope,
// credentials and the callback origin always come from the trusted host.
export function businessTools(turn: Turn, claim: (kind: 'tool_calls') => Promise<void>) {
  const base = new URL(process.env.SOKOCHAT_INTERNAL_URL || 'http://127.0.0.1:4000');
  if (base.protocol !== 'https:' && !(base.protocol === 'http:' && ['127.0.0.1', 'localhost', '[::1]'].includes(base.hostname))) {
    throw new Error('SOKOCHAT_INTERNAL_URL must use HTTPS outside loopback');
  }
  async function read(tool: string, params: Record<string, string | number> = {}) {
    await claim('tool_calls');
    const url = new URL(`/api/intelligence/workspaces/${turn.workspace_id}/conversations/${turn.conversation_id}/tools/${tool}`, base);
    for (const [key, value] of Object.entries(params)) url.searchParams.set(key, String(value));
    const response = await fetch(url, {
      headers: { authorization: `Bearer ${process.env.PI_SERVICE_TOKEN}`, 'x-pi-request-id': turn.request_id },
      signal: AbortSignal.timeout(8000), redirect: 'error',
    });
    if (!response.ok) throw new Error(`Business tool unavailable (HTTP ${response.status})`);
    const chunks: Uint8Array[] = [];
    let size = 0;
    if (!response.body) throw new Error('Business tool returned no response body');
    for await (const chunk of response.body) {
      size += chunk.byteLength;
      if (size > 128_000) throw new Error('Business tool response exceeds size limit');
      chunks.push(chunk);
    }
    const text = Buffer.concat(chunks).toString('utf8');
    return { output: [{ type: 'text' as const, text }], details: { tool } };
  }
  return defineExtension({
    name: 'sokochat-business',
    tools: [
      defineTool({ name: 'shop_profile', description: 'Read this shop’s factual business profile and contact information. Never invent missing policies.',
        parameters: Type.Object({}), replay: 'safe', execute: () => read('shop_profile') }),
      defineTool({ name: 'list_categories', description: 'List this shop’s product categories before broad browsing.',
        parameters: Type.Object({}), replay: 'safe', execute: () => read('list_categories') }),
      defineTool({ name: 'search_products', description: 'Search active products in this shop. Empty query browses products. Results include IDs, image URLs, price, size variants and stock metadata. Use next_offset for more results.',
        parameters: Type.Object({ query: Type.String({ maxLength: 160 }), category: Type.Optional(Type.String({ maxLength: 120 })), offset: Type.Optional(Type.Integer({ minimum: 0, maximum: 10000 })) }),
        replay: 'safe', execute: args => read('search_products', { query: args.query, category: args.category || '', offset: args.offset || 0 }) }),
      defineTool({ name: 'get_product', description: 'Get one active product by its returned ID or external ID. Use for exact current size, price and image details.',
        parameters: Type.Object({ product_id: Type.String({ minLength: 1, maxLength: 120 }) }),
        replay: 'safe', execute: args => read('get_product', args) }),
    ],
  });
}
