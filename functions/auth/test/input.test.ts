import assert from 'node:assert/strict';
import { test } from 'node:test';

import { FlowError } from '../src/logic/errors';
import {
  asObject,
  isStrongPassword,
  normalizeEmail,
  parseCode,
  parseLanguage,
  parseName,
  parsePassword,
  parsePurpose,
} from '../src/logic/input';

function throwsCode(fn: () => unknown, code: string) {
  assert.throws(fn, (e: unknown) => e instanceof FlowError && e.code === code);
}

test('emails are trimmed and lowercased', () => {
  assert.equal(normalizeEmail('  Abebe.Kebede@Gmail.COM '), 'abebe.kebede@gmail.com');
  assert.equal(normalizeEmail('a+tag@mail.example.et'), 'a+tag@mail.example.et');
});

test('invalid emails are rejected like the rules isValidEmail', () => {
  for (const bad of ['', 'abc', 'a@b', 'a@b.c', 'a b@c.com', 'a@b..com', '@b.com', 'a@.com', 'a@b.c0m', 'ሀ@b.com', 42, null, undefined]) {
    throwsCode(() => normalizeEmail(bad), 'invalid-email');
  }
  throwsCode(() => normalizeEmail(`${'a'.repeat(250)}@b.com`), 'invalid-email');
});

test('purpose must be register or reset', () => {
  assert.equal(parsePurpose('register'), 'register');
  assert.equal(parsePurpose('reset'), 'reset');
  for (const bad of ['login', '', undefined, 1]) throwsCode(() => parsePurpose(bad), 'invalid-input');
});

test('language defaults to English and must be en or am', () => {
  assert.equal(parseLanguage(undefined), 'en');
  assert.equal(parseLanguage(null), 'en');
  assert.equal(parseLanguage('am'), 'am');
  throwsCode(() => parseLanguage('fr'), 'invalid-input');
});

test('codes must be six digits (as a string)', () => {
  assert.equal(parseCode(' 012345 '), '012345');
  for (const bad of ['12345', '1234567', 'abcdef', 123456, null]) throwsCode(() => parseCode(bad), 'invalid-code');
});

test('password rules: 8-128 characters with a letter and a digit', () => {
  assert.equal(isStrongPassword('abcdefg1'), true);
  assert.equal(isStrongPassword('ሰላምሰላም12'), true);
  assert.equal(isStrongPassword(`a1${'x'.repeat(126)}`), true);
  assert.equal(isStrongPassword('abc1234'), false); // 7
  assert.equal(isStrongPassword('abcdefgh'), false); // no digit
  assert.equal(isStrongPassword('12345678'), false); // no letter
  assert.equal(isStrongPassword(`a1${'x'.repeat(127)}`), false); // 129
  throwsCode(() => parsePassword('short1'), 'weak-password');
  throwsCode(() => parsePassword(12345678), 'invalid-input');
  assert.equal(parsePassword('password1'), 'password1');
});

test('names are optional, trimmed and at most 80 characters', () => {
  assert.equal(parseName(undefined), undefined);
  assert.equal(parseName('   '), undefined);
  assert.equal(parseName('  Abebe  '), 'Abebe');
  throwsCode(() => parseName('x'.repeat(81)), 'invalid-input');
  throwsCode(() => parseName(5), 'invalid-input');
});

test('data must be an object', () => {
  for (const bad of [null, undefined, 'x', [1]]) throwsCode(() => asObject(bad), 'invalid-input');
  assert.deepEqual(asObject({ a: 1 }), { a: 1 });
});
