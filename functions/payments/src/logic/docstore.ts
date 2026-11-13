/**
 * A tiny document-store interface so multi-step payment flows can run
 * against Firestore in production and an in-memory fake in unit tests.
 */

export type DocData = Record<string, any>;

/** Reads and writes inside one transaction (all reads before writes). */
export interface DocTx {
  get(collection: string, id: string): Promise<DocData | undefined>;
  create(collection: string, id: string, data: DocData): void;
  update(collection: string, id: string, data: DocData): void;
}

export interface DocStore {
  get(collection: string, id: string): Promise<DocData | undefined>;
  update(collection: string, id: string, data: DocData): Promise<void>;
  /** A new random document id for [collection]. */
  newId(collection: string): string;
  runTransaction<T>(fn: (tx: DocTx) => Promise<T>): Promise<T>;
}

export type FlowErrorCode =
  | 'permission-denied'
  | 'failed-precondition'
  | 'not-found'
  | 'already-exists'
  | 'invalid-argument'
  | 'aborted'
  | 'unavailable';

/** A user-facing failure of a payment flow; index.ts turns it into an HttpsError. */
export class FlowError extends Error {
  constructor(
    readonly code: FlowErrorCode,
    message: string,
  ) {
    super(message);
    this.name = 'FlowError';
  }
}
