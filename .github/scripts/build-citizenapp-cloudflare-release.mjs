#!/usr/bin/env node

import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { gunzipSync, gzipSync } from 'node:zlib';
import {
  copyFileSync,
  existsSync,
  mkdirSync,
  readFileSync,
  readdirSync,
  statSync,
  writeFileSync,
} from 'node:fs';
import { dirname, join, relative, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

const PRODUCT_ID = 'citizenapp-cloudflare';
const MIGRATION_NAME = /^citizenapp_(\d{4})\.sql$/;
const REQUIRED_PAYLOAD_FILES = [
  'worker.mjs',
  'wrangler.toml',
  'schema/citizenapp.sql',
  'package.json',
  'package-lock.json',
];
const RESOURCE_HEADERS = new Map([
  ['routes', 'routes'],
  ['stream', 'stream'],
  ['version_metadata', 'version_metadata'],
  ['r2_buckets', 'r2'],
  ['d1_databases', 'd1'],
  ['kv_namespaces', 'kv'],
  ['durable_objects.bindings', 'durable_objects'],
  ['exports.Chat', 'durable_object_exports'],
  ['queues.producers', 'queue_producers'],
  ['queues.consumers', 'queue_consumers'],
  ['triggers', 'cron'],
]);
const RESOURCE_KEYS = [...new Set(RESOURCE_HEADERS.values())].sort();

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

function resourceIdentity(category, block) {
  const value = (key) => new RegExp(`^${key}\\s*=\\s*"([^"]+)"`, 'm').exec(block)?.[1] || '';
  const identity = {
    routes: 'routes',
    stream: 'stream',
    version_metadata: value('binding'),
    r2: value('binding'),
    d1: value('binding'),
    kv: value('binding'),
    durable_objects: value('name'),
    durable_object_exports: /^\[exports\.([^\]]+)\]$/m.exec(block)?.[1] || '',
    queue_producers: value('binding'),
    queue_consumers: value('queue'),
    cron: 'triggers',
  }[category];
  if (!identity) fail(`资源分类 ${category} 缺少稳定标识`);
  return identity;
}

function ensureEmptyOutputDirectory(outputPath) {
  if (existsSync(outputPath)) fail(`候选输出目录已存在，拒绝覆盖：${outputPath}`);
  mkdirSync(outputPath, { recursive: true, mode: 0o700 });
}

function copyPayload(sourcePath, outputPath, relativePath) {
  const destination = join(outputPath, ...relativePath.split('/'));
  mkdirSync(dirname(destination), { recursive: true, mode: 0o700 });
  copyFileSync(sourcePath, destination);
  return destination;
}

function parsePackage(projectPath) {
  const packagePath = join(projectPath, 'package.json');
  const lockPath = join(projectPath, 'package-lock.json');
  const packageJson = JSON.parse(readFileSync(packagePath, 'utf8'));
  const lockJson = JSON.parse(readFileSync(lockPath, 'utf8'));
  const version = String(packageJson.version || '');
  if (!/^\d+\.\d{1,2}\.\d{1,2}$/.test(version)) fail(`后端软件版本无效：${version}`);
  if (lockJson.version !== version || lockJson.packages?.['']?.version !== version) {
    fail('package.json 与 package-lock.json 后端软件版本不一致');
  }
  return { packageJson, lockJson, version };
}

function migrationFiles(projectPath) {
  const migrationPath = join(projectPath, 'migrations');
  if (!existsSync(migrationPath)) return [];
  if (!statSync(migrationPath).isDirectory()) fail('migrations 必须是目录');
  const names = readdirSync(migrationPath).sort();
  const files = names.map((name, index) => {
    const match = MIGRATION_NAME.exec(name);
    if (!match) fail(`D1 migration 文件名无效：${name}`);
    const expected = String(index + 1).padStart(4, '0');
    if (match[1] !== expected) fail(`D1 migration 编号必须从 0001 连续递增：${name}`);
    const path = join(migrationPath, name);
    if (!statSync(path).isFile()) fail(`D1 migration 只能是普通 SQL 文件：${name}`);
    return { name, path };
  });
  return files;
}

export function normalizedResourceSections(configText) {
  const buckets = Object.fromEntries(RESOURCE_KEYS.map((key) => [key, []]));
  let active = null;
  let block = null;
  const flush = () => {
    if (active && block?.length) buckets[active].push(block.join('\n'));
    block = null;
  };
  for (const rawLine of configText.replace(/\r\n?/g, '\n').split('\n')) {
    const line = rawLine.trim();
    if (!line || line.startsWith('#')) continue;
    const arrayHeader = /^\[\[([^\]]+)\]\]$/.exec(line);
    const tableHeader = /^\[([^\]]+)\]$/.exec(line);
    if (arrayHeader || tableHeader) {
      flush();
      const header = (arrayHeader || tableHeader)[1];
      active = RESOURCE_HEADERS.get(header) || null;
      if (active) block = [arrayHeader ? `[[${header}]]` : `[${header}]`];
      continue;
    }
    if (/^(routes|stream)\s*=/.test(line)) {
      flush();
      const key = line.startsWith('routes') ? 'routes' : 'stream';
      buckets[key].push(line.replace(/\s+/g, ' '));
      active = null;
      continue;
    }
    if (active && block) block.push(line.replace(/\s+/g, ' '));
  }
  flush();
  return Object.fromEntries(RESOURCE_KEYS.map((key) => {
    const entries = buckets[key].map((entry) => ({
      identity: resourceIdentity(key, entry),
      sha256: sha256Bytes(entry),
    })).sort((a, b) => a.identity.localeCompare(b.identity));
    const identities = entries.map(({ identity }) => identity);
    if (new Set(identities).size !== identities.length) fail(`资源分类 ${key} 存在重复标识`);
    const normalized = buckets[key].sort().join('\n');
    return [key, {
      present: normalized.length > 0,
      sha256: normalized ? sha256Bytes(normalized) : null,
      entries,
    }];
  }));
}

function writeOctal(buffer, offset, length, value) {
  const text = value.toString(8).padStart(length - 1, '0');
  if (text.length >= length) fail('Release 归档字段超过 tar 限制');
  buffer.write(`${text}\0`, offset, length, 'ascii');
}

function deterministicTar(candidatePath) {
  const chunks = [];
  for (const relativePath of candidateFiles(candidatePath)) {
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
    const checksumText = checksum.toString(8).padStart(6, '0');
    header.write(`${checksumText}\0 `, 148, 8, 'ascii');
    chunks.push(header, content);
    const padding = (512 - (content.length % 512)) % 512;
    if (padding) chunks.push(Buffer.alloc(padding));
  }
  chunks.push(Buffer.alloc(1024));
  return Buffer.concat(chunks);
}

export function writeCitizenAppCloudflareArchive(candidatePath, archivePath) {
  const candidate = resolve(candidatePath);
  verifyCitizenAppCloudflareRelease(candidate);
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

export function extractCitizenAppCloudflareArchive(archivePath, outputPath, expectedGitCommitSha = null) {
  const archive = resolve(archivePath);
  const output = resolve(outputPath);
  if (!existsSync(archive) || !statSync(archive).isFile()) fail('Release 归档不存在');
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
    const actualChecksum = checksumHeader.reduce((sum, byte) => sum + byte, 0);
    if (storedChecksum !== actualChecksum) fail('Release 归档 header checksum 不一致');
    const nul = header.indexOf(0, 0);
    const relativePath = header.subarray(0, nul < 0 || nul > 100 ? 100 : nul).toString('utf8');
    if (!relativePath || relativePath.startsWith('/') || relativePath.split('/').includes('..')
        || !/^[A-Za-z0-9._/-]+$/.test(relativePath)) fail('Release 归档路径不安全');
    const type = header[156];
    if (type !== 0 && type !== '0'.charCodeAt(0)) fail('Release 归档只允许普通文件');
    const size = readTarOctal(header, 124, 12, 'size');
    if (!Number.isSafeInteger(size) || size < 0 || offset + size > tar.length) fail('Release 归档文件大小无效');
    const destination = join(output, ...relativePath.split('/'));
    const outputPrefix = `${output}${sep}`;
    if (!destination.startsWith(outputPrefix)) fail('Release 归档路径越界');
    mkdirSync(dirname(destination), { recursive: true, mode: 0o700 });
    writeFileSync(destination, tar.subarray(offset, offset + size), { mode: 0o600, flag: 'wx' });
    offset += Math.ceil(size / 512) * 512;
  }
  if (!ended || tar.subarray(offset).some((byte) => byte !== 0)) fail('Release 归档尾部无效');
  const manifest = verifyCitizenAppCloudflareRelease(output, expectedGitCommitSha);
  // gzip 的压缩字节会随 Node/zlib 版本变化；跨 runner 验证只能比较规范 tar 载荷。
  // gzip CRC、文件清单、逐文件哈希与 tar header 已在上方分别校验，不能再把压缩器
  // 实现细节误当成候选身份，否则同一候选从 GitHub runner 下载到本机必然可能误报。
  if (!deterministicTar(output).equals(tar)) fail('Release 归档不是规范的确定性候选');
  return manifest;
}

function toolVersions(projectPath) {
  const lock = JSON.parse(readFileSync(join(projectPath, 'package-lock.json'), 'utf8'));
  const wrangler = String(lock.packages?.['node_modules/wrangler']?.version || '');
  if (!/^\d+\.\d+\.\d+/.test(wrangler)) fail('package-lock.json 缺少锁定 Wrangler 版本');
  const npm = execFileSync('npm', ['--version'], { encoding: 'utf8' }).trim();
  return { node: process.version.replace(/^v/, ''), npm, wrangler };
}

function assertNoSecrets(candidatePath) {
  const forbiddenNames = /(^|\/)(\.env(?:\.|$)|\.dev\.vars(?:\.|$)|\.wrangler(?:\/|$)|.*\.(?:pem|p8|p12|jks|keystore))$/i;
  const privateMaterial = /-----BEGIN (?:[A-Z ]+ )?PRIVATE KEY-----/;
  const secretAssignment = /(?:DEPLOY|CF_DATA_TOKEN|CLOUDFLARE_API_TOKEN|CHAIN_SECRET|GH_TOKEN|APP_KEY|IOS_KEY|UPDATE_KEY|UPDATE_PASS)\s*[:=]\s*["'][^"']{6,}["']/;
  const visit = (directory) => {
    for (const name of readdirSync(directory).sort()) {
      const path = join(directory, name);
      const relativePath = relative(candidatePath, path).split(sep).join('/');
      if (forbiddenNames.test(relativePath)) fail(`候选包含禁止的本地或密钥文件：${relativePath}`);
      const info = statSync(path);
      if (info.isDirectory()) visit(path);
      else if (info.isFile()) {
        const content = readFileSync(path, 'utf8');
        if (privateMaterial.test(content) || secretAssignment.test(content)) {
          fail(`候选疑似包含私密材料：${relativePath}`);
        }
      } else fail(`候选只允许普通文件和目录：${relativePath}`);
    }
  };
  visit(candidatePath);
}

function assertExactKeys(value, expected, label) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) fail(`${label} 必须是对象`);
  const actual = Object.keys(value).sort();
  const wanted = [...expected].sort();
  if (JSON.stringify(actual) !== JSON.stringify(wanted)) fail(`${label} 字段集合不正确`);
}

function candidateFiles(candidatePath) {
  const results = [];
  const visit = (directory) => {
    for (const name of readdirSync(directory).sort()) {
      const path = join(directory, name);
      const info = statSync(path);
      if (info.isDirectory()) visit(path);
      else if (info.isFile()) results.push(relative(candidatePath, path).split(sep).join('/'));
      else fail('候选只允许普通文件和目录');
    }
  };
  visit(candidatePath);
  return results.sort();
}

export function verifyCitizenAppCloudflareRelease(candidatePath, expectedGitCommitSha = null) {
  const candidate = resolve(candidatePath);
  const manifestPath = join(candidate, 'release-manifest.json');
  if (!existsSync(manifestPath)) fail('候选缺少 release-manifest.json');
  const manifest = JSON.parse(readFileSync(manifestPath, 'utf8'));
  assertExactKeys(
    manifest,
    ['product_id', 'software_version', 'git_commit_sha', 'tools', 'files', 'migrations', 'resources'],
    'release manifest',
  );
  if (manifest.product_id !== PRODUCT_ID) fail('候选产品 id 不正确');
  if (!/^\d+\.\d{1,2}\.\d{1,2}$/.test(manifest.software_version)) fail('候选软件版本无效');
  if (!/^[0-9a-f]{40}$/.test(manifest.git_commit_sha)) fail('候选 Git SHA 无效');
  if (expectedGitCommitSha !== null && manifest.git_commit_sha !== expectedGitCommitSha) {
    fail('候选 Git SHA 与期望提交不一致');
  }
  assertExactKeys(manifest.tools, ['node', 'npm', 'wrangler'], '候选工具版本');
  assertExactKeys(manifest.resources, ['wrangler_sha256', 'categories'], '候选资源摘要');
  assertExactKeys(manifest.resources.categories, RESOURCE_KEYS, '候选资源分类');
  for (const key of RESOURCE_KEYS) {
    const category = manifest.resources.categories[key];
    assertExactKeys(category, ['present', 'sha256', 'entries'], `资源分类 ${key}`);
    if (!Array.isArray(category.entries)) fail(`资源分类 ${key} entries 必须是数组`);
    const identities = [];
    for (const entry of category.entries) {
      assertExactKeys(entry, ['identity', 'sha256'], `资源分类 ${key} entry`);
      if (typeof entry.identity !== 'string' || !entry.identity || !/^[0-9a-f]{64}$/.test(entry.sha256)) {
        fail(`资源分类 ${key} entry 无效`);
      }
      identities.push(entry.identity);
    }
    if (JSON.stringify(identities) !== JSON.stringify([...identities].sort())
        || new Set(identities).size !== identities.length) fail(`资源分类 ${key} entry 顺序或唯一性无效`);
    if (category.present !== (category.entries.length > 0)) fail(`资源分类 ${key} present 无效`);
    if (category.present !== (category.sha256 !== null)) fail(`资源分类 ${key} sha256 状态无效`);
    if (category.sha256 !== null && !/^[0-9a-f]{64}$/.test(category.sha256)) {
      fail(`资源分类 ${key} sha256 无效`);
    }
  }
  const configCategories = normalizedResourceSections(readFileSync(join(candidate, 'wrangler.toml'), 'utf8'));
  if (stableJson(configCategories) !== stableJson(manifest.resources.categories)) {
    fail('候选资源分类与 Wrangler 配置不一致');
  }
  if (!Array.isArray(manifest.files) || !Array.isArray(manifest.migrations)) fail('候选文件或 migration 清单无效');
  const expectedPayload = [...REQUIRED_PAYLOAD_FILES];
  manifest.migrations.forEach((entry, index) => {
    assertExactKeys(entry, ['name', 'sha256'], `migration ${index + 1}`);
    const match = MIGRATION_NAME.exec(entry.name);
    const expected = String(index + 1).padStart(4, '0');
    if (!match || match[1] !== expected) fail('候选 migration 编号不连续');
    if (sha256File(join(candidate, 'migrations', entry.name)) !== entry.sha256) {
      fail(`候选 migration 哈希不一致：${entry.name}`);
    }
    expectedPayload.push(`migrations/${entry.name}`);
  });
  if (manifest.files.length !== expectedPayload.length) fail('候选 payload 文件数量不正确');
  manifest.files.forEach((entry, index) => {
    assertExactKeys(entry, ['path', 'sha256'], `payload ${index + 1}`);
    if (entry.path !== expectedPayload[index]) fail('候选 payload 文件顺序不正确');
    const path = join(candidate, ...entry.path.split('/'));
    if (!existsSync(path) || sha256File(path) !== entry.sha256) fail(`候选文件哈希不一致：${entry.path}`);
  });
  const packageJson = JSON.parse(readFileSync(join(candidate, 'package.json'), 'utf8'));
  const lockJson = JSON.parse(readFileSync(join(candidate, 'package-lock.json'), 'utf8'));
  if (packageJson.version !== manifest.software_version
      || lockJson.version !== manifest.software_version
      || lockJson.packages?.['']?.version !== manifest.software_version) {
    fail('候选软件版本与 package 文件不一致');
  }
  if (sha256File(join(candidate, 'wrangler.toml')) !== manifest.resources.wrangler_sha256) {
    fail('候选 Wrangler 配置哈希不一致');
  }
  const expectedChecksums = [
    ...manifest.files,
    { path: 'release-manifest.json', sha256: sha256File(manifestPath) },
  ].sort((a, b) => a.path.localeCompare(b.path));
  const checksumText = `${expectedChecksums.map(({ sha256, path }) => `${sha256}  ${path}`).join('\n')}\n`;
  if (readFileSync(join(candidate, 'SHA256SUMS'), 'utf8') !== checksumText) fail('候选 SHA256SUMS 不一致');
  const expectedFiles = [...expectedPayload, 'release-manifest.json', 'SHA256SUMS'].sort();
  if (JSON.stringify(candidateFiles(candidate)) !== JSON.stringify(expectedFiles)) fail('候选包含未登记文件');
  assertNoSecrets(candidate);
  return manifest;
}

export function buildCitizenAppCloudflareRelease({ projectPath, bundlePath, outputPath, gitCommitSha, archivePath = null }) {
  const project = resolve(projectPath);
  const bundle = resolve(bundlePath);
  const output = resolve(outputPath);
  if (!/^[0-9a-f]{40}$/.test(gitCommitSha)) fail('Git commit SHA 必须是 40 位小写十六进制');
  if (!existsSync(bundle) || !statSync(bundle).isFile() || statSync(bundle).size === 0) {
    fail('Worker bundle 缺失或为空');
  }
  if (readFileSync(bundle, 'utf8').startsWith('------formdata-undici-')) {
    fail('Worker 候选必须是 Wrangler outdir 生成的确定性模块，不能使用随机 multipart outfile');
  }
  const { version } = parsePackage(project);
  const migrations = migrationFiles(project);
  ensureEmptyOutputDirectory(output);

  copyPayload(bundle, output, 'worker.mjs');
  copyPayload(join(project, 'wrangler.toml'), output, 'wrangler.toml');
  copyPayload(join(project, 'schema', 'citizenapp.sql'), output, 'schema/citizenapp.sql');
  copyPayload(join(project, 'package.json'), output, 'package.json');
  copyPayload(join(project, 'package-lock.json'), output, 'package-lock.json');
  for (const migration of migrations) copyPayload(migration.path, output, `migrations/${migration.name}`);

  const payloadPaths = [
    ...REQUIRED_PAYLOAD_FILES,
    ...migrations.map(({ name }) => `migrations/${name}`),
  ];
  const payload = payloadPaths.map((path) => ({ path, sha256: sha256File(join(output, ...path.split('/'))) }));
  const configText = readFileSync(join(project, 'wrangler.toml'), 'utf8');
  const manifest = {
    product_id: PRODUCT_ID,
    software_version: version,
    git_commit_sha: gitCommitSha,
    tools: toolVersions(project),
    files: payload,
    migrations: migrations.map(({ name }) => ({
      name,
      sha256: sha256File(join(output, 'migrations', name)),
    })),
    resources: {
      wrangler_sha256: sha256File(join(output, 'wrangler.toml')),
      categories: normalizedResourceSections(configText),
    },
  };
  const manifestPath = join(output, 'release-manifest.json');
  writeFileSync(manifestPath, prettyStableJson(manifest), { encoding: 'utf8', mode: 0o600 });
  const checksums = [
    ...payload,
    { path: 'release-manifest.json', sha256: sha256File(manifestPath) },
  ].sort((a, b) => a.path.localeCompare(b.path));
  writeFileSync(
    join(output, 'SHA256SUMS'),
    `${checksums.map(({ sha256, path }) => `${sha256}  ${path}`).join('\n')}\n`,
    { encoding: 'utf8', mode: 0o600 },
  );
  const verified = verifyCitizenAppCloudflareRelease(output, gitCommitSha);
  if (archivePath) writeCitizenAppCloudflareArchive(output, archivePath);
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
      const manifest = verifyCitizenAppCloudflareRelease(args.verify, args['expected-git-sha'] || null);
      if (args.archive) writeCitizenAppCloudflareArchive(args.verify, args.archive);
      process.stdout.write(`CitizenApp Cloudflare 候选校验通过：${manifest.software_version}\n`);
      process.exit(0);
    }
    if (args.extract) {
      if (!args.output) fail('缺少参数 --output');
      const manifest = extractCitizenAppCloudflareArchive(
        args.extract,
        args.output,
        args['expected-git-sha'] || null,
      );
      process.stdout.write(`CitizenApp Cloudflare Release 归档校验通过：${manifest.software_version}\n`);
      process.exit(0);
    }
    for (const key of ['project', 'bundle', 'output', 'git-sha']) {
      if (!args[key]) fail(`缺少参数 --${key}`);
    }
    const manifest = buildCitizenAppCloudflareRelease({
      projectPath: args.project,
      bundlePath: args.bundle,
      outputPath: args.output,
      gitCommitSha: args['git-sha'],
      archivePath: args.archive || null,
    });
    process.stdout.write(`CitizenApp Cloudflare 候选已生成：${manifest.software_version}\n`);
  } catch (error) {
    process.stderr.write(`${error instanceof Error ? error.message : String(error)}\n`);
    process.exitCode = 1;
  }
}
