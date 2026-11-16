/**
 * Parsers for the official receipt pages (pure, fixture-tested).
 *
 * UNCERTAINTY: the formats below come from public open-source verifiers
 * (e.g. github.com/Vixen878/verifier-api) and were not checked against a
 * live receipt from this project's accounts. The parsers are tolerant;
 * anything they cannot read sends the payment to 'needs_review' (an admin
 * decides), never to 'verified'.
 *
 * telebirr (HTML, https://transactioninfo.ethiotelecom.et/receipt/{id}):
 *   a table of label/value cells, labels bilingual, e.g.
 *   "የገንዘብ ተቀባይ ስም/Credited Party name" | "Crown and Blade PLC"
 *   "የገንዘብ ተቀባይ ቴሌብር ቁ./Credited party account no" | "2519****3344"
 *   "የክፍያው ሁኔታ/transaction status" | "Completed"
 *   then a details table: header row "Invoice No. | Payment date |
 *   Settled Amount" and a value row "CHK1AB2CDE | 15-11-2026 10:22:33 |
 *   1,400.00 Birr". Dates are DD-MM-YYYY HH:MM:SS, Addis Ababa time.
 *
 * CBE (PDF, https://apps.cbe.com.et:100/?id=FT...{8-digit payer suffix}):
 *   text like "Payer ABEBE KEBEDE Account 1****5678 Receiver CROWN AND
 *   BLADE Account 1****9012 Payment Date & Time 11/15/2026, 10:22:33 AM
 *   Reference No. (VAT Invoice No) FT2412345ABC Reason / Type of service
 *   ... Transferred Amount 1,400.00 ETB". Dates are M/D/YYYY h:mm:ss AM,
 *   Addis Ababa time. A receipt is only issued for completed transfers.
 */
import { inflateSync } from 'node:zlib';

export interface ParsedReceipt {
  /** The page described a transaction (not an error / empty page). */
  found: boolean;
  /** Lowercased status as shown ('completed'), or null. */
  status: string | null;
  reference: string | null;
  receiverName: string | null;
  /** As shown, usually masked (2519****3344, 1****9012). */
  receiverAccount: string | null;
  payerName: string | null;
  amount: number | null;
  /** UTC instant of the payment. */
  paidAt: Date | null;
}

const EMPTY: ParsedReceipt = {
  found: false,
  status: null,
  reference: null,
  receiverName: null,
  receiverAccount: null,
  payerName: null,
  amount: null,
  paidAt: null,
};

/** Addis Ababa is UTC+3 all year (no DST). */
const ADDIS_OFFSET_HOURS = 3;

function addisToUtc(y: number, mo: number, d: number, h: number, mi: number, s: number): Date | null {
  if (mo < 1 || mo > 12 || d < 1 || d > 31 || h > 23 || mi > 59 || s > 59) return null;
  const date = new Date(Date.UTC(y, mo - 1, d, h - ADDIS_OFFSET_HOURS, mi, s));
  return Number.isNaN(date.getTime()) ? null : date;
}

/** "15-11-2026 10:22:33" (DD-MM-YYYY, Addis time) -> UTC. */
export function parseTelebirrDate(text: string | null): Date | null {
  const m = text?.match(/(\d{1,2})[-/.](\d{1,2})[-/.](\d{4})\s+(\d{1,2}):(\d{2})(?::(\d{2}))?/);
  if (!m) return null;
  return addisToUtc(+m[3], +m[2], +m[1], +m[4], +m[5], +(m[6] ?? 0));
}

/** "11/15/2026, 10:22:33 AM" (M/D/YYYY, Addis time) -> UTC. */
export function parseCbeDate(text: string | null): Date | null {
  const m = text?.match(/(\d{1,2})\/(\d{1,2})\/(\d{4}),?\s+(\d{1,2}):(\d{2})(?::(\d{2}))?\s*([AP]\.?M\.?)?/i);
  if (!m) return null;
  let hour = +m[4];
  const ampm = m[7]?.replace(/\./g, '').toUpperCase();
  if (ampm === 'PM' && hour < 12) hour += 12;
  if (ampm === 'AM' && hour === 12) hour = 0;
  return addisToUtc(+m[3], +m[1], +m[2], hour, +m[5], +(m[6] ?? 0));
}

/** "1,400.00 Birr" / "ETB 1400" -> 1400. */
export function parseAmount(text: string | null): number | null {
  const m = text?.match(/(\d{1,3}(?:,\d{3})+|\d+)(?:\.(\d{1,2}))?/);
  if (!m) return null;
  const v = Number(`${m[1].replace(/,/g, '')}.${m[2] ?? '0'}`);
  return Number.isFinite(v) && v > 0 ? Math.round(v * 100) / 100 : null;
}

const ENTITIES: Record<string, string> = { amp: '&', lt: '<', gt: '>', quot: '"', apos: "'", nbsp: ' ' };

function decodeEntities(s: string): string {
  return s.replace(/&(#x[0-9a-f]+|#\d+|[a-z]+);/gi, (all, e: string) => {
    if (e[0] === '#') {
      const code = e[1].toLowerCase() === 'x' ? parseInt(e.slice(2), 16) : parseInt(e.slice(1), 10);
      return Number.isFinite(code) ? String.fromCodePoint(code) : all;
    }
    return ENTITIES[e.toLowerCase()] ?? all;
  });
}

function cellText(html: string): string {
  return decodeEntities(html.replace(/<br\s*\/?>/gi, ' ').replace(/<[^>]*>/g, ' '))
    .replace(/\s+/g, ' ')
    .trim();
}

/** HTML tables -> rows of cell texts. */
export function htmlTableRows(html: string): string[][] {
  const body = html.replace(/<script[\s\S]*?<\/script>/gi, '').replace(/<style[\s\S]*?<\/style>/gi, '');
  const rows: string[][] = [];
  for (const tr of body.matchAll(/<tr\b[^>]*>([\s\S]*?)<\/tr>/gi)) {
    const cells = [...tr[1].matchAll(/<t[dh]\b[^>]*>([\s\S]*?)<\/t[dh]>/gi)].map((c) => cellText(c[1]));
    if (cells.length > 0) rows.push(cells);
  }
  return rows;
}

/** The value cell right after the first cell matching [label] (same row). */
function valueAfter(rows: string[][], label: RegExp): string | null {
  for (const row of rows) {
    for (let i = 0; i < row.length - 1; i++) {
      if (label.test(row[i]) && row[i + 1]) return row[i + 1];
    }
  }
  return null;
}

/** For a header row containing [label]: the cell in the same column of the next row. */
function valueBelow(rows: string[][], label: RegExp): string | null {
  for (let r = 0; r < rows.length - 1; r++) {
    const col = rows[r].findIndex((c) => label.test(c));
    if (col >= 0 && rows[r + 1][col]) return rows[r + 1][col];
  }
  return null;
}

const TB = {
  payerName: /Payer\s*Name/i,
  receiverName: /Credited\s*Party\s*name/i,
  receiverAccount: /Credited\s*party\s*account\s*no/i,
  status: /transaction\s*status/i,
  invoice: /Invoice\s*No/i,
  paymentDate: /Payment\s*date/i,
  settled: /Settled\s*Amount/i,
  total: /Total\s*Paid\s*Amount/i,
};

/** Parses the telebirr receipt HTML. */
export function parseTelebirrReceipt(html: string): ParsedReceipt {
  if (!html || typeof html !== 'string') return EMPTY;
  const rows = htmlTableRows(html);
  const isAmount = (v: string | null) => (v && /\d/.test(v) && !/[a-z]{4,}\s*\//i.test(v) ? v : null);
  const reference = valueBelow(rows, TB.invoice) ?? null;
  const dateText = valueBelow(rows, TB.paymentDate) ?? html.match(/\d{2}-\d{2}-\d{4}\s+\d{2}:\d{2}:\d{2}/)?.[0] ?? null;
  const amountText =
    isAmount(valueBelow(rows, TB.settled)) ?? isAmount(valueAfter(rows, TB.settled)) ?? isAmount(valueAfter(rows, TB.total));
  const parsed: ParsedReceipt = {
    found: false,
    status: valueAfter(rows, TB.status)?.toLowerCase() ?? null,
    reference: reference && /^[A-Z0-9]{6,20}$/i.test(reference) ? reference.toUpperCase() : null,
    receiverName: valueAfter(rows, TB.receiverName),
    receiverAccount: valueAfter(rows, TB.receiverAccount),
    payerName: valueAfter(rows, TB.payerName),
    amount: parseAmount(amountText),
    paidAt: parseTelebirrDate(dateText),
  };
  parsed.found = parsed.amount !== null && (parsed.reference !== null || parsed.receiverName !== null);
  return parsed;
}

/** Parses the text of a CBE receipt PDF (whitespace is normalized first). */
export function parseCbeReceiptText(raw: string): ParsedReceipt {
  if (!raw || typeof raw !== 'string') return EMPTY;
  const text = raw.replace(/\s+/g, ' ').trim();
  const accounts = [...text.matchAll(/Account(?:\s*No\.?)?\s*:?\s*([A-Z0-9]?\d*\*{2,}\d{2,})/gi)].map((m) => m[1]);
  const clean = (s: string | undefined) => s?.replace(/\s+/g, ' ').trim() || null;
  const amountText = text.match(/Transferred\s*Amount\s*:?\s*(?:ETB\s*)?([\d,]+(?:\.\d{1,2})?)/i)?.[1] ?? null;
  const reference = text.match(/Reference\s*No\.?\s*(?:\(\s*VAT\s*Invoice\s*No\s*\))?\s*:?\s*(FT[A-Z0-9]+)/i)?.[1] ?? null;
  const parsed: ParsedReceipt = {
    found: false,
    status: null,
    reference: reference ? reference.toUpperCase() : null,
    payerName: clean(text.match(/Payer\s*:?\s*(.*?)\s+Account/i)?.[1]),
    receiverName: clean(text.match(/Receiver\s*:?\s*(.*?)\s+Account/i)?.[1]),
    receiverAccount: accounts[1] ?? null,
    amount: parseAmount(amountText),
    paidAt: parseCbeDate(text.match(/Payment\s*Date\s*(?:&|and)?\s*Time\s*:?\s*([\d/,: ]+(?:[AP]\.?M\.?)?)/i)?.[1] ?? null),
  };
  parsed.found = parsed.amount !== null && parsed.reference !== null;
  // CBE issues a receipt only for a completed transfer.
  if (parsed.found) parsed.status = /\b(failed|reversed|cancelled)\b/i.test(text) ? 'failed' : 'completed';
  return parsed;
}

// ------------------------------------------------------------ PDF text

function unescapePdfString(s: string): string {
  return s.replace(/\\(\d{1,3}|[nrtbf()\\]|\r?\n)/g, (_all, e: string) => {
    if (/^\d/.test(e)) return String.fromCharCode(parseInt(e, 8) & 0xff);
    return { n: '\n', r: '\r', t: '\t', b: '\b', f: '\f', '(': '(', ')': ')', '\\': '\\' }[e] ?? '';
  });
}

function hexString(hex: string): string {
  const clean = hex.replace(/\s+/g, '');
  let out = '';
  // 4-hex-digit glyphs (Identity-H) are kept only when they look like Unicode.
  const step = clean.length % 4 === 0 && /^(00[0-9a-f]{2})+$/i.test(clean) ? 4 : 2;
  for (let i = 0; i + step <= clean.length; i += step) out += String.fromCharCode(parseInt(clean.slice(i, i + step), 16));
  return out;
}

/** Text shown by one content stream (Tj, TJ, ', " operators; Td/T* etc. become spaces). */
export function contentStreamText(content: string): string {
  const parts: string[] = [];
  const tokens = /\((?:\\[\s\S]|[^\\)])*\)|<[0-9a-fA-F\s]*>|\[|\]|-?\d*\.?\d+|\/[^\s/[\]()<>]+|[A-Za-z'"*]+/g;
  let inArray = false;
  let pending: string[] = [];
  for (const m of content.matchAll(tokens)) {
    const t = m[0];
    if (t.startsWith('(')) pending.push(unescapePdfString(t.slice(1, -1)));
    else if (t.startsWith('<') && t !== '<<') pending.push(hexString(t.slice(1, -1)));
    else if (t === '[') {
      inArray = true;
      pending = [];
    } else if (t === ']') inArray = false;
    else if (inArray && /^-?\d*\.?\d+$/.test(t)) {
      if (Number(t) < -200) pending.push(' ');
    } else if (t === 'Tj' || t === 'TJ' || t === "'" || t === '"') {
      parts.push(pending.join(''));
      pending = [];
    } else if (['Td', 'TD', 'T*', 'Tm', 'ET', 'BT'].includes(t)) {
      parts.push(' ');
      pending = [];
    } else if (!inArray) pending = [];
  }
  return parts.join('').replace(/\s+/g, ' ').trim();
}

/**
 * Minimal, dependency-free text extraction: inflates FlateDecode streams
 * and reads their text operators. Enough for simple generated receipts;
 * PDFs with custom font encodings yield garbage, which the CBE parser then
 * rejects (-> needs_review).
 */
export function extractPdfText(pdf: Buffer): string {
  const raw = pdf.toString('latin1');
  const texts: string[] = [];
  const re = /<<([\s\S]*?)>>\s*stream\r?\n/g;
  let m: RegExpExecArray | null;
  while ((m = re.exec(raw)) !== null) {
    const start = m.index + m[0].length;
    const end = raw.indexOf('endstream', start);
    if (end < 0) break;
    const dict = m[1];
    if (/\/Subtype\s*\/Image|\/Type\s*\/XObject|\/FontFile|\/Length1/.test(dict)) continue;
    let bytes = pdf.subarray(start, end);
    if (/\/FlateDecode/.test(dict)) {
      try {
        bytes = inflateSync(bytes);
      } catch {
        try {
          bytes = inflateSync(pdf.subarray(start, end).subarray(0, Math.max(0, end - start - 2)));
        } catch {
          continue;
        }
      }
    } else if (/\/Filter/.test(dict)) continue;
    const content = bytes.toString('latin1');
    if (/\b(Tj|TJ)\b/.test(content)) texts.push(contentStreamText(content));
    re.lastIndex = end;
  }
  return texts.join(' ').replace(/\s+/g, ' ').trim();
}

// ----------------------------------------------------------- receivers

/** Lowercase letters/digits only, '&' -> 'and', single spaces. */
export function normalizeName(name: string): string {
  return name
    .toLowerCase()
    .replace(/&/g, ' and ')
    .replace(/[^\p{L}\p{N}]+/gu, ' ')
    .replace(/\b(plc|sc|s c|llc|ltd|share company|trading)\b/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

/** Same name, or one contains the other (receipts often add or drop "PLC", show "Crown and Blade" for "Crown & Blade"). */
export function namesMatch(shown: string, configured: string): boolean {
  const a = normalizeName(shown);
  const b = normalizeName(configured);
  if (a.length < 3 || b.length < 3) return false;
  return a === b || a.includes(b) || b.includes(a);
}

/**
 * A masked account ("2519****3344", "1****9012", or unmasked) against the
 * configured one ("+251911223344", "1000123459012"): the visible leading
 * and trailing digits must match; at least 3 trailing digits must show.
 */
export function accountsMatch(shown: string, configured: string): boolean {
  const conf = configured.replace(/\D/g, '');
  const trimmed = shown.replace(/\s+/g, '');
  if (!conf || /X/i.test(configured)) return false;
  const m = trimmed.match(/^\+?(\d*)[*xX•]+(\d+)$/);
  if (!m) {
    const digits = trimmed.replace(/\D/g, '');
    return digits.length >= 6 && (digits === conf || conf.endsWith(digits) || digits.endsWith(conf));
  }
  const [, head, tail] = m;
  if (tail.length < 3 || !conf.endsWith(tail)) return false;
  // 2519**** vs 0911...: compare the head only when both use the same prefix style.
  if (head && !(conf.startsWith(head) || conf.replace(/^251/, '0').startsWith(head))) return false;
  return true;
}

/** The receipt names the configured receiver (name and/or account; at least one shown). */
export function receiverMatches(parsed: ParsedReceipt, configured: { account: string; name: string }): boolean {
  const hasName = !!parsed.receiverName;
  const hasAccount = !!parsed.receiverAccount;
  if (!hasName && !hasAccount) return false;
  if (hasName && !namesMatch(parsed.receiverName!, configured.name)) return false;
  if (hasAccount && !accountsMatch(parsed.receiverAccount!, configured.account)) return false;
  return true;
}
