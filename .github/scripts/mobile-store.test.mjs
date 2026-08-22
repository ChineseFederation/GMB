import assert from 'node:assert/strict';
import { mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';
import { createHash } from 'node:crypto';
import { verifyMobileStoreInput } from './mobile-store.mjs';

// 中文注释：夹具只用临时伪资产闭合产品、平台、Tag、源码和 SHA-256 合同，
// 不包含真实商店账号、签名材料或正式 Release 内容。
function fixture(platform = 'ios') {
  const root = mkdtempSync(join(tmpdir(), 'gmb-mobile-store.'));
  const productId = 'citizenapp';
  const assetName = `${productId}.${platform === 'ios' ? 'ipa' : 'aab'}`;
  const assetPath = join(root, assetName);
  writeFileSync(assetPath, 'fixture-release-asset');
  const digest = createHash('sha256').update('fixture-release-asset').digest('hex');
  const manifestPath = join(root, `${productId}-release-${platform}.json`);
  writeFileSync(manifestPath, JSON.stringify({
    product_id: productId, version: '1.2.3', build_number: 7,
    head_sha: 'a'.repeat(40), bundle_id: 'ios.citizenapp',
    package_name: 'com.crcfrcn.citizenapp',
    assets: [{ platform, asset_name: assetName, asset_sha256: digest }],
  }));
  return { root, productId, assetPath, manifestPath, sourceSha: 'a'.repeat(40), versionTag: `${productId}-${platform}-v1.2.3`, platform };
}

test('移动端发布只接受准确 Release Tag、源码、产品端和资产摘要', () => {
  const value = fixture();
  try {
    const result = verifyMobileStoreInput(value);
    assert.equal(result.assetName, 'citizenapp.ipa');
    assert.equal(result.manifest.build_number, 7);
  } finally { rmSync(value.root, { recursive: true, force: true }); }
});

test('移动端发布拒绝摘要漂移和跨端 Tag', () => {
  const value = fixture('android');
  try {
    writeFileSync(value.assetPath, 'tampered');
    assert.throws(() => verifyMobileStoreInput(value), /摘要/u);
    writeFileSync(value.assetPath, 'fixture-release-asset');
    assert.throws(() => verifyMobileStoreInput({ ...value, versionTag: 'citizenapp-ios-v1.2.3' }), /身份/u);
  } finally { rmSync(value.root, { recursive: true, force: true }); }
});
