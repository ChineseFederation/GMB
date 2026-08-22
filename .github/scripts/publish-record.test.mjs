import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import { recordPublish, verifyPublishReceipt } from './publish-record.mjs';

const receipt = Object.freeze({
  product_id: 'citizenapp', platform: 'ios', software_flow: 'publish',
  software_version: '1.2.3', version_tag: 'citizenapp-ios-v1.2.3',
  build_number: 7, asset_sha256: 'b'.repeat(64), source_sha: 'a'.repeat(40),
  publish_state: 'reviewing', publish_receipt_id: 'fixture',
});

test('发布回执只接受准确 GitHub 正式版本身份', () => {
  assert.equal(verifyPublishReceipt(receipt, {
    environment: 'citizenapp-ios-production', url: 'https://apps.apple.com/',
  }), receipt);
  assert.throws(() => verifyPublishReceipt({ ...receipt, software_flow: 'release' }, {
    environment: 'citizenapp-ios-production', url: 'https://apps.apple.com/',
  }), /身份/u);
  assert.throws(() => verifyPublishReceipt({ ...receipt, publish_receipt_id: '' }, {
    environment: 'citizenapp-ios-production', url: 'https://apps.apple.com/',
  }), /身份/u);
  assert.throws(() => verifyPublishReceipt({ ...receipt, extra: true }, {
    environment: 'citizenapp-ios-production', url: 'https://apps.apple.com/',
  }), /字段集合/u);
  const web = {
    product_id: 'citizenweb', software_flow: 'publish', software_version: '1.2.3',
    version_tag: 'citizenweb-v1.2.3', source_sha: 'a'.repeat(40), publish_state: 'published',
    publish_receipt_id: '42',
  };
  assert.equal(verifyPublishReceipt(web, {
    environment: 'citizenweb-production', url: 'https://www.crcfrcn.com/',
  }), web);
});

test('GitHub Deployment 先创建记录再写成功状态', async () => {
  const calls = [];
  const id = await recordPublish({
    receipt, environment: 'citizenapp-ios-production',
    description: '公民 iOS 发布', url: 'https://apps.apple.com/',
    client: { async request(path, body) {
      calls.push({ path, body });
      return path === 'deployments' ? { id: 42 } : {};
    } },
  });
  assert.equal(id, 42);
  assert.deepEqual(calls.map((call) => call.path), ['deployments', 'deployments/42/statuses']);
  assert.equal(calls[0].body.ref, receipt.version_tag);
  assert.equal(calls[1].body.state, 'success');
});

test('六条发布 Workflow 只消费 GitHub Release 且不编译产品', () => {
  const workflows = [
    'citizenapp-publish-ios.yml', 'citizenapp-publish-android.yml',
    'citizenwallet-publish-ios.yml', 'citizenwallet-publish-android.yml',
    'citizenapp-cloudflare-publish-cloudflare.yml', 'citizenweb-publish-web.yml',
  ];
  for (const workflow of workflows) {
    const source = readFileSync(new URL(`../workflows/${workflow}`, import.meta.url), 'utf8');
    assert.match(source, /workflow_dispatch:/);
    assert.match(source, /source_sha:/);
    assert.match(source, /version_tag:/);
    assert.match(source, /gh release download/);
    assert.match(source, /publish-record\.mjs/);
    assert.match(source, /runs-on: ubuntu-24\.04/);
    assert.doesNotMatch(source, /flutter build|xcodebuild|cargo build|upload-artifact/);
    assert.doesNotMatch(source, /\/Users\/rhett|CitizenConsoleMobileStore/);
  }
});

test('公民网发布保留预览逐文件验收和生产失败回滚', () => {
  const source = readFileSync(new URL('../workflows/citizenweb-publish-web.yml', import.meta.url), 'utf8');
  assert.match(source, /--branch citizenweb-candidate/);
  assert.match(source, /manifest\.files\.filter/);
  assert.match(source, /createHash.*require\('node:crypto'\)/);
  assert.match(source, /待发布官网版本.*必须高于当前生产版本/);
  assert.match(source, /\/deployments\/\$\{encodeURIComponent\(id\)\}\/rollback/);
  assert.match(source, /回滚后的正式域名版本标记不是旧版本/);
  assert.match(source, /verify_deployment 'https:\/\/www\.crcfrcn\.com'/);
});

test('公民后端发布回滚后复核旧 Worker 版本', () => {
  const source = readFileSync(new URL(
    '../workflows/citizenapp-cloudflare-publish-cloudflare.yml', import.meta.url,
  ), 'utf8');
  assert.match(source, /versions deploy "\$\{stable\}@100"/);
  assert.match(source, /&& health "\$stable"/);
  assert.match(source, /已恢复并验证旧 Worker 版本/);
});
