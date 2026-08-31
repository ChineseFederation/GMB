import { describe, expect, it } from 'vitest';
import { issueChatServerAccess } from '../src/auth/chatserver_access';
import type { Env, MembershipRow, SessionState } from '../src/types';

const CID_NUMBER = 'CN220-CTZN2-198805200-2026';
const ACCOUNT_ID = `0x${'1'.repeat(64)}`;

class AccessStatement {
  constructor(private readonly membership: MembershipRow | null) {}
  bind(): AccessStatement {
    return this;
  }
  async first<T>(): Promise<T | null> {
    return this.membership as T | null;
  }
}

function activeMembership(overrides: Partial<MembershipRow> = {}): MembershipRow {
  return {
    cid_number: CID_NUMBER,
    account_id: ACCOUNT_ID,
    membership_level: 'freedom',
    started_at: Date.now() - 1000,
    last_charged_at: Date.now() - 1000,
    last_charged_price_fen: 100,
    paid_until: Date.now() + 86400000,
    subscription_status: 'active',
    finalized_block_number: 1,
    finalized_block_hash: `0x${'2'.repeat(64)}`,
    verified_at: Date.now(),
    entitlement_lapsed_at: null,
    last_tx_hash: `0x${'3'.repeat(64)}`,
    ...overrides,
  };
}

async function privateKeyPem(key: CryptoKey): Promise<string> {
  const bytes = new Uint8Array(await crypto.subtle.exportKey('pkcs8', key));
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  const encoded = btoa(binary).match(/.{1,64}/g)?.join('\n') ?? '';
  return `-----BEGIN PRIVATE KEY-----\n${encoded}\n-----END PRIVATE KEY-----`;
}

function decodeBase64Url(value: string): Uint8Array {
  const normalized = value.replace(/-/g, '+').replace(/_/g, '/');
  const binary = atob(normalized.padEnd(Math.ceil(normalized.length / 4) * 4, '='));
  return Uint8Array.from(binary, (character) => character.charCodeAt(0));
}

function bufferSource(bytes: Uint8Array): ArrayBuffer {
  const copy = new Uint8Array(bytes.byteLength);
  copy.set(bytes);
  return copy.buffer;
}

async function setup(membership: MembershipRow | null) {
  const session: SessionState = {
    cid_number: CID_NUMBER,
    binding_revision: 1,
    account_id: ACCOUNT_ID,
    device_key_hash: 'a'.repeat(64),
    created_at: Date.now(),
    expires_at: Date.now() + 60000,
  };
  const keys = await crypto.subtle.generateKey(
    { name: 'Ed25519' },
    true,
    ['sign', 'verify'],
  ) as CryptoKeyPair;
  const env = {
    DB: {
      prepare: () => new AccessStatement(membership),
    },
    SQUARE_CACHE: {
      get: async () => session,
    },
    CHAT_AUTH_ED25519_PRIVATE_KEY: await privateKeyPem(keys.privateKey),
    CHAT_SERVER_URL: 'https://chat.example.test',
    WEB_ORIGIN: 'https://www.crcfrcn.com',
  } as unknown as Env;
  const body = JSON.stringify({ device_id: 'chat-device-a' });
  const request = new Request('https://worker.test/api/auth/chatserver/access', {
    method: 'POST',
    headers: {
      authorization: 'Bearer session-token',
      'content-type': 'application/json',
      'content-length': `${new TextEncoder().encode(body).byteLength}`,
    },
    body,
  });
  return { env, request, publicKey: keys.publicKey };
}

describe('ChatServer short-lived access', () => {
  it('signs only neutral identity and entitlement claims with EdDSA', async () => {
    const { env, request, publicKey } = await setup(activeMembership());
    const response = await issueChatServerAccess(request, env);
    const payload = await response.json() as Record<string, unknown>;
    expect(payload.ok).toBe(true);
    expect(payload.chat_server_url).toBe('https://chat.example.test');

    const token = payload.chat_server_token as string;
    const [headerPart, claimsPart, signaturePart] = token.split('.');
    expect(JSON.parse(new TextDecoder().decode(decodeBase64Url(headerPart)))).toEqual({
      alg: 'EdDSA',
      typ: 'JWT',
    });
    const claims = JSON.parse(
      new TextDecoder().decode(decodeBase64Url(claimsPart)),
    ) as Record<string, unknown>;
    expect(claims).toMatchObject({
      sub: CID_NUMBER,
      device_id: 'chat-device-a',
      chat_enabled: true,
      max_attachment_bytes: 10 * 1024 * 1024,
      iss: 'https://www.crcfrcn.com',
      aud: 'chatserver',
    });
    expect(claims).not.toHaveProperty('account_id');
    expect(claims).not.toHaveProperty('session_token');
    expect(
      await crypto.subtle.verify(
        { name: 'Ed25519' },
        publicKey,
        bufferSource(decodeBase64Url(signaturePart)),
        new TextEncoder().encode(`${headerPart}.${claimsPart}`),
      ),
    ).toBe(true);
  });

  it('rejects a user without an active finalized membership projection', async () => {
    const { env, request } = await setup(
      activeMembership({ subscription_status: 'inactive' }),
    );
    await expect(issueChatServerAccess(request, env)).rejects.toMatchObject({
      status: 403,
      code: 'chat_membership_required',
    });
  });

  it('rejects a cleartext ChatServer deployment URL', async () => {
    const { env, request } = await setup(activeMembership());
    env.CHAT_SERVER_URL = 'http://chat.example.test';
    await expect(issueChatServerAccess(request, env)).rejects.toMatchObject({
      status: 503,
      code: 'chat_server_not_configured',
    });
  });
});
