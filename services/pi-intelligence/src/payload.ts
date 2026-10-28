import type { Turn } from './runtime.ts';

export function responsePayload(body: Record<string, unknown>, turn: Turn) {
  if (!Array.isArray(body.input)) throw new Error('Provider did not supply a Responses transcript');
  return {
    ...body,
    input: [...turn.input.slice(0, -1), ...body.input],
    instructions: turn.instructions,
    max_output_tokens: 1024,
    text: { verbosity: 'low', format: turn.response_format },
  };
}
