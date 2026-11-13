import assert from 'node:assert/strict';
import { beforeEach, describe, test } from 'node:test';

import { CodeDoc, codeDocId, MAX_ATTEMPTS } from '../src/logic/codes';
import { FlowError } from '../src/logic/errors';
import { emailRateKey, RateDoc } from '../src/logic/rateLimit';
import {
  AuthStore,
  AuthTx,
  AuthUsers,
  completeEmailRegistration,
  Deps,
  Mailer,
  requestEmailCode,
  resetPasswordWithCode,
} from '../src/logic/service';
import type { EmailMessage } from '../src/logic/templates';

/** In-memory Firestore: reads first, buffered writes applied on success. */
class FakeStore implements AuthStore {
  codes = new Map<string, CodeDoc>();
  rates = new Map<string, RateDoc>();

  async run<T>(fn: (tx: AuthTx) => Promise<T>): Promise<T> {
    const writes: (() => void)[] = [];
    let wrote = false;
    const read = () => assert.equal(wrote, false, 'reads must come before writes');
    const write = (w: () => void) => {
      wrote = true;
      writes.push(w);
    };
    const tx: AuthTx = {
      getCode: async (id) => (read(), this.codes.has(id) ? { ...this.codes.get(id)! } : null),
      getRate: async (key) => (read(), this.rates.has(key) ? { ...this.rates.get(key)! } : null),
      setCode: (id, doc) => write(() => this.codes.set(id, { ...doc })),
      setCodeAttempts: (id, attempts) =>
        write(() => {
          const d = this.codes.get(id);
          assert.ok(d, 'update of a missing doc');
          this.codes.set(id, { ...d, attempts });
        }),
      deleteCode: (id) => write(() => this.codes.delete(id)),
      setRate: (key, doc) => write(() => this.rates.set(key, { ...doc })),
    };
    const result = await fn(tx); // a throw discards the writes
    for (const w of writes) w();
    return result;
  }

  async deleteCode(id: string) {
    this.codes.delete(id);
  }
}

interface FakeUser {
  uid: string;
  email: string;
  password?: string;
  providerIds: string[];
  emailVerified: boolean;
  displayName?: string;
  revoked: number;
}

class FakeUsers implements AuthUsers {
  byEmail = new Map<string, FakeUser>();
  raceOnCreate = false;

  add(email: string, providerIds: string[], password?: string) {
    const u: FakeUser = { uid: `uid_${this.byEmail.size + 1}`, email, providerIds, password, emailVerified: true, revoked: 0 };
    this.byEmail.set(email, u);
    return u;
  }
  async findByEmail(email: string) {
    const u = this.byEmail.get(email);
    return u ? { uid: u.uid, providerIds: [...u.providerIds] } : null;
  }
  async create(user: { email: string; password: string; displayName?: string }) {
    if (this.raceOnCreate || this.byEmail.has(user.email)) return 'exists' as const;
    const u = this.add(user.email, ['password'], user.password);
    u.displayName = user.displayName;
    return 'created' as const;
  }
  async setPassword(uid: string, password: string) {
    for (const u of this.byEmail.values()) if (u.uid === uid) u.password = password;
  }
  async revokeSessions(uid: string) {
    for (const u of this.byEmail.values()) if (u.uid === uid) u.revoked++;
  }
}

class FakeMailer implements Mailer {
  sent: { to: string; message: EmailMessage }[] = [];
  fail = false;
  async send(to: string, message: EmailMessage) {
    if (this.fail) throw new Error('smtp down');
    this.sent.push({ to, message });
  }
  lastCode(): string {
    const m = this.sent.at(-1)!.message.text.match(/code is ([0-9]{6})/);
    return m![1];
  }
}

let store: FakeStore;
let users: FakeUsers;
let mailer: FakeMailer;
let clock: Date;
let deps: Deps;
let nextCode: string | null;

const T0 = new Date('2026-11-20T07:00:00.000Z');
const advance = (seconds: number) => {
  clock = new Date(clock.getTime() + seconds * 1000);
};
const IP = '196.188.1.1';

beforeEach(() => {
  store = new FakeStore();
  users = new FakeUsers();
  mailer = new FakeMailer();
  clock = T0;
  nextCode = null;
  deps = {
    store,
    users,
    mailer,
    now: () => clock,
    randomCode: () => nextCode ?? String(Math.floor(Math.random() * 1e6)).padStart(6, '0'),
  };
});

async function rejectsWith(p: Promise<unknown>, code: string, details?: Record<string, unknown>) {
  await assert.rejects(p, (e: unknown) => {
    assert.ok(e instanceof FlowError, `expected FlowError, got ${String(e)}`);
    assert.equal(e.code, code);
    if (details) for (const [k, v] of Object.entries(details)) assert.deepEqual(e.details[k], v, k);
    return true;
  });
}

const request = (email: string, purpose: string, language?: string, ip: string | null = IP) =>
  requestEmailCode(deps, { email, purpose, language }, ip);

describe('requestEmailCode', () => {
  test('register: sends a code and stores only its hash', async () => {
    nextCode = '482913';
    const res = await request('  New.Person@Example.com ', 'register');
    assert.deepEqual(res, { ok: true, resendAfterSeconds: 60, expiresInSeconds: 600 });
    assert.equal(mailer.sent.length, 1);
    assert.equal(mailer.sent[0].to, 'new.person@example.com');
    assert.equal(mailer.lastCode(), '482913');
    const doc = store.codes.get(codeDocId('register', 'new.person@example.com'))!;
    assert.ok(doc);
    assert.equal(doc.attempts, 0);
    assert.equal(doc.expiresAt, '2026-11-20T07:10:00.000Z');
    assert.ok(!JSON.stringify([...store.codes.values(), ...store.rates.values()]).includes('482913'));
    assert.ok(!JSON.stringify([...store.codes.keys(), ...store.rates.keys()]).includes('example.com'));
  });

  test('register: Amharic first when asked', async () => {
    await request('a@example.com', 'register', 'am');
    assert.ok(mailer.sent[0].message.subject.startsWith('የ'));
  });

  test('register: an existing account (any provider) is refused', async () => {
    users.add('taken@example.com', ['google.com']);
    await rejectsWith(request('taken@example.com', 'register'), 'email-already-registered');
    assert.equal(mailer.sent.length, 0);
    assert.equal(store.codes.size, 0);
  });

  test('reset: unknown and Google-only emails get the same answer and no email', async () => {
    users.add('google@example.com', ['google.com']);
    users.add('pw@example.com', ['password']);
    const a = await request('nobody@example.com', 'reset');
    const b = await request('google@example.com', 'reset');
    const c = await request('pw@example.com', 'reset');
    assert.deepEqual(a, b);
    assert.deepEqual(b, c);
    assert.equal(mailer.sent.length, 1);
    assert.equal(mailer.sent[0].to, 'pw@example.com');
    // Cooldown behaves the same for everyone too.
    await rejectsWith(request('nobody@example.com', 'reset'), 'too-soon');
    await rejectsWith(request('pw@example.com', 'reset'), 'too-soon');
  });

  test('resend cooldown is 60 s per email and purpose', async () => {
    await request('a@example.com', 'register');
    advance(20);
    await rejectsWith(request('a@example.com', 'register'), 'too-soon', { retryAfterSeconds: 40 });
    users.add('b@example.com', ['password']);
    await request('b@example.com', 'reset'); // other email: fine
    advance(40);
    await request('a@example.com', 'register');
    assert.equal(mailer.sent.length, 3);
  });

  test('a new code replaces the previous one', async () => {
    nextCode = '111111';
    await request('a@example.com', 'register');
    advance(61);
    nextCode = '222222';
    await request('a@example.com', 'register');
    await rejectsWith(
      completeEmailRegistration(deps, { email: 'a@example.com', code: '111111', password: 'secret123' }),
      'invalid-code',
    );
    await completeEmailRegistration(deps, { email: 'a@example.com', code: '222222', password: 'secret123' });
  });

  test('at most 5 sends per email per day', async () => {
    for (let i = 0; i < 5; i++) {
      await request('a@example.com', 'register', 'en', `10.0.0.${i}`);
      advance(61);
    }
    await rejectsWith(request('a@example.com', 'register', 'en', '10.0.1.1'), 'rate-limited');
    // The daily count covers both purposes.
    users.add('a@example.com', ['password']);
    await rejectsWith(request('a@example.com', 'reset', 'en', '10.0.1.1'), 'rate-limited');
    assert.equal(store.rates.get(emailRateKey('a@example.com'))!.count, 5);
    advance(24 * 3600);
    await request('a@example.com', 'reset', 'en', '10.0.1.1');
  });

  test('at most 20 sends per IP per hour', async () => {
    for (let i = 0; i < 20; i++) await request(`p${i}@example.com`, 'register');
    await rejectsWith(request('p20@example.com', 'register'), 'rate-limited');
    await request('p20@example.com', 'register', 'en', '196.188.9.9'); // other IP
    advance(3600);
    await request('p21@example.com', 'register');
  });

  test('a refused request does not consume the counters', async () => {
    await request('a@example.com', 'register');
    await rejectsWith(request('a@example.com', 'register'), 'too-soon');
    assert.equal(store.rates.get(emailRateKey('a@example.com'))!.count, 1);
  });

  test('no IP: only the per-email limits apply', async () => {
    await request('a@example.com', 'register', 'en', null);
    assert.equal(store.rates.size, 1);
  });

  test('missing SMTP config fails clearly before anything is stored', async () => {
    deps.mailer = null;
    await rejectsWith(request('a@example.com', 'register'), 'email-not-configured');
    assert.equal(store.codes.size, 0);
  });

  test('a failed send removes the code so the person can retry', async () => {
    mailer.fail = true;
    await rejectsWith(request('a@example.com', 'register'), 'email-send-failed');
    assert.equal(store.codes.size, 0);
    mailer.fail = false;
    await request('a@example.com', 'register');
  });

  test('input validation', async () => {
    await rejectsWith(request('not-an-email', 'register'), 'invalid-email');
    await rejectsWith(request('a@example.com', 'login'), 'invalid-input');
    await rejectsWith(request('a@example.com', 'register', 'fr'), 'invalid-input');
    await rejectsWith(requestEmailCode(deps, null, IP), 'invalid-input');
  });
});

describe('completeEmailRegistration', () => {
  beforeEach(async () => {
    nextCode = '123456';
    await request('new@example.com', 'register');
  });

  test('creates a verified email/password user and consumes the code', async () => {
    const res = await completeEmailRegistration(deps, {
      email: 'NEW@example.com',
      code: '123456',
      password: 'secret123',
      name: ' Abebe ',
    });
    assert.deepEqual(res, { ok: true });
    const u = users.byEmail.get('new@example.com')!;
    assert.equal(u.password, 'secret123');
    assert.equal(u.emailVerified, true);
    assert.equal(u.displayName, 'Abebe');
    assert.deepEqual(u.providerIds, ['password']);
    assert.equal(store.codes.size, 0);
    await rejectsWith(
      completeEmailRegistration(deps, { email: 'new@example.com', code: '123456', password: 'secret123' }),
      'code-expired',
    );
  });

  test('wrong codes count attempts; after 5 the code is gone', async () => {
    const body = { email: 'new@example.com', code: '000000', password: 'secret123' };
    for (let left = MAX_ATTEMPTS - 1; left >= 1; left--) {
      await rejectsWith(completeEmailRegistration(deps, body), 'invalid-code', { attemptsLeft: left });
    }
    await rejectsWith(completeEmailRegistration(deps, body), 'code-expired');
    assert.equal(store.codes.size, 0);
    await rejectsWith(completeEmailRegistration(deps, { ...body, code: '123456' }), 'code-expired');
    assert.equal(users.byEmail.size, 0);
  });

  test('expired after 10 minutes and deleted', async () => {
    advance(600);
    await rejectsWith(
      completeEmailRegistration(deps, { email: 'new@example.com', code: '123456', password: 'secret123' }),
      'code-expired',
    );
    assert.equal(store.codes.size, 0);
  });

  test('a weak password or malformed code does not use an attempt', async () => {
    await rejectsWith(
      completeEmailRegistration(deps, { email: 'new@example.com', code: '123456', password: 'password' }),
      'weak-password',
    );
    await rejectsWith(
      completeEmailRegistration(deps, { email: 'new@example.com', code: '12-456', password: 'secret123' }),
      'invalid-code',
    );
    assert.equal(store.codes.get(codeDocId('register', 'new@example.com'))!.attempts, 0);
  });

  test('a reset code cannot be used to register (purpose separation)', async () => {
    users.add('pw@example.com', ['password']);
    nextCode = '654321';
    await request('pw@example.com', 'reset');
    users.byEmail.delete('pw@example.com');
    await rejectsWith(
      completeEmailRegistration(deps, { email: 'pw@example.com', code: '654321', password: 'secret123' }),
      'code-expired', // no register code exists for this email
    );
    await rejectsWith(
      completeEmailRegistration(deps, { email: 'new@example.com', code: '654321', password: 'secret123' }),
      'invalid-code',
    );
    assert.ok(store.codes.has(codeDocId('reset', 'pw@example.com')));
  });

  test('race: the account was created meanwhile', async () => {
    users.raceOnCreate = true;
    await rejectsWith(
      completeEmailRegistration(deps, { email: 'new@example.com', code: '123456', password: 'secret123' }),
      'email-already-registered',
    );
  });
});

describe('resetPasswordWithCode', () => {
  test('sets the new password and revokes sessions', async () => {
    const u = users.add('pw@example.com', ['password'], 'oldpass11');
    nextCode = '777777';
    await request('pw@example.com', 'reset');
    const res = await resetPasswordWithCode(deps, { email: 'pw@example.com', code: '777777', newPassword: 'newpass22' });
    assert.deepEqual(res, { ok: true });
    assert.equal(u.password, 'newpass22');
    assert.equal(u.revoked, 1);
    assert.equal(store.codes.size, 0);
  });

  test('a register code cannot reset a password', async () => {
    nextCode = '777777';
    await request('x@example.com', 'register');
    users.add('x@example.com', ['password'], 'oldpass11');
    await rejectsWith(
      resetPasswordWithCode(deps, { email: 'x@example.com', code: '777777', newPassword: 'newpass22' }),
      'code-expired',
    );
    assert.equal(users.byEmail.get('x@example.com')!.password, 'oldpass11');
  });

  test('unknown account: invalid-code, nothing revealed', async () => {
    nextCode = '777777';
    await request('ghost@example.com', 'reset');
    assert.equal(mailer.sent.length, 0);
    await rejectsWith(
      resetPasswordWithCode(deps, { email: 'ghost@example.com', code: '777777', newPassword: 'newpass22' }),
      'invalid-code',
    );
  });

  test('weak new password', async () => {
    users.add('pw@example.com', ['password']);
    await request('pw@example.com', 'reset');
    await rejectsWith(
      resetPasswordWithCode(deps, { email: 'pw@example.com', code: mailer.lastCode(), newPassword: 'abc' }),
      'weak-password',
    );
  });

  test('wrong code counts attempts', async () => {
    users.add('pw@example.com', ['password']);
    nextCode = '777777';
    await request('pw@example.com', 'reset');
    await rejectsWith(
      resetPasswordWithCode(deps, { email: 'pw@example.com', code: '777778', newPassword: 'newpass22' }),
      'invalid-code',
      { attemptsLeft: 4 },
    );
  });
});
