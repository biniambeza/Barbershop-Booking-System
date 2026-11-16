/**
 * The owner's receipt photo, wherever the app stored it (pure; the Storage
 * read is injected so it is unit-tested without Firebase):
 *
 *  - Blaze, admin switch `storageReceipts` on: Firebase Storage object
 *    `receipts/{shopId}/{paymentId}.jpg`, named by the payment's `imagePath`.
 *  - Free plan (or an upload that failed): base64 JPEG inline in
 *    `receiptImage`.
 *
 * The photo is not evidence on its own (the official receipt is); the flow
 * records what it found in `autoCheck.image` so an admin sees at a glance
 * whether the photo is there.
 */

/** Largest receipt object the storage rules accept (and we read). */
export const RECEIPT_IMAGE_MAX_BYTES = 2 * 1024 * 1024;

/** Where the app uploads a receipt photo (lib/.../receipt_photo_storage.dart). */
export function receiptImagePath(shopId: string, paymentId: string): string {
  return `receipts/${shopId}/${paymentId}.jpg`;
}

export type ReceiptImageError = 'bad_path' | 'missing' | 'unavailable' | 'too_large' | 'not_jpeg' | 'bad_base64';

export interface ReceiptImageSummary {
  source: 'storage' | 'inline' | 'none';
  ok: boolean;
  bytes?: number;
  path?: string;
  error?: ReceiptImageError;
  /** Why the Storage object could not be used (an inline copy was used instead). */
  storageError?: ReceiptImageError;
}

export interface LoadedReceiptImage {
  summary: ReceiptImageSummary;
  /** JPEG bytes when [summary.ok]. */
  data: Buffer | null;
}

/** Reads a Storage object; null when it does not exist. Throws on errors. */
export type StorageObjectReader = (path: string) => Promise<Buffer | null>;

const isJpeg = (b: Buffer) => b.length >= 3 && b[0] === 0xff && b[1] === 0xd8 && b[2] === 0xff;

function checkBytes(data: Buffer): ReceiptImageError | null {
  if (data.length > RECEIPT_IMAGE_MAX_BYTES) return 'too_large';
  if (!isJpeg(data)) return 'not_jpeg';
  return null;
}

function fromInline(raw: string): LoadedReceiptImage {
  const text = raw.trim();
  if (!/^[A-Za-z0-9+/]+={0,2}$/.test(text) || text.length % 4 === 1) {
    return { summary: { source: 'inline', ok: false, error: 'bad_base64' }, data: null };
  }
  const data = Buffer.from(text, 'base64');
  const error = checkBytes(data);
  return error
    ? { summary: { source: 'inline', ok: false, bytes: data.length, error }, data: null }
    : { summary: { source: 'inline', ok: true, bytes: data.length }, data };
}

/**
 * The receipt photo of `subscriptionPayments/{paymentId}` ([payment] is its
 * data). A Storage `imagePath` is read only when it is exactly this
 * payment's own path (receipts/{shopId}/{paymentId}.jpg), never an
 * arbitrary object. Never throws.
 */
export async function loadReceiptImage(
  payment: Record<string, unknown>,
  paymentId: string,
  readStorageObject?: StorageObjectReader,
): Promise<LoadedReceiptImage> {
  const inline = typeof payment.receiptImage === 'string' && payment.receiptImage.trim() !== '' ? payment.receiptImage : null;
  const path = typeof payment.imagePath === 'string' && payment.imagePath !== '' ? payment.imagePath : null;
  if (path === null) {
    return inline ? fromInline(inline) : { summary: { source: 'none', ok: false }, data: null };
  }

  let stored: LoadedReceiptImage;
  const shopId = typeof payment.shopId === 'string' ? payment.shopId : '';
  if (!shopId || path !== receiptImagePath(shopId, paymentId)) {
    stored = { summary: { source: 'storage', ok: false, path, error: 'bad_path' }, data: null };
  } else if (!readStorageObject) {
    stored = { summary: { source: 'storage', ok: false, path, error: 'unavailable' }, data: null };
  } else {
    try {
      const data = await readStorageObject(path);
      if (!data) {
        stored = { summary: { source: 'storage', ok: false, path, error: 'missing' }, data: null };
      } else {
        const error = checkBytes(data);
        stored = error
          ? { summary: { source: 'storage', ok: false, path, bytes: data.length, error }, data: null }
          : { summary: { source: 'storage', ok: true, path, bytes: data.length }, data };
      }
    } catch {
      stored = { summary: { source: 'storage', ok: false, path, error: 'unavailable' }, data: null };
    }
  }
  if (stored.summary.ok || !inline) return stored;
  const fallback = fromInline(inline);
  return fallback.summary.ok ? { summary: { ...fallback.summary, path, storageError: stored.summary.error }, data: fallback.data } : stored;
}
