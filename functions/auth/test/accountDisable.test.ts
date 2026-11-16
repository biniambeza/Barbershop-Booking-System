import assert from 'node:assert/strict';
import { test } from 'node:test';

import { authDisableAction, AuthAccounts, isDisabledDoc, mirrorDisabledToAuth } from '../src/logic/accountDisable';

function fakeAuth(fail?: unknown) {
  const calls: string[] = [];
  const auth: AuthAccounts = {
    async setDisabled(uid, disabled) {
      if (fail) throw fail;
      calls.push(`setDisabled:${uid}:${disabled}`);
    },
    async revokeRefreshTokens(uid) {
      calls.push(`revoke:${uid}`);
    },
  };
  return { auth, calls };
}

test('isDisabledDoc only accepts disabled === true', () => {
  assert.equal(isDisabledDoc({ disabled: true }), true);
  assert.equal(isDisabledDoc({ disabled: 'true' }), false);
  assert.equal(isDisabledDoc({}), false);
  assert.equal(isDisabledDoc(null), false);
});

test('authDisableAction follows the transition of the flag', () => {
  assert.equal(authDisableAction({ role: 'customer' }, { role: 'customer', disabled: true }), 'disable');
  assert.equal(authDisableAction({ disabled: true }, { role: 'customer' }), 'enable');
  assert.equal(authDisableAction({ disabled: true }, { disabled: true, name: 'x' }), 'none');
  assert.equal(authDisableAction({ name: 'a' }, { name: 'b' }), 'none');
  // Created already disabled (admin restore) -> disable.
  assert.equal(authDisableAction(null, { disabled: true }), 'disable');
  // Deleted profile: nothing to mirror.
  assert.equal(authDisableAction({ disabled: true }, null), 'none');
});

test('disable sets the Auth user disabled and revokes its tokens', async () => {
  const { auth, calls } = fakeAuth();
  assert.equal(await mirrorDisabledToAuth('u1', 'disable', auth), 'disable');
  assert.deepEqual(calls, ['setDisabled:u1:true', 'revoke:u1']);
});

test('enable re-enables the Auth user without revoking', async () => {
  const { auth, calls } = fakeAuth();
  assert.equal(await mirrorDisabledToAuth('u1', 'enable', auth), 'enable');
  assert.deepEqual(calls, ['setDisabled:u1:false']);
});

test('none does nothing', async () => {
  const { auth, calls } = fakeAuth();
  assert.equal(await mirrorDisabledToAuth('u1', 'none', auth), 'none');
  assert.deepEqual(calls, []);
});

test('a missing Auth user is ignored, other errors are thrown', async () => {
  const missing = fakeAuth({ code: 'auth/user-not-found' });
  assert.equal(await mirrorDisabledToAuth('gone', 'disable', missing.auth), 'none');
  const broken = fakeAuth({ code: 'auth/internal-error' });
  await assert.rejects(mirrorDisabledToAuth('u1', 'disable', broken.auth));
});
