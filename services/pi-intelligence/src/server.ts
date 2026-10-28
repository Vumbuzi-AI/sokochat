import { createServer, type IncomingMessage, type ServerResponse } from 'node:http';
import { mkdir, readFile, readdir } from 'node:fs/promises';
import { resolve, join } from 'node:path';
import { createHash, timingSafeEqual } from 'node:crypto';
import { runTurn, type Turn } from './runtime.ts';
import { atomicJSON, acquireOwner } from './storage.ts';
import { Ajv } from 'ajv';
import { thinkingLevel } from './generation.ts';

const host = process.env.PI_HOST || '127.0.0.1';
const port = Number(process.env.PI_PORT || 4100);
const data = resolve(process.env.PI_DATA_DIR || './data');
const token = process.env.PI_SERVICE_TOKEN;
const modelId = process.env.PI_MODEL || process.env.OPENAI_MODEL || 'gpt-5.5';
const generationThinking = thinkingLevel(modelId, process.env.PI_THINKING_LEVEL);
if (!token || token.length < 32) throw new Error('Set PI_SERVICE_TOKEN to at least 32 random characters');
if (!process.env.OPENAI_API_KEY) throw new Error('OPENAI_API_KEY is required by the local Pi provider');
const expectedAuth = createHash('sha256').update(`Bearer ${token}`).digest();
await mkdir(data, { recursive: true, mode: 0o700 });

// The same exclusive ownership applies to the service and offline retention.
const releaseOwner = await acquireOwner(data);

const pending = new Map<string, Turn>();
const running = new Set<string>();
const activeWorkspaces = new Set<number>();
const maxActive = 4;
const dailyLimit = Number(process.env.PI_WORKSPACE_DAILY_TURN_LIMIT || 1000);
if (!Number.isSafeInteger(dailyLimit) || dailyLimit < 1) throw new Error('PI_WORKSPACE_DAILY_TURN_LIMIT must be a positive integer');
let closing = false;
let admissionLine = Promise.resolve();
async function admit<T>(action: () => Promise<T>): Promise<T> {
  const result = admissionLine.then(action);
  admissionLine = result.then(() => {}, () => {});
  return result;
}
const directoryFor = (workspace: number, request: string) => join(data, String(workspace), request);
function canonical(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(canonical);
  if (value && typeof value === 'object') return Object.fromEntries(Object.entries(value).sort(([a], [b]) => a.localeCompare(b)).map(([key, item]) => [key, canonical(item)]));
  return value;
}
const digest = (value: unknown) => createHash('sha256').update(JSON.stringify(canonical(value))).digest('hex');
async function readJSON(path: string): Promise<any | undefined> {
  try { return JSON.parse(await readFile(path, 'utf8')); }
  catch (error) { if ((error as NodeJS.ErrnoException).code === 'ENOENT') return undefined; throw error; }
}
function schedule() {
  if (closing) return;
  for (const [directory, turn] of pending) {
    if (running.size >= maxActive) break;
    if (activeWorkspaces.has(turn.workspace_id)) continue;
    pending.delete(directory);
    running.add(directory);
    activeWorkspaces.add(turn.workspace_id);
    void (async () => {
      const start = Date.now();
      try {
        const result = await runTurn(directory, turn);
        await atomicJSON(join(directory, 'result.json'), { status: 'done', ...result });
        console.log(JSON.stringify({ event: 'turn_done', workspace_id: turn.workspace_id, request_id: turn.request_id, duration_ms: Date.now() - start }));
      } catch (error) {
        // Never return provider diagnostics, customer text or credentials to logs.
        await atomicJSON(join(directory, 'result.json'), { status: 'failed', error: 'Generation failed. Check model access and credentials; retry as a new turn.' });
        console.error(JSON.stringify({ event: 'turn_failed', workspace_id: turn.workspace_id, request_id: turn.request_id, error_type: error instanceof Error ? error.name : 'UnknownError' }));
      } finally { running.delete(directory); activeWorkspaces.delete(turn.workspace_id); schedule(); }
    })().catch(() => { console.error('Unable to persist turn outcome; restart to recover'); closing = true; });
  }
}
function enqueue(directory: string, turn: Turn) {
  if (!running.has(directory)) pending.set(directory, turn);
  schedule();
}
function send(res: ServerResponse, status: number, body: unknown) {
  res.writeHead(status, { 'content-type': 'application/json', 'cache-control': 'no-store' });
  res.end(JSON.stringify(body));
}
async function body(req: IncomingMessage) {
  const chunks: Buffer[] = [];
  let size = 0;
  for await (const chunk of req) {
    size += chunk.length;
    if (size > 1_000_000) throw new Error('Request exceeds 1 MB');
    chunks.push(chunk);
  }
  return JSON.parse(Buffer.concat(chunks).toString('utf8'));
}
function validTurn(value: any): value is Turn {
  return value && Number.isSafeInteger(value.workspace_id) && value.workspace_id > 0 &&
    Number.isSafeInteger(value.conversation_id) && value.conversation_id > 0 &&
    typeof value.request_id === 'string' && /^[a-zA-Z0-9_-]{1,100}$/.test(value.request_id) &&
    typeof value.model === 'string' && value.model.length > 0 &&
    (value.thinking_level === undefined || ['off', 'low'].includes(value.thinking_level)) &&
    (value.tool_mode === undefined || ['catalog', 'context'].includes(value.tool_mode)) &&
    typeof value.instructions === 'string' && value.instructions.length > 0 && value.instructions.length <= 300_000 &&
    Array.isArray(value.input) && value.input.length > 0 && value.input.length <= 100 &&
    value.input.every((m: any) => m && typeof m === 'object' && ['user', 'assistant'].includes(m.role) && typeof m.content === 'string' && m.content.length <= 20000) &&
    value.input.at(-1).role === 'user' && value.response_format?.type === 'json_schema' &&
    value.response_format.strict === true && /^[a-zA-Z0-9_-]{1,64}$/.test(value.response_format.name) &&
    typeof value.response_format?.schema === 'object' && value.response_format.schema !== null;
}

// Recover admitted jobs on service startup, without waiting for a new chat message.
for (const workspace of await readdir(data, { withFileTypes: true })) {
  if (!workspace.isDirectory() || !/^\d+$/.test(workspace.name)) continue;
  for (const request of await readdir(join(data, workspace.name), { withFileTypes: true })) {
    if (!request.isDirectory() || !/^[a-zA-Z0-9_-]{1,100}$/.test(request.name)) continue;
    const directory = join(data, workspace.name, request.name);
    if (await readJSON(join(directory, 'expired.json'))) continue;
    const turn = await readJSON(join(directory, 'request.json'));
    if (validTurn(turn) && !(await readJSON(join(directory, 'result.json')))) pending.set(directory, turn);
  }
}
schedule();

const server = createServer(async (req, res) => {
  try {
    const url = new URL(req.url || '/', 'http://localhost');
    if (req.method === 'GET' && url.pathname === '/health') {
      return send(res, closing ? 503 : 200, { service: 'sokochat-pi-intelligence', status: closing ? 'draining' : 'ready', active: running.size, queued: pending.size });
    }
    const actual = createHash('sha256').update(req.headers.authorization || '').digest();
    if (!timingSafeEqual(actual, expectedAuth)) return send(res, 401, { error: 'Unauthorized' });
    if (closing) return send(res, 503, { error: 'Service is draining' });
    if (req.method === 'POST' && url.pathname === '/v1/turns') {
      let turn: unknown;
      try { turn = await body(req); } catch { return send(res, 400, { error: 'Invalid JSON or request too large' }); }
      if (turn && typeof turn === 'object') turn = { ...turn, model: modelId, thinking_level: generationThinking };
      if (!validTurn(turn)) return send(res, 422, { error: 'Invalid turn contract' });
      try { new Ajv({ strict: false }).compile(turn.response_format.schema); }
      catch { return send(res, 422, { error: 'Invalid reply schema' }); }
      const accepted = turn;
      return await admit(async () => {
        let turn = accepted;
        const directory = directoryFor(turn.workspace_id, turn.request_id);
        await mkdir(directory, { recursive: true, mode: 0o700 });
        // Exclusive publication keeps simultaneous duplicate submissions consistent.
        if (await readJSON(join(directory, 'expired.json'))) return send(res, 410, { error: 'Turn has expired under the retention policy' });
        const requestPath = join(directory, 'request.json');
        const existing = await readJSON(requestPath);
        if (existing) turn = { ...turn, model: existing.model, thinking_level: existing.thinking_level, expires_at: existing.expires_at };
        if (existing && digest(existing) !== digest(turn)) return send(res, 409, { error: 'Request ID already belongs to different input' });
        if (!existing) {
          if (pending.size + running.size >= 100) return send(res, 429, { error: 'Intelligence queue is full' });
          if ([...pending.values()].filter(item => item.workspace_id === turn.workspace_id).length >= 25) return send(res, 429, { error: 'Workspace queue is full' });
          const quotaPath = join(data, String(turn.workspace_id), `quota-${new Date().toISOString().slice(0, 10)}.json`);
          const quota = await readJSON(quotaPath) || { turns: 0 };
          if (!Number.isSafeInteger(quota.turns) || quota.turns < 0) throw new Error('Invalid workspace quota state');
          if (quota.turns >= dailyLimit) return send(res, 429, { error: 'Workspace daily turn limit reached' });
          // Reserve before publication. A crash may consume a slot, never overspend it.
          await atomicJSON(quotaPath, { turns: quota.turns + 1 });
          turn = { ...turn, expires_at: Date.now() + 900_000 };
          await atomicJSON(requestPath, turn);
        }
        const result = await readJSON(join(directory, 'result.json'));
        if (!result) enqueue(directory, turn);
        return send(res, result ? 200 : 202, { workspace_id: turn.workspace_id, request_id: turn.request_id, ...(result || { status: 'pending' }) });
      });
    }
    const match = /^\/v1\/turns\/([1-9]\d*)\/([a-zA-Z0-9_-]{1,100})$/.exec(url.pathname);
    if (req.method === 'GET' && match) {
      const directory = directoryFor(Number(match[1]), match[2]);
      if (await readJSON(join(directory, 'expired.json'))) return send(res, 410, { error: 'Turn has expired under the retention policy' });
      if (!(await readJSON(join(directory, 'request.json')))) return send(res, 404, { error: 'Turn not found' });
      const result = await readJSON(join(directory, 'result.json'));
      return send(res, 200, result || { status: 'pending' });
    }
    send(res, 404, { error: 'Not found' });
  } catch { send(res, 500, { error: 'Intelligence service could not handle this request' }); }
});
server.requestTimeout = 15_000;
server.headersTimeout = 10_000;
server.listen(port, host, () => console.log(`SokoChat Pi Durable: http://${host}:${port}`));
async function shutdown() {
  closing = true;
  server.close();
  // Running jobs finish and persist; queued jobs resume on the next startup.
  while (running.size) await new Promise(resolve => setTimeout(resolve, 100));
  await releaseOwner();
  process.exit(0);
}
process.once('SIGINT', () => void shutdown());
process.once('SIGTERM', () => void shutdown());
