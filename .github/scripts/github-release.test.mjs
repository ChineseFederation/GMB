import assert from 'node:assert/strict';
import test from 'node:test';

import { gh, release } from './github-release.mjs';

function input() {
  return {
    repository: 'ChineseFederation/GMB',
    tag: `citizenapp-cloudflare-v${['1', '0', '1'].join('.')}`,
    sourceSHA: '6f2c0e5355156db2fd36216ab7f928f8090ab3e0',
    title: '公民后端 · Release · Cloudflare',
    notes: '公民后端 1.0.1。',
    latest: false,
    assets: [
      { path: '/candidate/archive.tgz', name: 'archive.tgz', size: 12 },
      { path: '/candidate/SHA256SUMS', name: 'SHA256SUMS', size: 64 },
    ],
  };
}

function client(options = {}) {
  const calls = [];
  const value = input();
  let created = false;
  let published = false;
  let tagExists = (options.staleDraft === true && options.staleDraftWithoutTag !== true)
    || options.staleTag === true;
  let staleDraft = options.staleDraft === true;
  const remote = (id = 42, draft = !published) => ({
    id,
    name: value.title,
    tag_name: value.tag,
    target_commitish: value.sourceSHA,
    draft,
    assets: value.assets.map((asset, index) => ({
      name: asset.name,
      size: index === 0 && options.badSize ? asset.size + 1 : asset.size,
      state: 'uploaded',
    })),
  });
  return {
    calls,
    async listReleases() {
      calls.push('list');
      if (options.publishedExisting) return [remote(7, false)];
      if (staleDraft) return [remote(7, true)];
      return created ? [remote()] : [];
    },
    async getTag() {
      calls.push('tag');
      return tagExists
        ? { ref: `refs/tags/${value.tag}`, object: { type: 'commit', sha: value.sourceSHA } }
        : null;
    },
    async getTagObject() {
      calls.push('tag-object');
      return { tag: value.tag, object: { type: 'commit', sha: value.sourceSHA } };
    },
    async createTag() {
      calls.push('create-tag');
      if (options.tagFailure) throw new Error('Tag 创建失败');
      tagExists = true;
    },
    async createDraft() {
      calls.push('create');
      created = true;
      if (options.createFailure) throw new Error('资产上传失败');
    },
    async getRelease() {
      calls.push('get');
      return remote();
    },
    async getReleaseByTag() {
      calls.push('by-tag');
      return remote();
    },
    async publish() {
      calls.push('publish');
      published = true;
      tagExists = true;
    },
    async deleteRelease() {
      calls.push('delete-release');
      staleDraft = false;
      created = false;
    },
    async deleteTag() {
      calls.push('delete-tag');
      tagExists = false;
    },
    async wait() {
      calls.push('wait');
    },
  };
}

test('Release 事务先创建唯一 Tag，正式资产完成后发布', async () => {
  const fake = client();
  const result = await release(input(), fake);
  assert.equal(result.draft, false);
  assert.ok(fake.calls.indexOf('create-tag') < fake.calls.indexOf('create'));
  assert.equal(fake.calls.includes('create'), true);
  assert.equal(fake.calls.includes('publish'), true);
  assert.equal(fake.calls.includes('delete-tag'), false);
});

test('草稿资产不一致时回滚草稿与事务 Tag', async () => {
  const fake = client({ badSize: true });
  await assert.rejects(release(input(), fake), /资产大小不符/);
  assert.equal(fake.calls.includes('publish'), false);
  assert.equal(fake.calls.includes('delete-release'), true);
  assert.equal(fake.calls.includes('delete-tag'), true);
});

test('下一条同版本 Release 先回滚上次中断遗留草稿与 Tag', async () => {
  const fake = client({ staleDraft: true });
  await release(input(), fake);
  assert.ok(fake.calls.filter((value) => value === 'delete-release').length >= 1);
  assert.ok(fake.calls.filter((value) => value === 'delete-tag').length >= 1);
  assert.equal(fake.calls.includes('create'), true);
});

test('下一条同版本 Release 可回滚尚未创建 Tag 的遗留草稿', async () => {
  const fake = client({ staleDraft: true, staleDraftWithoutTag: true });
  await release(input(), fake);
  assert.ok(fake.calls.filter((value) => value === 'delete-release').length >= 1);
  assert.equal(fake.calls.includes('delete-tag'), false);
  assert.equal(fake.calls.includes('publish'), true);
});

test('复用已登录用户会话预建且准确指向成功 CI 的事务 Tag', async () => {
  const fake = client({ staleTag: true });
  await release(input(), fake);
  assert.equal(fake.calls.includes('create-tag'), false);
  assert.equal(fake.calls.includes('delete-tag'), false);
  assert.equal(fake.calls.includes('publish'), true);
});

test('已有正式 Release 时拒绝覆盖', async () => {
  const fake = client({ publishedExisting: true });
  await assert.rejects(release(input(), fake), /正式 Release 已存在/);
  assert.equal(fake.calls.includes('create'), false);
  assert.equal(fake.calls.includes('delete-release'), false);
});

test('创建命令部分失败时回滚可能已经生成的草稿且不占用 Tag', async () => {
  const fake = client({ createFailure: true });
  await assert.rejects(release(input(), fake), /资产上传失败/);
  assert.equal(fake.calls.includes('delete-release'), true);
  assert.equal(fake.calls.includes('delete-tag'), true);
  assert.equal(fake.calls.includes('publish'), false);
});

test('Release 只读接口对 GitHub integration 临时 403 有限重试', () => {
  let attempts = 0;
  const delays = [];
  const output = gh(['api', 'repos/ChineseFederation/GMB/releases'], {
    retryRead: true,
    run() {
      attempts += 1;
      if (attempts < 3) {
        return { status: 1, stdout: '', stderr: 'HTTP 403: Resource not accessible by integration' };
      }
      return { status: 0, stdout: '[]\n', stderr: '' };
    },
    wait(milliseconds) { delays.push(milliseconds); },
  });
  assert.equal(output, '[]');
  assert.equal(attempts, 3);
  assert.deepEqual(delays, [10_000, 10_000]);
});

test('Release 写操作遇到 integration 403 不自动重放', () => {
  let attempts = 0;
  assert.throws(() => gh(['release', 'create'], {
    run() {
      attempts += 1;
      return { status: 1, stdout: '', stderr: 'HTTP 403: Resource not accessible by integration' };
    },
    wait() { throw new Error('写操作不得等待重试'); },
  }), /Resource not accessible by integration/);
  assert.equal(attempts, 1);
});

test('Tag 创建失败时不创建草稿且不占用版本号', async () => {
  const fake = client({ tagFailure: true });
  await assert.rejects(release(input(), fake), /Tag 创建失败/);
  assert.equal(fake.calls.includes('create'), false);
  assert.equal(fake.calls.includes('publish'), false);
});
