/**
 * Minimal in-memory stand-in for the parts of the Admin Firestore API that
 * dispatch.ts uses: doc get/create/update/delete, subcollections, and
 * equality where() + limit() queries. Not a general emulator.
 */

import type { Firestore } from 'firebase-admin/firestore';

type Data = Record<string, unknown>;

class Snapshot {
  constructor(
    readonly id: string,
    private readonly value: Data | undefined,
    readonly ref: FakeDocRef,
  ) {}
  get exists(): boolean {
    return this.value !== undefined;
  }
  data(): Data | undefined {
    return this.value === undefined ? undefined : { ...this.value };
  }
  get(field: string): unknown {
    return this.value?.[field];
  }
}

class FakeDocRef {
  constructor(
    private readonly store: FakeFirestore,
    readonly path: string,
  ) {}
  get id(): string {
    return this.path.split('/').pop()!;
  }
  async get(): Promise<Snapshot> {
    return new Snapshot(this.id, this.store.docs.get(this.path), this);
  }
  async create(data: Data): Promise<void> {
    if (this.store.docs.has(this.path)) {
      throw Object.assign(new Error('ALREADY_EXISTS'), { code: 6 });
    }
    this.store.docs.set(this.path, { ...data });
  }
  async set(data: Data): Promise<void> {
    this.store.docs.set(this.path, { ...data });
  }
  async update(data: Data): Promise<void> {
    const cur = this.store.docs.get(this.path);
    if (!cur) throw Object.assign(new Error('NOT_FOUND'), { code: 5 });
    this.store.docs.set(this.path, { ...cur, ...data });
  }
  async delete(): Promise<void> {
    this.store.docs.delete(this.path);
  }
  collection(name: string): FakeQuery {
    return new FakeQuery(this.store, `${this.path}/${name}`, [], Infinity);
  }
}

class FakeQuery {
  constructor(
    private readonly store: FakeFirestore,
    private readonly path: string,
    private readonly filters: [string, unknown][],
    private readonly max: number,
  ) {}
  doc(id: string): FakeDocRef {
    return new FakeDocRef(this.store, `${this.path}/${id}`);
  }
  where(field: string, op: string, value: unknown): FakeQuery {
    if (op !== '==') throw new Error(`fake firestore supports only ==, got ${op}`);
    return new FakeQuery(this.store, this.path, [...this.filters, [field, value]], this.max);
  }
  limit(n: number): FakeQuery {
    return new FakeQuery(this.store, this.path, this.filters, n);
  }
  async get(): Promise<{ empty: boolean; size: number; docs: Snapshot[] }> {
    const prefix = `${this.path}/`;
    const docs: Snapshot[] = [];
    for (const [key, value] of this.store.docs) {
      if (!key.startsWith(prefix) || key.slice(prefix.length).includes('/')) continue;
      if (!this.filters.every(([f, v]) => value[f] === v)) continue;
      docs.push(new Snapshot(key.slice(prefix.length), value, new FakeDocRef(this.store, key)));
      if (docs.length >= this.max) break;
    }
    return { empty: docs.length === 0, size: docs.length, docs };
  }
}

export class FakeFirestore {
  readonly docs = new Map<string, Data>();

  collection(name: string): FakeQuery {
    return new FakeQuery(this, name, [], Infinity);
  }

  /** Seeds a document at a slash path. */
  put(path: string, data: Data): this {
    this.docs.set(path, { ...data });
    return this;
  }

  /** Document data at a slash path. */
  read(path: string): Data | undefined {
    return this.docs.get(path);
  }

  /** Paths under a prefix, sorted. */
  paths(prefix: string): string[] {
    return [...this.docs.keys()].filter((k) => k.startsWith(prefix)).sort();
  }

  asFirestore(): Firestore {
    return this as unknown as Firestore;
  }
}
