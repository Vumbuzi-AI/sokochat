import { readdir, readFile, stat, rm } from 'node:fs/promises';
import { resolve, join } from 'node:path';
import { acquireOwner, atomicJSON } from './storage.ts';

const args = process.argv.slice(2);
if (args[0] !== '--days' || !/^\d+$/.test(args[1] || '') || Number(args[1]) < 1 || args.length !== 2) {
  throw new Error('Usage: npm run prune -- --days 30. Stop the service first.');
}
const cutoff = Date.now() - Number(args[1]) * 86400_000;
const data = resolve(process.env.PI_DATA_DIR || './data');
const release = await acquireOwner(data);
let pruned = 0;
try {
  for (const workspace of await readdir(data, { withFileTypes: true })) {
    if (!workspace.isDirectory() || !/^\d+$/.test(workspace.name)) continue;
    for (const request of await readdir(join(data, workspace.name), { withFileTypes: true })) {
      if (!request.isDirectory() || !/^[a-zA-Z0-9_-]{1,100}$/.test(request.name)) continue;
      const directory = join(data, workspace.name, request.name);
      let alreadyExpired = false;
      try { await stat(join(directory, 'expired.json')); alreadyExpired = true; }
      catch (error) { if ((error as NodeJS.ErrnoException).code !== 'ENOENT') throw error; }
      if (alreadyExpired) {
        for (const entry of await readdir(directory)) {
          if (entry !== 'expired.json') await rm(join(directory, entry), { force: true });
        }
        continue;
      }
      let resultStat;
      try { resultStat = await stat(join(directory, 'result.json')); }
      catch (error) { if ((error as NodeJS.ErrnoException).code === 'ENOENT') continue; throw error; }
      if (resultStat.mtimeMs >= cutoff) continue;
      const result = JSON.parse(await readFile(join(directory, 'result.json'), 'utf8'));
      if (!['done', 'failed'].includes(result.status)) continue;
      await atomicJSON(join(directory, 'expired.json'), { expired_at: new Date().toISOString() });
      for (const entry of await readdir(directory)) {
        if (entry !== 'expired.json') await rm(join(directory, entry), { force: true });
      }
      pruned++;
    }
  }
  console.log(JSON.stringify({ event: 'retention_pruned', turns: pruned }));
} finally { await release(); }
