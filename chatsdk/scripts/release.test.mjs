import assert from 'node:assert/strict';
import { mkdtemp, mkdir, readFile, rm, symlink, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';
import { gzipSync, gunzipSync } from 'node:zlib';

import { buildRelease, verifyReleaseAssets } from './release.mjs';

const SHA = '0123456789abcdef0123456789abcdef01234567';

async function fixture() {
  const root = await mkdtemp(join(tmpdir(), 'chatsdk-release-test-'));
  const source = join(root, 'source');
  const native = join(root, 'native');
  const output = join(root, 'output');
  await mkdir(source, { recursive: true });
  for (const file of ['README.md', 'analysis_options.yaml', 'pubspec.yaml', 'pubspec.lock']) {
    await writeFile(join(source, file), `${file}\n`);
  }
  for (const directory of ['include', 'ios', 'lib', 'native']) {
    await mkdir(join(source, directory), { recursive: true });
    await writeFile(join(source, directory, `${directory}.txt`), `${directory}\n`);
  }
  const artifacts = [
    ['android', 'libchat_sdk.so'],
    ['ios', 'libchat_sdk.a'],
    ['macos', 'libchat_sdk.dylib'],
  ];
  for (const [directory, name] of artifacts) {
    await mkdir(join(native, directory), { recursive: true });
    await writeFile(join(native, directory, name), `${directory}-binary`);
  }
  const build = () => buildRelease({
    source,
    native,
    output,
    archive: join(output, 'chatsdk.tgz'),
    gitSha: SHA,
    softwareVersion: '1.0.0',
  });
  return { root, source, native, output, build };
}

test('builds a deterministic three-asset ChatSDK release and verifies it', async () => {
  const item = await fixture();
  try {
    await item.build();
    const first = await readFile(join(item.output, 'chatsdk.tgz'));
    await item.build();
    const second = await readFile(join(item.output, 'chatsdk.tgz'));
    assert.deepEqual(first, second);
    const manifest = await verifyReleaseAssets(item.output, { expectedGitSha: SHA, softwareVersion: '1.0.0' });
    assert.equal(manifest.product_id, 'chatsdk');
    assert.equal(manifest.platforms.length, 3);
  } finally {
    await rm(item.root, { recursive: true, force: true });
  }
});

test('rejects the wrong source SHA', async () => {
  const item = await fixture();
  try {
    await item.build();
    await assert.rejects(
      verifyReleaseAssets(item.output, { expectedGitSha: 'f'.repeat(40), softwareVersion: '1.0.0' }),
      /源提交不一致/,
    );
  } finally {
    await rm(item.root, { recursive: true, force: true });
  }
});

test('rejects a missing native artifact', async () => {
  const item = await fixture();
  try {
    await rm(join(item.native, 'ios', 'libchat_sdk.a'));
    await assert.rejects(item.build(), /原生资产/);
  } finally {
    await rm(item.root, { recursive: true, force: true });
  }
});

test('rejects source symlinks', async () => {
  const item = await fixture();
  try {
    await symlink(join(item.source, 'README.md'), join(item.source, 'lib', 'linked.md'));
    await assert.rejects(item.build(), /禁止符号链接/);
  } finally {
    await rm(item.root, { recursive: true, force: true });
  }
});

test('rejects extra release assets and tampered checksums', async () => {
  const item = await fixture();
  try {
    await item.build();
    await writeFile(join(item.output, 'extra.bin'), 'extra');
    await assert.rejects(verifyReleaseAssets(item.output), /必须且只能包含三项资产/);
    await rm(join(item.output, 'extra.bin'));
    await writeFile(join(item.output, 'SHA256SUMS'), `${'0'.repeat(64)}  chatsdk.tgz\n${'0'.repeat(64)}  chatsdk-release.json\n`);
    await assert.rejects(verifyReleaseAssets(item.output), /校验和错误/);
  } finally {
    await rm(item.root, { recursive: true, force: true });
  }
});

test('rejects a path-traversal tar entry', async () => {
  const item = await fixture();
  try {
    await item.build();
    const archivePath = join(item.output, 'chatsdk.tgz');
    const tar = gunzipSync(await readFile(archivePath));
    tar.fill(0, 0, 100);
    Buffer.from('../escape/').copy(tar, 0);
    tar.fill(0x20, 148, 156);
    const checksum = tar.subarray(0, 512).reduce((sum, byte) => sum + byte, 0);
    Buffer.from(`${checksum.toString(8).padStart(6, '0')}\0 `).copy(tar, 148);
    await writeFile(archivePath, gzipSync(tar, { level: 9, mtime: 0 }));
    const manifest = await readFile(join(item.output, 'chatsdk-release.json'));
    const { createHash } = await import('node:crypto');
    const digest = (value) => createHash('sha256').update(value).digest('hex');
    const archive = await readFile(archivePath);
    await writeFile(
      join(item.output, 'SHA256SUMS'),
      `${digest(archive)}  chatsdk.tgz\n${digest(manifest)}  chatsdk-release.json\n`,
    );
    await assert.rejects(verifyReleaseAssets(item.output), /非法相对路径|不属于 ChatSDK/);
  } finally {
    await rm(item.root, { recursive: true, force: true });
  }
});
