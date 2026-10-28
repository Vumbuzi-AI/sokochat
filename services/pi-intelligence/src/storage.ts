import { open, rename } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { spawnSync } from 'node:child_process';

// Publish only complete JSON and flush both file contents and directory rename.
export async function atomicJSON(path: string, value: unknown) {
  const temporary = `${path}.tmp`;
  const file = await open(temporary, 'w', 0o600);
  try { await file.writeFile(JSON.stringify(value, null, 2)); await file.sync(); }
  finally { await file.close(); }
  await rename(temporary, path);
  const directory = await open(dirname(path), 'r');
  try { await directory.sync(); } finally { await directory.close(); }
}

export async function acquireOwner(directory: string) {
  const { readFile, unlink, writeFile } = await import('node:fs/promises');
  // BSD flock is attached to the open file description. The child locks its
  // inherited fd 3; our retained FileHandle keeps that same kernel lock alive
  // after the helper exits. Process death closes it without stale-file races.
  const file = await open(join(directory, '.owner.lock'), 'a+', 0o600);
  const acquired = spawnSync('/usr/bin/flock', ['--exclusive', '--nonblock', '3'], {
    stdio: ['ignore', 'ignore', 'pipe', file.fd], timeout: 3000,
  });
  if (acquired.error || acquired.status !== 0) {
    await file.close();
    if (acquired.status === 1) throw new Error('Data directory is already owned');
    throw new Error('Linux /usr/bin/flock is required for exclusive storage ownership');
  }
  const diagnostic = join(directory, 'owner.pid');
  try {
    if ((await file.readFile('utf8')) === '') {
      // Upgrade guard for the earlier PID-only implementation. Stop that old
      // service before first adoption; subsequent ownership uses flock only.
      try {
        const pid = Number(await readFile(diagnostic, 'utf8'));
        try { process.kill(pid, 0); throw new Error('Stop the legacy Pi service before upgrading its storage lock'); }
        catch (error) { if ((error as NodeJS.ErrnoException).code !== 'ESRCH') throw error; }
      } catch (error) { if ((error as NodeJS.ErrnoException).code !== 'ENOENT') throw error; }
      await file.writeFile('sokochat-flock-v1\n');
      await file.sync();
    }
    await writeFile(diagnostic, String(process.pid), { mode: 0o600 });
  } catch (error) { await file.close(); throw error; }
  let released = false;
  return async () => {
    if (released) return;
    released = true;
    try { await unlink(diagnostic); }
    catch (error) { if ((error as NodeJS.ErrnoException).code !== 'ENOENT') throw error; }
    finally { await file.close(); }
  };
}
