import { afterEach, describe, expect, it, vi } from 'vitest';

import {
  acknowledgeChatAttachment,
  completeChatAttachment,
  prepareChatAttachment,
} from '../src/chat/attachments';
import type { Env } from '../src/types';

const ACCOUNT_ID =
  '0x1111111111111111111111111111111111111111111111111111111111111111';
const ALICE = 'CN220-CTZN2-198805200-2026';
const BOB = 'CN220-CTZN2-199001010-2026';
const CAROL = 'CN220-CTZN2-199201010-2026';
const SHA256 = 'a'.repeat(64);

interface AttachmentRow {
  attachment_id: string;
  sender_cid_number: string;
  object_key: string;
  cipher_byte_size: number;
  cipher_sha256: string;
  multipart_upload_id: string;
  part_count: number;
  upload_state: 'uploading' | 'ready';
  expires_at: number;
}

class AttachmentDb {
  readonly attachments = new Map<string, AttachmentRow>();
  readonly recipients = new Map<string, Set<string>>();

  prepare(sql: string): AttachmentStatement {
    return new AttachmentStatement(this, sql.replace(/\s+/g, ' ').trim());
  }

  async batch(statements: AttachmentStatement[]): Promise<unknown[]> {
    return Promise.all(statements.map((statement) => statement.run()));
  }
}

class AttachmentStatement {
  private values: unknown[] = [];

  constructor(
    private readonly db: AttachmentDb,
    private readonly sql: string,
  ) {}

  bind(...values: unknown[]): AttachmentStatement {
    this.values = values;
    return this;
  }

  async first<T>(): Promise<T | null> {
    if (this.sql.includes('FROM square_memberships')) {
      return {
        cid_number: this.values[0],
        account_id: ACCOUNT_ID,
        membership_level: 'freedom',
        paid_until: Date.now() + 86_400_000,
        subscription_status: 'active',
      } as T;
    }
    if (this.sql.includes('FROM users') && this.sql.includes('WHERE cid_number = ?')) {
      const cidNumber = String(this.values[0]);
      if (![ALICE, BOB, CAROL].includes(cidNumber)) return null;
      return { cid_number: cidNumber, account_id: ACCOUNT_ID } as T;
    }
    if (this.sql.includes('FROM chat_attachments WHERE attachment_id = ?')) {
      return (this.db.attachments.get(String(this.values[0])) ?? null) as T | null;
    }
    if (this.sql.includes('SELECT recipient_cid_number FROM chat_attachment_recipients')) {
      const recipients = this.db.recipients.get(String(this.values[0]));
      const cidNumber = String(this.values[1]);
      return (recipients?.has(cidNumber)
        ? { recipient_cid_number: cidNumber }
        : null) as T | null;
    }
    if (this.sql.includes('SELECT COUNT(*) AS n FROM chat_attachment_recipients')) {
      return {
        n: this.db.recipients.get(String(this.values[0]))?.size ?? 0,
      } as T;
    }
    return null;
  }

  async all<T>(): Promise<{ results: T[] }> {
    if (this.sql.includes('SELECT recipient_cid_number FROM chat_attachment_recipients')) {
      const values = [...(this.db.recipients.get(String(this.values[0])) ?? [])]
        .sort()
        .map((recipient_cid_number) => ({ recipient_cid_number }));
      return { results: values as T[] };
    }
    return { results: [] };
  }

  async run(): Promise<{ meta: { changes: number } }> {
    if (this.sql.startsWith('INSERT INTO chat_attachments')) {
      const row: AttachmentRow = {
        attachment_id: String(this.values[0]),
        sender_cid_number: String(this.values[1]),
        object_key: String(this.values[3]),
        cipher_byte_size: Number(this.values[4]),
        cipher_sha256: String(this.values[5]),
        multipart_upload_id: String(this.values[6]),
        part_count: Number(this.values[7]),
        upload_state: 'uploading',
        expires_at: Number(this.values[9]),
      };
      this.db.attachments.set(row.attachment_id, row);
      return { meta: { changes: 1 } };
    }
    if (this.sql.startsWith('INSERT INTO chat_attachment_recipients')) {
      const attachmentId = String(this.values[0]);
      const recipients = this.db.recipients.get(attachmentId) ?? new Set<string>();
      recipients.add(String(this.values[1]));
      this.db.recipients.set(attachmentId, recipients);
      return { meta: { changes: 1 } };
    }
    if (this.sql.startsWith('UPDATE chat_attachments SET upload_state')) {
      const row = this.db.attachments.get(String(this.values[0]));
      if (row) row.upload_state = 'ready';
      return { meta: { changes: row ? 1 : 0 } };
    }
    if (this.sql.startsWith('DELETE FROM chat_attachment_recipients')) {
      const recipients = this.db.recipients.get(String(this.values[0]));
      const changed = recipients?.delete(String(this.values[1])) ? 1 : 0;
      return { meta: { changes: changed } };
    }
    if (this.sql.startsWith('DELETE FROM chat_attachments')) {
      const attachmentId = String(this.values[0]);
      const changed = this.db.attachments.delete(attachmentId) ? 1 : 0;
      this.db.recipients.delete(attachmentId);
      return { meta: { changes: changed } };
    }
    return { meta: { changes: 1 } };
  }
}

class SessionKv {
  constructor(private readonly cidNumber: string) {}

  async get<T>(): Promise<T> {
    return {
      cid_number: this.cidNumber,
      binding_revision: 1,
      account_id: ACCOUNT_ID,
      device_key_hash: 'device-key-hash',
      created_at: Date.now(),
      expires_at: Date.now() + 60_000,
    } as T;
  }
}

class PrivateBucket {
  readonly deleted: string[] = [];

  async head(): Promise<{ size: number }> {
    return { size: 4 };
  }

  async delete(key: string): Promise<void> {
    this.deleted.push(key);
  }
}

function envFor(
  cidNumber: string,
  db: AttachmentDb,
  bucket: PrivateBucket,
): Env {
  return {
    DB: db as unknown as D1Database,
    SQUARE_CACHE: new SessionKv(cidNumber) as unknown as KVNamespace,
    SQUARE_PRIVATE: bucket as unknown as R2Bucket,
    CF_ACCOUNT_ID: 'account-id',
    R2_KEY: 'access-key',
    R2_SECRET: 'secret-key',
    SQUARE_PRIVATE_BUCKET_NAME: 'citizenapp-private',
  } as Env;
}

function request(path: string, body: Record<string, unknown>): Request {
  return new Request(`https://worker.test${path}`, {
    method: 'POST',
    headers: {
      authorization: 'Bearer test-session',
      'content-type': 'application/json',
    },
    body: JSON.stringify(body),
  });
}

afterEach(() => vi.unstubAllGlobals());

describe('encrypted chat attachments', () => {
  it('accepts canonical CID values and rejects malformed recipient CID', async () => {
    const db = new AttachmentDb();
    const bucket = new PrivateBucket();
    vi.stubGlobal('fetch', vi.fn(async () =>
      new Response('<UploadId>upload-1</UploadId>', { status: 200 })));

    const response = await prepareChatAttachment(
      request('/chat/attachments/prepare', {
        attachment_id: 'att-canonical-0001',
        recipient_cid_numbers: [BOB],
        cipher_byte_size: 4,
        cipher_sha256: SHA256,
      }),
      envFor(ALICE, db, bucket),
    );
    expect(response.status).toBe(200);
    expect(db.recipients.get('att-canonical-0001')).toEqual(new Set([BOB]));

    await expect(prepareChatAttachment(
      request('/chat/attachments/prepare', {
        attachment_id: 'att-invalid-cid-0001',
        recipient_cid_numbers: ['123456'],
        cipher_byte_size: 4,
        cipher_sha256: SHA256,
      }),
      envFor(ALICE, db, bucket),
    )).rejects.toThrow();
  });

  it('uploads one group ciphertext and deletes it only after the last recipient ACK', async () => {
    const db = new AttachmentDb();
    const bucket = new PrivateBucket();
    vi.stubGlobal('fetch', vi.fn(async (input: RequestInfo | URL) => {
      const url = new URL(input instanceof Request ? input.url : input.toString());
      if (url.searchParams.has('uploads')) {
        return new Response('<UploadId>upload-group</UploadId>', { status: 200 });
      }
      return new Response('', { status: 200 });
    }));

    const senderEnv = envFor(ALICE, db, bucket);
    const prepared = await prepareChatAttachment(
      request('/chat/attachments/prepare', {
        attachment_id: 'att-group-cloud-0001',
        recipient_cid_numbers: [BOB, CAROL],
        cipher_byte_size: 4,
        cipher_sha256: SHA256,
      }),
      senderEnv,
    );
    const plan = await prepared.json() as { parts: unknown[]; expires_at: number };
    expect(plan.parts).toHaveLength(1);
    expect(plan.expires_at).toBeGreaterThan(Date.now() + 6 * 24 * 60 * 60 * 1000);
    expect(db.attachments.size).toBe(1);
    expect(db.recipients.get('att-group-cloud-0001')).toEqual(new Set([BOB, CAROL]));

    await completeChatAttachment(
      request('/chat/attachments/complete', {
        attachment_id: 'att-group-cloud-0001',
        etags: ['etag-part-0001'],
      }),
      senderEnv,
    );

    await acknowledgeChatAttachment(
      request('/chat/attachments/ack', { attachment_id: 'att-group-cloud-0001' }),
      envFor(BOB, db, bucket),
    );
    expect(db.attachments.has('att-group-cloud-0001')).toBe(true);
    expect(bucket.deleted).toEqual([]);

    await acknowledgeChatAttachment(
      request('/chat/attachments/ack', { attachment_id: 'att-group-cloud-0001' }),
      envFor(CAROL, db, bucket),
    );
    expect(db.attachments.has('att-group-cloud-0001')).toBe(false);
    expect(bucket.deleted).toEqual([
      `chat/${ALICE}/att-group-cloud-0001.cipher`,
    ]);
  });
});
