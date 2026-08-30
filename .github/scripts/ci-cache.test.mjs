import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

import {
  CI_CACHE_SCHEMA,
  cacheIdentity,
  cacheKeys,
  cachePathPlan,
  parseCacheKey,
  parseLogicalCacheKey,
  planCachePrune,
  selectLatestCache,
} from './ci-cache.mjs';

// 固定向量覆盖缓存身份、恢复和收口边界，保证不同产品端互不污染。
const identity = cacheIdentity({
  repository: 'ChineseFederation/GMB',
  product: 'CitizenApp',
  platform: 'Android',
  architecture: 'ARM64',
  component: 'Build',
  runnerOs: 'Linux',
  runnerArch: 'ARM64',
  toolchainFingerprint: '0123456789abcdef'.repeat(4),
});

test('固定向量生成稳定且分端隔离的CI缓存身份', () => {
  assert.equal(CI_CACHE_SCHEMA, 'ci');
  assert.equal(
    identity.baseKey,
    'ci-chinesefederation.gmb-citizenapp-android-arm64-build-linux-arm64-0123456789abcdef',
  );
  assert.deepEqual(cacheKeys(identity, '90210', '3'), {
    successPrefix: `${identity.baseKey}-success-`,
    failurePrefix: `${identity.baseKey}-failure-`,
    successKey: `${identity.baseKey}-success-90210-3`,
    failureKey: `${identity.baseKey}-failure-90210-3`,
  });
  assert.equal(
    parseCacheKey(identity, `${identity.baseKey}-success-90210-3`)?.state,
    'success',
  );
  assert.equal(parseCacheKey(identity, `${identity.baseKey}-success-none`), null);
});

test('恢复只选择最高Run与Attempt的成功槽而不读取失败槽', () => {
  const caches = [
    { id: 1, key: `${identity.baseKey}-success-100-2`, ref: 'refs/heads/main' },
    { id: 2, key: `${identity.baseKey}-success-101-1`, ref: 'refs/heads/main' },
    { id: 3, key: `${identity.baseKey}-failure-999-1`, ref: 'refs/heads/main' },
    { id: 4, key: `${identity.baseKey}-success-500-1`, ref: 'refs/heads/other' },
  ];
  const selected = selectLatestCache(identity, caches, 'success', 'refs/heads/main');
  assert.equal(selected.id, '2');
  assert.equal(selected.runId, '101');
  assert.equal(selected.state, 'success');
});

test('收口计划对同一身份和Ref最多保留一个成功与一个失败槽', () => {
  const caches = [
    { id: 10, key: `${identity.baseKey}-success-100-1`, ref: 'refs/heads/main' },
    { id: 11, key: `${identity.baseKey}-success-101-1`, ref: 'refs/heads/main' },
    { id: 12, key: `${identity.baseKey}-failure-98-1`, ref: 'refs/heads/main' },
    { id: 13, key: `${identity.baseKey}-failure-102-2`, ref: 'refs/heads/main' },
    { id: 14, key: 'foreign-cache', ref: 'refs/heads/main' },
  ];
  const plan = planCachePrune(identity, caches, 'refs/heads/main');
  assert.deepEqual(plan.retain.map((entry) => entry.id).sort(), ['11', '13']);
  assert.deepEqual(plan.remove.map((entry) => entry.id).sort(), ['10', '12']);
});

test('工具链升级后只恢复当前指纹并清理旧指纹槽', () => {
  const previousKey = identity.baseKey.replace('0123456789abcdef', 'fedcba9876543210');
  const caches = [
    { id: 20, key: `${previousKey}-success-200-1`, ref: 'refs/heads/main' },
    { id: 21, key: `${identity.baseKey}-success-201-1`, ref: 'refs/heads/main' },
    { id: 22, key: `${previousKey}-failure-199-1`, ref: 'refs/heads/main' },
  ];
  assert.equal(parseCacheKey(identity, caches[0].key), null);
  assert.equal(parseLogicalCacheKey(identity, caches[0].key)?.toolchain, 'fedcba9876543210');
  assert.equal(selectLatestCache(identity, caches, 'success', 'refs/heads/main').id, '21');
  const plan = planCachePrune(identity, caches, 'refs/heads/main');
  assert.deepEqual(plan.retain.map((entry) => entry.id).sort(), ['21', '22']);
  assert.deepEqual(plan.remove.map((entry) => entry.id), ['20']);
});

test('缓存路径只能由安全相对名派生到Runner临时目录', () => {
  const plan = cachePathPlan(identity, '/runner/temp', 'cargo-target\nnpm\ndart-pub');
  assert.match(plan.root, /^\/runner\/temp\/ci-cache\/citizenapp-android-build-/);
  assert.deepEqual(plan.successPaths, [
    `${plan.root}/cargo-target`,
    `${plan.root}/npm`,
    `${plan.root}/dart-pub`,
  ]);
  assert.equal(plan.failurePath, `${plan.root}/failure-diagnostic`);
  assert.throws(() => cachePathPlan(identity, '/runner/temp', '../source'));
  assert.throws(() => cachePathPlan(identity, '/runner/temp', '/absolute'));
  assert.throws(() => cachePathPlan(identity, 'relative', 'cargo-target'));
});

test('缓存身份拒绝路径、超长标识和非SHA256工具链指纹', () => {
  assert.throws(() => cacheIdentity({
    repository: 'ChineseFederation/GMB',
    product: '../citizenapp',
    platform: 'android',
    architecture: 'arm64',
    component: 'build',
    runnerOs: 'linux',
    runnerArch: 'arm64',
    toolchainFingerprint: '0'.repeat(64),
  }));
  assert.throws(() => cacheIdentity({
    repository: 'ChineseFederation/GMB',
    product: 'citizenapp',
    platform: 'android',
    architecture: 'arm64',
    component: 'build',
    runnerOs: 'linux',
    runnerArch: 'arm64',
    toolchainFingerprint: 'not-a-sha256',
  }));
});

test('GitHub缓存请求使用无版本语义的固定客户端身份', () => {
  const source = readFileSync(new URL('./ci-cache.mjs', import.meta.url), 'utf8');
  assert.match(source, /'User-Agent': 'ci-cache'/);
  assert.doesNotMatch(source, /cache[-_.]v[0-9]+/i);
});
