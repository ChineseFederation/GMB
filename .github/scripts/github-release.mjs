#!/usr/bin/env node

import { lstatSync } from 'node:fs';
import { basename } from 'node:path';
import { spawnSync } from 'node:child_process';
import { pathToFileURL } from 'node:url';

const SHA_PATTERN = /^[0-9a-f]{40}$/;
const REPOSITORY_PATTERN = /^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/;
const TAG_PATTERN = /^[A-Za-z0-9][A-Za-z0-9._-]{0,199}$/;
const READ_ATTEMPTS = 7;
const READ_RETRY_MS = 10_000;

function required(condition, message) {
  if (!condition) throw new Error(message);
}

export function gh(args, options = {}) {
  const run = options.run || spawnSync;
  const wait = options.wait || ((milliseconds) => {
    Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, milliseconds);
  });
  const attempts = options.retryRead ? READ_ATTEMPTS : 1;
  for (let attempt = 1; attempt <= attempts; attempt += 1) {
    const result = run('gh', args, {
      encoding: 'utf8',
      input: options.input,
      env: process.env,
      maxBuffer: 16 * 1024 * 1024,
    });
    if (result.error) throw result.error;
    if (result.status === 0) return String(result.stdout || '').trim();
    const detail = String(result.stderr || result.stdout || '').trim();
    if (options.notFound && /(?:HTTP 404|Not Found)/i.test(detail)) return null;
    // 中文注释：GitHub 偶发把具有 Contents write 的 Actions 令牌拒绝在只读 Release
    // 查询上；只重试幂等读取，创建、发布与删除事务绝不自动重放。
    const integrationDenied = /HTTP 403:\s*Resource not accessible by integration/i.test(detail);
    const retryable = options.retryRead && (integrationDenied || /HTTP 5\d\d/i.test(detail));
    if (!retryable || attempt === attempts) {
      throw new Error(detail || `gh 执行失败，退出码 ${result.status}`);
    }
    console.error(`[GitHub] Release 只读接口暂时不可用，${READ_RETRY_MS / 1000} 秒后重试（${attempt}/${attempts - 1}）`);
    wait(READ_RETRY_MS);
  }
  throw new Error('GitHub Release 只读接口重试状态异常');
}

function json(output, context) {
  try {
    return JSON.parse(output);
  } catch {
    throw new Error(`${context}返回了无效 JSON`);
  }
}

export function createClient() {
  return {
    async listReleases(repository) {
      const releases = [];
      for (let page = 1; page <= 100; page += 1) {
        const output = gh(['api', `repos/${repository}/releases?per_page=100&page=${page}`], {
          retryRead: true,
        });
        const values = json(output, 'GitHub Release 列表');
        required(Array.isArray(values), 'GitHub Release 列表格式无效');
        releases.push(...values);
        if (values.length < 100) return releases;
      }
      throw new Error('GitHub Release 列表超过安全分页上限');
    },
    async getTag(repository, tag) {
      const output = gh(['api', `repos/${repository}/git/ref/tags/${encodeURIComponent(tag)}`], {
        notFound: true,
        retryRead: true,
      });
      return output === null ? null : json(output, 'GitHub Tag');
    },
    async getTagObject(repository, objectSHA) {
      return json(gh(['api', `repos/${repository}/git/tags/${objectSHA}`], { retryRead: true }), 'GitHub Tag 对象');
    },
    async createTag(repository, tag, releaseSHA) {
      const payload = JSON.stringify({ ref: `refs/tags/${tag}`, sha: releaseSHA });
      gh(['api', '--method', 'POST', `repos/${repository}/git/refs`, '--input', '-'], {
        input: payload,
      });
    },
    async createDraft(input) {
      const args = [
        'release', 'create', input.tag, '--repo', input.repository,
        '--verify-tag', '--draft', '--title', input.title,
      ];
      if (input.notes) args.push('--notes', input.notes);
      else args.push('--notes-file', input.notesFile);
      args.push(...input.assets.map((asset) => asset.path));
      // 中文注释：版本 Tag 已在同一 Release 事务中准确绑定本次 Release
      // workflow 提交；成功 CI 提交只是正式构建与产物来源，不冒充 Tag 目标。
      gh(args);
    },
    async getRelease(repository, releaseId) {
      return json(gh(['api', `repos/${repository}/releases/${releaseId}`], { retryRead: true }), 'GitHub Release');
    },
    async getReleaseByTag(repository, tag) {
      const output = gh(
        ['api', `repos/${repository}/releases/tags/${encodeURIComponent(tag)}`],
        { notFound: true, retryRead: true },
      );
      return output === null ? null : json(output, 'GitHub Tag Release');
    },
    async publish(repository, releaseId, latest) {
      const payload = JSON.stringify({ draft: false, make_latest: latest ? 'true' : 'false' });
      gh(['api', '--method', 'PATCH', `repos/${repository}/releases/${releaseId}`, '--input', '-'], {
        input: payload,
      });
    },
    async deleteRelease(repository, releaseId) {
      gh(['api', '--method', 'DELETE', `repos/${repository}/releases/${releaseId}`]);
    },
    async deleteTag(repository, tag) {
      gh(['api', '--method', 'DELETE', `repos/${repository}/git/refs/tags/${encodeURIComponent(tag)}`]);
    },
    async wait() {
      await new Promise((resolve) => setTimeout(resolve, 1_000));
    },
  };
}

function verifyAssets(release, assets) {
  required(Array.isArray(release.assets), 'GitHub Release 资产格式无效');
  required(release.assets.length === assets.length, 'GitHub Release 资产数量不符');
  const actual = new Map();
  for (const asset of release.assets) {
    required(typeof asset?.name === 'string' && !actual.has(asset.name), 'GitHub Release 资产名称重复或无效');
    actual.set(asset.name, asset);
  }
  for (const expected of assets) {
    const asset = actual.get(expected.name);
    required(asset, `GitHub Release 缺少资产：${expected.name}`);
    required(asset.state === 'uploaded', `GitHub Release 资产未完成上传：${expected.name}`);
    required(asset.size === expected.size, `GitHub Release 资产大小不符：${expected.name}`);
  }
}

function verifyRelease(release, input, draft) {
  required(Number.isSafeInteger(release?.id) && release.id > 0, 'GitHub Release id 无效');
  required(release.tag_name === input.tag, 'GitHub 版本 Tag 不符');
  required(release.name === input.title, 'GitHub Release 标题不符');
  required(release.draft === draft, draft ? 'GitHub Release 不是草稿' : 'GitHub Release 尚未固化');
  verifyAssets(release, input.assets);
}

// 中文注释：草稿没有稳定的最终 Tag 查询入口，只能从含草稿的 Release 列表取得唯一数字 id。
async function findDraft(client, input) {
  for (let attempt = 0; attempt < 5; attempt += 1) {
    const matches = (await client.listReleases(input.repository))
      .filter((value) => value?.tag_name === input.tag
        && value?.name === input.title && value?.draft === true);
    required(matches.length <= 1, `发现多个同名 GitHub Release：${input.tag}`);
    if (matches.length === 1) return matches[0];
    await client.wait();
  }
  return null;
}

async function versionTagCommit(client, input) {
  const reference = await client.getTag(input.repository, input.tag);
  required(reference?.ref === `refs/tags/${input.tag}`
    && SHA_PATTERN.test(String(reference?.object?.sha || '')), '正式版本 Tag 不存在或无效');
  if (reference.object.type === 'commit') {
    required(reference.object.sha === input.releaseSHA, '正式版本 Tag 未指向本次 Release 提交');
    return reference.object.sha;
  }
  required(reference.object.type === 'tag', '正式版本 Tag 类型无效');
  const object = await client.getTagObject(input.repository, reference.object.sha);
  required(object?.tag === input.tag && object?.object?.type === 'commit'
    && object.object.sha === input.releaseSHA, '正式版本 Tag 未指向本次 Release 提交');
  return object.object.sha;
}

export async function release(input, client = createClient()) {
  let releaseId = null;
  let transactionStarted = false;
  let reuseExistingTag = false;
  const existing = (await client.listReleases(input.repository))
    .filter((value) => value?.tag_name === input.tag);
  const published = existing.filter((value) => value?.draft === false);
  required(published.length === 0, `正式 Release 已存在，禁止覆盖：${input.tag}`);
  const drafts = existing.filter((value) => value?.draft === true);
  required(drafts.length <= 1, `发现多个同 Tag 草稿 Release：${input.tag}`);
  if (drafts.length === 1) {
    // 中文注释：新事务以真实 Tag 指向为准；仅兼容清理旧工具尚未建 Tag、但已准确
    // 记录成功 CI 源提交的草稿，不保留旧发布流程。
    const draftTag = await client.getTag(input.repository, input.tag);
    if (draftTag) {
      await versionTagCommit(client, input);
    } else {
      required(drafts[0]?.target_commitish === input.sourceSHA,
        '遗留草稿未绑定本次成功 CI 源提交，禁止清理');
    }
    await client.deleteRelease(input.repository, drafts[0].id);
    if (draftTag) await client.deleteTag(input.repository, input.tag);
  } else {
    const staleTag = await client.getTag(input.repository, input.tag);
    if (staleTag) {
      // 中文注释：上次事务如在创建 Tag 后中断，本次只复用准确指向
      // 当前 Release workflow 提交的 Tag，禁止复用任意旧源码 Tag。
      await versionTagCommit(client, input);
      reuseExistingTag = true;
    }
  }

  try {
    transactionStarted = true;
    // 中文注释：Release 独占版本推进；先为本次 Release workflow 提交创建
    // 精确轻量 Tag，再要求草稿复用该 Tag。正式资产仍严格来自 sourceSHA。
    // 任一后续步骤失败都会在本事务中回滚，失败任务不会占用版本号。
    if (!reuseExistingTag) await client.createTag(input.repository, input.tag, input.releaseSHA);
    await client.createDraft(input);
    let draft = await findDraft(client, input);
    required(draft, `无法取得新建草稿 Release：${input.tag}`);
    releaseId = draft.id;
    draft = await client.getRelease(input.repository, releaseId);
    verifyRelease(draft, input, true);
    // 中文注释：草稿资产全部校验通过后再发布，已有事务 Tag 此时才成为正式版本入口。
    await client.publish(input.repository, releaseId, input.latest);

    const result = await client.getRelease(input.repository, releaseId);
    verifyRelease(result, input, false);
    const byTag = await client.getReleaseByTag(input.repository, input.tag);
    required(byTag?.id === releaseId, '版本 Tag 未关联本次 GitHub Release');
    await versionTagCommit(client, input);
    console.log(`正式 Release 与唯一版本 Tag 已固化：${input.tag}`);
    return result;
  } catch (error) {
    const cleanupErrors = [];
    if (transactionStarted) {
      try {
        if (releaseId) await client.deleteRelease(input.repository, releaseId);
        else {
          const draft = await findDraft(client, input);
          if (draft) await client.deleteRelease(input.repository, draft.id);
        }
      } catch (cleanupError) {
        cleanupErrors.push(`草稿回滚失败：${cleanupError.message}`);
      }
      try {
        const tag = await client.getTag(input.repository, input.tag);
        if (tag) {
          await versionTagCommit(client, input);
          await client.deleteTag(input.repository, input.tag);
        }
      } catch (cleanupError) {
        cleanupErrors.push(`Tag 回滚失败：${cleanupError.message}`);
      }
    }
    const suffix = cleanupErrors.length > 0 ? `；${cleanupErrors.join('；')}` : '';
    throw new Error(`${error.message}${suffix}`);
  }
}

export function parseArgs(argv, environment = process.env) {
  const values = new Map();
  const assetIndex = argv.indexOf('--assets');
  required(assetIndex >= 0 && assetIndex < argv.length - 1, '缺少 --assets');
  const assetPaths = argv.slice(assetIndex + 1);
  const optionArgs = argv.slice(0, assetIndex);
  required(optionArgs.length % 2 === 0, 'Release 参数必须成对提供');
  for (let index = 0; index < optionArgs.length; index += 2) {
    const key = optionArgs[index];
    required(/^--[a-z-]+$/.test(key) && !values.has(key), `Release 参数无效或重复：${key}`);
    values.set(key, optionArgs[index + 1]);
  }

  const repository = environment.GITHUB_REPOSITORY;
  const releaseSHA = environment.GITHUB_SHA;
  const tag = values.get('--tag');
  const sourceSHA = values.get('--source-sha');
  const title = values.get('--title');
  const notes = values.get('--notes');
  const notesFile = values.get('--notes-file');
  const latestValue = values.get('--latest');
  required(REPOSITORY_PATTERN.test(repository || ''), 'GITHUB_REPOSITORY 无效');
  required(SHA_PATTERN.test(releaseSHA || ''), 'Release workflow 提交无效');
  required(TAG_PATTERN.test(tag || ''), '版本 Tag 无效');
  required(SHA_PATTERN.test(sourceSHA || ''), 'Release 源提交无效');
  required(typeof title === 'string' && title.trim() === title && title.length > 0, 'Release 标题无效');
  required(Boolean(notes) !== Boolean(notesFile), '必须且只能提供 --notes 或 --notes-file');
  required(latestValue === 'true' || latestValue === 'false', '--latest 只允许 true 或 false');

  const assets = assetPaths.map((path) => {
    const value = lstatSync(path);
    required(value.isFile() && value.size > 0, `Release 资产不是非空普通文件：${path}`);
    return { path, name: basename(path), size: value.size };
  });
  required(new Set(assets.map((asset) => asset.name)).size === assets.length, 'Release 资产文件名重复');
  return {
    repository,
    releaseSHA,
    tag,
    sourceSHA,
    title,
    notes,
    notesFile,
    latest: latestValue === 'true',
    assets,
  };
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    await release(parseArgs(process.argv.slice(2)));
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
