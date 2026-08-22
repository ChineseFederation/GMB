#!/usr/bin/env node

import { readFileSync, writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { verifyCitizenAppCloudflareRelease } from './build-citizenapp-cloudflare-release.mjs';

const PRODUCT_ID = 'citizenapp-cloudflare';
const WORKER_NAME = 'citizenapp';
const CATEGORY_KEYS = [
  'cron',
  'd1',
  'durable_object_exports',
  'durable_objects',
  'kv',
  'queue_consumers',
  'queue_producers',
  'r2',
  'routes',
  'stream',
  'version_metadata',
];
const PERSISTENT_CATEGORIES = new Set([
  'd1',
  'durable_objects',
  'kv',
  'queue_consumers',
  'queue_producers',
  'r2',
]);

function fail(message) {
  throw new Error(message);
}

function stableJson(value) {
  if (Array.isArray(value)) return `[${value.map(stableJson).join(',')}]`;
  if (value && typeof value === 'object') {
    return `{${Object.keys(value).sort().map((key) => `${JSON.stringify(key)}:${stableJson(value[key])}`).join(',')}}`;
  }
  return JSON.stringify(value);
}

function prettyStableJson(value) {
  return `${JSON.stringify(JSON.parse(stableJson(value)), null, 2)}\n`;
}

function semverParts(value) {
  const match = /^(\d+)\.(\d{1,2})\.(\d{1,2})$/.exec(value);
  if (!match) fail(`软件版本无效：${value}`);
  return match.slice(1).map(Number);
}

function compareSemver(left, right) {
  const a = semverParts(left);
  const b = semverParts(right);
  for (let index = 0; index < 3; index += 1) {
    if (a[index] !== b[index]) return a[index] - b[index];
  }
  return 0;
}

function assertLiveState(liveState) {
  const keys = Object.keys(liveState || {}).sort();
  const expected = ['active_percentage', 'stable_version_id', 'worker_name'];
  if (JSON.stringify(keys) !== JSON.stringify(expected)) fail('生产 Worker 状态字段集合不正确');
  if (liveState.worker_name !== WORKER_NAME) fail('生产 Worker 名称不正确');
  if (liveState.active_percentage !== 100) fail('生产 Worker 必须只有一个 100% 稳定版本');
  if (!/^[0-9a-f-]{36}$/i.test(liveState.stable_version_id)) fail('生产 Worker version id 无效');
}

function safeMigrationSql(path, name) {
  const raw = readFileSync(path, 'utf8');
  const sql = raw
    .replace(/\/\*[\s\S]*?\*\//g, '')
    .replace(/^\s*--.*$/gm, '')
    .trim();
  if (!sql) fail(`D1 migration 不能为空：${name}`);
  const destructive = /\b(DROP|DELETE|TRUNCATE|VACUUM|REPLACE)\b|\bALTER\s+TABLE\b[\s\S]*?\b(RENAME|DROP)\b/i;
  if (destructive.test(sql)) fail(`D1 migration 包含禁止的数据破坏操作：${name}`);
  const statements = sql.split(';').map((statement) => statement.trim()).filter(Boolean);
  for (const statement of statements) {
    const allowed = [
      /^CREATE\s+TABLE\s+IF\s+NOT\s+EXISTS\b/i,
      /^CREATE\s+(?:UNIQUE\s+)?INDEX\s+IF\s+NOT\s+EXISTS\b/i,
      /^ALTER\s+TABLE\s+[^\s]+\s+ADD\s+COLUMN\b/i,
      /^INSERT\s+OR\s+IGNORE\b/i,
      /^PRAGMA\s+defer_foreign_keys\s*=\s*(?:true|false|on|off|0|1)$/i,
    ].some((pattern) => pattern.test(statement));
    if (!allowed) fail(`D1 migration 含未登记 SQL 语句：${name}`);
    if (/^ALTER\s+TABLE\b/i.test(statement)
        && /\bNOT\s+NULL\b/i.test(statement)
        && !/\bDEFAULT\b/i.test(statement)) {
      fail(`D1 新增 NOT NULL 字段必须提供默认值：${name}`);
    }
  }
}

function migrationDelta(candidatePath, candidate, current) {
  const previous = current?.migrations || [];
  if (previous.length > candidate.migrations.length) fail('Release 删除了已经登记的 D1 migration');
  for (let index = 0; index < previous.length; index += 1) {
    if (stableJson(previous[index]) !== stableJson(candidate.migrations[index])) {
      fail(`Release 改写了已经登记的 D1 migration：${previous[index].name}`);
    }
  }
  const added = candidate.migrations.slice(previous.length);
  for (const migration of added) {
    safeMigrationSql(join(candidatePath, 'migrations', migration.name), migration.name);
  }
  return added.map(({ name, sha256 }) => ({ name, sha256 }));
}

function resourceDelta(candidate, current) {
  const changes = {};
  const blocked = [];
  for (const category of CATEGORY_KEYS) {
    const next = candidate.resources.categories[category];
    const previous = current?.resources.categories[category] || null;
    const changed = previous === null || stableJson(previous) !== stableJson(next);
    const previousEntries = new Set((previous?.entries || []).map(({ identity }) => identity));
    const nextEntries = new Set(next.entries.map(({ identity }) => identity));
    const removed = [...previousEntries].filter((identity) => !nextEntries.has(identity)).sort();
    if (current && PERSISTENT_CATEGORIES.has(category) && removed.length) {
      blocked.push(`${category} 禁止自动删除或解绑生产持久资源：${removed.join('、')}`);
    }
    if (current && category === 'durable_object_exports' && changed) {
      blocked.push('Durable Object 类生命周期变化会阻断旧 Worker 回退，必须单独实施');
    }
    changes[category] = {
      action: changed ? 'verify' : 'skip',
      changed,
      removed,
    };
  }
  if (blocked.length) fail(blocked.join('\n'));
  return changes;
}

export function planCitizenAppCloudflarePublish({
  candidatePath,
  currentCandidatePath = null,
  liveState,
}) {
  const candidateRoot = resolve(candidatePath);
  const candidate = verifyCitizenAppCloudflareRelease(candidateRoot);
  const current = currentCandidatePath
    ? verifyCitizenAppCloudflareRelease(resolve(currentCandidatePath))
    : null;
  assertLiveState(liveState);
  if (current && compareSemver(candidate.software_version, current.software_version) <= 0) {
    fail('发布版本必须高于当前已发布版本');
  }
  const migrations = migrationDelta(candidateRoot, candidate, current);
  const resources = resourceDelta(candidate, current);
  return {
    product_id: PRODUCT_ID,
    worker_name: WORKER_NAME,
    software_version: candidate.software_version,
    git_commit_sha: candidate.git_commit_sha,
    stable_version_id: liveState.stable_version_id,
    bootstrap: current === null,
    migrations,
    resources,
  };
}

function parseArgs(argv) {
  const values = {};
  for (let index = 0; index < argv.length; index += 2) {
    const key = argv[index];
    const value = argv[index + 1];
    if (!key?.startsWith('--') || value === undefined) fail(`参数格式无效：${key || ''}`);
    values[key.slice(2)] = value;
  }
  for (const key of ['candidate', 'live-state', 'output']) {
    if (!values[key]) fail(`缺少参数 --${key}`);
  }
  return values;
}

const isMain = process.argv[1] && resolve(process.argv[1]) === resolve(fileURLToPath(import.meta.url));
if (isMain) {
  try {
    const args = parseArgs(process.argv.slice(2));
    const plan = planCitizenAppCloudflarePublish({
      candidatePath: args.candidate,
      currentCandidatePath: args.current || null,
      liveState: JSON.parse(readFileSync(args['live-state'], 'utf8')),
    });
    writeFileSync(resolve(args.output), prettyStableJson(plan), { encoding: 'utf8', mode: 0o600, flag: 'wx' });
    process.stdout.write(`CitizenApp Cloudflare 发布计划已生成：${plan.software_version}\n`);
  } catch (error) {
    process.stderr.write(`${error instanceof Error ? error.message : String(error)}\n`);
    process.exitCode = 1;
  }
}
