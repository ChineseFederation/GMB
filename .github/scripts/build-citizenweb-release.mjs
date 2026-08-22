#!/usr/bin/env node

import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { gunzipSync, gzipSync } from 'node:zlib';
import {
  copyFileSync,
  existsSync,
  lstatSync,
  mkdirSync,
  readFileSync,
  readdirSync,
  writeFileSync,
} from 'node:fs';
import { dirname, join, relative, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

const PRODUCT_ID = 'citizenweb';
const VERSION_MARKER = 'dist/citizenweb-release.json';
const ROOT_PAYLOAD = ['package-lock.json', 'package.json'];

function fail(message) {
  throw new Error(message);
}

function sha256Bytes(bytes) {
  return createHash('sha256').update(bytes).digest('hex');
}

function sha256File(path) {
  return sha256Bytes(readFileSync(path));
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

function assertExactKeys(value, expected, label) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) fail(`${label} 必须是对象`);
  const actual = Object.keys(value).sort();
  const wanted = [...expected].sort();
  if (JSON.stringify(actual) !== JSON.stringify(wanted)) fail(`${label} 字段集合不正确`);
}

function ensureEmptyOutputDirectory(path) {
  if (existsSync(path)) fail(`候选输出目录已存在，拒绝覆盖：${path}`);
  mkdirSync(path, { recursive: true, mode: 0o700 });
}

function regularFiles(root) {
  const files = [];
  const visit = (directory) => {
    for (const name of readdirSync(directory).sort()) {
      const path = join(directory, name);
      const info = lstatSync(path);
      const relativePath = relative(root, path).split(sep).join('/');
      if (info.isSymbolicLink()) fail(`候选禁止符号链接：${relativePath}`);
      if (info.isDirectory()) visit(path);
      else if (info.isFile()) files.push(relativePath);
      else fail(`候选只允许普通文件和目录：${relativePath}`);
    }
  };
  visit(root);
  return files.sort();
}

function assertNoSecrets(root) {
  const forbiddenNames = /(^|\/)(\.env(?:\.|$)|\.dev\.vars(?:\.|$)|\.wrangler(?:\/|$)|.*\.(?:pem|p8|p12|jks|keystore))$/i;
  const privateMaterial = /-----BEGIN (?:[A-Z ]+ )?PRIVATE KEY-----/;
  const secretAssignment = /(?:DEPLOY|CF_DATA_TOKEN|CLOUDFLARE_API_TOKEN|GH_TOKEN|APP_KEY|IOS_KEY|UPDATE_KEY|UPDATE_PASS)\s*[:=]\s*["'][^"']{6,}["']/;
  for (const relativePath of regularFiles(root)) {
    if (forbiddenNames.test(relativePath)) fail(`候选包含禁止的本地或密钥文件：${relativePath}`);
    const content = readFileSync(join(root, ...relativePath.split('/')), 'utf8');
    if (privateMaterial.test(content) || secretAssignment.test(content)) {
      fail(`候选疑似包含私密材料：${relativePath}`);
    }
  }
}

function parsePackage(projectPath) {
  const packageJson = JSON.parse(readFileSync(join(projectPath, 'package.json'), 'utf8'));
  const lockJson = JSON.parse(readFileSync(join(projectPath, 'package-lock.json'), 'utf8'));
  const version = String(packageJson.version || '');
  if (!/^\d+\.\d{1,2}\.\d{1,2}$/.test(version)) fail(`官网软件版本无效：${version}`);
  if (lockJson.version !== version || lockJson.packages?.['']?.version !== version) {
    fail('package.json 与 package-lock.json 官网软件版本不一致');
  }
  return { lockJson, version };
}

function toolVersions(projectPath, lockJson) {
  const version = (name) => String(lockJson.packages?.[`node_modules/${name}`]?.version || '');
  const vite = version('vite');
  const wrangler = version('wrangler');
  if (!/^\d+\.\d+\.\d+/.test(vite) || !/^\d+\.\d+\.\d+/.test(wrangler)) {
    fail('package-lock.json 缺少锁定的 Vite 或 Wrangler 版本');
  }
  return {
    node: process.version.replace(/^v/, ''),
    npm: execFileSync('npm', ['--version'], { encoding: 'utf8' }).trim(),
    vite,
    wrangler,
  };
}

function copyPayload(sourceRoot, outputRoot, relativePath) {
  const destination = join(outputRoot, ...relativePath.split('/'));
  mkdirSync(dirname(destination), { recursive: true, mode: 0o700 });
  copyFileSync(join(sourceRoot, ...relativePath.split('/')), destination);
}

function fileEntries(root, paths) {
  return paths.map((path) => ({ path, sha256: sha256File(join(root, ...path.split('/'))) }));
}

function writeOctal(buffer, offset, length, value) {
  const text = value.toString(8).padStart(length - 1, '0');
  if (text.length >= length) fail('Release 归档字段超过 tar 限制');
  buffer.write(`${text}\0`, offset, length, 'ascii');
}

function deterministicTar(candidatePath) {
  const chunks = [];
  for (const relativePath of regularFiles(candidatePath)) {
    if (Buffer.byteLength(relativePath) > 100) fail(`Release 归档路径过长：${relativePath}`);
    const content = readFileSync(join(candidatePath, ...relativePath.split('/')));
    const header = Buffer.alloc(512);
    header.write(relativePath, 0, 100, 'utf8');
    writeOctal(header, 100, 8, 0o600);
    writeOctal(header, 108, 8, 0);
    writeOctal(header, 116, 8, 0);
    writeOctal(header, 124, 12, content.length);
    writeOctal(header, 136, 12, 0);
    header.fill(0x20, 148, 156);
    header[156] = '0'.charCodeAt(0);
    header.write('ustar\0', 257, 6, 'ascii');
    header.write('00', 263, 2, 'ascii');
    const checksum = header.reduce((sum, byte) => sum + byte, 0);
    header.write(`${checksum.toString(8).padStart(6, '0')}\0 `, 148, 8, 'ascii');
    chunks.push(header, content);
    const padding = (512 - (content.length % 512)) % 512;
    if (padding) chunks.push(Buffer.alloc(padding));
  }
  chunks.push(Buffer.alloc(1024));
  return Buffer.concat(chunks);
}

export function writeCitizenWebArchive(candidatePath, archivePath) {
  const candidate = resolve(candidatePath);
  verifyCitizenWebRelease(candidate);
  const archive = resolve(archivePath);
  if (existsSync(archive)) fail(`Release 归档已存在，拒绝覆盖：${archive}`);
  mkdirSync(dirname(archive), { recursive: true, mode: 0o700 });
  writeFileSync(archive, gzipSync(deterministicTar(candidate), { level: 9, mtime: 0 }), { mode: 0o600 });
  return sha256File(archive);
}

function readTarOctal(header, offset, length, label) {
  const value = header.subarray(offset, offset + length).toString('ascii').replace(/\0.*$/, '').trim();
  if (!/^[0-7]+$/.test(value)) fail(`Release 归档 ${label} 无效`);
  return Number.parseInt(value, 8);
}

export function extractCitizenWebArchive(archivePath, outputPath, expectedGitCommitSha = null) {
  const archive = resolve(archivePath);
  const output = resolve(outputPath);
  if (!existsSync(archive) || !lstatSync(archive).isFile()) fail('Release 归档不存在');
  ensureEmptyOutputDirectory(output);
  const tar = gunzipSync(readFileSync(archive));
  let offset = 0;
  let ended = false;
  while (offset + 512 <= tar.length) {
    const header = tar.subarray(offset, offset + 512);
    offset += 512;
    if (header.every((byte) => byte === 0)) {
      ended = true;
      break;
    }
    const storedChecksum = readTarOctal(header, 148, 8, 'checksum');
    const checksumHeader = Buffer.from(header);
    checksumHeader.fill(0x20, 148, 156);
    if (storedChecksum !== checksumHeader.reduce((sum, byte) => sum + byte, 0)) {
      fail('Release 归档 header checksum 不一致');
    }
    const nul = header.indexOf(0, 0);
    const relativePath = header.subarray(0, nul < 0 || nul > 100 ? 100 : nul).toString('utf8');
    if (!relativePath || relativePath.startsWith('/') || relativePath.split('/').includes('..')
        || !/^[A-Za-z0-9._/-]+$/.test(relativePath)) fail('Release 归档路径不安全');
    const type = header[156];
    if (type !== 0 && type !== '0'.charCodeAt(0)) fail('Release 归档只允许普通文件');
    const size = readTarOctal(header, 124, 12, 'size');
    if (!Number.isSafeInteger(size) || size < 0 || offset + size > tar.length) fail('Release 归档文件大小无效');
    const destination = join(output, ...relativePath.split('/'));
    if (!destination.startsWith(`${output}${sep}`)) fail('Release 归档路径越界');
    mkdirSync(dirname(destination), { recursive: true, mode: 0o700 });
    writeFileSync(destination, tar.subarray(offset, offset + size), { mode: 0o600, flag: 'wx' });
    offset += Math.ceil(size / 512) * 512;
  }
  if (!ended || tar.subarray(offset).some((byte) => byte !== 0)) fail('Release 归档尾部无效');
  const manifest = verifyCitizenWebRelease(output, expectedGitCommitSha);
  // gzip 只是传输封装，不是候选身份；不同 Node/zlib 版本允许产生不同压缩字节。
  // 身份由规范 tar、精确文件集合、manifest 与逐文件 SHA-256 共同确定。
  if (!deterministicTar(output).equals(tar)) {
    fail('Release 归档不是规范的确定性候选');
  }
  return manifest;
}

export function verifyCitizenWebRelease(candidatePath, expectedGitCommitSha = null) {
  const candidate = resolve(candidatePath);
  const manifestPath = join(candidate, 'release-manifest.json');
  if (!existsSync(manifestPath)) fail('候选缺少 release-manifest.json');
  const manifest = JSON.parse(readFileSync(manifestPath, 'utf8'));
  assertExactKeys(
    manifest,
    ['product_id', 'software_version', 'git_commit_sha', 'tools', 'assets_sha256', 'files'],
    'release manifest',
  );
  if (manifest.product_id !== PRODUCT_ID) fail('候选产品 id 不正确');
  if (!/^\d+\.\d{1,2}\.\d{1,2}$/.test(manifest.software_version)) fail('候选软件版本无效');
  if (!/^[0-9a-f]{40}$/.test(manifest.git_commit_sha)) fail('候选 Git SHA 无效');
  if (expectedGitCommitSha !== null && manifest.git_commit_sha !== expectedGitCommitSha) {
    fail('候选 Git SHA 与期望提交不一致');
  }
  assertExactKeys(manifest.tools, ['node', 'npm', 'vite', 'wrangler'], '候选工具版本');
  for (const value of Object.values(manifest.tools)) {
    if (typeof value !== 'string' || !value) fail('候选工具版本无效');
  }
  if (!/^[0-9a-f]{64}$/.test(manifest.assets_sha256)) fail('候选静态资源摘要无效');
  if (!Array.isArray(manifest.files) || manifest.files.length < 4) fail('候选文件清单无效');
  const paths = [];
  for (const [index, entry] of manifest.files.entries()) {
    assertExactKeys(entry, ['path', 'sha256'], `候选文件 ${index + 1}`);
    if (!/^(dist\/|package(?:-lock)?\.json$)[A-Za-z0-9._/-]*$/.test(entry.path)
        || !/^[0-9a-f]{64}$/.test(entry.sha256)) fail('候选文件条目无效');
    const path = join(candidate, ...entry.path.split('/'));
    if (!existsSync(path) || !lstatSync(path).isFile() || sha256File(path) !== entry.sha256) {
      fail(`候选文件哈希不一致：${entry.path}`);
    }
    paths.push(entry.path);
  }
  if (JSON.stringify(paths) !== JSON.stringify([...paths].sort()) || new Set(paths).size !== paths.length) {
    fail('候选文件顺序或唯一性无效');
  }
  for (const required of [...ROOT_PAYLOAD, 'dist/index.html', VERSION_MARKER]) {
    if (!paths.includes(required)) fail(`候选缺少必需文件：${required}`);
  }
  const packageJson = JSON.parse(readFileSync(join(candidate, 'package.json'), 'utf8'));
  const lockJson = JSON.parse(readFileSync(join(candidate, 'package-lock.json'), 'utf8'));
  if (packageJson.version !== manifest.software_version
      || lockJson.version !== manifest.software_version
      || lockJson.packages?.['']?.version !== manifest.software_version) {
    fail('候选软件版本与 package 文件不一致');
  }
  const assetEntries = manifest.files.filter(({ path }) => path.startsWith('dist/') && path !== VERSION_MARKER);
  if (sha256Bytes(stableJson(assetEntries)) !== manifest.assets_sha256) fail('候选静态资源摘要不一致');
  const marker = JSON.parse(readFileSync(join(candidate, ...VERSION_MARKER.split('/')), 'utf8'));
  assertExactKeys(marker, ['product_id', 'software_version', 'git_commit_sha', 'assets_sha256'], '官网版本标记');
  const expectedMarker = {
    product_id: PRODUCT_ID,
    software_version: manifest.software_version,
    git_commit_sha: manifest.git_commit_sha,
    assets_sha256: manifest.assets_sha256,
  };
  if (stableJson(marker) !== stableJson(expectedMarker)) fail('官网版本标记与 Release 候选不一致');
  const expectedChecksums = [
    ...manifest.files,
    { path: 'release-manifest.json', sha256: sha256File(manifestPath) },
  ].sort((a, b) => a.path.localeCompare(b.path));
  const checksumText = `${expectedChecksums.map(({ sha256, path }) => `${sha256}  ${path}`).join('\n')}\n`;
  if (readFileSync(join(candidate, 'SHA256SUMS'), 'utf8') !== checksumText) fail('候选 SHA256SUMS 不一致');
  const expectedFiles = [...paths, 'release-manifest.json', 'SHA256SUMS'].sort();
  if (JSON.stringify(regularFiles(candidate)) !== JSON.stringify(expectedFiles)) fail('候选包含未登记文件');
  assertNoSecrets(candidate);
  return manifest;
}

export function buildCitizenWebRelease({ projectPath, distPath, outputPath, gitCommitSha, archivePath = null }) {
  const project = resolve(projectPath);
  const sourceDist = resolve(distPath);
  const output = resolve(outputPath);
  if (!/^[0-9a-f]{40}$/.test(gitCommitSha)) fail('Git commit SHA 必须是 40 位小写十六进制');
  if (!existsSync(sourceDist) || !lstatSync(sourceDist).isDirectory()) fail('官网 dist 目录不存在');
  const distFiles = regularFiles(sourceDist);
  if (!distFiles.includes('index.html')) fail('官网 dist 缺少 index.html');
  if (distFiles.includes('citizenweb-release.json')) fail('官网 dist 含上次构建的版本标记，拒绝复用旧产物');
  assertNoSecrets(sourceDist);
  const { lockJson, version } = parsePackage(project);
  ensureEmptyOutputDirectory(output);
  for (const path of distFiles) copyPayload(sourceDist, join(output, 'dist'), path);
  for (const path of ROOT_PAYLOAD) copyPayload(project, output, path);
  const assetPaths = distFiles.map((path) => `dist/${path}`).sort();
  const assets = fileEntries(output, assetPaths);
  const assetsSha256 = sha256Bytes(stableJson(assets));
  const marker = {
    product_id: PRODUCT_ID,
    software_version: version,
    git_commit_sha: gitCommitSha,
    assets_sha256: assetsSha256,
  };
  writeFileSync(join(output, ...VERSION_MARKER.split('/')), prettyStableJson(marker), { mode: 0o600 });
  const payloadPaths = [...ROOT_PAYLOAD, ...assetPaths, VERSION_MARKER].sort();
  const manifest = {
    product_id: PRODUCT_ID,
    software_version: version,
    git_commit_sha: gitCommitSha,
    tools: toolVersions(project, lockJson),
    assets_sha256: assetsSha256,
    files: fileEntries(output, payloadPaths),
  };
  const manifestPath = join(output, 'release-manifest.json');
  writeFileSync(manifestPath, prettyStableJson(manifest), { mode: 0o600 });
  const checksums = [
    ...manifest.files,
    { path: 'release-manifest.json', sha256: sha256File(manifestPath) },
  ].sort((a, b) => a.path.localeCompare(b.path));
  writeFileSync(
    join(output, 'SHA256SUMS'),
    `${checksums.map(({ sha256, path }) => `${sha256}  ${path}`).join('\n')}\n`,
    { mode: 0o600 },
  );
  const verified = verifyCitizenWebRelease(output, gitCommitSha);
  if (archivePath) writeCitizenWebArchive(output, archivePath);
  return verified;
}

function parseArgs(argv) {
  const values = {};
  for (let index = 0; index < argv.length; index += 2) {
    const key = argv[index];
    const value = argv[index + 1];
    if (!key?.startsWith('--') || value === undefined) fail(`参数格式无效：${key || ''}`);
    values[key.slice(2)] = value;
  }
  return values;
}

const isMain = process.argv[1] && resolve(process.argv[1]) === resolve(fileURLToPath(import.meta.url));
if (isMain) {
  try {
    const args = parseArgs(process.argv.slice(2));
    if (args.verify) {
      const manifest = verifyCitizenWebRelease(args.verify, args['expected-git-sha'] || null);
      if (args.archive) writeCitizenWebArchive(args.verify, args.archive);
      process.stdout.write(`CitizenWeb 候选校验通过：${manifest.software_version}\n`);
      process.exit(0);
    }
    if (args.extract) {
      if (!args.output) fail('缺少参数 --output');
      const manifest = extractCitizenWebArchive(args.extract, args.output, args['expected-git-sha'] || null);
      process.stdout.write(`CitizenWeb Release 归档校验通过：${manifest.software_version}\n`);
      process.exit(0);
    }
    for (const key of ['project', 'dist', 'output', 'git-sha']) {
      if (!args[key]) fail(`缺少参数 --${key}`);
    }
    const manifest = buildCitizenWebRelease({
      projectPath: args.project,
      distPath: args.dist,
      outputPath: args.output,
      gitCommitSha: args['git-sha'],
      archivePath: args.archive || null,
    });
    process.stdout.write(`CitizenWeb 候选已生成：${manifest.software_version}\n`);
  } catch (error) {
    process.stderr.write(`${error instanceof Error ? error.message : String(error)}\n`);
    process.exitCode = 1;
  }
}
