#!/usr/bin/env node

import { readFileSync, writeFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { pathToFileURL } from 'node:url';

const VERSION_PATTERN = /^\d+\.(?:0|[1-9]\d?)\.(?:0|[1-9]\d?)$/;
const CARGO_PATH = 'citizenchain/Cargo.toml';
const LOCK_PATH = 'citizenchain/Cargo.lock';
const TAURI_PATH = 'citizenchain/node/tauri.conf.json';

function required(condition, message) {
  if (!condition) throw new Error(message);
}

export function applyVersion(version) {
  required(VERSION_PATTERN.test(version), '公民链节点候选版本无效');
  const tauri = JSON.parse(readFileSync(TAURI_PATH, 'utf8'));
  tauri.version = version;
  writeFileSync(TAURI_PATH, `${JSON.stringify(tauri, null, 2)}\n`);

  let cargo = readFileSync(CARGO_PATH, 'utf8');
  const pattern = /(\[workspace\.package\][\s\S]*?\nversion\s*=\s*")[^"]+("\s*)/;
  required(pattern.test(cargo), 'CitizenChain workspace.package 版本真源无效');
  cargo = cargo.replace(pattern, `$1${version}$2`);
  writeFileSync(CARGO_PATH, cargo);
}

function packageBlocks(text) {
  // 中文注释：Windows runner 会把检出文件转换为 CRLF，而 Cargo 重写锁文件时可能恢复 LF；
  // 先统一换行再做逐块比对，避免把完全相同的 Cargo.lock 误判为缺少 package。
  const normalized = text.replaceAll('\r\n', '\n');
  const marker = '[[package]]\n';
  const first = normalized.indexOf(marker);
  required(first >= 0, 'Cargo.lock 缺少 package');
  const prefix = normalized.slice(0, first);
  const blocks = normalized.slice(first).split(/(?=^\[\[package\]\]\n)/m);
  return { prefix, blocks };
}

function packageField(block, field) {
  return new RegExp(`^${field} = "([^"]+)"$`, 'm').exec(block)?.[1] ?? null;
}

export function validateLockChange(before, after, version) {
  const left = packageBlocks(before);
  const right = packageBlocks(after);
  required(left.prefix === right.prefix && left.blocks.length === right.blocks.length,
    'Cargo.lock 发生了非 workspace 版本变化');
  let changes = 0;
  for (let index = 0; index < left.blocks.length; index += 1) {
    const oldBlock = left.blocks[index];
    const newBlock = right.blocks[index];
    if (oldBlock === newBlock) continue;
    const oldName = packageField(oldBlock, 'name');
    const newName = packageField(newBlock, 'name');
    const oldVersion = packageField(oldBlock, 'version');
    const newVersion = packageField(newBlock, 'version');
    required(oldName && oldName === newName && oldVersion && newVersion === version,
      'Cargo.lock workspace 包身份或候选版本无效');
    required(packageField(oldBlock, 'source') === null && packageField(newBlock, 'source') === null,
      `Cargo.lock 禁止修改远端依赖：${oldName}`);
    const normalize = (block) => block.replace(/^version = "[^"]+"$/m, 'version = "<workspace>"');
    required(normalize(oldBlock) === normalize(newBlock),
      `Cargo.lock 除 workspace 版本外发生变化：${oldName}`);
    required(oldVersion !== newVersion, `Cargo.lock 出现无效版本变化：${oldName}`);
    changes += 1;
  }
  // 中文注释：CI 只验证源码版本，不推进正式版本；源码 manifest 与 Cargo.lock 已经一致时，
  // `cargo update --workspace` 合法地不产生差异，随后 metadata --locked 仍会验证锁定一致性。
  return changes;
}

function runCargo(args) {
  const result = spawnSync('cargo', args, {
    cwd: 'citizenchain', encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'],
  });
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(String(result.stderr || result.stdout).trim());
}

export function lockVersion(version) {
  required(VERSION_PATTERN.test(version), '公民链节点候选版本无效');
  const cargo = readFileSync(CARGO_PATH, 'utf8');
  const tauri = JSON.parse(readFileSync(TAURI_PATH, 'utf8'));
  const escapedVersion = version.replaceAll('.', '\\.');
  required(new RegExp(`\\[workspace\\.package\\][\\s\\S]*?\\nversion\\s*=\\s*"${escapedVersion}"`).test(cargo)
    && tauri.version === version, '锁文件同步前的节点候选版本不一致');
  const before = readFileSync(LOCK_PATH, 'utf8');
  // 中文注释：全新 runner 可能尚未缓存 Cargo.lock 已钉死的 Git 源，因此这里允许 Cargo
  // 取得锁文件所需源码；紧随其后的逐块校验仍只允许本地 workspace 包版本发生变化。
  runCargo(['update', '--workspace']);
  const after = readFileSync(LOCK_PATH, 'utf8');
  validateLockChange(before, after, version);
  runCargo(['metadata', '--locked', '--offline', '--no-deps', '--format-version', '1']);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    const [command, version] = process.argv.slice(2);
    if (command === 'apply') applyVersion(version);
    else if (command === 'lock') lockVersion(version);
    else throw new Error('公民链节点版本命令无效');
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
