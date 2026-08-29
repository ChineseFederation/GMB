#!/usr/bin/env node

// CitizenSDK 确定性候选打包器。源码只读，所有候选和归档必须落在源码树之外。
import { createHash } from 'node:crypto';
import { gzipSync } from 'node:zlib';
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

const PRODUCT_ID = 'citizensdk';
const PACKAGE_NAME = 'citizen_sdk';
const CONSOLE_TARGET_ROOT = '/Users/rhett/Only/console/target/citizensdk';
const ROOT_FILES = [
  '.gitignore',
  'Cargo.lock',
  'Cargo.toml',
  'LICENSE-GPL-3.0',
  'LICENSE-MIT',
  'README.md',
  'THIRD_PARTY_NOTICES.md',
  'analysis_options.yaml',
  'pubspec.lock',
  'pubspec.yaml',
];
const ROOT_DIRECTORIES = ['android', 'assets', 'docs', 'ios', 'lib', 'native', 'scripts', 'test'];
const FORBIDDEN_DIRECTORIES = new Set([
  '.dart_tool', '.gradle', 'DerivedData', 'Pods', 'build', 'target',
]);
const NATIVE_FILES = Object.freeze({
  'android/src/main/jniLibs/arm64-v8a/libsmoldot.so': 'android/arm64-v8a/libsmoldot.so',
  'ios/libsmoldot.a': 'ios/libsmoldot.a',
  'ios/exported_symbols.txt': 'ios/exported_symbols.txt',
});

function fail(message) {
  throw new Error(message);
}

function sha256File(path) {
  return createHash('sha256').update(readFileSync(path)).digest('hex');
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

function assertOutsideSource(source, target, label) {
  const sourcePrefix = `${resolve(source)}${sep}`;
  const resolvedTarget = resolve(target);
  if (resolvedTarget === resolve(source) || resolvedTarget.startsWith(sourcePrefix)) {
    fail(`${label} 禁止位于 CitizenSDK 源码树：${resolvedTarget}`);
  }
}

function assertLocalTarget(path, label) {
  if (process.env.GITHUB_ACTIONS === 'true') return;
  const root = resolve(CONSOLE_TARGET_ROOT);
  const target = resolve(path);
  if (target !== root && !target.startsWith(`${root}${sep}`)) {
    fail(`${label} 的本地路径必须位于 ${root}：${target}`);
  }
}

function ensureNewDirectory(path, source, label) {
  assertOutsideSource(source, path, label);
  if (existsSync(path)) fail(`${label} 已存在，拒绝覆盖：${path}`);
  mkdirSync(path, { recursive: true, mode: 0o700 });
}

function copySourceTree(source, output, relativePath) {
  const sourcePath = join(source, ...relativePath.split('/'));
  const info = lstatSync(sourcePath);
  if (info.isSymbolicLink()) fail(`SDK 候选禁止符号链接：${relativePath}`);
  if (info.isDirectory()) {
    if (FORBIDDEN_DIRECTORIES.has(relativePath.split('/').at(-1))) {
      fail(`SDK 源码包含编译目录：${relativePath}`);
    }
    mkdirSync(join(output, ...relativePath.split('/')), { recursive: true, mode: 0o700 });
    for (const name of readdirSync(sourcePath).sort()) {
      copySourceTree(source, output, `${relativePath}/${name}`);
    }
    return;
  }
  if (!info.isFile()) fail(`SDK 候选只允许普通文件和目录：${relativePath}`);
  if (/\.(?:a|dylib|dll|exe|o|so)$/i.test(relativePath) || relativePath.endsWith('/exported_symbols.txt')) {
    fail(`SDK 源码树包含原生编译产物：${relativePath}`);
  }
  const destination = join(output, ...relativePath.split('/'));
  mkdirSync(dirname(destination), { recursive: true, mode: 0o700 });
  copyFileSync(sourcePath, destination);
}

function regularFiles(root) {
  const files = [];
  const visit = (directory) => {
    for (const name of readdirSync(directory).sort()) {
      const path = join(directory, name);
      const info = lstatSync(path);
      const relativePath = relative(root, path).split(sep).join('/');
      if (info.isSymbolicLink()) fail(`SDK 候选禁止符号链接：${relativePath}`);
      if (info.isDirectory()) visit(path);
      else if (info.isFile()) files.push(relativePath);
      else fail(`SDK 候选只允许普通文件和目录：${relativePath}`);
    }
  };
  visit(root);
  return files.sort();
}

function replaceExact(path, pattern, replacement, label) {
  const source = readFileSync(path, 'utf8');
  const matches = source.match(pattern);
  if (!matches || matches.length !== 1) fail(`${label} 版本字段不唯一`);
  writeFileSync(path, source.replace(pattern, replacement));
}

function applySoftwareVersion(output, version) {
  replaceExact(join(output, 'pubspec.yaml'), /^version: \d+\.\d{1,2}\.\d{1,2}$/gm, `version: ${version}`, 'pubspec.yaml');
  replaceExact(join(output, 'android/build.gradle'), /^version = '\d+\.\d{1,2}\.\d{1,2}'$/gm, `version = '${version}'`, 'android/build.gradle');
  replaceExact(join(output, 'ios/citizen_sdk.podspec'), /^  s\.version\s+= '\d+\.\d{1,2}\.\d{1,2}'$/gm, `  s.version          = '${version}'`, 'citizen_sdk.podspec');
}

function copyNativeFiles(nativeRoot, output) {
  for (const [destinationPath, sourcePath] of Object.entries(NATIVE_FILES)) {
    const source = join(nativeRoot, ...sourcePath.split('/'));
    if (!existsSync(source) || !lstatSync(source).isFile()) fail(`缺少原生产物：${sourcePath}`);
    const destination = join(output, ...destinationPath.split('/'));
    mkdirSync(dirname(destination), { recursive: true, mode: 0o700 });
    copyFileSync(source, destination);
  }
}

export function assertNoSecrets(root) {
  const forbiddenName = /(^|\/)(\.env(?:\.|$)|\.dev\.vars(?:\.|$)|.*\.(?:jks|keystore|p8|p12|pem))$/i;
  // 分段构造使扫描器源码本身不携带完整 PEM 标记，同时仍逐字节检查候选内容。
  const privateMaterial = Buffer.from(['PRIVATE', ' KEY-----'].join(''));
  for (const relativePath of regularFiles(root)) {
    if (forbiddenName.test(relativePath)) fail(`SDK 候选包含禁止的本地或密钥文件：${relativePath}`);
    if (readFileSync(join(root, ...relativePath.split('/'))).includes(privateMaterial)) {
      fail(`SDK 候选疑似包含私钥材料：${relativePath}`);
    }
  }
}

function fileEntries(root, paths) {
  return paths.map((path) => ({ path, sha256: sha256File(join(root, ...path.split('/'))) }));
}

function writeOctal(buffer, offset, length, value) {
  const text = value.toString(8).padStart(length - 1, '0');
  if (text.length >= length) fail('CitizenSDK 归档字段超过 tar 限制');
  buffer.write(`${text}\0`, offset, length, 'ascii');
}

function deterministicTar(candidatePath) {
  const chunks = [];
  for (const relativePath of regularFiles(candidatePath)) {
    if (Buffer.byteLength(relativePath) > 100) fail(`CitizenSDK 归档路径过长：${relativePath}`);
    const path = join(candidatePath, ...relativePath.split('/'));
    const content = readFileSync(path);
    const header = Buffer.alloc(512);
    header.write(relativePath, 0, 100, 'utf8');
    writeOctal(header, 100, 8, (lstatSync(path).mode & 0o111) === 0 ? 0o600 : 0o700);
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

export function verifyCitizenSdkRelease(candidatePath, expectedGitSha = null) {
  const candidate = resolve(candidatePath);
  if (!existsSync(candidate) || lstatSync(candidate).isSymbolicLink() || !lstatSync(candidate).isDirectory()) {
    fail('CitizenSDK 候选目录不存在或不是普通目录');
  }
  const manifestPath = join(candidate, 'citizensdk-release.json');
  const sumsPath = join(candidate, 'SHA256SUMS');
  if (!existsSync(manifestPath) || !existsSync(sumsPath)) fail('CitizenSDK 候选缺少正式清单');
  const manifest = JSON.parse(readFileSync(manifestPath, 'utf8'));
  const keys = Object.keys(manifest).sort();
  const expectedKeys = ['files', 'git_commit_sha', 'package_name', 'platforms', 'product_id', 'software_version'];
  if (JSON.stringify(keys) !== JSON.stringify(expectedKeys)) fail('CitizenSDK 正式清单字段集合不正确');
  if (manifest.product_id !== PRODUCT_ID || manifest.package_name !== PACKAGE_NAME) fail('CitizenSDK 候选产品身份不正确');
  if (!/^\d+\.\d{1,2}\.\d{1,2}$/.test(manifest.software_version)) fail('CitizenSDK 候选版本无效');
  if (!/^[0-9a-f]{40}$/.test(manifest.git_commit_sha)) fail('CitizenSDK 候选 Git SHA 无效');
  if (expectedGitSha !== null && manifest.git_commit_sha !== expectedGitSha) fail('CitizenSDK 候选 Git SHA 不匹配');
  const expectedPlatforms = [
    { abi: 'arm64-v8a', platform: 'android' },
    { abi: 'arm64', platform: 'ios' },
  ];
  if (stableJson(manifest.platforms) !== stableJson(expectedPlatforms)) fail('CitizenSDK 候选平台集合不正确');
  if (!Array.isArray(manifest.files) || manifest.files.length === 0) fail('CitizenSDK 候选文件清单为空');
  const paths = [];
  for (const entry of manifest.files) {
    if (!entry || Object.keys(entry).sort().join(',') !== 'path,sha256'
        || typeof entry.path !== 'string' || entry.path.startsWith('/')
        || entry.path.split('/').includes('..') || !/^[A-Za-z0-9._/-]+$/.test(entry.path)
        || !/^[0-9a-f]{64}$/.test(entry.sha256)) {
      fail('CitizenSDK 候选文件条目无效');
    }
    const path = join(candidate, ...entry.path.split('/'));
    if (!path.startsWith(`${candidate}${sep}`)) fail('CitizenSDK 候选文件路径越界');
    if (!existsSync(path) || !lstatSync(path).isFile() || sha256File(path) !== entry.sha256) {
      fail(`CitizenSDK 候选文件哈希不一致：${entry.path}`);
    }
    paths.push(entry.path);
  }
  if (JSON.stringify(paths) !== JSON.stringify([...paths].sort()) || new Set(paths).size !== paths.length) {
    fail('CitizenSDK 候选文件顺序或唯一性无效');
  }
  for (const required of ['pubspec.yaml', ...Object.keys(NATIVE_FILES)]) {
    if (!paths.includes(required)) fail(`CitizenSDK 候选缺少必需文件：${required}`);
  }
  const checksums = [
    ...manifest.files,
    { path: 'citizensdk-release.json', sha256: sha256File(manifestPath) },
  ].sort((left, right) => left.path.localeCompare(right.path));
  const expectedSums = `${checksums.map(({ sha256, path }) => `${sha256}  ${path}`).join('\n')}\n`;
  if (readFileSync(sumsPath, 'utf8') !== expectedSums) fail('CitizenSDK SHA256SUMS 不一致');
  const expectedFiles = [...paths, 'SHA256SUMS', 'citizensdk-release.json'].sort();
  if (JSON.stringify(regularFiles(candidate)) !== JSON.stringify(expectedFiles)) fail('CitizenSDK 候选包含未登记文件');
  assertNoSecrets(candidate);
  return manifest;
}

export function buildCitizenSdkRelease({ sourcePath, nativePath, outputPath, archivePath, gitCommitSha, softwareVersion }) {
  const source = resolve(sourcePath);
  const native = resolve(nativePath);
  const output = resolve(outputPath);
  const archive = resolve(archivePath);
  if (!existsSync(source) || !lstatSync(source).isDirectory()) fail('CitizenSDK 源码目录不存在');
  if (!existsSync(native) || !lstatSync(native).isDirectory()) fail('CitizenSDK 原生产物目录不存在');
  if (!/^[0-9a-f]{40}$/.test(gitCommitSha)) fail('Git commit SHA 必须是 40 位小写十六进制');
  if (!/^\d+\.\d{1,2}\.\d{1,2}$/.test(softwareVersion)) fail('CitizenSDK 软件版本无效');
  assertLocalTarget(native, '原生产物目录');
  assertLocalTarget(output, '候选目录');
  assertLocalTarget(archive, '归档');
  assertOutsideSource(source, native, '原生产物目录');
  assertOutsideSource(source, archive, '归档');
  assertOutsideSource(native, output, '候选目录');
  assertOutsideSource(output, archive, '归档');
  if (existsSync(archive)) fail(`归档已存在，拒绝覆盖：${archive}`);
  ensureNewDirectory(output, source, '候选目录');
  for (const path of ROOT_FILES) copySourceTree(source, output, path);
  for (const path of ROOT_DIRECTORIES) copySourceTree(source, output, path);
  applySoftwareVersion(output, softwareVersion);
  copyNativeFiles(native, output);
  const payloadPaths = regularFiles(output);
  const manifest = {
    product_id: PRODUCT_ID,
    package_name: PACKAGE_NAME,
    software_version: softwareVersion,
    git_commit_sha: gitCommitSha,
    platforms: [
      { platform: 'android', abi: 'arm64-v8a' },
      { platform: 'ios', abi: 'arm64' },
    ],
    files: fileEntries(output, payloadPaths),
  };
  const manifestPath = join(output, 'citizensdk-release.json');
  writeFileSync(manifestPath, prettyStableJson(manifest), { mode: 0o600 });
  const checksums = [
    ...manifest.files,
    { path: 'citizensdk-release.json', sha256: sha256File(manifestPath) },
  ].sort((left, right) => left.path.localeCompare(right.path));
  writeFileSync(join(output, 'SHA256SUMS'), `${checksums.map(({ sha256, path }) => `${sha256}  ${path}`).join('\n')}\n`, { mode: 0o600 });
  verifyCitizenSdkRelease(output, gitCommitSha);
  mkdirSync(dirname(archive), { recursive: true, mode: 0o700 });
  writeFileSync(archive, gzipSync(deterministicTar(output), { level: 9, mtime: 0 }), { mode: 0o600 });
  return manifest;
}

function parseArguments(argumentsList) {
  const values = {};
  for (let index = 0; index < argumentsList.length; index += 2) {
    const key = argumentsList[index];
    const value = argumentsList[index + 1];
    if (!key?.startsWith('--') || value === undefined) fail(`参数格式无效：${key || ''}`);
    values[key.slice(2)] = value;
  }
  return values;
}

const isMain = process.argv[1] && resolve(process.argv[1]) === resolve(fileURLToPath(import.meta.url));
if (isMain) {
  try {
    const values = parseArguments(process.argv.slice(2));
    if (values.verify) {
      const manifest = verifyCitizenSdkRelease(values.verify, values['expected-git-sha'] || null);
      process.stdout.write(`CitizenSDK 候选校验通过：${manifest.software_version}\n`);
    } else {
      for (const key of ['source', 'native', 'output', 'archive', 'git-sha', 'software-version']) {
        if (!values[key]) fail(`缺少参数 --${key}`);
      }
      const manifest = buildCitizenSdkRelease({
        sourcePath: values.source,
        nativePath: values.native,
        outputPath: values.output,
        archivePath: values.archive,
        gitCommitSha: values['git-sha'],
        softwareVersion: values['software-version'],
      });
      process.stdout.write(`CitizenSDK 候选已生成：${manifest.software_version}\n`);
    }
  } catch (error) {
    process.stderr.write(`${error instanceof Error ? error.message : String(error)}\n`);
    process.exitCode = 1;
  }
}
