import { readFile } from 'node:fs/promises';
import { join } from 'node:path';
import { atomicJSON } from './storage.ts';

type Budget = { started_at: number; model_requests: number; tool_calls: number };
export async function turnBudget(directory: string, expiresAt = Infinity) {
  const path = join(directory, 'budget.json');
  let state: Budget;
  try { state = JSON.parse(await readFile(path, 'utf8')); }
  catch (error) {
    if ((error as NodeJS.ErrnoException).code !== 'ENOENT') throw error;
    state = { started_at: Date.now(), model_requests: 0, tool_calls: 0 };
    await atomicJSON(path, state);
  }
  if (!Number.isSafeInteger(state.started_at) || state.started_at < 1 ||
      !Number.isSafeInteger(state.model_requests) || state.model_requests < 0 || state.model_requests > 8 ||
      !Number.isSafeInteger(state.tool_calls) || state.tool_calls < 0 || state.tool_calls > 24) {
    throw new Error('Invalid persisted execution budget');
  }
  let line = Promise.resolve();
  const deadline = Math.min(state.started_at + 180_000, expiresAt);
  return {
    deadline,
    claim(kind: 'model_requests' | 'tool_calls') {
      const result = line.then(async () => {
        if (Date.now() >= deadline || state[kind] >= (kind === 'model_requests' ? 8 : 24)) throw new Error('Turn execution budget exhausted');
        state = { ...state, [kind]: state[kind] + 1 };
        await atomicJSON(path, state); // Reserve before an external request, including across restarts.
      });
      line = result.catch(() => {});
      return result;
    },
  };
}
