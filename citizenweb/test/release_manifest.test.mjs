import assert from 'node:assert/strict';
import { afterEach, test } from 'node:test';
import {
  cpSync,
  existsSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  symlinkSync,
  writeFileSync,
} from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';

const projectPath = resolve(import.meta.dirname, '..');
const downloadButtonSource = readFileSync(join(projectPath, 'src', 'components', 'DownloadButton.tsx'), 'utf8');
const ecosystemSource = readFileSync(join(projectPath, 'src', 'pages', 'Ecosystem.tsx'), 'utf8');
const appSource = readFileSync(join(projectPath, 'src', 'App.tsx'), 'utf8');
const privacySource = readFileSync(join(projectPath, 'src', 'pages', 'Privacy.tsx'), 'utf8');
const supportSource = readFileSync(join(projectPath, 'src', 'pages', 'Support.tsx'), 'utf8');
const termsSource = readFileSync(join(projectPath, 'src', 'pages', 'Terms.tsx'), 'utf8');
const gitCommitSha = '1234567890abcdef1234567890abcdef12345678';
const temporaryRoots = [];
const flowRoot = process.env.PROGRAM_CONSOLE_FLOW_ROOT;
if (!flowRoot) throw new Error('缺少 PROGRAM_CONSOLE_FLOW_ROOT');
const releaseAction = resolve(flowRoot, 'gmb/scripts/citizenweb-ci-web.mjs');

function runRelease(argumentsList) {
  const result = spawnSync(process.execPath, [releaseAction, 'citizenweb-release', ...argumentsList], {
    cwd: resolve(import.meta.dirname, '../..'),
    encoding: 'utf8',
  });
  if (result.status !== 0) throw new Error((result.stderr || result.stdout).trim());
}

function buildCitizenWebRelease({ projectPath, distPath, outputPath, gitCommitSha, archivePath = null }) {
  const args = ['--project', projectPath, '--dist', distPath, '--output', outputPath, '--git-sha', gitCommitSha];
  if (archivePath) args.push('--archive', archivePath);
  runRelease(args);
  return JSON.parse(readFileSync(join(outputPath, 'release-manifest.json'), 'utf8'));
}

function extractCitizenWebArchive(archivePath, outputPath, expectedGitCommitSha = null) {
  const args = ['--extract', archivePath, '--output', outputPath];
  if (expectedGitCommitSha) args.push('--expected-git-sha', expectedGitCommitSha);
  runRelease(args);
  return JSON.parse(readFileSync(join(outputPath, 'release-manifest.json'), 'utf8'));
}

function verifyCitizenWebRelease(candidatePath, expectedGitCommitSha = null) {
  const args = ['--verify', candidatePath];
  if (expectedGitCommitSha) args.push('--expected-git-sha', expectedGitCommitSha);
  runRelease(args);
  return JSON.parse(readFileSync(join(candidatePath, 'release-manifest.json'), 'utf8'));
}

function writeCitizenWebArchive(candidatePath, archivePath) {
  runRelease(['--verify', candidatePath, '--archive', archivePath]);
}

function temporaryRoot() {
  const path = mkdtempSync(join(tmpdir(), 'gmb-citizenweb-release-'));
  temporaryRoots.push(path);
  return path;
}

function fixture(root, name = 'fixture') {
  const path = join(root, name);
  mkdirSync(join(path, 'dist', 'assets'), { recursive: true });
  cpSync(join(projectPath, 'package.json'), join(path, 'package.json'));
  cpSync(join(projectPath, 'package-lock.json'), join(path, 'package-lock.json'));
  writeFileSync(join(path, 'dist', 'index.html'), '<!doctype html><script src="/assets/app.js"></script>\n');
  writeFileSync(join(path, 'dist', 'assets', 'app.js'), 'console.log("citizenweb");\n');
  return path;
}

function build(root, name = 'candidate', source = fixture(root)) {
  const outputPath = join(root, name);
  const archivePath = join(root, `${name}.tgz`);
  const manifest = buildCitizenWebRelease({
    projectPath: source,
    distPath: join(source, 'dist'),
    outputPath,
    gitCommitSha,
    archivePath,
  });
  return { archivePath, manifest, outputPath };
}

afterEach(() => {
  for (const path of temporaryRoots.splice(0)) rmSync(path, { recursive: true, force: true });
});

test('公民链四端下载固定走后端白名单代理，不受 Runtime Release 影响', () => {
  assert.match(downloadButtonSource, /href=\{`\/api\$\{option\.downloadPath\}`\}/);
  for (const downloadPath of [
    '/download/citizenchain/macos-arm64',
    '/download/citizenchain/windows-x86_64',
    '/download/citizenchain/linux-arm64',
    '/download/citizenchain/linux-amd64',
  ]) {
    assert.match(ecosystemSource, new RegExp(`downloadPath: '${downloadPath}'`));
  }
  assert.doesNotMatch(ecosystemSource, /citizenchain-release|releaseTag:/);
});

test('App Store 前置公开页面固定提供用户协议、隐私政策和技术支持路由', () => {
  assert.match(appSource, /path="\/terms" element=\{<Terms \/>\}/);
  assert.match(appSource, /path="\/privacy" element=\{<Privacy \/>\}/);
  assert.match(appSource, /path="\/support" element=\{<Support \/>\}/);
  assert.match(privacySource, /公民钱包是离线冷钱包，不声明网络权限/);
  assert.match(privacySource, /不出售个人数据/);
  assert.match(privacySource, /选择“注销用户”/);
  assert.match(privacySource, /立即硬删除该 CID 在 Cloudflare 中可清除的账户投影/);
  assert.match(privacySource, /链上已经最终确认的 CID 注册、绑定、交易、发布或治理记录/);
  assert.match(supportSource, /禁止附带助记词、私钥、密码、验证码/);
  assert.match(termsSource, /用户保留其合法拥有/);
  assert.match(termsSource, /举报违法、侵权或违反本协议的内容/);
  assert.match(termsSource, /链上已经最终确认的公开记录不能由运营方单方面篡改或删除/);
});

test('相同官网构建与 Git SHA 生成完全一致的候选和归档', () => {
  const root = temporaryRoot();
  const source = fixture(root);
  const first = build(root, 'first', source);
  const second = build(root, 'second', source);

  assert.deepEqual(first.manifest, second.manifest);
  assert.deepEqual(readFileSync(first.archivePath), readFileSync(second.archivePath));
  assert.equal(
    readFileSync(join(first.outputPath, 'release-manifest.json'), 'utf8'),
    readFileSync(join(second.outputPath, 'release-manifest.json'), 'utf8'),
  );
});

test('官网公开版本标记绑定软件版本、Git SHA 和全部静态资源摘要', () => {
  const root = temporaryRoot();
  const candidate = build(root);
  const marker = JSON.parse(readFileSync(
    join(candidate.outputPath, 'dist', 'citizenweb-release.json'),
    'utf8',
  ));

  assert.deepEqual(marker, {
    product_id: 'citizenweb',
    software_version: candidate.manifest.software_version,
    git_commit_sha: gitCommitSha,
    assets_sha256: candidate.manifest.assets_sha256,
  });
  assert.ok(candidate.manifest.files.some(({ path }) => path === 'dist/assets/app.js'));
});

test('官网依赖 Cloudflare Pages 原生 SPA 回退，不发布全局资源改写规则', () => {
  assert.equal(existsSync(join(projectPath, 'public', '_redirects')), false);
});

test('规范归档可安全解包并复核为原候选', () => {
  const root = temporaryRoot();
  const candidate = build(root);
  const output = join(root, 'extracted');
  const manifest = extractCitizenWebArchive(candidate.archivePath, output, gitCommitSha);

  assert.deepEqual(manifest, candidate.manifest);
  assert.deepEqual(
    readFileSync(join(output, 'SHA256SUMS')),
    readFileSync(join(candidate.outputPath, 'SHA256SUMS')),
  );
});

test('文件篡改、未知文件和错误 Git SHA 均失败关闭', () => {
  const root = temporaryRoot();
  const first = build(root, 'tampered');
  assert.throws(
    () => verifyCitizenWebRelease(first.outputPath, '0'.repeat(40)),
    /候选 Git SHA 与期望提交不一致/,
  );
  writeFileSync(join(first.outputPath, 'dist', 'assets', 'app.js'), 'tampered\n');
  assert.throws(() => verifyCitizenWebRelease(first.outputPath, gitCommitSha), /候选文件哈希不一致/);

  const second = build(root, 'unknown', fixture(root, 'unknown-source'));
  writeFileSync(join(second.outputPath, 'dist', 'extra.txt'), 'extra\n');
  assert.throws(() => verifyCitizenWebRelease(second.outputPath, gitCommitSha), /候选包含未登记文件/);
});

test('候选拒绝私钥、符号链接和上一次构建遗留的版本标记', () => {
  const root = temporaryRoot();
  const privateSource = fixture(root, 'private-source');
  writeFileSync(
    join(privateSource, 'dist', 'private.pem'),
    '-----BEGIN PRIVATE KEY-----\nsecret\n-----END PRIVATE KEY-----\n',
  );
  assert.throws(() => buildCitizenWebRelease({
    projectPath: privateSource,
    distPath: join(privateSource, 'dist'),
    outputPath: join(root, 'private-output'),
    gitCommitSha,
  }), /候选包含禁止的本地或密钥文件/);

  const linkSource = fixture(root, 'link-source');
  symlinkSync(join(linkSource, 'dist', 'index.html'), join(linkSource, 'dist', 'linked.html'));
  assert.throws(() => buildCitizenWebRelease({
    projectPath: linkSource,
    distPath: join(linkSource, 'dist'),
    outputPath: join(root, 'link-output'),
    gitCommitSha,
  }), /候选禁止符号链接/);

  const staleSource = fixture(root, 'stale-source');
  writeFileSync(join(staleSource, 'dist', 'citizenweb-release.json'), '{}\n');
  assert.throws(() => buildCitizenWebRelease({
    projectPath: staleSource,
    distPath: join(staleSource, 'dist'),
    outputPath: join(root, 'stale-output'),
    gitCommitSha,
  }), /含上次构建的版本标记/);
});

test('同一候选归档只接受新路径，拒绝覆盖既有文件', () => {
  const root = temporaryRoot();
  const candidate = build(root);
  assert.throws(
    () => writeCitizenWebArchive(candidate.outputPath, candidate.archivePath),
    /Release 归档已存在，拒绝覆盖/,
  );
});
