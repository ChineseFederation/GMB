import assert from 'node:assert/strict';
import {
  copyFileSync,
  mkdirSync,
  mkdtempSync,
  rmSync,
  writeFileSync,
} from 'node:fs';
import { join } from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

import { assertNoSecrets } from './release.mjs';

const workRoot = process.env.CONSOLE_WORK_DIR;
if (!workRoot) {
  throw new Error('CitizenSDK 发布测试缺少 Console 中央工作目录');
}

test('私钥扫描器不误报自身且仍拒绝真实 PEM 标记', () => {
  const root = mkdtempSync(join(workRoot, 'release-secret-test-'));
  try {
    const scripts = join(root, 'scripts');
    mkdirSync(scripts);
    copyFileSync(fileURLToPath(new URL('./release.mjs', import.meta.url)), join(scripts, 'release.mjs'));
    assert.doesNotThrow(() => assertNoSecrets(root));

    const privateMarker = ['-----PRIVATE', ' KEY-----'].join('');
    writeFileSync(join(root, 'leaked-secret.txt'), privateMarker);
    assert.throws(() => assertNoSecrets(root), /SDK 候选疑似包含私钥材料/);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});
