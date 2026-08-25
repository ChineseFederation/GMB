import { readUserByCidNumber } from '../account/user_repository';
import { decodeSquarePostSubscriptionEvents } from '../chain/square_post_event';
import {
  fetchBlockHeader,
  fetchCanonicalBlockHash,
  fetchFinalizedHead,
  fetchSystemEventsAtBlock,
  isChainRpcConfigured,
} from '../chain/rpc';
import {
  readCreatorPlansBatchAtBlock,
  readSubscriptionsAtBlock,
  type ChainCreatorTier,
  type ChainSubscriptionState,
} from '../chain/subscription';
import { HttpError } from '../shared/http';
import { nowMs } from '../shared/time';
import type { Env, SubscriptionProjectionCursorRow } from '../types';
import { projectPlatformSubscription } from './citizen_coin';
import {
  projectCreatorSubscription,
  replaceCreatorTierProjection,
  type CreatorTierInput,
} from './creator';

const SUBSCRIPTION_PROJECTION_BLOCK_BATCH = 10;

type SubscriptionRelation =
  | { subscriberCidNumber: string; issuer: { kind: 'platform' } }
  | { subscriberCidNumber: string; issuer: { kind: 'creator'; creatorCidNumber: string } };

export interface SubscriptionProjectionDeps {
  fetchFinalizedHead: typeof fetchFinalizedHead;
  fetchBlockHeader: typeof fetchBlockHeader;
  fetchCanonicalBlockHash: typeof fetchCanonicalBlockHash;
  fetchSystemEventsAtBlock: typeof fetchSystemEventsAtBlock;
  readSubscriptionsAtBlock: typeof readSubscriptionsAtBlock;
  readCreatorPlansBatchAtBlock: typeof readCreatorPlansBatchAtBlock;
}

const defaultDeps: SubscriptionProjectionDeps = {
  fetchFinalizedHead,
  fetchBlockHeader,
  fetchCanonicalBlockHash,
  fetchSystemEventsAtBlock,
  readSubscriptionsAtBlock,
  readCreatorPlansBatchAtBlock,
};

export interface SubscriptionProjectionReconcileResult {
  enabled: boolean;
  processed_block_count: number;
  projected_subscription_count: number;
  projected_creator_count: number;
  finalized_block_number: number | null;
  cursor_block_number: number | null;
}

/**
 * 唯一 finalized 订阅投影任务。Worker 通过既有 Access + Tunnel RPC 读取国储会节点；
 * 事件只定位关系，平台会员、创作者订阅和档位均以同区块 storage 为唯一状态真源。
 */
export async function reconcileFinalizedSubscriptionProjection(
  env: Env,
  deps: SubscriptionProjectionDeps = defaultDeps,
): Promise<SubscriptionProjectionReconcileResult> {
  if (!isChainRpcConfigured(env)) {
    return {
      enabled: false,
      processed_block_count: 0,
      projected_subscription_count: 0,
      projected_creator_count: 0,
      finalized_block_number: null,
      cursor_block_number: null,
    };
  }
  const finalizedHash = await deps.fetchFinalizedHead(env);
  const finalizedHeader = await deps.fetchBlockHeader(env, finalizedHash);
  const finalizedNumber = parseBlockNumber(finalizedHeader.number);
  let cursor = await ensureProjectionCursor(env, deps);
  const canonicalCursorHash = await deps.fetchCanonicalBlockHash(env, cursor.finalized_block_number);
  if (canonicalCursorHash !== cursor.finalized_block_hash) {
    throw new HttpError(409, 'subscription_projection_cursor_not_canonical', '订阅投影游标不属于 canonical 主链');
  }
  const lastBlock = Math.min(
    finalizedNumber,
    cursor.finalized_block_number + SUBSCRIPTION_PROJECTION_BLOCK_BATCH,
  );
  let processedBlocks = 0;
  let projectedSubscriptions = 0;
  let projectedCreators = 0;
  for (let blockNumber = cursor.finalized_block_number + 1; blockNumber <= lastBlock; blockNumber += 1) {
    const blockHash = await deps.fetchCanonicalBlockHash(env, blockNumber);
    const result = await projectCanonicalBlock(env, blockNumber, blockHash, deps);
    cursor = await advanceProjectionCursor(env, cursor, blockNumber, blockHash);
    processedBlocks += 1;
    projectedSubscriptions += result.projectedSubscriptions;
    projectedCreators += result.projectedCreators;
  }
  return {
    enabled: true,
    processed_block_count: processedBlocks,
    projected_subscription_count: projectedSubscriptions,
    projected_creator_count: projectedCreators,
    finalized_block_number: finalizedNumber,
    cursor_block_number: cursor.finalized_block_number,
  };
}

async function projectCanonicalBlock(
  env: Env,
  blockNumber: number,
  blockHash: string,
  deps: SubscriptionProjectionDeps,
): Promise<{ projectedSubscriptions: number; projectedCreators: number }> {
  const events = decodeSquarePostSubscriptionEvents(await deps.fetchSystemEventsAtBlock(env, blockHash));
  const relations = new Map<string, SubscriptionRelation>();
  const creatorCidNumbers = new Set<string>();
  for (const event of events) {
    if (event.subscriber_cid_number && event.issuer_kind === 'platform') {
      const relation: SubscriptionRelation = {
        subscriberCidNumber: event.subscriber_cid_number,
        issuer: { kind: 'platform' },
      };
      relations.set(relationKey(relation), relation);
    }
    if (event.subscriber_cid_number && event.issuer_kind === 'creator' && event.creator_cid_number) {
      const relation: SubscriptionRelation = {
        subscriberCidNumber: event.subscriber_cid_number,
        issuer: { kind: 'creator', creatorCidNumber: event.creator_cid_number },
      };
      relations.set(relationKey(relation), relation);
    }
    if (!event.subscriber_cid_number && event.creator_cid_number) {
      creatorCidNumbers.add(event.creator_cid_number);
    }
  }
  const relationList = [...relations.values()];
  const creatorList = [...creatorCidNumbers];
  const [states, creatorPlans] = await Promise.all([
    deps.readSubscriptionsAtBlock(env, relationList, blockHash),
    deps.readCreatorPlansBatchAtBlock(env, creatorList, blockHash),
  ]);
  const point = { blockNumber, blockHash, verifiedAt: nowMs(), lastTxHash: null };

  for (let index = 0; index < relationList.length; index += 1) {
    const relation = relationList[index];
    const state = states[index] ?? null;
    const subscriber = await readUserByCidNumber(env, relation.subscriberCidNumber);
    if (!subscriber) {
      await deleteRelationProjection(env, relation, blockNumber);
      continue;
    }
    if (relation.issuer.kind === 'platform') {
      if (state === null) await deleteRelationProjection(env, relation, blockNumber);
      else {
        assertPlanKind(state, 'platform');
        await projectPlatformSubscription(env, relation.subscriberCidNumber, subscriber.account_id, state, point);
      }
      continue;
    }
    const creator = await readUserByCidNumber(env, relation.issuer.creatorCidNumber);
    if (!creator || state === null) {
      await deleteRelationProjection(env, relation, blockNumber);
      continue;
    }
    assertPlanKind(state, 'creator');
    await projectCreatorSubscription(
      env,
      relation.subscriberCidNumber,
      subscriber.account_id,
      relation.issuer.creatorCidNumber,
      creator.account_id,
      state,
      point,
    );
  }
  for (let index = 0; index < creatorList.length; index += 1) {
    const creatorCidNumber = creatorList[index];
    const creator = await readUserByCidNumber(env, creatorCidNumber);
    if (!creator) continue;
    await replaceCreatorTierProjection(
      env,
      creatorCidNumber,
      creator.account_id,
      projectionTiers(creatorPlans[index] ?? []),
      point,
    );
  }
  return { projectedSubscriptions: relationList.length, projectedCreators: creatorList.length };
}

async function deleteRelationProjection(
  env: Env,
  relation: SubscriptionRelation,
  blockNumber: number,
): Promise<void> {
  if (relation.issuer.kind === 'platform') {
    await env.DB.prepare(
      'DELETE FROM square_memberships WHERE cid_number = ? AND finalized_block_number <= ?',
    ).bind(relation.subscriberCidNumber, blockNumber).run();
    return;
  }
  await env.DB.prepare(
    `DELETE FROM square_creator_subscriptions
      WHERE subscriber_cid_number = ? AND creator_cid_number = ?
        AND finalized_block_number <= ?`,
  ).bind(relation.subscriberCidNumber, relation.issuer.creatorCidNumber, blockNumber).run();
}

function assertPlanKind(state: ChainSubscriptionState, kind: 'platform' | 'creator'): void {
  if (state.plan.kind !== kind) {
    throw new HttpError(502, 'subscription_projection_plan_mismatch', '链上订阅关系与计划类型不一致');
  }
}

function projectionTiers(tiers: ChainCreatorTier[]): CreatorTierInput[] {
  return tiers.map((tier) => {
    if (tier.tierName === null) {
      throw new HttpError(502, 'creator_tier_name_missing', '链上创作者档位名称缺失');
    }
    return {
      tier_id: tier.tierId,
      tier_name: tier.tierName,
      prices_fen: Object.fromEntries(
        Object.entries(tier.pricesFen).map(([period, price]) => [period, safePrice(price)]),
      ),
    };
  });
}

function safePrice(value: bigint): number {
  if (value <= 0n || value > BigInt(Number.MAX_SAFE_INTEGER)) {
    throw new HttpError(502, 'subscription_price_out_of_range', '链上订阅价格超出边缘服务范围');
  }
  return Number(value);
}

function relationKey(relation: SubscriptionRelation): string {
  return relation.issuer.kind === 'platform'
    ? `${relation.subscriberCidNumber}:platform`
    : `${relation.subscriberCidNumber}:creator:${relation.issuer.creatorCidNumber}`;
}

async function ensureProjectionCursor(
  env: Env,
  deps: SubscriptionProjectionDeps,
): Promise<SubscriptionProjectionCursorRow> {
  const existing = await readProjectionCursor(env);
  if (existing) return existing;
  const genesisHash = await deps.fetchCanonicalBlockHash(env, 0);
  await env.DB.prepare(
    `INSERT OR IGNORE INTO membership_projection_cursor
      (cursor_id, finalized_block_number, finalized_block_hash, updated_at)
      VALUES (1, 0, ?, ?)`,
  ).bind(genesisHash, nowMs()).run();
  const created = await readProjectionCursor(env);
  if (!created) throw new Error('订阅投影游标初始化失败');
  return created;
}

async function readProjectionCursor(env: Env): Promise<SubscriptionProjectionCursorRow | null> {
  return env.DB.prepare(
    `SELECT cursor_id, finalized_block_number, finalized_block_hash, updated_at
      FROM membership_projection_cursor WHERE cursor_id = 1`,
  ).first<SubscriptionProjectionCursorRow>();
}

async function advanceProjectionCursor(
  env: Env,
  previous: SubscriptionProjectionCursorRow,
  blockNumber: number,
  blockHash: string,
): Promise<SubscriptionProjectionCursorRow> {
  const updatedAt = nowMs();
  const result = await env.DB.prepare(
    `UPDATE membership_projection_cursor
      SET finalized_block_number = ?, finalized_block_hash = ?, updated_at = ?
      WHERE cursor_id = 1 AND finalized_block_number = ? AND finalized_block_hash = ?`,
  ).bind(
    blockNumber,
    blockHash,
    updatedAt,
    previous.finalized_block_number,
    previous.finalized_block_hash,
  ).run();
  if (result.meta.changes !== 1) {
    throw new HttpError(409, 'subscription_projection_cursor_conflict', '订阅投影游标被并发修改');
  }
  return {
    cursor_id: 1,
    finalized_block_number: blockNumber,
    finalized_block_hash: blockHash,
    updated_at: updatedAt,
  };
}

function parseBlockNumber(value: string): number {
  if (!/^0x[0-9a-fA-F]+$/.test(value)) {
    throw new HttpError(502, 'chain_rpc_invalid_response', '链服务节点返回了无效区块高度');
  }
  const parsed = Number(BigInt(value));
  if (!Number.isSafeInteger(parsed) || parsed < 0) {
    throw new HttpError(502, 'chain_rpc_invalid_response', '链服务节点区块高度超出范围');
  }
  return parsed;
}
