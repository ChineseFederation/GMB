#!/usr/bin/env node

import { spawnSync } from 'node:child_process';
import { existsSync, lstatSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';

const root = resolve(process.env.GMB_REPOSITORY_ROOT || process.cwd());
const expectedWorkflows = [
  '.github/workflows/chatsdk/ci-sdk.yml',
  '.github/workflows/chatsdk/release-sdk.yml',
];
const expectedFiles = [
  'chatsdk/pubspec.yaml',
  'chatsdk/pubspec.lock',
  'chatsdk/native/Cargo.toml',
  'chatsdk/native/Cargo.lock',
  'chatsdk/README.md',
  'chatsdk/scripts/release.mjs',
  'chatsdk/scripts/release.test.mjs',
  '.github/scripts/chatsdk/ci-sdk.mjs',
  '.github/scripts/chatsdk/release-sdk.mjs',
];

function fail(message) {
  throw new Error(message);
}

function read(path) {
  const absolute = resolve(root, path);
  const status = lstatSync(absolute, { throwIfNoEntry: false });
  if (!status?.isFile() || status.isSymbolicLink()) fail(`缺少普通依赖文件：${path}`);
  return readFileSync(absolute, 'utf8');
}

function exactArray(actual, expected, label) {
  if (!Array.isArray(actual)
      || JSON.stringify([...actual].sort()) !== JSON.stringify([...expected].sort())) {
    fail(`${label}登记不准确`);
  }
}

function checkPinnedActions(path, source) {
  const actions = [...source.matchAll(/^\s*uses:\s*([^\s#]+).*$/gm)].map((match) => match[1]);
  if (actions.length === 0) fail(`${path} 没有登记固定 GitHub Action`);
  for (const action of actions) {
    if (action.startsWith('./')) continue;
    const revision = action.split('@')[1];
    if (!/^[0-9a-f]{40}$/.test(String(revision || ''))) {
      fail(`${path} 的 GitHub Action 未固定到 40 位提交：${action}`);
    }
  }
}

function checkDependencies(scopeName) {
  if (scopeName !== 'chatsdk') fail('ChatSDK 动作只接受 chatsdk 依赖作用域');
  const contract = JSON.parse(read('.github/dependencies.json'));
  if (contract.schema !== 1 || !contract.scopes?.chatsdk) fail('ChatSDK 依赖契约无效');
  const scope = contract.scopes.chatsdk;
  exactArray(scope.workflows, expectedWorkflows, 'ChatSDK Workflow');
  exactArray(scope.requiredFiles, expectedFiles, 'ChatSDK 必需文件');
  if (!contract.dartApplications?.includes('chatsdk')) fail('ChatSDK 未登记 Dart 应用');
  if (!contract.cargoProjects?.includes('chatsdk/native')) fail('ChatSDK 未登记 Rust 项目');
  if (!contract.auditedScopes?.includes('chatsdk')) fail('ChatSDK 未登记安全审计作用域');
  for (const path of expectedFiles) read(path);

  const pubspec = read('chatsdk/pubspec.yaml');
  if (!/^name:\s*chat_sdk\s*$/m.test(pubspec)) fail('ChatSDK pubspec 包名必须是 chat_sdk');
  if (!/^version:\s*\d+\.\d{1,2}\.\d{1,2}(?:\+\d+)?\s*$/m.test(pubspec)) {
    fail('ChatSDK pubspec 软件版本无效');
  }
  const cargo = read('chatsdk/native/Cargo.toml');
  if (!/^\[package\]\s*$/m.test(cargo)) fail('ChatSDK Rust package 无效');

  const ci = read(expectedWorkflows[0]);
  const release = read(expectedWorkflows[1]);
  for (const [path, source] of [[expectedWorkflows[0], ci], [expectedWorkflows[1], release]]) {
    checkPinnedActions(path, source);
    if (/\b(?:http|ws):\/\//u.test(source)) fail(`${path} 包含明文网络协议`);
  }
  if (!/^name: 聊天SDK · CI · SDK$/m.test(ci)
      || /software_version:|source_sha:/u.test(ci)
      || !/name: ChatSDK-CI/u.test(ci)) {
    fail('ChatSDK CI 身份、无版本规则或候选名称无效');
  }
  if (!/^name: 聊天SDK · Release · SDK$/m.test(release)
      || !/source_sha:[\s\S]*ci_run_id:[\s\S]*version_tag:[\s\S]*software_version:/u.test(release)
      || !/chatsdk\.tgz[\s\S]*chatsdk-release\.json[\s\S]*SHA256SUMS/u.test(release)) {
    fail('ChatSDK Release 输入或三件套闭集无效');
  }
  const central = read('.github/workflows/gmb-repository.yml');
  for (const workflow of expectedWorkflows) {
    if (!central.includes(`inputs.pipeline == '${workflow}'`)) fail(`GMB 顶层入口缺少路由：${workflow}`);
  }
  if (!/^  chatsdk_ci_sdk__check:/m.test(central)
      || !/^  chatsdk_release_sdk__check:/m.test(central)) {
    fail('GMB 顶层入口缺少 ChatSDK 独立作业');
  }
}

function auditDependencies(scopeName) {
  checkDependencies(scopeName);
  const result = spawnSync('cargo', ['audit', '--file', 'Cargo.lock'], {
    cwd: resolve(root, 'chatsdk/native'),
    stdio: 'inherit',
    env: process.env,
  });
  if (result.error) fail(`无法启动 cargo audit：${result.error.message}`);
  if (result.status !== 0) fail(`ChatSDK Rust 依赖安全审计失败：${result.status}`);
}

function option(argumentsList, name) {
  const index = argumentsList.indexOf(name);
  return index >= 0 ? argumentsList[index + 1] : undefined;
}

function main() {
  const [command, subcommand, ...argumentsList] = process.argv.slice(2);
  if (command !== 'dependencies' || !['check', 'audit'].includes(subcommand)) {
    fail('ChatSDK CI 动作只支持 dependencies check/audit');
  }
  const scope = option(argumentsList, '--scope');
  if (subcommand === 'check') checkDependencies(scope);
  else auditDependencies(scope);
  process.stdout.write(`ChatSDK dependencies ${subcommand} passed\n`);
}

try {
  main();
} catch (error) {
  process.stderr.write(`ChatSDK CI 检查失败：${error.message}\n`);
  process.exitCode = 1;
}
