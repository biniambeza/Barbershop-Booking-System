/** Minimal Chapa REST client (https://developer.chapa.co). Server-side only. */
import { CHAPA_API_BASE } from './config';
import { ChapaVerifyData } from './logic/verification';

const TIMEOUT_MS = 15_000;

export class ChapaError extends Error {
  constructor(
    message: string,
    readonly httpStatus: number,
    readonly body: unknown,
  ) {
    super(message);
    this.name = 'ChapaError';
  }
}

export interface InitializeRequest {
  amount: string;
  currency: string;
  tx_ref: string;
  first_name?: string;
  last_name?: string;
  email?: string;
  phone_number?: string;
  callback_url?: string;
  return_url?: string;
  customization?: { title?: string; description?: string };
  meta?: Record<string, unknown>;
}

async function call(secretKey: string, path: string, init: RequestInit): Promise<{ status: number; body: any }> {
  const res = await fetch(`${CHAPA_API_BASE}${path}`, {
    ...init,
    headers: {
      Authorization: `Bearer ${secretKey}`,
      'Content-Type': 'application/json',
      Accept: 'application/json',
    },
    signal: AbortSignal.timeout(TIMEOUT_MS),
  });
  const text = await res.text();
  let body: any = null;
  try {
    body = text ? JSON.parse(text) : null;
  } catch {
    body = { raw: text.slice(0, 500) };
  }
  return { status: res.status, body };
}

/** POST /transaction/initialize. Returns the hosted checkout URL. */
export async function initializeTransaction(secretKey: string, req: InitializeRequest): Promise<string> {
  const { status, body } = await call(secretKey, '/transaction/initialize', {
    method: 'POST',
    body: JSON.stringify(req),
  });
  const url = body?.data?.checkout_url;
  if (status >= 200 && status < 300 && body?.status === 'success' && typeof url === 'string') {
    return url;
  }
  const message = typeof body?.message === 'string' ? body.message : JSON.stringify(body?.message ?? body);
  throw new ChapaError(`Chapa initialize failed (${status}): ${message}`, status, body);
}

/**
 * GET /transaction/verify/{tx_ref}. Returns the transaction data, or null
 * when Chapa does not know the transaction yet (customer has not paid).
 * Throws ChapaError on auth/server errors so callers can retry.
 */
export async function verifyTransaction(secretKey: string, txRef: string): Promise<ChapaVerifyData | null> {
  const { status, body } = await call(secretKey, `/transaction/verify/${encodeURIComponent(txRef)}`, {
    method: 'GET',
  });
  if (status >= 200 && status < 300 && body?.data && typeof body.data === 'object') {
    return body.data as ChapaVerifyData;
  }
  // Chapa answers 400/404 with "Invalid transaction or Transaction not found"
  // for references that were never paid.
  if (status === 400 || status === 404) return null;
  throw new ChapaError(`Chapa verify failed (${status})`, status, body);
}
