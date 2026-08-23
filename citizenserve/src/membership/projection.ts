import { readUserByCidNumber } from '../account/user_repository';
import {
  fetchBlockHeader,
  fetchCanonicalBlockHash,
  fetchFinalizedHead,
  fetchSystemEventsAtBlock,
  isChainRpcConfigured,
} from '../chain/rpc';
import { decodeSquarePostProjectionEvents } from '../chain/square_post_event';
import {
  readChainTimestampAtBlock,
  readCreatorPlansBatchAtBlock,
  readSubscriptionsAtBlock,
  updateChainClock,
  type ChainCreatorTier,
} from '../chain/subscription';
import { HttpError } from '../shared/http';
import { nowMs } from '../shared/time';
import type { Env, MembershipProjectionCursorRow } from '../types';
import {
  projectCreatorSubscription,
  replaceCreatorTierProjection,
  type CreatorTierInput,
} from './creator';
import { applyPlatformState, type FinalizedPoint } from './reconcile';

const MEMBERSHIP_PROJECTION_BLOCK_BATCH = 5;

export interface MembershipProjectionDeps {
  fetchFinalizedHead: typeof fetchFinalizedHead;
  fetchBlockHeader: typeof fetchBlockHeader;
  fetchCanonicalBlockHash: typeof fetchCanonicalBlockHash;
  fetchSystemEventsAtBlock: typeof fetchSystemEventsAtBlock;
  readChainTimestampAtBlock: typeof readChainTimestampAtBlock;
  readSubscriptionsAtBlock: typeof readSubscriptionsAtBlock;
  readCreatorPlansBatchAtBlock: typeof readCreatorPlansBatchAtBlock;
}

const defaultDeps: MembershipProjectionDeps = {
  fetchFinalizedHead,
  fetchBlockHeader,
  fetchCanonicalBlockHash,
  fetchSystemEventsAtBlock,
  readChainTimestampAtBlock,
  readSubscriptionsAtBlock,
  readCreatorPlansBatchAtBlock,
};

export interface MembershipProjectionResult {
  enabled: boolean;
  processed_block_count: number;
  projected_membership_count: number;
  projected_creator_plan_count: number;
  projected_creator_subscription_count: number;
  finalized_block_number: number | null;
  cursor_block_number: number | null;
}

/// Cron 专用 finalized 投影。用户投影必须先执行；普通主页、动态和 Chat 不调用本函数。
export async function reconcileFinalizedMembershipProjection(
  env: Env,
  deps: MembershipProjectionDeps = defaultDeps,
): Promise<MembershipProjectionResult> {
  if (!isChainRpcConfigured(env)) return emptyResult();
  const finalizedHash = await deps.fetchFinalizedHead(env);
  const finalizedHeader = await deps.fetchBlockHeader(env, finalizedHash);
  const finalizedNumber = parseBlockNumber(finalizedHeader.number);
  let cursor = await ensureCursor(env, deps);
  if (
    await deps.fetchCanonicalBlockHash(env, cursor.finalized_block_number) !==
    cursor.finalized_block_hash
  ) {
    throw new HttpError(
      409,
      'membership_projection_cursor_not_canonical',
      '订阅投影游标不属于 canonical 主链',
    );
  }

  const lastBlock = Math.min(
    finalizedNumber,
    cursor.finalized_block_number + MEMBERSHIP_PROJECTION_BLOCK_BATCH,
  );
  let processedBlocks = 0;
  let memberships = 0;
  let plans = 0;
  let creatorSubscriptions = 0;
  for (
    let blockNumber = cursor.finalized_block_number + 1;
    blockNumber <= lastBlock;
    blockNumber += 1
  ) {
    const blockHash = await deps.fetchCanonicalBlockHash(env, blockNumber);
    const chainTimestamp = await deps.readChainTimestampAtBlock(env, blockHash);
    const result = await projectBlock(env, blockNumber, blockHash, chainTimestamp, deps);
    cursor = await advanceCursor(env, cursor, blockNumber, blockHash);
    processedBlocks += 1;
    memberships += result.memberships;
    plans += result.plans;
    creatorSubscriptions += result.creatorSubscriptions;
  }
  return {
    enabled: true,
    processed_block_count: processedBlocks,
    projected_membership_count: memberships,
    projected_creator_plan_count: plans,
    projected_creator_subscription_count: creatorSubscriptions,
    finalized_block_number: finalizedNumber,
    cursor_block_number: cursor.finalized_block_number,
  };
}

async function projectBlock(
  env: Env,
  blockNumber: number,
  blockHash: string,
  chainTimestamp: number,
  deps: MembershipProjectionDeps,
): Promise<{ memberships: number; plans: number; creatorSubscriptions: number }> {
  const eventsHex = await deps.fetchSystemEventsAtBlock(env, blockHash);
  const events = decodeSquarePostProjectionEvents(eventsHex);
  const platformCids = new Set<string>();
  const creatorPlans = new Set<string>();
  const creatorSubscriptions = new Map<string, { subscriber: string; creator: string }>();
  for (const event of events) {
    if (event.subscriber_cid_number) {
      if (event.creator_cid_number) {
        creatorSubscriptions.set(
          `${event.subscriber_cid_number}\u0000${event.creator_cid_number}`,
          { subscriber: event.subscriber_cid_number, creator: event.creator_cid_number },
        );
      } else {
        platformCids.add(event.subscriber_cid_number);
      }
    }
    if (
      event.creator_cid_number &&
      (event.event_name === 'CreatorPlansSet' || event.event_name === 'CreatorTierNameUpdated')
    ) {
      creatorPlans.add(event.creator_cid_number);
    }
  }

  const observedAt = nowMs();
  await updateChainClock(env, {
    chainTimestamp,
    blockNumber,
    blockHash,
    observedAt,
  });
  const point: FinalizedPoint = {
    blockHash,
    blockNumber,
    chainTimestamp,
    observedAt,
  };

  const platformCidNumbers = [...platformCids];
  const creatorCidNumbers = [...creatorPlans];
  const creatorRelations = [...creatorSubscriptions.values()];
  const [platformStates, creatorPlanStates, creatorSubscriptionStates] = await Promise.all([
    deps.readSubscriptionsAtBlock(
      env,
      platformCidNumbers.map((subscriberCidNumber) => ({
        subscriberCidNumber,
        issuer: { kind: 'platform' as const },
      })),
      blockHash,
    ),
    deps.readCreatorPlansBatchAtBlock(env, creatorCidNumbers, blockHash),
    deps.readSubscriptionsAtBlock(
      env,
      creatorRelations.map((relation) => ({
        subscriberCidNumber: relation.subscriber,
        issuer: { kind: 'creator' as const, creatorCidNumber: relation.creator },
      })),
      blockHash,
    ),
  ]);

  for (const [index, cidNumber] of platformCidNumbers.entries()) {
    const user = await requireUser(env, cidNumber);
    const state = platformStates[index] ?? null;
    await applyPlatformState(env, cidNumber, user.account_id, state, point);
  }

  for (const [index, creatorCidNumber] of creatorCidNumbers.entries()) {
    const creator = await requireUser(env, creatorCidNumber);
    const chainTiers = creatorPlanStates[index] ?? [];
    await replaceCreatorTierProjection(
      env,
      creatorCidNumber,
      creator.account_id,
      projectionTiers(chainTiers),
      { blockNumber, blockHash, verifiedAt: observedAt, lastTxHash: null },
    );
  }

  for (const [index, relation] of creatorRelations.entries()) {
    const [subscriber, creator] = await Promise.all([
      requireUser(env, relation.subscriber),
      requireUser(env, relation.creator),
    ]);
    const state = creatorSubscriptionStates[index] ?? null;
    if (!state || state.plan.kind !== 'creator') {
      await env.DB.prepare(
        `UPDATE square_creator_subscriptions
          SET subscription_status = 'terminated', finalized_block_number = ?,
              finalized_block_hash = ?, verified_at = ?
          WHERE subscriber_cid_number = ? AND creator_cid_number = ?
            AND finalized_block_number <= ?`,
      ).bind(
        blockNumber,
        blockHash,
        observedAt,
        relation.subscriber,
        relation.creator,
        blockNumber,
      ).run();
      continue;
    }
    await projectCreatorSubscription(
      env,
      relation.subscriber,
      subscriber.account_id,
      relation.creator,
      creator.account_id,
      state,
      { blockNumber, blockHash, verifiedAt: observedAt, lastTxHash: null },
    );
  }
  return {
    memberships: platformCidNumbers.length,
    plans: creatorCidNumbers.length,
    creatorSubscriptions: creatorRelations.length,
  };
}

function projectionTiers(tiers: ChainCreatorTier[]): CreatorTierInput[] {
  // runtime 升级前旧计划没有名称：不得用旧 Cloudflare 名称伪造；保持空投影，等创作者链上补名。
  if (tiers.some((tier) => tier.tierName === null)) return [];
  return tiers.map((tier) => ({
    tier_id: tier.tierId,
    tier_name: tier.tierName!,
    prices_fen: Object.fromEntries(
      (['monthly', 'quarterly', 'yearly'] as const).flatMap((period) => {
        const value = tier.pricesFen[period];
        if (value === undefined) return [];
        if (value <= 0n || value > BigInt(Number.MAX_SAFE_INTEGER)) {
          throw new HttpError(502, 'creator_price_out_of_range', '链上创作者价格超出 D1 范围');
        }
        return [[period, Number(value)]];
      }),
    ),
  }));
}

async function requireUser(env: Env, cidNumber: string) {
  const user = await readUserByCidNumber(env, cidNumber);
  if (!user) {
    throw new HttpError(
      409,
      'membership_projection_user_missing',
      '订阅事件对应用户尚未完成 finalized 投影',
    );
  }
  return user;
}

async function ensureCursor(
  env: Env,
  deps: MembershipProjectionDeps,
): Promise<MembershipProjectionCursorRow> {
  const existing = await readCursor(env);
  if (existing) return existing;
  const genesisHash = await deps.fetchCanonicalBlockHash(env, 0);
  await env.DB.prepare(
    `INSERT OR IGNORE INTO membership_projection_cursor
      (cursor_id, finalized_block_number, finalized_block_hash, updated_at)
      VALUES (1, 0, ?, ?)`,
  ).bind(genesisHash, nowMs()).run();
  const created = await readCursor(env);
  if (!created) throw new Error('membership projection cursor was not created');
  return created;
}

function readCursor(env: Env): Promise<MembershipProjectionCursorRow | null> {
  return env.DB.prepare(
    `SELECT cursor_id, finalized_block_number, finalized_block_hash, updated_at
      FROM membership_projection_cursor WHERE cursor_id = 1`,
  ).first<MembershipProjectionCursorRow>();
}

async function advanceCursor(
  env: Env,
  previous: MembershipProjectionCursorRow,
  blockNumber: number,
  blockHash: string,
): Promise<MembershipProjectionCursorRow> {
  const result = await env.DB.prepare(
    `UPDATE membership_projection_cursor
      SET finalized_block_number = ?, finalized_block_hash = ?, updated_at = ?
      WHERE cursor_id = 1 AND finalized_block_number = ? AND finalized_block_hash = ?`,
  ).bind(
    blockNumber,
    blockHash,
    nowMs(),
    previous.finalized_block_number,
    previous.finalized_block_hash,
  ).run();
  if ((result.meta.changes ?? 0) === 1) {
    const advanced = await readCursor(env);
    if (advanced) return advanced;
  }
  const concurrent = await readCursor(env);
  if (concurrent && concurrent.finalized_block_number >= blockNumber) return concurrent;
  throw new HttpError(409, 'membership_projection_cursor_conflict', '订阅投影游标发生并发冲突');
}

function parseBlockNumber(value: string): number {
  if (!/^0x[0-9a-fA-F]+$/.test(value)) throw new Error('finalized block number invalid');
  const parsed = Number(BigInt(value));
  if (!Number.isSafeInteger(parsed) || parsed < 0) throw new Error('finalized block number out of range');
  return parsed;
}

function emptyResult(): MembershipProjectionResult {
  return {
    enabled: false,
    processed_block_count: 0,
    projected_membership_count: 0,
    projected_creator_plan_count: 0,
    projected_creator_subscription_count: 0,
    finalized_block_number: null,
    cursor_block_number: null,
  };
}
