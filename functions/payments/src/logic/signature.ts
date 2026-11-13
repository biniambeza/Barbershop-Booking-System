/**
 * Chapa webhook signature checks.
 *
 * Chapa documents two headers, both HMAC-SHA256 hex digests keyed with the
 * webhook secret set in the Chapa dashboard:
 *  - x-chapa-signature: HMAC of the event payload (bound to this payload)
 *  - chapa-signature:   HMAC of the secret itself (a static token)
 * Their sample hashes JSON.stringify(req.body); we accept either the raw body
 * or that re-serialization. The handler always re-verifies the transaction
 * with GET /transaction/verify, so the signature only gates processing.
 */
import { createHmac, timingSafeEqual } from 'crypto';

export function hmacSha256Hex(secret: string, data: string | Buffer): string {
  return createHmac('sha256', secret).update(data).digest('hex');
}

export function safeEqualHex(a: string, b: string): boolean {
  const x = Buffer.from(a.trim().toLowerCase(), 'utf8');
  const y = Buffer.from(b.trim().toLowerCase(), 'utf8');
  return x.length === y.length && x.length > 0 && timingSafeEqual(x, y);
}

export interface SignatureInput {
  secret: string;
  rawBody?: Buffer | string;
  parsedBody?: unknown;
  chapaSignature?: string | string[];
  xChapaSignature?: string | string[];
}

export interface SignatureResult {
  valid: boolean;
  /** True only when the payload-bound x-chapa-signature matched. */
  payloadBound: boolean;
}

function first(h: string | string[] | undefined): string | undefined {
  return Array.isArray(h) ? h[0] : h;
}

export function verifyChapaSignature(input: SignatureInput): SignatureResult {
  const { secret } = input;
  if (!secret) return { valid: false, payloadBound: false };

  const x = first(input.xChapaSignature);
  if (x) {
    const candidates: string[] = [];
    if (input.rawBody !== undefined && input.rawBody.length > 0) {
      candidates.push(hmacSha256Hex(secret, input.rawBody));
    }
    if (input.parsedBody !== undefined && input.parsedBody !== null) {
      candidates.push(hmacSha256Hex(secret, JSON.stringify(input.parsedBody)));
    }
    if (candidates.some((c) => safeEqualHex(c, x))) return { valid: true, payloadBound: true };
  }

  const c = first(input.chapaSignature);
  if (c && safeEqualHex(hmacSha256Hex(secret, secret), c)) {
    return { valid: true, payloadBound: false };
  }
  return { valid: false, payloadBound: false };
}
