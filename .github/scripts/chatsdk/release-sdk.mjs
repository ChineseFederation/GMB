#!/usr/bin/env node

import { createHash } from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { existsSync, lstatSync, readFileSync } from 'node:fs';
import { basename, resolve } from 'node:path';

const root = resolve(process.env.GMB_REPOSITORY_ROOT || process.cwd());
const tagPrefix = 'chatsdk-v';
const releaseTitle = '聊天SDK · Release · SDK';
const releaseAssets = ['SHA256SUMS', 'chatsdk-release.json', 'chatsdk.tgz'];
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
  // 先显式判断存在性，避免把 Node 文件系统选项误识别成第一方契约字段。
  if (!existsSync(absolute)) fail(`缺少普通依赖文件：${path}`);
  const status = lstatSync(absolute);
  if (!status.isFile() || status.isSymbolicLink()) fail(`缺少普通依赖文件：${path}`);
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
    if (!/^[0-9a-f]{40}$/.test(String(action.split('@')[1] || ''))) {
      fail(`${path} 的 GitHub Action 未固定到 40 位提交：${action}`);
    }
  }
}

function checkDependencies(scopeName) {
  if (scopeName !== 'chatsdk') fail('ChatSDK 动作只接受 chatsdk 依赖作用域');
  const contract = JSON.parse(read('.github/dependencies.json'));
  if (contract.schema !== 1 || !contract.scopes?.chatsdk) fail('ChatSDK 依赖契约无效');
  exactArray(contract.scopes.chatsdk.workflows, expectedWorkflows, 'ChatSDK Workflow');
  exactArray(contract.scopes.chatsdk.requiredFiles, expectedFiles, 'ChatSDK 必需文件');
  if (!contract.dartApplications?.includes('chatsdk')
      || !contract.cargoProjects?.includes('chatsdk/native')
      || !contract.auditedScopes?.includes('chatsdk')) {
    fail('ChatSDK 依赖项目登记不完整');
  }
  for (const path of expectedFiles) read(path);
  const pubspec = read('chatsdk/pubspec.yaml');
  if (!/^name:\s*chat_sdk\s*$/m.test(pubspec)
      || !/^version:\s*\d+\.\d{1,2}\.\d{1,2}(?:\+\d+)?\s*$/m.test(pubspec)) {
    fail('ChatSDK pubspec 身份或软件版本无效');
  }
  if (!/^\[package\]\s*$/m.test(read('chatsdk/native/Cargo.toml'))) fail('ChatSDK Rust package 无效');
  for (const workflow of expectedWorkflows) {
    const source = read(workflow);
    checkPinnedActions(workflow, source);
    if (/\b(?:http|ws):\/\//u.test(source)) fail(`${workflow} 包含明文网络协议`);
  }
  const central = read('.github/workflows/gmb-repository.yml');
  for (const workflow of expectedWorkflows) {
    if (!central.includes(`inputs.pipeline == '${workflow}'`)) fail(`GMB 顶层入口缺少路由：${workflow}`);
  }
}

function auditDependencies(scopeName) {
  checkDependencies(scopeName);
  const result = spawnSync('cargo', ['audit', '--file', 'Cargo.lock'], {
    cwd: resolve(root, 'chatsdk/native'), stdio: 'inherit', env: process.env,
  });
  if (result.error) fail(`无法启动 cargo audit：${result.error.message}`);
  if (result.status !== 0) fail(`ChatSDK Rust 依赖安全审计失败：${result.status}`);
}

function parseOptions(argumentsList) {
  const values = Object.create(null);
  for (let index = 0; index < argumentsList.length; index += 1) {
    const key = argumentsList[index];
    if (!key.startsWith('--')) fail(`未知参数：${key}`);
    if (key === '--assets') {
      const assets = [];
      while (argumentsList[index + 1] && !argumentsList[index + 1].startsWith('--')) {
        assets.push(argumentsList[index + 1]);
        index += 1;
      }
      values.assets = assets;
      continue;
    }
    const value = argumentsList[index + 1];
    if (!value || value.startsWith('--')) fail(`参数缺少值：${key}`);
    values[key.slice(2)] = value;
    index += 1;
  }
  return values;
}

function requireOption(values, key) {
  const value = values[key];
  if (typeof value !== 'string' || value.length === 0) fail(`缺少参数：--${key}`);
  return value;
}

function runGh(argumentsList, { allowFailure = false } = {}) {
  const result = spawnSync('gh', argumentsList, {
    cwd: root, encoding: 'utf8', env: process.env, maxBuffer: 32 * 1024 * 1024,
  });
  if (result.error) fail(`无法启动 gh：${result.error.message}`);
  if (result.status !== 0 && !allowFailure) {
    fail(`GitHub API 失败：${String(result.stderr || result.stdout).trim()}`);
  }
  return result;
}

function ghJSON(argumentsList) {
  const result = runGh(argumentsList);
  try {
    return JSON.parse(result.stdout);
  } catch {
    fail('GitHub API 返回的不是有效 JSON');
  }
}

function semver(value, label) {
  const match = String(value || '').match(/^(0|[1-9][0-9]*)\.(\d{1,2})\.(\d{1,2})$/);
  if (!match) fail(`${label}必须是三段软件版本且后两段不超过两位`);
  const parts = match.slice(1).map(Number);
  if (parts[1] > 99 || parts[2] > 99) fail(`${label}后两段不能超过 99`);
  return parts;
}

function compareVersion(left, right) {
  for (let index = 0; index < 3; index += 1) {
    if (left[index] !== right[index]) return left[index] - right[index];
  }
  return 0;
}

function nextVersion(parts) {
  let [major, minor, patch] = parts;
  patch += 1;
  if (patch > 99) { patch = 0; minor += 1; }
  if (minor > 99) { minor = 0; major += 1; }
  return `${major}.${minor}.${patch}`;
}

function nextSemanticRelease(values) {
  if (requireOption(values, 'prefix') !== tagPrefix) fail('ChatSDK Tag 前缀错误');
  const seedText = requireOption(values, 'seed');
  const seed = semver(seedText, 'ChatSDK 种子版本');
  const pages = ghJSON(['api', '--paginate', '--slurp', 'repos/{owner}/{repo}/releases?per_page=100']);
  const releases = Array.isArray(pages) ? pages.flat() : [];
  const versions = releases
    .filter((release) => release?.draft === false && release?.prerelease === false)
    .map((release) => String(release?.tag_name || '').match(/^chatsdk-v(\d+\.\d{1,2}\.\d{1,2})$/)?.[1])
    .filter(Boolean)
    .map((value) => semver(value, 'GitHub ChatSDK Release 版本'))
    .sort(compareVersion);
  if (versions.length === 0 || compareVersion(seed, versions.at(-1)) > 0) {
    process.stdout.write(seedText);
    return;
  }
  process.stdout.write(nextVersion(versions.at(-1)));
}

function githubFile(path, sourceSHA) {
  const value = ghJSON(['api', `repos/{owner}/{repo}/contents/${path}?ref=${sourceSHA}`]);
  if (value?.encoding !== 'base64' || typeof value.content !== 'string') {
    fail(`GitHub 源文件响应无效：${path}`);
  }
  return Buffer.from(value.content.replace(/\s/g, ''), 'base64').toString('utf8');
}

function verifyReleaseSource(values) {
  const ciRunID = Number(requireOption(values, 'ci-run-id'));
  const versionTag = requireOption(values, 'version-tag');
  const sourceSHA = requireOption(values, 'source-sha');
  const softwareVersion = requireOption(values, 'software-version');
  if (!Number.isSafeInteger(ciRunID) || ciRunID <= 0) fail('ChatSDK CI run_id 无效');
  if (!/^[0-9a-f]{40}$/.test(sourceSHA)) fail('ChatSDK source_sha 无效');
  semver(softwareVersion, 'ChatSDK Release 版本');
  if (versionTag !== `${tagPrefix}${softwareVersion}`
      || requireOption(values, 'prefix') !== tagPrefix
      || requireOption(values, 'product-id') !== 'chatsdk'
      || requireOption(values, 'target') !== 'sdk'
      || requireOption(values, 'workflow') !== 'chatsdk/ci-sdk.yml') {
    fail('ChatSDK Release 产品、平台、Workflow 或 Tag 身份无效');
  }
  const run = ghJSON(['api', `repos/{owner}/{repo}/actions/runs/${ciRunID}`]);
  if (run?.id !== ciRunID || run?.status !== 'completed' || run?.conclusion !== 'success'
      || run?.event !== 'workflow_dispatch' || run?.head_branch !== 'main'
      || run?.head_sha !== sourceSHA || run?.display_title !== '聊天SDK · CI · SDK'
      || !/(?:^|\/)gmb-repository\.yml(?:@|$)/.test(String(run?.path || ''))
      || run?.head_repository?.full_name !== 'ChineseFederation/GMB') {
    fail('ChatSDK Release 所绑定 CI 不是准确成功终态');
  }
  const pubspec = githubFile('chatsdk/pubspec.yaml', sourceSHA);
  const version = pubspec.match(/^version:\s*(\d+\.\d{1,2}\.\d{1,2})(?:\+\d+)?\s*$/m)?.[1];
  if (version !== softwareVersion) fail('ChatSDK Release 版本与成功 CI 源码不一致');
}

function sha256(value) {
  return createHash('sha256').update(value).digest('hex');
}

function exactMarker(body, name, pattern) {
  const matches = [...String(body || '').matchAll(new RegExp(`${name}:(${pattern})(?=\\s|$)`, 'g'))];
  if (matches.length !== 1) fail(`ChatSDK Release ${name} 标记无效`);
  return matches[0][1];
}

function tagCommitSHA(tag) {
  let object = ghJSON(['api', `repos/{owner}/{repo}/git/ref/tags/${encodeURIComponent(tag)}`])?.object;
  if (object?.type === 'tag') object = ghJSON(['api', `repos/{owner}/{repo}/git/tags/${object.sha}`])?.object;
  if (object?.type !== 'commit' || !/^[0-9a-f]{40}$/.test(String(object?.sha || ''))) {
    fail('ChatSDK Release Tag 未绑定准确提交');
  }
  return object.sha;
}

function verifyLocalAssets(paths, tag, sourceSHA) {
  const byName = Object.create(null);
  for (const path of paths) {
    if (!existsSync(path)) fail(`ChatSDK 正式资产无效：${path}`);
    const status = lstatSync(path);
    if (!status.isFile() || status.isSymbolicLink() || status.size <= 0) fail(`ChatSDK 正式资产无效：${path}`);
    const name = basename(path);
    if (byName[name]) fail(`ChatSDK 正式资产重名：${name}`);
    byName[name] = { path, bytes: readFileSync(path) };
  }
  exactArray(Object.keys(byName), releaseAssets, 'ChatSDK 正式资产');
  const manifest = JSON.parse(byName['chatsdk-release.json'].bytes.toString('utf8'));
  const version = tag.slice(tagPrefix.length);
  if (manifest?.product_id !== 'chatsdk' || manifest?.package_name !== 'chat_sdk'
      || manifest?.git_commit_sha !== sourceSHA || manifest?.software_version !== version
      || !Array.isArray(manifest.platforms) || manifest.platforms.length !== 3
      || !Array.isArray(manifest.files) || manifest.files.length === 0) {
    fail('ChatSDK 正式 manifest 内容无效');
  }
  const lines = byName.SHA256SUMS.bytes.toString('utf8').trimEnd().split('\n');
  const expected = [
    `${sha256(byName['chatsdk.tgz'].bytes)}  chatsdk.tgz`,
    `${sha256(byName['chatsdk-release.json'].bytes)}  chatsdk-release.json`,
  ];
  if (JSON.stringify(lines) !== JSON.stringify(expected)) fail('ChatSDK SHA256SUMS 内容无效');
}

function verifyRemoteRelease(tag, sourceSHA, expectedBody) {
  const release = ghJSON(['api', `repos/{owner}/{repo}/releases/tags/${encodeURIComponent(tag)}`]);
  if (!Number.isSafeInteger(release?.id) || release.id <= 0 || release.tag_name !== tag
      || release.name !== releaseTitle || release.draft !== false || release.prerelease !== false
      || String(release.body || '') !== expectedBody || !Array.isArray(release.assets)
      || release.assets.length !== 3
      || release.assets.some((asset) => asset?.state !== 'uploaded'
        || !Number.isSafeInteger(asset?.id) || asset.id <= 0
        || !Number.isSafeInteger(asset?.size) || asset.size <= 0)) {
    fail('ChatSDK 正式 Release 回读身份或上传状态无效');
  }
  exactArray(release.assets.map((asset) => asset.name), releaseAssets, 'ChatSDK 远端正式资产');
  if (exactMarker(release.body, 'GMB_RELEASE_SOURCE_SHA', '[0-9a-f]{40}') !== sourceSHA) {
    fail('ChatSDK 正式 Release 源码标记不一致');
  }
  exactMarker(release.body, 'GMB_RELEASE_CI_RUN_ID', '[1-9][0-9]*');
  exactMarker(release.body, 'GMB_RELEASE_RUN_ID', '[1-9][0-9]*');
  if (tagCommitSHA(tag) !== sourceSHA) fail('ChatSDK 正式 Release Tag 源码不一致');
}

function createGitHubRelease(values) {
  const tag = requireOption(values, 'tag');
  const sourceSHA = requireOption(values, 'source-sha');
  const title = requireOption(values, 'title');
  const notes = requireOption(values, 'notes');
  if (title !== releaseTitle || values.latest !== 'false' || !/^[0-9a-f]{40}$/.test(sourceSHA)
      || !/^chatsdk-v\d+\.\d{1,2}\.\d{1,2}$/.test(tag)) {
    fail('ChatSDK 正式 Release 参数无效');
  }
  exactMarker(notes, 'GMB_RELEASE_CI_RUN_ID', '[1-9][0-9]*');
  exactMarker(notes, 'GMB_RELEASE_RUN_ID', '[1-9][0-9]*');
  if (notes.includes('GMB_RELEASE_SOURCE_SHA:')) fail('ChatSDK source 标记只能由 Release 工具写入');
  const assets = Array.isArray(values.assets) ? values.assets : [];
  verifyLocalAssets(assets, tag, sourceSHA);
  const body = `${notes.trimEnd()}\nGMB_RELEASE_SOURCE_SHA:${sourceSHA}`;
  runGh([
    'release', 'create', tag, '--target', sourceSHA, '--title', title,
    '--notes', body, '--latest=false', ...assets,
  ]);
  try {
    verifyRemoteRelease(tag, sourceSHA, body);
  } catch (error) {
    runGh(['release', 'delete', tag, '--yes', '--cleanup-tag'], { allowFailure: true });
    throw error;
  }
}

function main() {
  const [command, subcommand, ...argumentsList] = process.argv.slice(2);
  const values = parseOptions(argumentsList);
  if (command === 'dependencies' && subcommand === 'check') checkDependencies(values.scope);
  else if (command === 'dependencies' && subcommand === 'audit') auditDependencies(values.scope);
  else if (command === 'version-tag' && subcommand === 'next-semantic-release') nextSemanticRelease(values);
  else if (command === 'version-tag' && subcommand === 'verify-release-source') verifyReleaseSource(values);
  else if (command === 'github-release' && subcommand === undefined) createGitHubRelease(values);
  else fail('不支持的 ChatSDK Release 命令');
}

try {
  main();
} catch (error) {
  process.stderr.write(`ChatSDK Release 检查失败：${error.message}\n`);
  process.exitCode = 1;
}
