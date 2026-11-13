import assert from 'node:assert/strict';
import { test } from 'node:test';

import { buildCodeEmail } from '../src/logic/templates';

const EN = 'Your Crown & Blade code is 123456. It expires in 10 minutes. If you did not ask for it, ignore this email.';
const AM = 'የCrown & Blade ኮድዎ 123456 ነው።';

test('English first by default, Amharic after', () => {
  const m = buildCodeEmail('register', 'en', '123456');
  assert.ok(m.text.includes(EN));
  assert.ok(m.text.includes(AM));
  assert.ok(m.text.indexOf(EN) < m.text.indexOf(AM));
  assert.ok(m.subject.startsWith('Your Crown & Blade sign-up code'));
  assert.ok(m.subject.includes('የምዝገባ'));
});

test('Amharic first when selected', () => {
  const m = buildCodeEmail('register', 'am', '123456');
  assert.ok(m.text.indexOf(AM) < m.text.indexOf(EN));
  assert.ok(m.subject.startsWith('የCrown & Blade የምዝገባ ኮድዎ'));
  assert.ok(m.html.indexOf('lang="am"') < m.html.indexOf('lang="en"'));
});

test('register and reset have different subjects and intros', () => {
  const r = buildCodeEmail('register', 'en', '123456');
  const p = buildCodeEmail('reset', 'en', '123456');
  assert.notEqual(r.subject, p.subject);
  assert.ok(p.subject.startsWith('Your Crown & Blade password reset code'));
  assert.ok(p.text.includes('reset your Crown & Blade password'));
  assert.ok(r.text.includes('finish creating your Crown & Blade account'));
  assert.ok(p.text.includes('የይለፍ ቃል'));
});

test('HTML carries the code and escapes the ampersand', () => {
  const m = buildCodeEmail('reset', 'en', '000777');
  assert.ok(m.html.startsWith('<!doctype html>'));
  assert.ok(m.html.includes('>000777<'));
  assert.ok(m.html.includes('Crown &amp; Blade'));
  assert.ok(!m.html.includes('Crown & Blade'));
});
