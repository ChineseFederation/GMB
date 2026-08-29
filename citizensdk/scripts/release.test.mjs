import assert from 'node:assert/strict';
import {
  cpSync,
  copyFileSync,
  existsSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  symlinkSync,
  writeFileSync,
} from 'node:fs';
import { spawnSync } from 'node:child_process';
import { basename, dirname, join, resolve } from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

import {
  assertChainAssets,
  assertLicenseSources,
  assertNoSecrets,
  assertSdkRootLocks,
  assertSdkTestContracts,
  assertSignerSource,
  assertSmoldotDartSource,
  assertSmoldotLocks,
  assertSmoldotRustSource,
  assertSourceFixtures,
  buildCitizenSdkRelease,
  verifyCitizenSdkRelease,
} from './release.mjs';

const workRoot = process.env.CONSOLE_WORK_DIR;
if (!workRoot) {
  throw new Error('CitizenSDK 发布测试缺少 Console 中央工作目录');
}
mkdirSync(workRoot, { recursive: true });

const citizenSdkRoot = fileURLToPath(new URL('../', import.meta.url));

function writeNativeFixture(root) {
  const native = join(root, 'native-output');
  for (const [path, value] of [
    ['android/arm64-v8a/libsmoldot.so', 'android-native'],
    ['ios/libsmoldot.a', 'ios-native'],
    ['ios/exported_symbols.txt', '_smoldot_test\n'],
  ]) {
    const destination = join(native, ...path.split('/'));
    mkdirSync(dirname(destination), { recursive: true });
    writeFileSync(destination, value);
  }
  return native;
}

// 中文注释：设备与 Simulator 必须共用唯一 iOS 16 常量，并把它直接传给各自
// Cargo 子进程；只固定 podspec 无法约束 Rust 依赖中由 C 编译器生成的对象版本。
function assertIosDeploymentTargetContract(source) {
  const declarations = source.match(/^[ \t]*ios_deployment_target=.*$/gm) ?? [];
  assert.deepEqual(declarations, ['ios_deployment_target=16.0']);

  const environmentPrefix = '  IPHONEOS_DEPLOYMENT_TARGET="$ios_deployment_target" \\\n';
  assert.equal(source.split(environmentPrefix).length - 1, 2);

  const functionBody = (name) => {
    const startMarker = `${name}() {\n`;
    const start = source.indexOf(startMarker);
    assert.notEqual(start, -1, `缺少 ${name}`);
    const end = source.indexOf('\n}\n', start + startMarker.length);
    assert.notEqual(end, -1, `${name} 未闭合`);
    return source.slice(start, end + 3);
  };
  const deviceCommand = `${environmentPrefix}    cargo build --manifest-path "$ffi_manifest" --release --locked --target aarch64-apple-ios\n`;
  const simulatorCommand = `${environmentPrefix}    cargo build --manifest-path "$ffi_manifest" --release --locked --target "$rust_target"\n`;
  assert.equal(functionBody('build_ios').split(deviceCommand).length - 1, 1);
  assert.equal(
    functionBody('build_ios_simulator').split(simulatorCommand).length - 1,
    1,
  );
  return { deviceCommand, environmentPrefix, simulatorCommand };
}

test('smoldot Dart Release 合同固定 24 个来源文件和 1 个 SDK 说明文件', () => {
  assert.doesNotThrow(() => assertSmoldotDartSource(citizenSdkRoot));
});

test('smoldot Rust 锁文件固定为已验证且已剥离产品依赖的字节', () => {
  assert.doesNotThrow(() => assertSmoldotLocks(citizenSdkRoot));
});

test('SDK 根 Cargo 与 Dart 锁文件固定已审查依赖闭包', () => {
  const root = mkdtempSync(join(workRoot, 'release-root-lock-test-'));
  try {
    for (const lock of ['Cargo.lock', 'pubspec.lock']) {
      copyFileSync(join(citizenSdkRoot, lock), join(root, lock));
    }
    assert.doesNotThrow(() => assertSdkRootLocks(root));

    writeFileSync(join(root, 'Cargo.lock'), 'drift\n');
    assert.throws(() => assertSdkRootLocks(root), /SDK 根锁文件哈希漂移：Cargo\.lock/);

    copyFileSync(join(citizenSdkRoot, 'Cargo.lock'), join(root, 'Cargo.lock'));
    writeFileSync(join(root, 'pubspec.lock'), 'drift\n');
    assert.throws(() => assertSdkRootLocks(root), /SDK 根锁文件哈希漂移：pubspec\.lock/);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test('smoldot Rust 收编源码按离线清单固定完整闭集与逐文件哈希', () => {
  assert.doesNotThrow(() => assertSmoldotRustSource(citizenSdkRoot));
  const root = mkdtempSync(join(workRoot, 'release-rust-source-test-'));
  try {
    cpSync(
      join(citizenSdkRoot, 'native', 'smoldot'),
      join(root, 'native', 'smoldot'),
      { recursive: true },
    );
    assert.doesNotThrow(() => assertSmoldotRustSource(root));
    const exactSource = join(
      root,
      'native',
      'smoldot',
      'pow',
      'light-base',
      'src',
      'database.rs',
    );
    writeFileSync(exactSource, `${readFileSync(exactSource, 'utf8')}\n`);
    assert.throws(
      () => assertSmoldotRustSource(root),
      /smoldot Rust 文件哈希漂移/,
    );
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test('smoldot Release 合同覆盖根支持文件并拒绝 248 文件闭集漂移', () => {
  const root = mkdtempSync(join(workRoot, 'release-smoldot-closure-test-'));
  const source = join(citizenSdkRoot, 'native', 'smoldot');
  const copy = join(root, 'native', 'smoldot');
  try {
    mkdirSync(join(root, 'native'), { recursive: true });
    cpSync(source, copy, { recursive: true });
    assert.doesNotThrow(() => assertSmoldotRustSource(root));

    const publicHeader = join(copy, 'include', 'citizensdk.h');
    writeFileSync(publicHeader, `${readFileSync(publicHeader, 'utf8')}\n`);
    assert.throws(
      () => assertSmoldotRustSource(root),
      /smoldot 支持文件哈希漂移：native\/smoldot\/include\/citizensdk\.h/,
    );

    copyFileSync(join(source, 'include', 'citizensdk.h'), publicHeader);
    writeFileSync(join(copy, 'unexpected-release-input.txt'), 'extra\n');
    assert.throws(
      () => assertSmoldotRustSource(root),
      /smoldot 248 文件闭集漂移.*额外=native\/smoldot\/unexpected-release-input\.txt/,
    );
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test('链资产合同固定两个运行时信任锚的闭集与逐文件哈希', () => {
  const root = mkdtempSync(join(workRoot, 'release-chain-assets-test-'));
  const source = join(citizenSdkRoot, 'assets');
  const copy = join(root, 'assets');
  try {
    cpSync(source, copy, { recursive: true });
    assert.doesNotThrow(() => assertChainAssets(root));

    const chainSpec = join(copy, 'chainspec.json');
    writeFileSync(chainSpec, `${readFileSync(chainSpec, 'utf8')}\n`);
    assert.throws(() => assertChainAssets(root), /链资产文件哈希漂移：assets\/chainspec\.json/);

    copyFileSync(join(source, 'chainspec.json'), chainSpec);
    writeFileSync(join(copy, 'unexpected.json'), '{}\n');
    assert.throws(
      () => assertChainAssets(root),
      /链资产闭集漂移.*额外=assets\/unexpected\.json/,
    );
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test('真实 Runtime metadata/events 测试夹具由 Release 固定完整闭集', () => {
  const root = mkdtempSync(join(workRoot, 'release-source-fixture-test-'));
  const fixtureNames = [
    'citizenchain-runtime-system-events.hex',
    'citizenchain-runtime-v14-metadata.hex',
    'substrate-v14-system-events-metadata.hex',
  ];
  try {
    for (const name of fixtureNames) {
      const relativePath = join('test', 'transaction', 'fixtures', name);
      const destination = join(root, relativePath);
      mkdirSync(dirname(destination), { recursive: true });
      copyFileSync(join(citizenSdkRoot, relativePath), destination);
    }
    assert.doesNotThrow(() => assertSourceFixtures(root));
    const destination = join(
      root,
      'test',
      'transaction',
      'fixtures',
      'substrate-v14-system-events-metadata.hex',
    );
    writeFileSync(destination, `${readFileSync(destination, 'utf8')}00\n`);
    assert.throws(
      () => assertSourceFixtures(root),
      /逐字节来源夹具文件哈希漂移.*substrate-v14-system-events-metadata\.hex/,
    );
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test('Release 固定 GPL-3.0 与 MIT 权威许可证原文字节', () => {
  const root = mkdtempSync(join(workRoot, 'release-license-test-'));
  try {
    for (const license of ['LICENSE-GPL-3.0', 'LICENSE-MIT']) {
      copyFileSync(join(citizenSdkRoot, license), join(root, license));
    }
    assert.doesNotThrow(() => assertLicenseSources(root));

    writeFileSync(join(root, 'LICENSE-GPL-3.0'), 'drift\n');
    assert.throws(
      () => assertLicenseSources(root),
      /许可证原文文件哈希漂移：LICENSE-GPL-3\.0/,
    );

    copyFileSync(
      join(citizenSdkRoot, 'LICENSE-GPL-3.0'),
      join(root, 'LICENSE-GPL-3.0'),
    );
    writeFileSync(join(root, 'LICENSE-MIT'), 'drift\n');
    assert.throws(
      () => assertLicenseSources(root),
      /许可证原文文件哈希漂移：LICENSE-MIT/,
    );
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test('SDK 自有测试源码固定根、signer、Android、iOS 与 Release 合同闭集', () => {
  const root = mkdtempSync(join(workRoot, 'release-test-contract-test-'));
  try {
    for (const relativeRoot of [
      'test',
      'native/signer/tests',
      'android/src/test',
      'ios/Tests',
    ]) {
      const destination = join(root, ...relativeRoot.split('/'));
      mkdirSync(dirname(destination), { recursive: true });
      cpSync(join(citizenSdkRoot, ...relativeRoot.split('/')), destination, {
        recursive: true,
      });
    }
    mkdirSync(join(root, 'scripts'), { recursive: true });
    copyFileSync(
      join(citizenSdkRoot, 'scripts', 'release.test.mjs'),
      join(root, 'scripts', 'release.test.mjs'),
    );
    assert.doesNotThrow(() => assertSdkTestContracts(root));

    const golden = join(root, 'test', 'crypto', 'derivation_golden_test.dart');
    writeFileSync(golden, `${readFileSync(golden, 'utf8')}\n`);
    assert.throws(
      () => assertSdkTestContracts(root),
      /测试合同文件哈希漂移：test\/crypto\/derivation_golden_test\.dart/,
    );

    copyFileSync(
      join(citizenSdkRoot, 'test', 'crypto', 'derivation_golden_test.dart'),
      golden,
    );
    writeFileSync(join(root, 'test', 'unexpected_test.dart'), 'void main() {}\n');
    assert.throws(
      () => assertSdkTestContracts(root),
      /测试文件闭集漂移：test.*额外=test\/unexpected_test\.dart/,
    );

    rmSync(join(root, 'test', 'unexpected_test.dart'));
    const officialAndroidTest = join(
      root,
      'android',
      'src',
      'test',
      'kotlin',
      'org',
      'citizen',
      'sdk',
      'HardwareSecretVaultTest.kt',
    );
    const flatAndroidTest = join(
      root,
      'android',
      'src',
      'test',
      'kotlin',
      'HardwareSecretVaultTest.kt',
    );
    copyFileSync(officialAndroidTest, flatAndroidTest);
    rmSync(officialAndroidTest);
    assert.throws(
      () => assertSdkTestContracts(root),
      /测试文件闭集漂移：android\/src\/test.*缺失=android\/src\/test\/kotlin\/org\/citizen\/sdk\/HardwareSecretVaultTest\.kt.*额外=android\/src\/test\/kotlin\/HardwareSecretVaultTest\.kt/,
    );
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test('sr25519 signer 固定为已验证来源字节', () => {
  assert.doesNotThrow(() => assertSignerSource(citizenSdkRoot));
});

test('sr25519 signer 合同拒绝来源内容漂移', () => {
  const root = mkdtempSync(join(workRoot, 'release-signer-test-'));
  try {
    const signer = join(root, 'native', 'signer');
    mkdirSync(join(root, 'native'), { recursive: true });
    cpSync(join(citizenSdkRoot, 'native', 'signer'), signer, { recursive: true });
    assert.doesNotThrow(() => assertSignerSource(root));
    writeFileSync(join(signer, 'src', 'lib.rs'), 'drift\n');
    assert.throws(() => assertSignerSource(root), /signer 来源字节漂移/);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test('sr25519 signer 合同拒绝可改变 Cargo 行为的额外文件', () => {
  const root = mkdtempSync(join(workRoot, 'release-signer-closure-test-'));
  try {
    const signer = join(root, 'native', 'signer');
    mkdirSync(join(root, 'native'), { recursive: true });
    cpSync(join(citizenSdkRoot, 'native', 'signer'), signer, { recursive: true });
    assert.doesNotThrow(() => assertSignerSource(root));
    writeFileSync(join(signer, 'build.rs'), 'fn main() {}\n');
    assert.throws(
      () => assertSignerSource(root),
      /signer 6 文件闭集漂移.*额外=native\/signer\/build\.rs/,
    );
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test('smoldot Rust 锁文件合同拒绝内容漂移', () => {
  const root = mkdtempSync(join(workRoot, 'release-lock-test-'));
  try {
    for (const area of ['ffi', 'pow']) {
      const directory = join(root, 'native', 'smoldot', area);
      mkdirSync(directory, { recursive: true });
      copyFileSync(
        join(citizenSdkRoot, 'native', 'smoldot', area, 'Cargo.lock'),
        join(directory, 'Cargo.lock'),
      );
    }
    assert.doesNotThrow(() => assertSmoldotLocks(root));
    writeFileSync(join(root, 'native', 'smoldot', 'ffi', 'Cargo.lock'), 'drift\n');
    assert.throws(() => assertSmoldotLocks(root), /smoldot 锁文件漂移/);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test('smoldot Dart Release 合同拒绝内容和闭集漂移', () => {
  const root = mkdtempSync(join(workRoot, 'release-smoldot-test-'));
  const source = join(citizenSdkRoot, 'native', 'smoldot', 'dart');
  const copy = join(root, 'native', 'smoldot', 'dart');
  try {
    mkdirSync(join(root, 'native', 'smoldot'), { recursive: true });
    cpSync(source, copy, { recursive: true });
    writeFileSync(join(copy, 'README.md'), 'drift\n');
    assert.throws(
      () => assertSmoldotDartSource(root),
      /smoldot Dart 文件哈希漂移：README\.md/,
    );

    copyFileSync(join(source, 'README.md'), join(copy, 'README.md'));
    writeFileSync(join(copy, 'unexpected.txt'), 'extra\n');
    assert.throws(
      () => assertSmoldotDartSource(root),
      /smoldot Dart 文件闭集漂移/,
    );
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

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

test('Release 在创建目录前拒绝路径穿越与既存符号链接祖先', () => {
  const root = mkdtempSync(join(workRoot, 'release-path-guard-test-'));
  try {
    const native = writeNativeFixture(root);
    const archive = join(root, 'citizensdk.tgz');
    const traversal = `${root}/../../../citizensdk-release-path-probe-${basename(root)}`;
    const traversalTarget = resolve(traversal);
    assert.equal(existsSync(traversalTarget), false);
    assert.throws(
      () => buildCitizenSdkRelease({
        sourcePath: citizenSdkRoot,
        nativePath: native,
        outputPath: traversal,
        archivePath: archive,
        gitCommitSha: '0'.repeat(40),
        softwareVersion: '0.1.0',
      }),
      /绝对规范路径|\. 或 \.\./,
    );
    assert.equal(existsSync(traversalTarget), false);

    const sourceProbe = join(citizenSdkRoot, `release-path-probe-${basename(root)}`);
    const redirect = join(root, 'source-link');
    assert.equal(existsSync(sourceProbe), false);
    symlinkSync(citizenSdkRoot, redirect, 'dir');
    assert.throws(
      () => buildCitizenSdkRelease({
        sourcePath: citizenSdkRoot,
        nativePath: native,
        outputPath: join(redirect, basename(sourceProbe)),
        archivePath: archive,
        gitCommitSha: '0'.repeat(40),
        softwareVersion: '0.1.0',
      }),
      /符号链接/,
    );
    assert.equal(existsSync(sourceProbe), false);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test('原生构建入口固定 iOS16 且在 mkdir 前拒绝穿越和中间符号链接', () => {
  const root = mkdtempSync(join(workRoot, 'native-path-guard-test-'));
  try {
    const nativeBuildScript = readFileSync(
      join(citizenSdkRoot, 'scripts', 'build-native.sh'),
      'utf8',
    );
    const iosContract = assertIosDeploymentTargetContract(nativeBuildScript);
    assert.throws(() => assertIosDeploymentTargetContract(
      nativeBuildScript.replace('ios_deployment_target=16.0', 'ios_deployment_target=17.0'),
    ));
    assert.throws(() => assertIosDeploymentTargetContract(
      nativeBuildScript.replace(
        iosContract.deviceCommand,
        iosContract.deviceCommand.replace(iosContract.environmentPrefix, ''),
      ),
    ));
    assert.throws(() => assertIosDeploymentTargetContract(
      nativeBuildScript.replace(
        iosContract.simulatorCommand,
        iosContract.simulatorCommand.replace(iosContract.environmentPrefix, ''),
      ),
    ));

    const traversal = `${root}/../../../citizensdk-native-path-probe-${basename(root)}`;
    const traversalTarget = resolve(traversal);
    assert.equal(existsSync(traversalTarget), false);
    const baseEnvironment = {
      ...process.env,
      CITIZENSDK_NATIVE_OUTPUT_DIR: join(root, 'native-output'),
      GITHUB_ACTIONS: 'false',
    };
    const traversalResult = spawnSync('/bin/bash', ['scripts/build-native.sh', 'android'], {
      cwd: citizenSdkRoot,
      encoding: 'utf8',
      env: { ...baseEnvironment, CITIZENSDK_WORK_DIR: traversal },
    });
    assert.notEqual(traversalResult.status, 0);
    assert.match(traversalResult.stderr, /\. 或 \.\.|规范路径/);
    assert.equal(existsSync(traversalTarget), false);

    const sourceProbe = join(citizenSdkRoot, `native-path-probe-${basename(root)}`);
    const redirect = join(root, 'source-link');
    assert.equal(existsSync(sourceProbe), false);
    symlinkSync(citizenSdkRoot, redirect, 'dir');
    const symlinkResult = spawnSync('/bin/bash', ['scripts/build-native.sh', 'android'], {
      cwd: citizenSdkRoot,
      encoding: 'utf8',
      env: {
        ...baseEnvironment,
        CITIZENSDK_WORK_DIR: join(redirect, basename(sourceProbe)),
      },
    });
    assert.notEqual(symlinkResult.status, 0);
    assert.match(symlinkResult.stderr, /符号链接/);
    assert.equal(existsSync(sourceProbe), false);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test('Android 原生构建固定 NDK 版本并可从宿主标准 SDK 目录自解析', () => {
  const root = mkdtempSync(join(workRoot, 'android-ndk-resolution-test-'));
  try {
    const sdkRelative = process.platform === 'darwin'
      ? ['Library', 'Android', 'sdk']
      : ['Android', 'Sdk'];
    const hostTag = process.platform === 'darwin'
      ? (process.arch === 'arm64' ? 'darwin-aarch64' : 'darwin-x86_64')
      : 'linux-x86_64';
    const sdk = join(root, ...sdkRelative);
    const toolchain = join(
      sdk,
      'ndk',
      '28.2.13676358',
      'toolchains',
      'llvm',
      'prebuilt',
      hostTag,
    );
    mkdirSync(toolchain, { recursive: true });
    const environment = {
      ...process.env,
      CITIZENSDK_BUILD_TEST: '1',
      CITIZENSDK_NATIVE_OUTPUT_DIR: join(root, 'native-output'),
      CITIZENSDK_WORK_DIR: join(root, 'native-work'),
      GITHUB_ACTIONS: 'true',
      HOME: root,
    };
    delete environment.ANDROID_HOME;
    delete environment.ANDROID_NDK_HOME;
    delete environment.ANDROID_SDK_ROOT;

    const resolved = spawnSync(
      '/bin/bash',
      ['scripts/build-native.sh', '__test-android-toolchain'],
      { cwd: citizenSdkRoot, encoding: 'utf8', env: environment },
    );
    assert.equal(resolved.status, 0, resolved.stderr);
    assert.equal(resolved.stdout.trim(), toolchain);

    const wrongNdk = join(sdk, 'ndk', '28.1.13356709');
    mkdirSync(wrongNdk, { recursive: true });
    const wrongVersion = spawnSync(
      '/bin/bash',
      ['scripts/build-native.sh', '__test-android-toolchain'],
      {
        cwd: citizenSdkRoot,
        encoding: 'utf8',
        env: { ...environment, ANDROID_NDK_HOME: wrongNdk },
      },
    );
    assert.notEqual(wrongVersion.status, 0);
    assert.match(wrongVersion.stderr, /统一版本 28\.2\.13676358/);

    const divergentSdk = join(root, 'divergent-sdk');
    mkdirSync(divergentSdk, { recursive: true });
    const divergentRoots = spawnSync(
      '/bin/bash',
      ['scripts/build-native.sh', '__test-android-toolchain'],
      {
        cwd: citizenSdkRoot,
        encoding: 'utf8',
        env: {
          ...environment,
          ANDROID_HOME: sdk,
          ANDROID_SDK_ROOT: divergentSdk,
        },
      },
    );
    assert.notEqual(divergentRoots.status, 0);
    assert.match(divergentRoots.stderr, /指向不同目录/);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test('最终 tgz、外层 SHA256SUMS 与候选闭集双向一致', () => {
  const root = mkdtempSync(join(workRoot, 'release-archive-test-'));
  try {
    const native = writeNativeFixture(root);
    const output = join(root, 'candidate');
    const archive = join(root, 'citizensdk.tgz');
    buildCitizenSdkRelease({
      sourcePath: citizenSdkRoot,
      nativePath: native,
      outputPath: output,
      archivePath: archive,
      gitCommitSha: '0'.repeat(40),
      softwareVersion: '0.1.0',
    });
    assert.doesNotThrow(() => verifyCitizenSdkRelease(output, archive, '0'.repeat(40)));
    const sums = readFileSync(join(output, 'SHA256SUMS'), 'utf8');
    assert.match(sums, /^[0-9a-f]{64}  citizensdk-release\.json\n[0-9a-f]{64}  citizensdk\.tgz\n$/);

    const corrupted = readFileSync(archive);
    corrupted[Math.floor(corrupted.length / 2)] ^= 0xff;
    writeFileSync(archive, corrupted);
    assert.throws(
      () => verifyCitizenSdkRelease(output, archive, '0'.repeat(40)),
      /归档不是候选闭集的规范 gzip\/tar 字节/,
    );
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});
