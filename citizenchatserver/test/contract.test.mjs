import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import test from 'node:test';

const root = new URL('../', import.meta.url);
const product = JSON.parse(readFileSync(new URL('product.json', root), 'utf8'));
const wrangler = JSON.parse(readFileSync(new URL('wrangler.jsonc', root), 'utf8'));

test('CitizenChatServer 是 TataChatServer 的独立 Cloudflare 实例', () => {
  assert.deepEqual(product, {
    product_id: 'citizenchatserver',
    source_repository: 'VoyagerRhett/TATA',
    source_product_id: 'tatachatserver',
    platform: 'cloudflare',
    public_url: 'https://chat.crcfrcn.com',
    realtime_url: 'wss://chat.crcfrcn.com/realtime',
  });
  assert.equal(wrangler.name, 'citizenchatserver');
  assert.deepEqual(wrangler.routes, [
    { pattern: 'chat.crcfrcn.com', custom_domain: true },
  ]);
  assert.equal(wrangler.d1_databases[0].database_name, 'citizenchatserver-db');
  assert.equal(wrangler.r2_buckets[0].bucket_name, 'citizenchatserver-attachments');
});

test('宿主目录不复制通用服务源码或构建产物', () => {
  for (const name of ['Cargo.toml', 'src', 'worker.mjs', 'build', 'target']) {
    assert.equal(existsSync(new URL(name, root)), false, `${name} 不得进入宿主源码根`);
  }
});
