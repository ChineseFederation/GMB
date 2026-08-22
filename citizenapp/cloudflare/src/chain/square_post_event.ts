import { assertCidNumber } from '../shared/ids';
import { hexToBytes } from '../shared/signing_message';

// SquarePost 是 runtime 官方 pallet index 34；事件索引严格按当前 Event 声明顺序。
const SQUARE_POST_PALLET_INDEX = 34;

export type SquarePostProjectionEventName =
  | 'SubscriptionCharged'
  | 'SubscriptionResumed'
  | 'SubscriptionSuspended'
  | 'SubscriptionReconsented'
  | 'SubscriptionIssuerPaused'
  | 'SubscriptionRenewalStopped'
  | 'SubscriptionCancelled'
  | 'SubscriptionPlanChanged'
  | 'CreatorPlansSet'
  | 'CreatorTierNameUpdated';

export interface SquarePostProjectionEvent {
  event_name: SquarePostProjectionEventName;
  subscriber_cid_number: string | null;
  creator_cid_number: string | null;
  extrinsic_index: number | null;
  record_offset: number;
}

interface EventPayload {
  event_name: SquarePostProjectionEventName;
  subscriber_cid_number: string | null;
  creator_cid_number: string | null;
  next_offset: number;
}

/// 从 System.Events 严格识别 SquarePost 订阅事件。事件只发现候选关系；投影器必须再读取
/// 同一 finalized 区块的 storage，事件载荷不能直接成为业务真源。
export function decodeSquarePostProjectionEvents(eventsHex: string): SquarePostProjectionEvent[] {
  const data = hexToBytes(eventsHex);
  if (data.length === 0) return [];
  const [eventCount, countSize] = readCompactU32(data, 0);
  if (eventCount === 0) return [];
  const events: SquarePostProjectionEvent[] = [];

  for (let recordOffset = countSize; recordOffset < data.length; recordOffset += 1) {
    try {
      let offset = recordOffset;
      const phase = data[offset++];
      let extrinsicIndex: number | null = null;
      if (phase === 0) {
        extrinsicIndex = readU32Le(data, offset);
        offset += 4;
      } else if (phase !== 1 && phase !== 2) {
        continue;
      }
      if (offset + 2 > data.length || data[offset] !== SQUARE_POST_PALLET_INDEX) continue;
      const eventIndex = data[offset + 1];
      offset += 2;
      const payload = decodePayload(data, offset, eventIndex);
      if (!payload || !hasValidTopics(data, payload.next_offset)) continue;
      events.push({
        event_name: payload.event_name,
        subscriber_cid_number: payload.subscriber_cid_number,
        creator_cid_number: payload.creator_cid_number,
        extrinsic_index: extrinsicIndex,
        record_offset: recordOffset,
      });
    } catch {
      // System.Events 混有其它 pallet 载荷；当前偏移不是目标记录时继续扫描。
    }
  }
  const unique = new Map<string, SquarePostProjectionEvent>();
  for (const event of events) {
    unique.set([
      event.record_offset,
      event.event_name,
      event.subscriber_cid_number,
      event.creator_cid_number,
    ].join(':'), event);
  }
  return [...unique.values()].sort((left, right) => left.record_offset - right.record_offset);
}

function decodePayload(data: Uint8Array, offset: number, eventIndex: number): EventPayload | null {
  if (eventIndex >= 1 && eventIndex <= 8) {
    return decodeSubscriptionEvent(data, offset, eventIndex);
  }
  if (eventIndex === 9 || eventIndex === 10) {
    const creator = readCidNumber(data, offset);
    let next = creator.next_offset + 32;
    requireBytes(data, creator.next_offset, 32);
    if (eventIndex === 9) {
      requireBytes(data, next, 4);
      next += 4;
    } else {
      next = readCompactBytes(data, next, 32).next_offset;
    }
    return {
      event_name: eventIndex === 9 ? 'CreatorPlansSet' : 'CreatorTierNameUpdated',
      subscriber_cid_number: null,
      creator_cid_number: creator.value,
      next_offset: next,
    };
  }
  return null;
}

function decodeSubscriptionEvent(
  data: Uint8Array,
  offset: number,
  eventIndex: number,
): EventPayload {
  const subscriber = readCidNumber(data, offset);
  let next = subscriber.next_offset;
  if (eventIndex === 1 || eventIndex === 8) {
    requireBytes(data, next, 32);
    next += 32;
  }
  const issuer = readIssuer(data, next);
  next = issuer.next_offset;

  switch (eventIndex) {
    case 1:
      next = readPlan(data, next);
      requireBytes(data, next, 16 + 8 + 8);
      next += 32;
      break;
    case 2:
    case 5:
    case 6:
    case 7:
      requireBytes(data, next, 8);
      next += 8;
      break;
    case 3:
      requireBytes(data, next, 1 + 8);
      if (data[next] > 2) throw new RangeError('invalid suspend reason');
      next += 9;
      break;
    case 4:
      requireBytes(data, next, 16);
      next += 16;
      break;
    case 8:
      next = readPlan(data, next);
      requireBytes(data, next, 16 + 8);
      next += 24;
      break;
    default:
      throw new RangeError('unsupported subscription event');
  }

  return {
    event_name: EVENT_NAMES[eventIndex],
    subscriber_cid_number: subscriber.value,
    creator_cid_number: issuer.creator_cid_number,
    next_offset: next,
  };
}

const EVENT_NAMES: Record<number, SquarePostProjectionEventName> = {
  1: 'SubscriptionCharged',
  2: 'SubscriptionResumed',
  3: 'SubscriptionSuspended',
  4: 'SubscriptionReconsented',
  5: 'SubscriptionIssuerPaused',
  6: 'SubscriptionRenewalStopped',
  7: 'SubscriptionCancelled',
  8: 'SubscriptionPlanChanged',
};

function readIssuer(
  data: Uint8Array,
  offset: number,
): { creator_cid_number: string | null; next_offset: number } {
  requireBytes(data, offset, 1);
  const tag = data[offset++];
  if (tag === 0) return { creator_cid_number: null, next_offset: offset };
  if (tag !== 1) throw new RangeError('invalid issuer');
  const creator = readCidNumber(data, offset);
  return { creator_cid_number: creator.value, next_offset: creator.next_offset };
}

function readPlan(data: Uint8Array, offset: number): number {
  requireBytes(data, offset, 1);
  const tag = data[offset++];
  if (tag === 0) {
    requireBytes(data, offset, 1);
    if (data[offset] > 2) throw new RangeError('invalid membership level');
    return offset + 1;
  }
  if (tag !== 1) throw new RangeError('invalid subscription plan');
  const tier = readCompactBytes(data, offset, 32);
  requireBytes(data, tier.next_offset, 1);
  if (data[tier.next_offset] > 2) throw new RangeError('invalid billing period');
  return tier.next_offset + 1;
}

function readCidNumber(
  data: Uint8Array,
  offset: number,
): { value: string; next_offset: number } {
  const bytes = readCompactBytes(data, offset, 32);
  const value = new TextDecoder('utf-8', { fatal: true }).decode(bytes.value);
  return { value: assertCidNumber(value), next_offset: bytes.next_offset };
}

function readCompactBytes(
  data: Uint8Array,
  offset: number,
  maxLength: number,
): { value: Uint8Array; next_offset: number } {
  const [length, size] = readCompactU32(data, offset);
  const start = offset + size;
  const end = start + length;
  if (length === 0 || length > maxLength || end > data.length) {
    throw new RangeError('bounded event bytes are invalid');
  }
  return { value: data.slice(start, end), next_offset: end };
}

function hasValidTopics(data: Uint8Array, offset: number): boolean {
  try {
    const [count, size] = readCompactU32(data, offset);
    return offset + size + count * 32 <= data.length;
  } catch {
    return false;
  }
}

function readCompactU32(data: Uint8Array, offset: number): [number, number] {
  if (offset >= data.length) throw new RangeError('compact value is missing');
  const first = data[offset];
  const mode = first & 3;
  if (mode === 0) return [first >> 2, 1];
  if (mode === 1) {
    requireBytes(data, offset, 2);
    return [(first >> 2) | (data[offset + 1] << 6), 2];
  }
  if (mode === 2) {
    requireBytes(data, offset, 4);
    return [
      (first >> 2)
        | (data[offset + 1] << 6)
        | (data[offset + 2] << 14)
        | (data[offset + 3] << 22),
      4,
    ];
  }
  throw new RangeError('compact big integer mode is unsupported');
}

function readU32Le(data: Uint8Array, offset: number): number {
  requireBytes(data, offset, 4);
  return new DataView(data.buffer, data.byteOffset + offset, 4).getUint32(0, true);
}

function requireBytes(data: Uint8Array, offset: number, length: number): void {
  if (offset < 0 || length < 0 || offset + length > data.length) {
    throw new RangeError('event payload is truncated');
  }
}
