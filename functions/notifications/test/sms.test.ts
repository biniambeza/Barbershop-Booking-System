import { test } from 'node:test';
import assert from 'node:assert/strict';

import { AfroMessageSmsProvider, LogOnlySmsProvider, createSmsProvider, maskPhone } from '../src/sms';

test('createSmsProvider logs only without a token', () => {
  assert.ok(createSmsProvider({ token: '' }) instanceof LogOnlySmsProvider);
  assert.ok(createSmsProvider({ token: '   ' }) instanceof LogOnlySmsProvider);
  assert.ok(createSmsProvider({ token: 'abc' }) instanceof AfroMessageSmsProvider);
});

test('AfroMessage request shape and success parsing', async () => {
  let captured: { url: string; init: RequestInit } | null = null;
  const fakeFetch = (async (url: string, init: RequestInit) => {
    captured = { url, init };
    return new Response(JSON.stringify({ acknowledge: 'success', response: { message_id: 42 } }), { status: 200 });
  }) as unknown as typeof fetch;
  const provider = new AfroMessageSmsProvider({ token: 'T', identifierId: 'ID', sender: 'CrownBlade', fetchImpl: fakeFetch });
  const result = await provider.send('+251911234567', 'hello');
  assert.deepEqual(result, { ok: true, providerId: '42' });
  assert.ok(captured);
  const c = captured as { url: string; init: RequestInit };
  assert.equal(c.url, 'https://api.afromessage.com/api/send');
  assert.equal((c.init.headers as Record<string, string>).Authorization, 'Bearer T');
  assert.deepEqual(JSON.parse(String(c.init.body)), { to: '+251911234567', message: 'hello', from: 'ID', sender: 'CrownBlade' });
});

test('AfroMessage error acknowledge is a failure', async () => {
  const fakeFetch = (async () =>
    new Response(JSON.stringify({ acknowledge: 'error', response: { errors: ['bad'] } }), { status: 200 })) as unknown as typeof fetch;
  const result = await new AfroMessageSmsProvider({ token: 'T', fetchImpl: fakeFetch }).send('+251911234567', 'x');
  assert.equal(result.ok, false);
  assert.match(result.error ?? '', /bad/);
});

test('maskPhone', () => {
  assert.equal(maskPhone('+251911234567'), '+2519*****567');
});
