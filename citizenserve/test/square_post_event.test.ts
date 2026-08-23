import { describe, expect, it } from 'vitest';

import { decodeSquarePostProjectionEvents } from '../src/chain/square_post_event';
import { bytesToHex, concatBytes, scaleCompact, u64Le } from '../src/shared/signing_message';

const SUBSCRIBER = 'CN220-CTZN2-100000001-2026';
const CREATOR = 'CN220-CTZN2-100000002-2026';

describe('SquarePost 官方事件解码', () => {
  it('严格发现平台订阅、创作者订阅、计划设置和单独改名候选', () => {
    const events = decodeSquarePostProjectionEvents(systemEvents([
      eventRecord(1, concatBytes(
        cid(SUBSCRIBER),
        new Uint8Array(32).fill(1),
        new Uint8Array([0]),
        new Uint8Array([0, 2]),
        u128Le(100n),
        u64Le(1_000),
        u64Le(2_000),
      )),
      eventRecord(1, concatBytes(
        cid(SUBSCRIBER),
        new Uint8Array(32).fill(1),
        new Uint8Array([1]),
        cid(CREATOR),
        new Uint8Array([1]),
        scaleBytes('supporter'),
        new Uint8Array([0]),
        u128Le(50n),
        u64Le(1_000),
        u64Le(2_000),
      )),
      eventRecord(9, concatBytes(
        cid(CREATOR),
        new Uint8Array(32).fill(2),
        u32Le(1),
      )),
      eventRecord(10, concatBytes(
        cid(CREATOR),
        new Uint8Array(32).fill(2),
        scaleBytes('supporter'),
      )),
    ]));

    expect(events.map((event) => event.event_name)).toEqual([
      'SubscriptionCharged',
      'SubscriptionCharged',
      'CreatorPlansSet',
      'CreatorTierNameUpdated',
    ]);
    expect(events[0]).toMatchObject({
      subscriber_cid_number: SUBSCRIBER,
      creator_cid_number: null,
    });
    expect(events[1]).toMatchObject({
      subscriber_cid_number: SUBSCRIBER,
      creator_cid_number: CREATOR,
    });
  });

  it('截断、非法枚举和其它 pallet 事件不得产生候选', () => {
    const malformed = systemEvents([
      eventRecord(3, concatBytes(cid(SUBSCRIBER), new Uint8Array([0, 9]))),
      Uint8Array.from([0, 0, 0, 0, 0, 10, 0, 0]),
    ]);
    expect(decodeSquarePostProjectionEvents(malformed)).toEqual([]);
  });
});

function systemEvents(records: Uint8Array[]): string {
  return `0x${bytesToHex(concatBytes(scaleCompact(records.length), ...records))}`;
}

function eventRecord(eventIndex: number, payload: Uint8Array): Uint8Array {
  return concatBytes(
    new Uint8Array([0]),
    u32Le(0),
    new Uint8Array([34, eventIndex]),
    payload,
    new Uint8Array([0]),
  );
}

function cid(value: string): Uint8Array {
  return scaleBytes(value);
}

function scaleBytes(value: string): Uint8Array {
  const bytes = new TextEncoder().encode(value);
  return concatBytes(scaleCompact(bytes.length), bytes);
}

function u32Le(value: number): Uint8Array {
  const out = new Uint8Array(4);
  new DataView(out.buffer).setUint32(0, value, true);
  return out;
}

function u128Le(value: bigint): Uint8Array {
  const out = new Uint8Array(16);
  let remaining = value;
  for (let index = 0; index < out.length; index += 1) {
    out[index] = Number(remaining & 0xffn);
    remaining >>= 8n;
  }
  return out;
}
