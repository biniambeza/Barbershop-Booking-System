import { test } from 'node:test';
import assert from 'node:assert/strict';
import { deflateSync } from 'node:zlib';

import { DocData, DocStore, DocTx } from '../src/logic/docstore';
import { evaluateReceipt, isDuplicateTransaction, ReceiptClaim } from '../src/receipts/evaluate';
import { checkFromPage, formatAddisDate, ReceiptFlowDeps, verifyReceiptPayment } from '../src/receipts/flow';
import { loadReceiptImage, RECEIPT_IMAGE_MAX_BYTES, receiptImagePath } from '../src/receipts/image';
import {
  accountsMatch,
  contentStreamText,
  extractPdfText,
  namesMatch,
  parseAmount,
  parseCbeDate,
  parseCbeReceiptText,
  parseTelebirrDate,
  parseTelebirrReceipt,
  ParsedReceipt,
} from '../src/receipts/parse';
import {
  DEFAULT_PRICING,
  extendByDays,
  isValidTransactionId,
  normalizePayerAccountSuffix,
  normalizeTransactionId,
  officialReceiptUrl,
  parsePricing,
  Pricing,
  receiptDocId,
  tierForAmount,
} from '../src/receipts/pricing';

// Sunday 15 Nov 2026, 12:00 Addis.
const NOW = new Date('2026-11-15T09:00:00.000Z');
const DAY = 24 * 60 * 60 * 1000;

const PRICING: Pricing = {
  ...DEFAULT_PRICING,
  telebirr: { account: '+251911223344', name: 'Crown & Blade' },
  cbe: { account: '1000123459012', name: 'Crown & Blade' },
};

// ------------------------------------------------------------ fixtures

/** Shaped like transactioninfo.ethiotelecom.et/receipt/{id}. */
function telebirrHtml(o: { receiver?: string; account?: string; status?: string; amount?: string; date?: string; id?: string } = {}) {
  return `<!DOCTYPE html><html><head><title>Receipt</title><style>td{padding:2px}</style></head><body>
<table class="receipttable">
  <tr><td class="receipttableTd1">የከፋይ ስም/Payer Name</td>
      <td class="receipttableTd receipttableTd2">Abebe Kebede</td></tr>
  <tr><td class="receipttableTd1">የከፋይ ቴሌብር ቁ./Payer telebirr no.</td>
      <td class="receipttableTd receipttableTd2">2519****0101</td></tr>
  <tr><td class="receipttableTd1">የገንዘብ ተቀባይ ስም/Credited Party name</td>
      <td class="receipttableTd receipttableTd2">${o.receiver ?? 'Crown &amp; Blade PLC'}</td></tr>
  <tr><td class="receipttableTd1">የገንዘብ ተቀባይ ቴሌብር ቁ./Credited party account no</td>
      <td class="receipttableTd receipttableTd2">${o.account ?? '2519****3344'}</td></tr>
  <tr><td class="receipttableTd1">የክፍያው ሁኔታ/transaction status</td>
      <td class="receipttableTd receipttableTd2"> ${o.status ?? 'Completed'} </td></tr>
</table>
<table>
  <tr><td colspan="3">የክፍያ ዝርዝር/ Transaction details</td></tr>
  <tr><td class="receipttableTd1">የክፍያ ቁጥር/Invoice No.</td>
      <td class="receipttableTd1">የክፍያ ቀን/Payment date</td>
      <td class="receipttableTd1">የተከፈለው መጠን/Settled Amount</td></tr>
  <tr><td class="receipttableTd receipttableTd2">${o.id ?? 'CHK1AB2CDE'}</td>
      <td class="receipttableTd receipttableTd2">${o.date ?? '14-11-2026 18:22:33'}</td>
      <td class="receipttableTd receipttableTd2">${o.amount ?? '1,400.00 Birr'}</td></tr>
</table>
<table>
  <tr><td>የአገልግሎት ክፍያ/Service fee</td><td>0.00 Birr</td></tr>
  <tr><td>ጠቅላላ የተከፈለ/Total Paid Amount</td><td>${o.amount ?? '1,400.00 Birr'}</td></tr>
</table></body></html>`;
}

const TELEBIRR_NOT_FOUND = '<html><body><h3>This request is not correct</h3></body></html>';

/** pdf-parse style text of a CBE receipt. */
function cbeText(o: { receiver?: string; account?: string; amount?: string; date?: string; ref?: string } = {}) {
  return `Commercial Bank of Ethiopia
VAT Receipt No: FT2412345ABC VAT Registration No: 0000000000
Customer Name: ABEBE KEBEDE Region: Addis Ababa
Payer ABEBE KEBEDE Account 1****5678
Receiver ${o.receiver ?? 'CROWN AND BLADE'} Account ${o.account ?? '1****9012'}
Payment Date & Time ${o.date ?? '11/14/2026, 6:22:33 PM'}
Reference No. (VAT Invoice No) ${o.ref ?? 'FT2412345ABC'}
Reason / Type of service subscription done via Mobile
Transferred Amount ${o.amount ?? '1,400.00'} ETB
Commission or Service Charge 0.00 ETB
Total amount debited from customers account ${o.amount ?? '1,400.00'} ETB`;
}

/** A tiny real PDF with one Flate-compressed content stream. */
function pdfOf(lines: string[]): Buffer {
  const esc = (s: string) => s.replace(/\\/g, '\\\\').replace(/\(/g, '\\(').replace(/\)/g, '\\)');
  const content = ['BT', '/F1 10 Tf', '72 760 Td', ...lines.map((l, i) => `${i ? '0 -14 Td ' : ''}(${esc(l)}) Tj`), 'ET'].join('\n');
  const stream = deflateSync(Buffer.from(content, 'latin1'));
  return Buffer.concat([
    Buffer.from('%PDF-1.4\n1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n4 0 obj\n<< /Length ' + stream.length + ' /Filter /FlateDecode >>\nstream\n', 'latin1'),
    stream,
    Buffer.from('\nendstream\nendobj\ntrailer\n<< /Root 1 0 R >>\n%%EOF\n', 'latin1'),
  ]);
}

// ------------------------------------------------------------ pricing

test('duration: the longest tier whose amount is covered', () => {
  const t = DEFAULT_PRICING.tiers;
  assert.equal(tierForAmount(t, 499), null);
  assert.equal(tierForAmount(t, 500)?.days, 30);
  assert.equal(tierForAmount(t, 1400)?.days, 90);
  assert.equal(tierForAmount(t, 2000)?.days, 90);
  assert.equal(tierForAmount(t, 2700)?.days, 180);
  assert.equal(tierForAmount(t, 5000)?.days, 365);
  assert.equal(tierForAmount(t, 99999)?.days, 365);
  assert.equal(tierForAmount([...t].reverse(), 2000)?.days, 90);
});

test('pricing doc parsing is tolerant', () => {
  assert.deepEqual(parsePricing(undefined), DEFAULT_PRICING);
  const p = parsePricing({
    tiers: [{ days: 90, amount: 1400 }, { days: 'x', amount: 1 }, { days: 30, amount: 500 }],
    receivers: { telebirr: { number: '+251911223344', name: 'Crown' }, cbe: { account: '1000123459012', name: 'Crown' } },
    receiptUrls: { telebirr: 'https://relay.example.et/tb/{id}', cbe: 'http://insecure/{id}' },
  });
  assert.deepEqual(p.tiers, [{ days: 30, amount: 500 }, { days: 90, amount: 1400 }]);
  assert.equal(p.telebirr.account, '+251911223344');
  assert.equal(p.telebirrReceiptUrl, 'https://relay.example.et/tb/{id}');
  assert.equal(p.cbeReceiptUrl, DEFAULT_PRICING.cbeReceiptUrl);
});

test('transaction numbers: normalization, shapes, doc ids, urls', () => {
  assert.equal(normalizeTransactionId(' chk1 ab2cde\n'), 'CHK1AB2CDE');
  assert.ok(isValidTransactionId('telebirr', 'CHK1AB2CDE'));
  assert.ok(!isValidTransactionId('telebirr', '1234567890'));
  assert.ok(isValidTransactionId('cbe', 'FT2412345ABC'));
  assert.ok(!isValidTransactionId('cbe', 'CHK1AB2CDE'));
  assert.equal(receiptDocId('cbe', 'FT2412345ABC'), 'cbe_FT2412345ABC');
  assert.equal(officialReceiptUrl('telebirr', 'chk1ab2cde'), 'https://transactioninfo.ethiotelecom.et/receipt/CHK1AB2CDE');
  assert.equal(officialReceiptUrl('cbe', 'FT2412345ABC'), 'https://apps.cbe.com.et:100/?id=FT2412345ABC');
  assert.equal(
    officialReceiptUrl('cbe', 'FT2412345ABC', { payerAccountSuffix: '1000 1234 5678' }),
    'https://apps.cbe.com.et:100/?id=FT2412345ABC12345678',
  );
  assert.equal(officialReceiptUrl('other', 'X-1'), null);
  assert.equal(normalizePayerAccountSuffix('12'), null);
});

test('extension counts from the current end or from now', () => {
  const future = new Date(NOW.getTime() + 10 * DAY);
  assert.equal(extendByDays(future, NOW, 30).getTime(), future.getTime() + 30 * DAY);
  assert.equal(extendByDays(new Date(NOW.getTime() - DAY), NOW, 30).getTime(), NOW.getTime() + 30 * DAY);
  assert.equal(extendByDays(null, NOW, 90).getTime(), NOW.getTime() + 90 * DAY);
});

// ------------------------------------------------------------ parsers

test('dates and amounts', () => {
  assert.equal(parseTelebirrDate('14-11-2026 18:22:33')?.toISOString(), '2026-11-14T15:22:33.000Z');
  assert.equal(parseCbeDate('11/14/2026, 6:22:33 PM')?.toISOString(), '2026-11-14T15:22:33.000Z');
  assert.equal(parseCbeDate('11/14/2026, 12:05:00 AM')?.toISOString(), '2026-11-13T21:05:00.000Z');
  assert.equal(parseTelebirrDate('99-99-2026 10:00:00'), null);
  assert.equal(parseAmount('1,400.00 Birr'), 1400);
  assert.equal(parseAmount('ETB 5000.5'), 5000.5);
  assert.equal(parseAmount('none'), null);
});

test('telebirr receipt HTML', () => {
  const r = parseTelebirrReceipt(telebirrHtml());
  assert.equal(r.found, true);
  assert.equal(r.reference, 'CHK1AB2CDE');
  assert.equal(r.status, 'completed');
  assert.equal(r.receiverName, 'Crown & Blade PLC');
  assert.equal(r.receiverAccount, '2519****3344');
  assert.equal(r.payerName, 'Abebe Kebede');
  assert.equal(r.amount, 1400);
  assert.equal(r.paidAt?.toISOString(), '2026-11-14T15:22:33.000Z');
  assert.equal(parseTelebirrReceipt(TELEBIRR_NOT_FOUND).found, false);
  assert.equal(parseTelebirrReceipt('').found, false);
});

test('CBE receipt text', () => {
  const r = parseCbeReceiptText(cbeText());
  assert.equal(r.found, true);
  assert.equal(r.reference, 'FT2412345ABC');
  assert.equal(r.status, 'completed');
  assert.equal(r.payerName, 'ABEBE KEBEDE');
  assert.equal(r.receiverName, 'CROWN AND BLADE');
  assert.equal(r.receiverAccount, '1****9012');
  assert.equal(r.amount, 1400);
  assert.equal(r.paidAt?.toISOString(), '2026-11-14T15:22:33.000Z');
  assert.equal(parseCbeReceiptText('Invalid request').found, false);
});

test('PDF text extraction (Flate streams, Tj / TJ)', () => {
  assert.equal(contentStreamText('BT /F1 9 Tf 10 10 Td (Payer) Tj 0 -10 Td [(Trans)-10(ferred)-400(Amount)] TJ ET'), 'Payer Transferred Amount');
  assert.equal(contentStreamText('BT (a\\(b\\)) Tj ET'), 'a(b)');
  const pdf = pdfOf(cbeText().split('\n'));
  const text = extractPdfText(pdf);
  assert.match(text, /Transferred Amount 1,400\.00 ETB/);
  const r = parseCbeReceiptText(text);
  assert.equal(r.found, true);
  assert.equal(r.amount, 1400);
  assert.equal(r.receiverAccount, '1****9012');
});

test('receiver matching', () => {
  assert.ok(namesMatch('Crown & Blade PLC', 'Crown & Blade'));
  assert.ok(namesMatch('CROWN AND BLADE', 'Crown & Blade'));
  assert.ok(!namesMatch('Abebe Kebede', 'Crown & Blade'));
  assert.ok(accountsMatch('2519****3344', '+251911223344'));
  assert.ok(accountsMatch('1****9012', '1000123459012'));
  assert.ok(!accountsMatch('2519****9999', '+251911223344'));
  assert.ok(!accountsMatch('2519****3344', '+2519XXXXXXXX'), 'placeholder never matches');
  assert.ok(accountsMatch('1000123459012', '1000123459012'));
});

// ------------------------------------------------------------ decisions

const fetched = (r: ParsedReceipt) => ({ kind: 'fetched' as const, receipt: r });
const tbClaim: ReceiptClaim = { method: 'telebirr', transactionId: 'CHK1AB2CDE', amount: 1400 };
const cbeClaim: ReceiptClaim = { method: 'cbe', transactionId: 'FT2412345ABC', amount: 1400 };

test('evaluate: accepts a matching telebirr and CBE receipt', () => {
  const tb = evaluateReceipt(tbClaim, PRICING, fetched(parseTelebirrReceipt(telebirrHtml())), NOW);
  assert.deepEqual(tb, { status: 'verified', reason: null, durationDays: 90, verifiedAmount: 1400 });
  const cbe = evaluateReceipt(cbeClaim, PRICING, fetched(parseCbeReceiptText(cbeText())), NOW);
  assert.equal(cbe.status, 'verified');
  // Paid more than claimed: the claimed tier, the shown amount.
  const more = evaluateReceipt(
    { ...tbClaim, amount: 2000 },
    PRICING,
    fetched(parseTelebirrReceipt(telebirrHtml({ amount: '2,100.00 Birr' }))),
    NOW,
  );
  assert.deepEqual(more, { status: 'verified', reason: null, durationDays: 90, verifiedAmount: 2100 });
});

test('evaluate: every failed check', () => {
  const tb = (o: Parameters<typeof telebirrHtml>[0], claim = tbClaim) =>
    evaluateReceipt(claim, PRICING, fetched(parseTelebirrReceipt(telebirrHtml(o))), NOW);
  assert.deepEqual(evaluateReceipt({ ...tbClaim, amount: 300 }, PRICING, { kind: 'skipped' }, NOW), {
    status: 'rejected',
    reason: 'amount_too_low',
    durationDays: 0,
    verifiedAmount: null,
  });
  assert.equal(evaluateReceipt(tbClaim, PRICING, { kind: 'skipped' }, NOW, true).reason, 'duplicate');
  assert.equal(evaluateReceipt(tbClaim, PRICING, { kind: 'skipped' }, NOW, true).status, 'rejected');
  assert.equal(evaluateReceipt({ ...tbClaim, method: 'other' }, PRICING, { kind: 'skipped' }, NOW).reason, 'unsupported_method');
  assert.equal(evaluateReceipt(tbClaim, PRICING, { kind: 'fetch_failed' }, NOW).reason, 'fetch_failed');
  assert.equal(evaluateReceipt(tbClaim, PRICING, { kind: 'not_found' }, NOW).reason, 'receipt_not_found');
  assert.equal(tb({ id: 'CHK9ZZZZZZ' }).reason, 'receipt_not_found');
  assert.equal(tb({ status: 'Failed' }).reason, 'not_completed');
  assert.equal(tb({ receiver: 'Someone Else' }).reason, 'receiver_mismatch');
  assert.equal(tb({ account: '2519****0000' }).reason, 'receiver_mismatch');
  assert.equal(tb({ amount: '500.00 Birr' }).reason, 'amount_mismatch');
  assert.equal(tb({ date: '01-09-2026 10:00:00' }).reason, 'too_old');
  assert.equal(tb({ date: '20-11-2026 10:00:00' }).reason, 'too_old', 'in the future');
  assert.equal(tb({ status: 'Failed' }).status, 'needs_review');
  // Unconfigured receiver (placeholders) never auto-verifies.
  assert.equal(
    evaluateReceipt(tbClaim, DEFAULT_PRICING, fetched(parseTelebirrReceipt(telebirrHtml())), NOW).reason,
    'receiver_mismatch',
  );
  assert.equal(
    evaluateReceipt(cbeClaim, PRICING, fetched(parseCbeReceiptText(cbeText({ account: '1****0000' }))), NOW).reason,
    'receiver_mismatch',
  );
});

test('duplicate transactions', () => {
  const t = (h: number) => new Date(NOW.getTime() - h * 3600_000);
  const self = { id: 'other_FT2412345ABC', createdAt: t(1) };
  assert.equal(isDuplicateTransaction(self, []), false);
  assert.equal(isDuplicateTransaction(self, [{ id: self.id, status: 'pending', createdAt: t(1) }]), false);
  assert.equal(isDuplicateTransaction(self, [{ id: 'cbe_FT2412345ABC', status: 'verified', createdAt: t(0) }]), true);
  assert.equal(isDuplicateTransaction(self, [{ id: 'cbe_FT2412345ABC', status: 'pending', createdAt: t(2) }]), true);
  assert.equal(isDuplicateTransaction(self, [{ id: 'cbe_FT2412345ABC', status: 'pending', createdAt: t(0) }]), false);
  assert.equal(isDuplicateTransaction(self, [{ id: 'cbe_FT2412345ABC', status: 'rejected', createdAt: t(5) }]), false);
});

test('checkFromPage: status codes, HTML, PDF', () => {
  const page = (status: number, body: string | Buffer, contentType = 'text/html') => ({
    status,
    contentType,
    body: Buffer.isBuffer(body) ? body : Buffer.from(body, 'utf8'),
  });
  assert.equal(checkFromPage('telebirr', page(404, '')).kind, 'not_found');
  assert.equal(checkFromPage('telebirr', page(503, '')).kind, 'fetch_failed');
  assert.equal(checkFromPage('telebirr', page(200, TELEBIRR_NOT_FOUND)).kind, 'not_found');
  assert.equal(checkFromPage('telebirr', page(200, telebirrHtml())).kind, 'fetched');
  assert.equal(checkFromPage('cbe', page(200, pdfOf(cbeText().split('\n')), 'application/pdf')).kind, 'fetched');
  // An unreadable PDF is not proof the receipt is missing.
  assert.equal(checkFromPage('cbe', page(200, Buffer.from('%PDF-1.4 garbage'), 'application/pdf')).kind, 'fetch_failed');
});

// ------------------------------------------------------------ flow

class MemStore implements DocStore {
  docs = new Map<string, DocData>();
  key = (c: string, id: string) => `${c}/${id}`;
  set(c: string, id: string, d: DocData) {
    this.docs.set(this.key(c, id), { ...d });
  }
  doc(c: string, id: string) {
    return this.docs.get(this.key(c, id));
  }
  async get(c: string, id: string) {
    const d = this.docs.get(this.key(c, id));
    return d ? { ...d } : undefined;
  }
  async update(c: string, id: string, data: DocData) {
    const k = this.key(c, id);
    if (!this.docs.has(k)) throw new Error('not found');
    this.docs.set(k, { ...this.docs.get(k), ...data });
  }
  newId() {
    return 'id';
  }
  async runTransaction<T>(fn: (tx: DocTx) => Promise<T>): Promise<T> {
    const writes: (() => void)[] = [];
    let wrote = false;
    const tx: DocTx = {
      get: async (c, id) => {
        if (wrote) throw new Error('read after write');
        return this.get(c, id);
      },
      create: (c, id, data) => {
        wrote = true;
        writes.push(() => {
          if (this.docs.has(this.key(c, id))) throw new Error('already exists');
          this.set(c, id, data);
        });
      },
      update: (c, id, data) => {
        wrote = true;
        writes.push(() => {
          const k = this.key(c, id);
          if (!this.docs.has(k)) throw new Error('not found');
          this.docs.set(k, { ...this.docs.get(k), ...data });
        });
      },
    };
    const out = await fn(tx);
    writes.forEach((w) => w());
    return out;
  }
}

function setup(o: { payment?: DocData; shopEnds?: string; page?: () => Promise<{ status: number; contentType: string; body: Buffer }> } = {}) {
  const store = new MemStore();
  store.set('platformConfig', 'subscriptionPricing', {
    currency: 'ETB',
    tiers: DEFAULT_PRICING.tiers,
    receivers: { telebirr: { number: '+251911223344', name: 'Crown & Blade' }, cbe: { account: '1000123459012', name: 'Crown & Blade' } },
  });
  store.set('barbershops', 'shop_1', {
    ownerId: 'owner_1',
    subscriptionPlan: 'basic',
    subscriptionStatus: 'suspended',
    adminSuspended: false,
    subscriptionEndsAt: o.shopEnds ?? new Date(NOW.getTime() - 3 * DAY).toISOString(),
  });
  store.set('users', 'owner_1', { role: 'barbershopOwner', language: 'am' });
  store.set('subscriptionPayments', 'telebirr_CHK1AB2CDE', {
    shopId: 'shop_1',
    ownerId: 'owner_1',
    method: 'telebirr',
    transactionId: 'CHK1AB2CDE',
    amount: 1400,
    status: 'pending',
    durationDays: 0,
    createdAt: NOW.toISOString(),
    ...o.payment,
  });
  const urls: string[] = [];
  const deps: ReceiptFlowDeps = {
    store,
    fetchPage: async (url) => {
      urls.push(url);
      return o.page ? o.page() : { status: 200, contentType: 'text/html', body: Buffer.from(telebirrHtml()) };
    },
    findSameTransaction: async () => [],
    now: () => NOW,
  };
  return { store, deps, urls };
}

test('flow: verified receipt extends a lapsed shop from now, reactivates it, notifies the owner', async () => {
  const { store, deps, urls } = setup();
  const result = await verifyReceiptPayment(deps, 'telebirr_CHK1AB2CDE');
  assert.equal(result.outcome, 'verified');
  assert.deepEqual(urls, ['https://transactioninfo.ethiotelecom.et/receipt/CHK1AB2CDE']);
  const p = store.doc('subscriptionPayments', 'telebirr_CHK1AB2CDE')!;
  assert.equal(p.status, 'verified');
  assert.equal(p.durationDays, 90);
  assert.equal(p.verifiedAmount, 1400);
  assert.equal(p.verifiedBy, 'auto');
  assert.equal(p.decidedAt, NOW.toISOString());
  assert.equal(p.autoCheck.receiverAccount, '2519****3344');
  const shop = store.doc('barbershops', 'shop_1')!;
  assert.equal(shop.subscriptionStatus, 'active');
  assert.equal(shop.subscriptionEndsAt, new Date(NOW.getTime() + 90 * DAY).toISOString());
  assert.equal(shop.subscriptionReceiptId, 'telebirr_CHK1AB2CDE');
  assert.equal(shop.subscriptionPlan, 'basic');
  const n = store.doc('users/owner_1/notifications', 'telebirr_CHK1AB2CDE_receipt')!;
  assert.equal(n.type, 'receiptApproved');
  assert.equal(n.title, 'የደንበኝነት ክፍያ ጸድቋል');
  assert.equal(n.read, false);
  // Re-running does nothing.
  assert.equal((await verifyReceiptPayment(deps, 'telebirr_CHK1AB2CDE')).outcome, 'skipped');
});

test('flow: extends from the current end when it is in the future; admin suspension untouched', async () => {
  const end = new Date(NOW.getTime() + 20 * DAY).toISOString();
  const { store, deps } = setup({ shopEnds: end });
  store.set('barbershops', 'shop_1', { ...store.doc('barbershops', 'shop_1'), adminSuspended: true });
  await verifyReceiptPayment(deps, 'telebirr_CHK1AB2CDE');
  const shop = store.doc('barbershops', 'shop_1')!;
  assert.equal(shop.subscriptionEndsAt, new Date(NOW.getTime() + 110 * DAY).toISOString());
  assert.equal(shop.adminSuspended, true);
});

test('flow: mismatches go to needs_review without touching the shop', async () => {
  const { store, deps } = setup({
    page: async () => ({ status: 200, contentType: 'text/html', body: Buffer.from(telebirrHtml({ receiver: 'Someone Else' })) }),
  });
  const before = { ...store.doc('barbershops', 'shop_1') };
  const r = await verifyReceiptPayment(deps, 'telebirr_CHK1AB2CDE');
  assert.deepEqual(r, { outcome: 'needs_review', reason: 'receiver_mismatch', durationDays: 0 });
  const p = store.doc('subscriptionPayments', 'telebirr_CHK1AB2CDE')!;
  assert.equal(p.status, 'needs_review');
  assert.equal(p.decisionReason, 'receiver_mismatch');
  assert.equal(p.decidedAt, undefined);
  assert.deepEqual(store.doc('barbershops', 'shop_1'), before);
  assert.equal(store.doc('users/owner_1/notifications', 'telebirr_CHK1AB2CDE_receipt'), undefined);
});

test('flow: network failure -> needs_review fetch_failed; admin re-run can verify it', async () => {
  let fail = true;
  const { store, deps } = setup({
    page: async () => {
      if (fail) throw new Error('ETIMEDOUT');
      return { status: 200, contentType: 'text/html', body: Buffer.from(telebirrHtml()) };
    },
  });
  assert.equal((await verifyReceiptPayment(deps, 'telebirr_CHK1AB2CDE')).outcome, 'needs_review');
  assert.equal(store.doc('subscriptionPayments', 'telebirr_CHK1AB2CDE')!.decisionReason, 'fetch_failed');
  fail = false;
  assert.equal((await verifyReceiptPayment(deps, 'telebirr_CHK1AB2CDE')).outcome, 'skipped');
  assert.equal((await verifyReceiptPayment(deps, 'telebirr_CHK1AB2CDE', { allowNeedsReview: true })).outcome, 'verified');
});

test('flow: duplicate and too-low amounts are rejected without fetching', async () => {
  const dup = setup();
  dup.deps.findSameTransaction = async () => [
    { id: 'telebirr_CHK1AB2CDE', status: 'pending', createdAt: NOW.toISOString() }, // itself
    { id: 'other_CHK1AB2CDE', status: 'verified', createdAt: new Date(NOW.getTime() - DAY).toISOString() },
  ];
  const r = await verifyReceiptPayment(dup.deps, 'telebirr_CHK1AB2CDE');
  assert.deepEqual(r, { outcome: 'rejected', reason: 'duplicate', durationDays: 0 });
  assert.deepEqual(dup.urls, []);
  const n = dup.store.doc('users/owner_1/notifications', 'telebirr_CHK1AB2CDE_receipt')!;
  assert.equal(n.type, 'receiptRejected');
  assert.match(String(n.body), /CHK1AB2CDE/);

  const low = setup({ payment: { amount: 200 } });
  assert.equal((await verifyReceiptPayment(low.deps, 'telebirr_CHK1AB2CDE')).outcome, 'rejected');
  assert.equal(low.store.doc('subscriptionPayments', 'telebirr_CHK1AB2CDE')!.decisionReason, 'amount_too_low');
  assert.deepEqual(low.urls, []);
});

test('flow: never extends a shop the payer does not own', async () => {
  const { store, deps } = setup({ payment: { ownerId: 'owner_9' } });
  const r = await verifyReceiptPayment(deps, 'telebirr_CHK1AB2CDE');
  assert.equal(r.outcome, 'needs_review');
  assert.equal(store.doc('barbershops', 'shop_1')!.subscriptionStatus, 'suspended');
});

test('flow: CBE uses the payer suffix and the PDF', async () => {
  const { store, deps, urls } = setup({
    payment: { method: 'cbe', transactionId: 'FT2412345ABC', payerAccountSuffix: '12345678' },
    page: async () => ({ status: 200, contentType: 'application/pdf', body: pdfOf(cbeText().split('\n')) }),
  });
  store.set('subscriptionPayments', 'cbe_FT2412345ABC', store.doc('subscriptionPayments', 'telebirr_CHK1AB2CDE')!);
  const r = await verifyReceiptPayment(deps, 'cbe_FT2412345ABC');
  assert.equal(r.outcome, 'verified');
  assert.deepEqual(urls, ['https://apps.cbe.com.et:100/?id=FT2412345ABC12345678']);
});

test('notification dates', () => {
  assert.match(formatAddisDate(new Date('2027-02-15T09:00:00Z'), 'en'), /15 Feb 2027/);
  assert.ok(formatAddisDate(new Date('2027-02-15T09:00:00Z'), 'am').length > 0);
});

// --- receipt photos: inline (free plan) or Firebase Storage (Blaze) ---

const JPEG = Buffer.from([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, 0x4a, 0x46, 0x49, 0x46, 0x00, 0xff, 0xd9]);
const PATH = 'receipts/shop_1/telebirr_CHK1AB2CDE.jpg';

test('photo: path, inline base64 and Storage reads', async () => {
  assert.equal(receiptImagePath('shop_1', 'telebirr_CHK1AB2CDE'), PATH);
  const pay = (o: Record<string, unknown>) => ({ shopId: 'shop_1', ...o });
  const reads: string[] = [];
  const reader = (objects: Record<string, Buffer>) => async (path: string) => {
    reads.push(path);
    return objects[path] ?? null;
  };

  // Nothing attached.
  assert.deepEqual((await loadReceiptImage(pay({}), 'telebirr_CHK1AB2CDE')).summary, { source: 'none', ok: false });

  // Inline (free plan).
  const inline = await loadReceiptImage(pay({ receiptImage: JPEG.toString('base64') }), 'telebirr_CHK1AB2CDE');
  assert.deepEqual(inline.summary, { source: 'inline', ok: true, bytes: JPEG.length });
  assert.deepEqual(inline.data, JPEG);
  assert.equal((await loadReceiptImage(pay({ receiptImage: 'not base64!' }), 'x')).summary.error, 'bad_base64');
  assert.equal((await loadReceiptImage(pay({ receiptImage: 'QUJD' }), 'x')).summary.error, 'not_jpeg');

  // Storage (Blaze): read from the payment's own path.
  const stored = await loadReceiptImage(pay({ imagePath: PATH }), 'telebirr_CHK1AB2CDE', reader({ [PATH]: JPEG }));
  assert.deepEqual(stored.summary, { source: 'storage', ok: true, path: PATH, bytes: JPEG.length });
  assert.deepEqual(stored.data, JPEG);
  assert.deepEqual(reads, [PATH]);

  // Missing object, read errors, no reader, oversize, not a JPEG.
  assert.equal((await loadReceiptImage(pay({ imagePath: PATH }), 'telebirr_CHK1AB2CDE', reader({}))).summary.error, 'missing');
  const failing = async () => {
    throw new Error('storage/bucket-not-found');
  };
  assert.equal((await loadReceiptImage(pay({ imagePath: PATH }), 'telebirr_CHK1AB2CDE', failing)).summary.error, 'unavailable');
  assert.equal((await loadReceiptImage(pay({ imagePath: PATH }), 'telebirr_CHK1AB2CDE')).summary.error, 'unavailable');
  const big = Buffer.concat([JPEG, Buffer.alloc(RECEIPT_IMAGE_MAX_BYTES)]);
  assert.equal((await loadReceiptImage(pay({ imagePath: PATH }), 'telebirr_CHK1AB2CDE', reader({ [PATH]: big }))).summary.error, 'too_large');
  assert.equal(
    (await loadReceiptImage(pay({ imagePath: PATH }), 'telebirr_CHK1AB2CDE', reader({ [PATH]: Buffer.from('ABC') }))).summary.error,
    'not_jpeg',
  );

  // Never reads an object outside this payment's own path.
  reads.length = 0;
  for (const other of ['receipts/shop_2/telebirr_CHK1AB2CDE.jpg', 'receipts/shop_1/cbe_FT1.jpg', 'users/x/secret.jpg', '../' + PATH]) {
    const r = await loadReceiptImage(pay({ imagePath: other }), 'telebirr_CHK1AB2CDE', reader({ [other]: JPEG }));
    assert.equal(r.summary.error, 'bad_path', other);
  }
  assert.deepEqual(reads, []);

  // A Storage failure with an inline copy uses the inline copy.
  const both = await loadReceiptImage(
    pay({ imagePath: PATH, receiptImage: JPEG.toString('base64') }),
    'telebirr_CHK1AB2CDE',
    reader({}),
  );
  assert.deepEqual(both.summary, { source: 'inline', ok: true, bytes: JPEG.length, path: PATH, storageError: 'missing' });
});

test('flow: records the Storage photo (Blaze) in autoCheck.image; the verdict does not depend on it', async () => {
  const { store, deps } = setup({ payment: { imagePath: PATH } });
  const reads: string[] = [];
  deps.readStorageObject = async (path) => {
    reads.push(path);
    return path === PATH ? JPEG : null;
  };
  assert.equal((await verifyReceiptPayment(deps, 'telebirr_CHK1AB2CDE')).outcome, 'verified');
  assert.deepEqual(reads, [PATH]);
  const p = store.doc('subscriptionPayments', 'telebirr_CHK1AB2CDE')!;
  assert.deepEqual(p.autoCheck.image, { source: 'storage', ok: true, path: PATH, bytes: JPEG.length });

  // Object missing (e.g. bucket gone): still decided from the official receipt.
  const gone = setup({ payment: { imagePath: PATH } });
  gone.deps.readStorageObject = async () => null;
  assert.equal((await verifyReceiptPayment(gone.deps, 'telebirr_CHK1AB2CDE')).outcome, 'verified');
  assert.deepEqual(gone.store.doc('subscriptionPayments', 'telebirr_CHK1AB2CDE')!.autoCheck.image, {
    source: 'storage',
    ok: false,
    path: PATH,
    error: 'missing',
  });
});

test('flow: inline photo (free plan) and no photo', async () => {
  const inline = setup({ payment: { receiptImage: JPEG.toString('base64') } });
  inline.deps.readStorageObject = async () => {
    throw new Error('must not read Storage for an inline photo');
  };
  await verifyReceiptPayment(inline.deps, 'telebirr_CHK1AB2CDE');
  assert.deepEqual(inline.store.doc('subscriptionPayments', 'telebirr_CHK1AB2CDE')!.autoCheck.image, {
    source: 'inline',
    ok: true,
    bytes: JPEG.length,
  });
  const none = setup();
  await verifyReceiptPayment(none.deps, 'telebirr_CHK1AB2CDE');
  assert.deepEqual(none.store.doc('subscriptionPayments', 'telebirr_CHK1AB2CDE')!.autoCheck.image, { source: 'none', ok: false });
});
