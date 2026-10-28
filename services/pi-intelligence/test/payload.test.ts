import test from 'node:test';
import assert from 'node:assert/strict';
import { responsePayload } from '../src/payload.ts';
import type { Turn } from '../src/runtime.ts';

const turn: Turn = {
  workspace_id: 4, conversation_id: 8, request_id: 'message-12', model: 'gpt-5.5',
  instructions: 'Help with shoes', tool_mode: 'catalog',
  input: [{ role: 'assistant', content: 'Hello there!' }, { role: 'user', content: 'Show Adidas Spezial' }],
  response_format: { type: 'json_schema', name: 'reply', strict: true, schema: { type: 'object' } },
};

test('preserves reasoning, tool calls, and their matching outputs on a follow-up generation', () => {
  const transcript = [
    { role: 'user', content: 'Show Adidas Spezial' },
    { type: 'reasoning', id: 'reason-1', summary: [] },
    { type: 'function_call', call_id: 'call-1', name: 'get_product', arguments: '{"product_id":"adidas"}' },
    { type: 'function_call_output', call_id: 'call-1', output: '{"price":6500}' },
  ];
  const result = responsePayload({ input: transcript, tools: [{ name: 'get_product' }] }, turn);
  assert.deepEqual(result.input, [turn.input[0], ...transcript]);
  assert.equal(result.input.filter((item: any) => item.content === 'Show Adidas Spezial').length, 1);
  assert.deepEqual((result as Record<string, unknown>).tools, [{ name: 'get_product' }]);
});

test('does not substitute a fresh user input when a provider transcript is missing', () => {
  assert.throws(() => responsePayload({}, turn), /Responses transcript/);
});
