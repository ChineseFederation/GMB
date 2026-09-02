import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const root = new URL('../', import.meta.url);
const source = [
  readFileSync(new URL('product.json', root), 'utf8'),
  readFileSync(new URL('wrangler.jsonc', root), 'utf8'),
].join('\n');
const wrangler = JSON.parse(readFileSync(new URL('wrangler.jsonc', root), 'utf8'));

test('CitizenChatServer 只声明 HTTPS、WSS 与准确双端应用身份', () => {
  assert.equal(source.includes(['http', '://'].join('')), false);
  assert.equal(source.includes(['ws', '://'].join('')), false);
  assert.equal(source.includes('/v' + '1'), false);
  assert.equal(wrangler.workers_dev, false);
  assert.equal(wrangler.preview_urls, false);
  assert.equal(wrangler.vars.TATACHATSERVER_IOS_APP_ID, 'ios.citizenapp');
  assert.equal(
    wrangler.vars.TATACHATSERVER_ANDROID_APP_ID,
    'com.crcfrcn.citizenapp',
  );
  assert.equal(wrangler.vars.TATACHATSERVER_AUTH_AUDIENCE, 'citizenchatserver');
  assert.equal(
    wrangler.vars.TATACHATSERVER_AUTH_ISSUER,
    'https://www.crcfrcn.com',
  );
});

test('生产资源编号与授权密钥不得写入产品声明', () => {
  assert.equal(source.includes('database_id'), false);
  assert.equal(source.includes('AUTH_ED25519_PUBLIC_KEY'), false);
  assert.equal(source.includes('PRIVATE_KEY'), false);
  assert.equal(source.includes('SERVICE_ACCOUNT'), false);
});
