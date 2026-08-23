import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { Miniflare } from 'miniflare';

import { createUserFromFinalizedRegistration } from '../src/account/user_repository';
import type { ChainSubscriptionState } from '../src/chain/subscription';
import {
  reconcileFinalizedMembershipProjection,
  type MembershipProjectionDeps,
} from '../src/membership/projection';
import { bytesToHex, concatBytes, scaleCompact, u64Le } from '../src/shared/signing_message';
import type { Env } from '../src/types';

const SUBSCRIBER = 'CN220-CTZN2-100000001-2026';
const CREATOR = 'CN220-CTZN2-100000002-2026';
const SUBSCRIBER_ACCOUNT = `0x${'11'.repeat(32)}`;
const CREATOR_ACCOUNT = `0x${'22'.repeat(32)}`;
const GENESIS = `0x${'00'.repeat(32)}`;
const BLOCK = `0x${'01'.repeat(32)}`;
const SCHEMA_SQL = readFileSync(resolve(process.cwd(), 'schema/citizenserve.sql'), 'utf8');

let miniflare: Miniflare;
let env: Env;

describe('SquarePost finalized 用户关联投影', () => {
  beforeEach(async () => {
    miniflare = new Miniflare({
      modules: true,
      script: 'export default { fetch() { return new Response("test"); } }',
      compatibilityDate: '2026-07-29',
      d1Databases: ['DB'],
      bindings: {
        CHAIN_URL: 'https://chain.test',
        CHAIN_ID: 'id',
        CHAIN_SECRET: 'secret',
      },
    });
    env = await miniflare.getBindings<Env>();
    await applySchema(env);
    await createUserFromFinalizedRegistration(env, registration(SUBSCRIBER, SUBSCRIBER_ACCOUNT));
    await createUserFromFinalizedRegistration(env, registration(CREATOR, CREATOR_ACCOUNT));
  });

  afterEach(async () => miniflare.dispose());

  it('从空投影重建平台会员、创作者档位和创作者订阅并推进游标', async () => {
    const result = await reconcileFinalizedMembershipProjection(env, deps());
    expect(result).toMatchObject({
      processed_block_count: 1,
      projected_membership_count: 1,
      projected_creator_plan_count: 1,
      projected_creator_subscription_count: 1,
      cursor_block_number: 1,
    });
    expect(await count('square_memberships')).toBe(1);
    expect(await env.DB.prepare(
      'SELECT tier_name FROM square_creator_tiers WHERE creator_cid_number = ?',
    ).bind(CREATOR).first()).toEqual({ tier_name: '支持者' });
    expect(await count('square_creator_subscriptions')).toBe(1);
  });

  it('不存在用户时外键拒绝孤立投影，删除用户级联清理全部关系', async () => {
    await reconcileFinalizedMembershipProjection(env, deps());
    await env.DB.prepare('DELETE FROM users WHERE cid_number = ?').bind(CREATOR).run();
    expect(await count('square_creator_tiers')).toBe(0);
    expect(await count('square_creator_subscriptions')).toBe(0);
    await expect(env.DB.prepare(
      `INSERT INTO square_creator_tiers
        (creator_cid_number, creator_account_id, tier_id, tier_name, tier_order,
         finalized_block_number, finalized_block_hash, verified_at, last_tx_hash)
        VALUES (?, ?, 'x', '名称', 0, 1, ?, 1, NULL)`,
    ).bind(CREATOR, CREATOR_ACCOUNT, BLOCK).run()).rejects.toThrow();
  });
});

function deps(): MembershipProjectionDeps {
  return {
    fetchFinalizedHead: async () => BLOCK,
    fetchBlockHeader: async (_env, hash) => ({
      number: hash === GENESIS ? '0x0' : '0x1',
      parentHash: GENESIS,
      stateRoot: GENESIS,
      extrinsicsRoot: GENESIS,
    }),
    fetchCanonicalBlockHash: async (_env, number) => number === 0 ? GENESIS : BLOCK,
    fetchSystemEventsAtBlock: async () => projectionEvents(),
    readChainTimestampAtBlock: async () => 1_500,
    readSubscriptionsAtBlock: async (_env, requests) => requests.map(({ issuer }) =>
      issuer.kind === 'platform' ? platformState() : creatorState()),
    readCreatorPlansBatchAtBlock: async (_env, creatorCidNumbers) =>
      creatorCidNumbers.map(() => [{
        tierId: 'supporter',
        tierName: '支持者',
        pricesFen: { monthly: 50n },
      }]),
  };
}

function platformState(): ChainSubscriptionState {
  return {
    plan: { kind: 'platform', membershipLevel: 'freedom' },
    startedAt: 1_000,
    lastChargedAt: 1_000,
    lastChargedPriceFen: 100n,
    paidUntil: 2_000,
    status: 'active',
    authorizedPriceFen: 100n,
    suspendReason: null,
  };
}

function creatorState(): ChainSubscriptionState {
  return {
    plan: { kind: 'creator', tierId: 'supporter', billingPeriod: 'monthly' },
    startedAt: 1_000,
    lastChargedAt: 1_000,
    lastChargedPriceFen: 50n,
    paidUntil: 2_000,
    status: 'active',
    authorizedPriceFen: 50n,
    suspendReason: null,
  };
}

function projectionEvents(): string {
  return systemEvents([
    eventRecord(1, concatBytes(
      cid(SUBSCRIBER), account(SUBSCRIBER_ACCOUNT), new Uint8Array([0, 0, 0]),
      u128Le(100n), u64Le(1_000), u64Le(2_000),
    )),
    eventRecord(1, concatBytes(
      cid(SUBSCRIBER), account(SUBSCRIBER_ACCOUNT), new Uint8Array([1]), cid(CREATOR),
      new Uint8Array([1]), scaleBytes('supporter'), new Uint8Array([0]),
      u128Le(50n), u64Le(1_000), u64Le(2_000),
    )),
    eventRecord(9, concatBytes(cid(CREATOR), account(CREATOR_ACCOUNT), u32Le(1))),
  ]);
}

function registration(cidNumber: string, accountId: string) {
  return {
    cid_number: cidNumber,
    account_id: accountId,
    binding_revision: 1,
    identity_level: 'visitor' as const,
    registration_finalized_block_number: 1,
    registration_finalized_block_hash: BLOCK,
    binding_finalized_block_number: 1,
    binding_finalized_block_hash: BLOCK,
    identity_finalized_block_number: 1,
    identity_finalized_block_hash: BLOCK,
    registered_at: 1_000,
    binding_updated_at: 1_000,
    identity_updated_at: 1_000,
  };
}

async function applySchema(target: Env): Promise<void> {
  const statements = SCHEMA_SQL
    .split('\n')
    .filter((line) => !line.trimStart().startsWith('--'))
    .join('\n')
    .split(';')
    .map((value) => value.trim())
    .filter(Boolean);
  for (const statement of statements) {
    await target.DB.prepare(statement).run();
  }
}

async function count(table: string): Promise<number> {
  const row = await env.DB.prepare(`SELECT COUNT(*) AS count FROM ${table}`).first<{ count: number }>();
  return Number(row?.count ?? 0);
}

function systemEvents(records: Uint8Array[]): string {
  return `0x${bytesToHex(concatBytes(scaleCompact(records.length), ...records))}`;
}

function eventRecord(index: number, payload: Uint8Array): Uint8Array {
  return concatBytes(new Uint8Array([0]), u32Le(0), new Uint8Array([34, index]), payload, new Uint8Array([0]));
}

function cid(value: string): Uint8Array { return scaleBytes(value); }
function scaleBytes(value: string): Uint8Array {
  const bytes = new TextEncoder().encode(value);
  return concatBytes(scaleCompact(bytes.length), bytes);
}
function account(value: string): Uint8Array {
  return Uint8Array.from(value.slice(2).match(/../g)!.map((byte) => Number.parseInt(byte, 16)));
}
function u32Le(value: number): Uint8Array {
  const out = new Uint8Array(4);
  new DataView(out.buffer).setUint32(0, value, true);
  return out;
}
function u128Le(value: bigint): Uint8Array {
  const out = new Uint8Array(16);
  for (let index = 0; index < 16; index += 1) {
    out[index] = Number(value & 0xffn);
    value >>= 8n;
  }
  return out;
}
