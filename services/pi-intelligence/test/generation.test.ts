import test from 'node:test';
import assert from 'node:assert/strict';
import { thinkingLevel } from '../src/generation.ts';

test('shop chat disables GPT-5.5 reasoning while keeping other models on low', () => {
  assert.equal(thinkingLevel('gpt-5.5'), 'off');
  assert.equal(thinkingLevel('gpt-6-astra'), 'low');
});

test('operators can restore low reasoning and invalid settings fail closed', () => {
  assert.equal(thinkingLevel('gpt-5.5', 'low'), 'low');
  assert.throws(() => thinkingLevel('gpt-5.5', 'lwo'), /PI_THINKING_LEVEL/);
});
