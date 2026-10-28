import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { turnBudget } from '../src/budget.ts';
import { acquireOwner } from '../src/storage.ts';

test('a restart cannot reset the reserved model-request budget', async () => {
  const directory = await mkdtemp(join(tmpdir(), 'sokochat-budget-'));
  try {
    const first = await turnBudget(directory);
    for (let n = 0; n < 8; n++) await first.claim('model_requests');
    const reopened = await turnBudget(directory);
    await assert.rejects(reopened.claim('model_requests'), /budget exhausted/);
  } finally { await rm(directory, { recursive: true }); }
});

test('tool reservations stay bounded when tools execute concurrently', async () => {
  const directory = await mkdtemp(join(tmpdir(), 'sokochat-tools-'));
  try {
    const budget = await turnBudget(directory);
    const reservations = await Promise.allSettled(Array.from({ length: 30 }, () => budget.claim('tool_calls')));
    assert.equal(reservations.filter(result => result.status === 'fulfilled').length, 24);
  } finally { await rm(directory, { recursive: true }); }
});

test('retention and a service cannot own the same data directory simultaneously', async () => {
  const directory = await mkdtemp(join(tmpdir(), 'sokochat-owner-'));
  try {
    const release = await acquireOwner(directory);
    await assert.rejects(acquireOwner(directory), /already owned/);
    await release();
    const second = await acquireOwner(directory);
    await second();
  } finally { await rm(directory, { recursive: true }); }
});
