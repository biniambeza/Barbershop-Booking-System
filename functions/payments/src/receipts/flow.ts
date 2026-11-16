/**
 * Automatic verification of a transfer receipt (Blaze plan): fetch the
 * official receipt, decide, and - when verified - extend the shop's
 * subscription, all against the DocStore interface so it is unit-tested
 * with an in-memory fake.
 *
 * Writes (admin SDK, one transaction):
 *  - subscriptionPayments/{id}: verified -> {status, durationDays,
 *    verifiedAmount, verifiedBy: 'auto', decidedAt, autoCheck};
 *    rejected -> {status, verifiedBy: 'auto', decisionReason, decidedAt,
 *    autoCheck}; needs_review -> {status, decisionReason, autoCheck}.
 *  - barbershops/{shopId} (verified): {subscriptionStatus: 'active',
 *    subscriptionEndsAt: max(now, current end) + days, subscriptionReceiptId}.
 *    adminSuspended is untouched.
 *  - users/{ownerId}/notifications/{id}_receipt (verified / rejected):
 *    {title, body, type: 'receiptApproved'|'receiptRejected', read: false,
 *    createdAt, shopId, paymentId}.
 *
 * autoCheck.image: what was found of the owner's receipt photo - read from
 * Firebase Storage when the payment has `imagePath` (Blaze, admin switch
 * `storageReceipts`), else the inline base64 `receiptImage` (see image.ts).
 */
import { DocStore } from '../logic/docstore';
import { ParsedReceipt, extractPdfText, parseCbeReceiptText, parseTelebirrReceipt } from './parse';
import { ReceiptCheck, ReceiptVerdict, evaluateReceipt, isDuplicateTransaction, precheckReceipt } from './evaluate';
import { ReceiptImageSummary, StorageObjectReader, loadReceiptImage } from './image';
import {
  PRICING_COLLECTION,
  PRICING_DOC,
  RECEIPTS_COLLECTION,
  RECEIPT_METHODS,
  ReceiptMethod,
  extendByDays,
  officialReceiptUrl,
  parsePricing,
  toDate,
} from './pricing';

export interface FetchedPage {
  status: number;
  contentType: string;
  body: Buffer;
}

export interface ReceiptFlowDeps {
  store: DocStore;
  /** GET [url]; throws on network errors / timeouts. */
  fetchPage(url: string): Promise<FetchedPage>;
  /** Other receipts with the same transaction number (any method). */
  findSameTransaction(transactionId: string): Promise<{ id: string; status: unknown; createdAt: unknown }[]>;
  now(): Date;
  /**
   * Reads a Firebase Storage object (receipt photos with `imagePath`); null
   * when it does not exist. Omitted: Storage photos are reported
   * 'unavailable' (inline photos still work).
   */
  readStorageObject?: StorageObjectReader;
}

export type ReceiptFlowResult =
  | { outcome: 'skipped'; why: string }
  | { outcome: ReceiptVerdict['status']; reason: string | null; durationDays: number; newEndsAt?: string };

/** Turns a fetched page into a check (HTML for telebirr, PDF or HTML for CBE). */
export function checkFromPage(method: ReceiptMethod, page: FetchedPage): ReceiptCheck {
  if (page.status === 404) return { kind: 'not_found' };
  if (page.status < 200 || page.status >= 300) return { kind: 'fetch_failed' };
  let receipt: ParsedReceipt;
  const isPdf = /pdf/i.test(page.contentType) || page.body.subarray(0, 5).toString('latin1') === '%PDF-';
  if (method === 'cbe') {
    const text = isPdf ? extractPdfText(page.body) : page.body.toString('utf8').replace(/<[^>]*>/g, ' ');
    receipt = parseCbeReceiptText(text);
    // A PDF we could not read is not evidence that the receipt is missing.
    if (!receipt.found && isPdf) return { kind: 'fetch_failed' };
  } else {
    receipt = parseTelebirrReceipt(page.body.toString('utf8'));
  }
  return receipt.found ? { kind: 'fetched', receipt } : { kind: 'not_found' };
}

const NOTIFY: Record<'en' | 'am', { approvedTitle: string; approvedBody: (d: number, end: string) => string; rejectedTitle: string; reasons: Record<string, string> }> = {
  en: {
    approvedTitle: 'Subscription payment approved',
    approvedBody: (d, end) => `${d === 1 ? '1 day was' : `${d} days were`} added. Your subscription runs until ${end}.`,
    rejectedTitle: 'Subscription payment rejected',
    reasons: {
      amount_too_low: 'The amount is below the cheapest subscription.',
      duplicate: 'This transaction has already been used.',
    },
  },
  am: {
    approvedTitle: 'የደንበኝነት ክፍያ ጸድቋል',
    approvedBody: (d, end) => `${d === 1 ? '1 ቀን ተጨምሯል' : `${d} ቀናት ተጨምረዋል`}። ደንበኝነትዎ እስከ ${end} ይቆያል።`,
    rejectedTitle: 'የደንበኝነት ክፍያ ውድቅ ተደርጓል',
    reasons: {
      amount_too_low: 'መጠኑ ከዝቅተኛው የደንበኝነት ዋጋ ያነሰ ነው።',
      duplicate: 'ይህ ግብይት ቀደም ሲል ጥቅም ላይ ውሏል።',
    },
  },
};

/** "15 Feb 2027" in Addis Ababa time (Amharic month names when ICU has them). */
export function formatAddisDate(date: Date, language: 'en' | 'am'): string {
  const opts: Intl.DateTimeFormatOptions = { timeZone: 'Africa/Addis_Ababa', day: 'numeric', month: 'short', year: 'numeric' };
  try {
    return new Intl.DateTimeFormat(language === 'am' ? 'am-ET' : 'en-GB', opts).format(date);
  } catch {
    return date.toISOString().slice(0, 10);
  }
}

export function receiptNotification(
  verdict: ReceiptVerdict,
  args: { paymentId: string; shopId: string; transactionId: string; language: unknown; newEndsAt: Date | null; now: Date },
): Record<string, unknown> | null {
  if (verdict.status === 'needs_review') return null;
  const lang: 'en' | 'am' = args.language === 'am' ? 'am' : 'en';
  const t = NOTIFY[lang];
  const base = { read: false, createdAt: args.now.toISOString(), shopId: args.shopId, paymentId: args.paymentId };
  if (verdict.status === 'verified') {
    return {
      ...base,
      type: 'receiptApproved',
      title: t.approvedTitle,
      body: t.approvedBody(verdict.durationDays, formatAddisDate(args.newEndsAt!, lang)),
    };
  }
  const reason = t.reasons[verdict.reason ?? ''] ?? verdict.reason ?? '';
  return {
    ...base,
    type: 'receiptRejected',
    title: t.rejectedTitle,
    body: lang === 'am' ? `ግብይት ${args.transactionId}፦ ${reason}` : `Transaction ${args.transactionId}: ${reason}`,
  };
}

function autoCheckSummary(check: ReceiptCheck, url: string | null): Record<string, unknown> {
  const out: Record<string, unknown> = { result: check.kind };
  if (url) out.url = url;
  if (check.kind === 'fetched') {
    const r = check.receipt;
    for (const [k, v] of Object.entries({
      reference: r.reference,
      status: r.status,
      receiverName: r.receiverName,
      receiverAccount: r.receiverAccount,
      amount: r.amount,
      paidAt: r.paidAt?.toISOString() ?? null,
    })) {
      if (v !== null && v !== undefined) out[k] = typeof v === 'string' ? v.slice(0, 120) : v;
    }
  }
  return out;
}

/**
 * Verifies `subscriptionPayments/{paymentId}`. Only 'pending' receipts are
 * processed ([allowNeedsReview] lets an admin re-run a needs_review one).
 * Idempotent: the decision is written in a transaction that re-checks the
 * status, so a concurrent admin decision wins.
 */
export async function verifyReceiptPayment(
  deps: ReceiptFlowDeps,
  paymentId: string,
  opts: { allowNeedsReview?: boolean } = {},
): Promise<ReceiptFlowResult> {
  const openStatuses = opts.allowNeedsReview ? ['pending', 'needs_review'] : ['pending'];
  const payment = await deps.store.get(RECEIPTS_COLLECTION, paymentId);
  if (!payment) return { outcome: 'skipped', why: 'not_found' };
  if (!openStatuses.includes(payment.status)) return { outcome: 'skipped', why: 'already_decided' };
  const method = payment.method as ReceiptMethod;
  if (!RECEIPT_METHODS.includes(method) || typeof payment.transactionId !== 'string' || typeof payment.amount !== 'number') {
    return { outcome: 'skipped', why: 'malformed' };
  }
  const claim = { method, transactionId: payment.transactionId, amount: payment.amount };
  const pricing = parsePricing(await deps.store.get(PRICING_COLLECTION, PRICING_DOC));
  const now = deps.now();

  const others = await deps.findSameTransaction(claim.transactionId);
  const duplicate = isDuplicateTransaction(
    { id: paymentId, createdAt: toDate(payment.createdAt) },
    others.map((o) => ({ id: o.id, status: o.status, createdAt: toDate(o.createdAt) })),
  );

  let check: ReceiptCheck = { kind: 'skipped' };
  let url: string | null = null;
  if (!precheckReceipt(claim, pricing, duplicate)) {
    url = officialReceiptUrl(method, claim.transactionId, {
      payerAccountSuffix: payment.payerAccountSuffix,
      telebirrTemplate: pricing.telebirrReceiptUrl,
      cbeTemplate: pricing.cbeReceiptUrl,
    });
    if (url) {
      try {
        check = checkFromPage(method, await deps.fetchPage(url));
      } catch {
        check = { kind: 'fetch_failed' };
      }
    }
  }
  let verdict = evaluateReceipt(claim, pricing, check, now, duplicate);
  let image: ReceiptImageSummary;
  try {
    image = (await loadReceiptImage(payment, paymentId, deps.readStorageObject)).summary;
  } catch {
    image = { source: 'none', ok: false, error: 'unavailable' };
  }

  return deps.store.runTransaction(async (tx) => {
    const current = await tx.get(RECEIPTS_COLLECTION, paymentId);
    if (!current || !openStatuses.includes(current.status)) {
      return { outcome: 'skipped', why: 'already_decided' } as ReceiptFlowResult;
    }
    const shopId = String(current.shopId ?? '');
    const ownerId = String(current.ownerId ?? '');
    const shop = shopId ? await tx.get('barbershops', shopId) : undefined;
    const owner = ownerId ? await tx.get('users', ownerId) : undefined;
    if (verdict.status === 'verified' && (!shop || shop.ownerId !== ownerId)) {
      // Never extend a shop the payer does not own.
      verdict = { status: 'needs_review', reason: 'receipt_not_found', durationDays: 0, verifiedAmount: null };
    }

    const decidedAt = now.toISOString();
    const autoCheck = { ...autoCheckSummary(check, url), image, checkedAt: decidedAt };
    let newEndsAt: Date | null = null;
    if (verdict.status === 'verified') {
      newEndsAt = extendByDays(toDate(shop!.subscriptionEndsAt), now, verdict.durationDays);
      tx.update(RECEIPTS_COLLECTION, paymentId, {
        status: 'verified',
        durationDays: verdict.durationDays,
        verifiedAmount: verdict.verifiedAmount,
        verifiedBy: 'auto',
        decidedAt,
        autoCheck,
      });
      tx.update('barbershops', shopId, {
        subscriptionStatus: 'active',
        subscriptionEndsAt: newEndsAt.toISOString(),
        subscriptionReceiptId: paymentId,
      });
    } else if (verdict.status === 'rejected') {
      tx.update(RECEIPTS_COLLECTION, paymentId, {
        status: 'rejected',
        verifiedBy: 'auto',
        decisionReason: verdict.reason,
        decidedAt,
        autoCheck,
      });
    } else {
      tx.update(RECEIPTS_COLLECTION, paymentId, { status: 'needs_review', decisionReason: verdict.reason, autoCheck });
    }
    const notification = receiptNotification(verdict, {
      paymentId,
      shopId,
      transactionId: String(current.transactionId ?? ''),
      language: owner?.language,
      newEndsAt,
      now,
    });
    if (notification && ownerId) tx.create(`users/${ownerId}/notifications`, `${paymentId}_receipt`, notification);
    return {
      outcome: verdict.status,
      reason: verdict.reason,
      durationDays: verdict.durationDays,
      ...(newEndsAt ? { newEndsAt: newEndsAt.toISOString() } : {}),
    } as ReceiptFlowResult;
  });
}

/** Fetcher used in production: 15 s timeout, at most 3 MB. */
export async function fetchReceiptPage(url: string): Promise<FetchedPage> {
  const res = await fetch(url, {
    signal: AbortSignal.timeout(15_000),
    redirect: 'follow',
    headers: { 'User-Agent': 'Mozilla/5.0 (receipt-check)', Accept: 'text/html,application/pdf;q=0.9,*/*;q=0.5' },
  });
  const buf = Buffer.from(await res.arrayBuffer());
  if (buf.length > 3 * 1024 * 1024) throw new Error('Receipt page too large');
  return { status: res.status, contentType: res.headers.get('content-type') ?? '', body: buf };
}
