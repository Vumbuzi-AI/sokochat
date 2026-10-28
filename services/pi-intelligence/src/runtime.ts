import { BACKGROUND_CONTEXT } from '@earendil-works/chord/context';
import { createModels } from '@earendil-works/pi-ai/models';
import { openaiProvider } from '@earendil-works/pi-ai/providers/openai';
import type { Provider } from '@earendil-works/pi-ai/models';
import { AssistantEntry, createRegistry, Harness } from '@earendil-works/pi-durable';
import { openNodeSqliteStorage } from '@earendil-works/pi-durable/storage/sqlite/node';
import { Ajv } from 'ajv';
import { join } from 'node:path';
import { businessTools } from './tools.ts';
import { turnBudget } from './budget.ts';
import { responsePayload } from './payload.ts';

export interface Turn {
  workspace_id: number;
  conversation_id: number;
  request_id: string;
  model: string;
  thinking_level?: 'off' | 'low';
  expires_at?: number;
  tool_mode?: 'catalog' | 'context';
  instructions: string;
  input: { role: 'user' | 'assistant'; content: string }[];
  response_format: { type: 'json_schema'; name: string; strict: boolean; schema: object };
}

// Each execution owns one SQLite file. Phoenix supplies the authoritative history
// snapshot; Pi owns admission, generation checkpoints, the answer and usage.
export async function runTurn(directory: string, turn: Turn) {
  const started = performance.now();
  const budget = await turnBudget(directory, turn.expires_at);
  if (Date.now() >= budget.deadline) throw new Error('Turn execution deadline exceeded');
  const provider = openaiProvider();
  const models = createModels();
  const sokochatProvider: Provider<'openai-responses'> = {
    ...provider,
    streamSimple(model, transcript, options) {
      return provider.streamSimple(model, transcript, {
        ...options,
        async onPayload(payload) {
          await budget.claim('model_requests');
          return responsePayload(payload as Record<string, unknown>, turn);
        },
      });
    },
  };
  models.setProvider(sokochatProvider);
  const modelId = turn.model;
  const model = models.getModel('openai', modelId);
  if (!model) throw new Error(`Model ${modelId} is absent from the pinned Pi catalog`);
  const thinking = turn.thinking_level ?? 'low'; // Older admitted turns retain their original setting.
  if (model.thinkingLevelMap?.[thinking] === null) throw new Error(`Model ${modelId} does not support ${thinking} thinking`);
  const storage = await openNodeSqliteStorage(join(directory, 'session.sqlite'));
  const registry = createRegistry();
  if (turn.tool_mode === 'catalog') registry.install(businessTools(turn, budget.claim));
  let harness: Awaited<ReturnType<typeof Harness.open>> | undefined;
  let deadlineTimer: ReturnType<typeof setTimeout> | undefined;
  try {
    harness = await Harness.open(storage, {
      models,
      registry,
      identity: { attribution: null },
      settings: {
        stream: { timeoutMs: 45_000, maxRetries: 0 },
        retry: { enabled: true, maxRetries: 1, baseDelayMs: 1000 },
        compaction: { enabled: false },
      },
    }, BACKGROUND_CONTEXT);
    const conversation = await harness.root(BACKGROUND_CONTEXT, {
      agent: { model: { provider: 'openai', modelId }, thinkingLevel: thinking, instructions: turn.instructions },
    });
    if (Date.now() >= budget.deadline) throw new Error('Turn execution deadline exceeded');
    deadlineTimer = setTimeout(() => {
      void conversation.abort(BACKGROUND_CONTEXT).catch(() => {});
    }, budget.deadline - Date.now());
    const submission = await conversation.submit({
      type: 'input', content: turn.input.at(-1)!.content, requestId: turn.request_id,
    }, BACKGROUND_CONTEXT);
    const settled = await submission.wait(BACKGROUND_CONTEXT);
    if (settled.status !== 'done' || settled.type !== 'input') throw new Error('Pi generation did not produce an answer');
    const answer = await conversation.commit(tx => tx.entry(AssistantEntry, settled.answer), BACKGROUND_CONTEXT);
    const message = answer?.model?.[0];
    if (!message || message.role !== 'assistant' || message.stopReason !== 'stop') throw new Error('Pi returned an incomplete answer');
    const text = message.content.filter(part => part.type === 'text').map(part => part.text).join('');
    const parsed: unknown = JSON.parse(text);
    if (!new Ajv({ strict: false }).validate(turn.response_format.schema, parsed)) throw new Error('Pi answer does not match the requested JSON schema');
    const usage = await harness.usage(BACKGROUND_CONTEXT);
    const tokens = Object.values(usage.models).reduce((total, model) => total + (model.totalTokens ?? model.input + model.output), 0);
    return { text, tokens, duration_ms: Math.round(performance.now() - started), model: modelId };
  } finally {
    clearTimeout(deadlineTimer);
    if (harness) await harness.close(BACKGROUND_CONTEXT);
    else await storage.close(BACKGROUND_CONTEXT);
  }
}
