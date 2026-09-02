import assert from 'node:assert/strict';
import {
  chmodSync,
  cpSync,
  copyFileSync,
  existsSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  readlinkSync,
  rmSync,
  symlinkSync,
  writeFileSync,
} from 'node:fs';
import { spawnSync } from 'node:child_process';
import { gunzipSync } from 'node:zlib';
import { basename, dirname, join, resolve } from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

import {
  assertAndroidReleaseProjection,
  assertAppleReleaseProjection,
  assertChainAssets,
  assertCoreRustSource,
  assertDocumentationSource,
  assertHostedPackageSource,
  assertHostedRuntimeDartProjection,
  assertLicenseSources,
  assertMobileBindingSource,
  assertNativeArtifactSources,
  assertNoSecrets,
  assertProviderLockParity,
  assertPublicAbiHeaders,
  assertSdkRootLocks,
  assertSdkScriptSource,
  assertSdkTestContracts,
  assertSignerSource,
  assertSmoldotDartSource,
  assertSmoldotLocks,
  assertSmoldotRustSource,
  assertSourceFixtures,
  buildCitizenSdkRelease,
  verifyCitizenSdkRelease,
} from './release.mjs';

const workRoot = process.env.TATA_CONSOLE_WORK_DIR;
if (!workRoot) {
  throw new Error('CitizenSDK 发布测试缺少 TataConsole 中央工作目录');
}
mkdirSync(workRoot, { recursive: true });

const citizenSdkRoot = fileURLToPath(new URL('../', import.meta.url));
const chainAssetPaths = [
  'assets/README.md',
  'assets/citizenchain/README.md',
  'assets/citizenchain/chainspec.json',
  'assets/citizenchain/light_sync_state.json',
  'assets/citizenchain/manifest.json',
];
const macOSFrameworkSymlinks = Object.freeze({
  CitizenSDK: 'Versions/Current/CitizenSDK',
  Headers: 'Versions/Current/Headers',
  Modules: 'Versions/Current/Modules',
  Resources: 'Versions/Current/Resources',
  'Versions/Current': 'A',
});
const appleSwiftModuleExtensions = Object.freeze([
  'abi.json',
  'private.swiftinterface',
  'swiftdoc',
  'swiftinterface',
  'swiftmodule',
  'swiftsourceinfo',
]);
const appleFixtureSliceIdentifiers = Object.freeze({
  iosDevice: 'xcode-library-0',
  iosSimulator: 'xcode-library-1',
  macOS: 'xcode-library-2',
});

const CRC32_TABLE = (() => {
  const table = new Uint32Array(256);
  for (let index = 0; index < table.length; index += 1) {
    let value = index;
    for (let bit = 0; bit < 8; bit += 1) {
      value = (value & 1) === 0 ? value >>> 1 : (value >>> 1) ^ 0xedb88320;
    }
    table[index] = value >>> 0;
  }
  return table;
})();

function crc32(bytes) {
  let value = 0xffffffff;
  for (const byte of bytes) value = CRC32_TABLE[(value ^ byte) & 0xff] ^ (value >>> 8);
  return (value ^ 0xffffffff) >>> 0;
}

function storedZip(entries) {
  const localChunks = [];
  const centralChunks = [];
  let offset = 0;
  for (const [name, rawContent] of Object.entries(entries).sort(([left], [right]) => left.localeCompare(right))) {
    const nameBytes = Buffer.from(name, 'utf8');
    const content = Buffer.isBuffer(rawContent) ? rawContent : Buffer.from(rawContent);
    const checksum = crc32(content);
    const local = Buffer.alloc(30);
    local.writeUInt32LE(0x04034b50, 0);
    local.writeUInt16LE(20, 4);
    local.writeUInt32LE(checksum, 14);
    local.writeUInt32LE(content.length, 18);
    local.writeUInt32LE(content.length, 22);
    local.writeUInt16LE(nameBytes.length, 26);
    localChunks.push(local, nameBytes, content);

    const central = Buffer.alloc(46);
    central.writeUInt32LE(0x02014b50, 0);
    central.writeUInt16LE(20, 4);
    central.writeUInt16LE(20, 6);
    central.writeUInt32LE(checksum, 16);
    central.writeUInt32LE(content.length, 20);
    central.writeUInt32LE(content.length, 24);
    central.writeUInt16LE(nameBytes.length, 28);
    central.writeUInt32LE(offset, 42);
    centralChunks.push(central, nameBytes);
    offset += local.length + nameBytes.length + content.length;
  }
  const central = Buffer.concat(centralChunks);
  const end = Buffer.alloc(22);
  end.writeUInt32LE(0x06054b50, 0);
  end.writeUInt16LE(Object.keys(entries).length, 8);
  end.writeUInt16LE(Object.keys(entries).length, 10);
  end.writeUInt32LE(central.length, 12);
  end.writeUInt32LE(offset, 16);
  return Buffer.concat([...localChunks, central, end]);
}

function plistXml(value) {
  const escape = (text) => String(text)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');
  const encode = (item) => {
    if (Array.isArray(item)) return `<array>${item.map(encode).join('')}</array>`;
    if (item && typeof item === 'object') {
      return `<dict>${Object.keys(item).sort().map((key) => `<key>${escape(key)}</key>${encode(item[key])}`).join('')}</dict>`;
    }
    if (typeof item === 'number') return `<integer>${item}</integer>`;
    if (typeof item === 'boolean') return item ? '<true/>' : '<false/>';
    return `<string>${escape(item)}</string>`;
  };
  return Buffer.from(
    `<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n<plist version="1.0">${encode(value)}</plist>\n`,
  );
}

function archivedSymlinks(gzipBytes) {
  const tar = gunzipSync(gzipBytes);
  const links = {};
  const field = (offset, length) => tar.subarray(offset, offset + length)
    .toString('utf8')
    .split('\0', 1)[0];
  let offset = 0;
  while (offset + 512 <= tar.length) {
    const header = tar.subarray(offset, offset + 512);
    if (header.every((byte) => byte === 0)) break;
    const name = field(offset, 100);
    const prefix = field(offset + 345, 155);
    const path = prefix.length === 0 ? name : `${prefix}/${name}`;
    const sizeText = field(offset + 124, 12).trim();
    const size = sizeText.length === 0 ? 0 : Number.parseInt(sizeText, 8);
    assert.equal(Number.isSafeInteger(size), true, `tar size 无效：${path}`);
    if (header[156] === '2'.charCodeAt(0)) {
      links[path] = field(offset + 157, 100);
    }
    offset += 512 + Math.ceil(size / 512) * 512;
  }
  return links;
}

function machOVersion(version) {
  const [major, minor, patch = 0] = version.split('.').map(Number);
  return ((major << 16) | (minor << 8) | patch) >>> 0;
}

function appleMachOFixture({
  installName = '@rpath/CitizenSDK.framework/CitizenSDK',
  minimum,
  platform,
  privateSymbols = [],
  symbols,
  cpuType = 0x0100000c,
}) {
  const dylibName = Buffer.from(`${installName}\0`);
  const dylibCommandSize = Math.ceil((24 + dylibName.length) / 8) * 8;
  const dylib = Buffer.alloc(dylibCommandSize);
  dylib.writeUInt32LE(0x0d, 0);
  dylib.writeUInt32LE(dylibCommandSize, 4);
  dylib.writeUInt32LE(24, 8);
  dylibName.copy(dylib, 24);

  const build = Buffer.alloc(24);
  build.writeUInt32LE(0x32, 0);
  build.writeUInt32LE(24, 4);
  build.writeUInt32LE(platform, 8);
  build.writeUInt32LE(machOVersion(minimum), 12);
  build.writeUInt32LE(machOVersion(minimum), 16);

  const symbolCommand = Buffer.alloc(24);
  symbolCommand.writeUInt32LE(0x02, 0);
  symbolCommand.writeUInt32LE(24, 4);
  const commands = Buffer.concat([dylib, build, symbolCommand]);
  const header = Buffer.alloc(32);
  header.writeUInt32LE(0xfeedfacf, 0);
  header.writeUInt32LE(cpuType, 4);
  header.writeUInt32LE(0, 8);
  header.writeUInt32LE(6, 12);
  header.writeUInt32LE(3, 16);
  header.writeUInt32LE(commands.length, 20);

  const strings = [Buffer.from([0])];
  const indexes = [];
  let stringOffset = 1;
  const symbolEntries = [
    ...symbols.map((symbol) => ({ isPrivate: false, symbol })),
    ...privateSymbols.map((symbol) => ({ isPrivate: true, symbol })),
  ];
  for (const { symbol } of symbolEntries) {
    const encoded = Buffer.from(`_${symbol}\0`);
    indexes.push(stringOffset);
    strings.push(encoded);
    stringOffset += encoded.length;
  }
  const nlist = Buffer.alloc(symbolEntries.length * 16);
  indexes.forEach((index, symbolIndex) => {
    const offset = symbolIndex * 16;
    nlist.writeUInt32LE(index, offset);
    nlist[offset + 4] = symbolEntries[symbolIndex].isPrivate ? 0x1f : 0x0f;
    nlist[offset + 5] = 1;
    nlist.writeBigUInt64LE(BigInt(symbolIndex + 1), offset + 8);
  });
  const symbolOffset = header.length + commands.length;
  const tableCommandOffset = dylib.length + build.length;
  commands.writeUInt32LE(symbolOffset, tableCommandOffset + 8);
  commands.writeUInt32LE(symbolEntries.length, tableCommandOffset + 12);
  commands.writeUInt32LE(symbolOffset + nlist.length, tableCommandOffset + 16);
  commands.writeUInt32LE(stringOffset, tableCommandOffset + 20);
  return Buffer.concat([header, commands, nlist, ...strings]);
}

function citizenSdkSymbols() {
  const header = readFileSync(join(citizenSdkRoot, 'include', 'citizensdk.h'), 'utf8');
  const symbols = [...new Set(
    [...header.matchAll(/\b(citizensdk_[a-z0-9_]+)\s*\(/g)].map((match) => match[1]),
  )].sort();
  assert.equal(symbols.length, 70);
  return symbols;
}

function citizenSdkExportSymbols() {
  return [...citizenSdkSymbols(), '$s10CitizenSDK0A0CMa'];
}

function writeAppleXcframework(destination, options = {}) {
  const slices = {
    iosDevice: {
      binaryPath: 'CitizenSDK.framework/CitizenSDK',
      bundlePlatform: 'iPhoneOS',
      dtPlatform: 'iphoneos',
      minimum: '16.0.0',
      minimumKey: 'MinimumOSVersion',
      installName: '@rpath/CitizenSDK.framework/CitizenSDK',
      module: 'arm64-apple-ios',
      platform: 2,
      supportedPlatform: 'ios',
      swiftTarget: 'arm64-apple-ios16.0',
    },
    iosSimulator: {
      binaryPath: 'CitizenSDK.framework/CitizenSDK',
      bundlePlatform: 'iPhoneSimulator',
      dtPlatform: 'iphonesimulator',
      minimum: '16.0.0',
      minimumKey: 'MinimumOSVersion',
      installName: '@rpath/CitizenSDK.framework/CitizenSDK',
      module: 'arm64-apple-ios-simulator',
      platform: 7,
      supportedPlatform: 'ios',
      swiftTarget: 'arm64-apple-ios16.0-simulator',
      variant: 'simulator',
    },
    macOS: {
      binaryPath: 'CitizenSDK.framework/Versions/A/CitizenSDK',
      bundlePlatform: 'MacOSX',
      dtPlatform: 'macosx',
      minimum: '13.0.0',
      minimumKey: 'LSMinimumSystemVersion',
      installName: '@rpath/CitizenSDK.framework/Versions/A/CitizenSDK',
      module: 'arm64-apple-macos',
      platform: 1,
      supportedPlatform: 'macos',
      swiftTarget: 'arm64-apple-macosx13.0',
    },
  };
  const libraries = [];
  for (const [sliceKey, contract] of Object.entries(slices)) {
    const override = options[sliceKey] ?? {};
    const identifier = override.identifier ?? appleFixtureSliceIdentifiers[sliceKey];
    const isMacOS = contract.supportedPlatform === 'macos';
    const framework = join(destination, identifier, 'CitizenSDK.framework');
    const contentRoot = isMacOS
      ? join(framework, 'Versions', 'A')
      : framework;
    const headers = join(contentRoot, 'Headers');
    const modules = join(contentRoot, 'Modules', 'CitizenSDK.swiftmodule');
    const resources = join(contentRoot, 'Resources');
    mkdirSync(headers, { recursive: true });
    mkdirSync(modules, { recursive: true });
    mkdirSync(join(resources, 'citizenchain'), { recursive: true });
    for (const header of ['citizensdk.h', 'citizensdk_types.h']) {
      copyFileSync(join(citizenSdkRoot, 'include', header), join(headers, header));
    }
    writeFileSync(
      join(contentRoot, 'Modules', 'module.modulemap'),
      'framework module CitizenSDK {\n  umbrella header "citizensdk.h"\n  export *\n}\n',
    );
    writeFileSync(join(modules, `${contract.module}.abi.json`), '{"abi":"fixture"}\n');
    writeFileSync(join(modules, `${contract.module}.swiftdoc`), 'compiled-swift-doc');
    writeFileSync(join(modules, `${contract.module}.swiftmodule`), 'compiled-swift-module');
    writeFileSync(
      join(modules, `${contract.module}.swiftsourceinfo`),
      'compiled-swift-source-info',
    );
    writeFileSync(
      join(modules, `${contract.module}.swiftinterface`),
      '// swift-interface-format-version: 1.0\n'
        + `// swift-module-flags: -target ${contract.swiftTarget} -module-name CitizenSDK\n`
        + '@_exported import CitizenSDK\n',
    );
    writeFileSync(
      join(modules, `${contract.module}.private.swiftinterface`),
      '// swift-interface-format-version: 1.0\n'
        + `// swift-module-flags: -target ${contract.swiftTarget} -module-name CitizenSDK\n`
        + '@_exported import CitizenSDK\n'
        + '  @_spi(CitizenSDKFlutter) final public func supervisedClose() async throws\n'
        + '  @_spi(CitizenSDKFlutter) final public func enqueueForSupervisedClose()\n',
    );
    for (const asset of ['chainspec.json', 'light_sync_state.json', 'manifest.json']) {
      copyFileSync(
        join(citizenSdkRoot, 'assets', 'citizenchain', asset),
        join(resources, 'citizenchain', asset),
      );
    }
    copyFileSync(
      join(citizenSdkRoot, 'darwin', 'Sources', 'CitizenSDK', 'PrivacyInfo.xcprivacy'),
      join(resources, 'PrivacyInfo.xcprivacy'),
    );
    writeFileSync(
      join(contentRoot, 'CitizenSDK'),
      override.binary ?? appleMachOFixture({
        cpuType: override.cpuType,
        installName: override.installName ?? contract.installName,
        minimum: override.minimum ?? contract.minimum,
        platform: override.platform ?? contract.platform,
        privateSymbols: override.privateSymbols ?? ['rust_dependency_hidden'],
        symbols: override.symbols ?? citizenSdkExportSymbols(),
      }),
    );
    writeFileSync(isMacOS
      ? join(resources, 'Info.plist')
      : join(framework, 'Info.plist'), plistXml({
      CFBundleDevelopmentRegion: 'en',
      CFBundleExecutable: 'CitizenSDK',
      CFBundleIdentifier: 'org.citizen.sdk',
      CFBundleInfoDictionaryVersion: '6.0',
      CFBundleName: 'CitizenSDK',
      CFBundlePackageType: 'FMWK',
      CFBundleShortVersionString: '1.0.0',
      CFBundleSupportedPlatforms: [contract.bundlePlatform],
      CFBundleVersion: '1.0.0',
      DTPlatformName: contract.dtPlatform,
      [contract.minimumKey]: contract.minimum.replace(/\.0$/, ''),
      ...(override.info ?? {}),
    }));
    if (isMacOS) {
      for (const [path, target] of Object.entries(macOSFrameworkSymlinks)) {
        const link = join(framework, ...path.split('/'));
        mkdirSync(dirname(link), { recursive: true });
        symlinkSync(target, link);
      }
    }
    libraries.push({
      BinaryPath: override.binaryPath ?? contract.binaryPath,
      LibraryIdentifier: identifier,
      LibraryPath: 'CitizenSDK.framework',
      SupportedArchitectures: override.architectures ?? ['arm64'],
      SupportedPlatform: override.supportedPlatform ?? contract.supportedPlatform,
      ...(contract.variant || override.variant
        ? { SupportedPlatformVariant: override.variant ?? contract.variant }
        : {}),
      ...(override.libraryInfo ?? {}),
    });
  }
  const xcframeworkInfo = options.xcframeworkInfo ?? {};
  writeFileSync(join(destination, 'Info.plist'), plistXml({
    AvailableLibraries: xcframeworkInfo.libraries ?? libraries,
    CFBundlePackageType: 'XFWK',
    XCFrameworkFormatVersion: '1.0',
    ...(xcframeworkInfo.fields ?? {}),
  }));
}

function writeAppleProjectionFixture(root, options = {}) {
  for (const path of [
    'include/citizensdk.h',
    'include/citizensdk_types.h',
    'assets/citizenchain/chainspec.json',
    'assets/citizenchain/light_sync_state.json',
    'assets/citizenchain/manifest.json',
    'darwin/Sources/CitizenSDK/PrivacyInfo.xcprivacy',
    'pubspec.yaml',
  ]) {
    const destination = join(root, ...path.split('/'));
    mkdirSync(dirname(destination), { recursive: true });
    copyFileSync(join(citizenSdkRoot, ...path.split('/')), destination);
  }
  writeAppleXcframework(
    join(root, 'darwin', 'CitizenSDK.xcframework'),
    options,
  );
}

function appleFixtureFramework(root, sliceKey) {
  const identifier = appleFixtureSliceIdentifiers[sliceKey] ?? sliceKey;
  return join(
    root,
    'darwin',
    'CitizenSDK.xcframework',
    identifier,
    'CitizenSDK.framework',
  );
}

function appleFixtureContentRoot(root, sliceKey) {
  const framework = appleFixtureFramework(root, sliceKey);
  return sliceKey === 'macOS' || sliceKey === appleFixtureSliceIdentifiers.macOS
    ? join(framework, 'Versions', 'A')
    : framework;
}

function androidAarFixture(core, jni, {
  classEntries = {
    'org/citizen/sdk/CitizenSdk.class': Buffer.from('CitizenSDK native facade'),
    'org/citizen/sdk/CitizenSdkLifecycle.class': Buffer.from('CitizenSDK lifecycle'),
    'org/citizen/sdk/CitizenSdkException.class': Buffer.from('CitizenSDK errors'),
    'org/citizen/sdk/CitizenSdkEvents.class': Buffer.from('CitizenSDK events'),
    'org/citizen/sdk/CitizenWalletProfile.class': Buffer.from('CitizenSDK wallet profile'),
    'org/citizen/sdk/CitizenSdkOperation.class': Buffer.from('CitizenSDK operation'),
    'org/citizen/sdk/internal/CitizenSdkNative.class': Buffer.from('CitizenSDK JNI owner'),
    'org/citizen/sdk/internal/CitizenSdkHardwareVault.class': Buffer.from('CitizenSDK vault'),
    'org/citizen/sdk/internal/CitizenSdkHostServices.class': Buffer.from('CitizenSDK host services'),
    'org/citizen/sdk/internal/CitizenSdkRequestRouter.class': Buffer.from('CitizenSDK request router'),
    'org/citizen/sdk/ui/CitizenSdkWalletFlowActivity.class': Buffer.from('CitizenSDK wallet activity'),
    'org/citizen/sdk/ui/CitizenSdkWalletFlowContract.class': Buffer.from('CitizenSDK wallet contract'),
    'org/citizen/sdk/ui/CitizenSdkWalletFlowCoordinator.class': Buffer.from('CitizenSDK wallet coordinator'),
  },
  assets = {
    'assets/README.md': Buffer.from('asset boundary'),
    'assets/citizenchain/README.md': Buffer.from('chain asset boundary'),
    'assets/citizenchain/chainspec.json': Buffer.from('chainspec'),
    'assets/citizenchain/light_sync_state.json': Buffer.from('sync-state'),
    'assets/citizenchain/manifest.json': Buffer.from('asset-manifest'),
  },
  extraEntries = {},
} = {}) {
  return storedZip({
    'AndroidManifest.xml': Buffer.from('manifest'),
    ...assets,
    'classes.jar': storedZip(classEntries),
    'jni/arm64-v8a/libcitizensdk.so': core,
    'jni/arm64-v8a/libcitizensdk_jni.so': jni,
    ...extraEntries,
  });
}

function writeNativeFixture(root) {
  const native = join(root, 'native-output');
  const core = Buffer.from('android-core');
  const jni = Buffer.from('android-jni');
  // The full-candidate fixture must carry the exact source trust anchors.
  // Synthetic asset bytes are reserved for the isolated projection tests;
  // otherwise the candidate test could not exercise the production
  // source↔AAR byte-identity contract.
  const assets = Object.fromEntries(chainAssetPaths.map((path) => [
    path,
    readFileSync(join(citizenSdkRoot, ...path.split('/'))),
  ]));
  const aar = androidAarFixture(core, jni, { assets });
  for (const [path, value] of [
    ['android/citizensdk.aar', aar],
    ['android/arm64-v8a/libcitizensdk.so', core],
    ['android/arm64-v8a/libcitizensdk_jni.so', jni],
  ]) {
    const destination = join(native, ...path.split('/'));
    mkdirSync(dirname(destination), { recursive: true });
    writeFileSync(destination, value);
  }
  writeAppleXcframework(join(native, 'apple', 'CitizenSDK.xcframework'));
  return native;
}

function writeAndroidProjectionFixture(root, options = {}) {
  const core = Buffer.from('android-core');
  const jni = Buffer.from('android-jni');
  const android = join(root, 'android');
  const assets = options.assets ?? {
    'assets/README.md': Buffer.from('asset boundary'),
    'assets/citizenchain/README.md': Buffer.from('chain asset boundary'),
    'assets/citizenchain/chainspec.json': Buffer.from('chainspec'),
    'assets/citizenchain/light_sync_state.json': Buffer.from('sync-state'),
    'assets/citizenchain/manifest.json': Buffer.from('asset-manifest'),
  };
  const nativeLeaf = join(android, 'src', 'main', 'jniLibs', 'arm64-v8a');
  mkdirSync(nativeLeaf, { recursive: true });
  for (const [path, value] of Object.entries(assets)) {
    const destination = join(root, ...path.split('/'));
    mkdirSync(dirname(destination), { recursive: true });
    writeFileSync(destination, value);
  }
  writeFileSync(
    join(android, 'citizensdk.aar'),
    androidAarFixture(core, jni, { ...options, assets }),
  );
  writeFileSync(join(nativeLeaf, 'libcitizensdk.so'), core);
  writeFileSync(join(nativeLeaf, 'libcitizensdk_jni.so'), jni);
  return android;
}

function writeCoreRustFixture(root) {
  const native = join(root, 'native');
  mkdirSync(native, { recursive: true });
  for (const directory of ['contracts', 'engine', 'ffi']) {
    cpSync(
      join(citizenSdkRoot, 'native', directory),
      join(native, directory),
      { recursive: true },
    );
  }
  for (const directory of ['signer', 'smoldot']) {
    mkdirSync(join(native, directory));
  }
  for (const path of [
    'Cargo.toml',
    'Cargo.lock',
    'docs/C_ABI.md',
    'THIRD_PARTY_NOTICES.md',
    'native/README.md',
  ]) {
    const destination = join(root, ...path.split('/'));
    mkdirSync(dirname(destination), { recursive: true });
    copyFileSync(join(citizenSdkRoot, ...path.split('/')), destination);
  }
}

// 中文注释：三个正式 Apple 技术变体必须共用 iOS 16/macOS 13
// 常量，只构建 native/ffi 产品 Core；legacy host 也只属于 macOS。
function assertAppleDeploymentTargetContract(source) {
  assert.deepEqual(
    source.match(/^[ \t]*(?:ios|macos)_deployment_target=.*$/gm) ?? [],
    ['ios_deployment_target=16.0', 'macos_deployment_target=13.0'],
  );
  const functionBody = (name) => {
    const startMarker = `${name}() {\n`;
    const start = source.indexOf(startMarker);
    assert.notEqual(start, -1, `缺少 ${name}`);
    const end = source.indexOf('\n}\n', start + startMarker.length);
    assert.notEqual(end, -1, `${name} 未闭合`);
    return source.slice(start, end + 3);
  };
  const slice = functionBody('build_apple_framework_slice');
  const verifySlice = functionBody('verify_apple_framework_slice');
  const restoreSwiftModules = functionBody('restore_swift_module_artifacts');
  const flutterAdapter = functionBody('compile_apple_flutter_adapter');
  const apple = functionBody('build_apple');
  const appleTests = functionBody('build_apple_tests');
  const appleTestHarness = functionBody('run_apple_test_harness');
  const appleTestPackage = functionBody('write_apple_test_package');
  const smokeFunctionStart = source.indexOf('run_final_apple_consumer_smoke() {\n');
  assert.notEqual(smokeFunctionStart, -1, '缺少最终 XCFramework 消费者 smoke');
  const smokeHeredocStart = source.indexOf("<<'SWIFT'\n", smokeFunctionStart);
  const smokeHeredocEnd = source.indexOf('\nSWIFT\n', smokeHeredocStart);
  assert.notEqual(smokeHeredocStart, -1, '消费者 smoke 缺少 Swift heredoc');
  assert.notEqual(smokeHeredocEnd, -1, '消费者 smoke Swift heredoc 未闭合');
  const consumerSmoke = source.slice(smokeHeredocStart, smokeHeredocEnd);
  const smokeShellEnd = source.indexOf('\n}\n\nbuild_apple_tests() {', smokeHeredocEnd);
  assert.notEqual(smokeShellEnd, -1, '消费者 smoke shell 函数未闭合');
  const smokeShell = source.slice(smokeFunctionStart, smokeShellEnd);
  const host = functionBody('build_host');
  assert.match(slice, /IPHONEOS_DEPLOYMENT_TARGET="\$ios_deployment_target"/);
  assert.match(slice, /MACOSX_DEPLOYMENT_TARGET="\$macos_deployment_target"/);
  assert.equal(
    slice.split('cargo build --manifest-path "$product_ffi_manifest"').length - 1,
    2,
  );
  assert.match(slice, /write_apple_exported_symbols/);
  assert.match(slice, /-exported_symbols_list/);
  assert.match(slice, /-warnings-as-errors/);
  assert.match(slice, /-swift-version 5/);
  assert.match(slice, /-strict-concurrency=complete/);
  assert.match(slice, /-import-underlying-module/);
  assert.match(slice, /-typecheck-module-from-interface/);
  assert.match(slice, /-emit-private-module-interface-path/);
  assert.match(slice, /private\.swiftinterface/);
  assert.doesNotMatch(slice, /-import-objc-header/);
  assert.match(slice, /framework_content_root="\$framework\/Versions\/A"/);
  assert.match(slice, /framework_plist="\$framework_content_root\/Resources\/Info\.plist"/);
  assert.match(
    slice,
    /framework_install_name='@rpath\/CitizenSDK\.framework\/Versions\/A\/CitizenSDK'/,
  );
  assert.match(
    slice,
    /framework_install_name='@rpath\/CitizenSDK\.framework\/CitizenSDK'/,
  );
  assert.match(slice, /-Xlinker "\$framework_install_name"/);
  for (const specification of [
    'Versions/Current|A',
    'Headers|Versions/Current/Headers',
    'Modules|Versions/Current/Modules',
    'Resources|Versions/Current/Resources',
  ]) {
    assert.match(slice, new RegExp(specification.replaceAll('/', '\\/').replace('|', '\\|')));
  }
  assert.match(slice, /ln -s 'Versions\/Current\/CitizenSDK' "\$framework\/CitizenSDK"/);
  assert.match(verifySlice, /apple-plist-contract/);
  assert.match(verifySlice, /plutil -convert binary1/);
  assert.match(
    verifySlice,
    /abi\.json[\s\S]*private\.swiftinterface[\s\S]*swiftdoc[\s\S]*swiftinterface[\s\S]*swiftmodule[\s\S]*swiftsourceinfo/,
  );
  assert.match(verifySlice, /Swift module 六文件闭集漂移/);
  for (const identity of [
    'arm64-apple-ios',
    'arm64-apple-ios-simulator',
    'arm64-apple-macos',
  ]) {
    assert.match(verifySlice, new RegExp(identity));
  }
  for (const specification of [
    'CitizenSDK|Versions/Current/CitizenSDK',
    'Headers|Versions/Current/Headers',
    'Modules|Versions/Current/Modules',
    'Resources|Versions/Current/Resources',
    'Versions/Current|A',
  ]) {
    assert.match(
      verifySlice,
      new RegExp(specification.replaceAll('/', '\\/').replace('|', '\\|')),
    );
  }
  assert.match(
    verifySlice,
    /expected_install_name='@rpath\/CitizenSDK\.framework\/Versions\/A\/CitizenSDK'/,
  );
  assert.match(
    verifySlice,
    /expected_install_name='@rpath\/CitizenSDK\.framework\/CitizenSDK'/,
  );
  assert.match(flutterAdapter, /darwin_flutter_source_root/);
  assert.match(flutterAdapter, /-warnings-as-errors/);
  assert.match(flutterAdapter, /-strict-concurrency=complete/);
  assert.match(flutterAdapter, /-typecheck/);
  assert.match(flutterAdapter, /-c/);
  assert.match(flutterAdapter, /citizen_slice_root/);
  assert.doesNotMatch(flutterAdapter, /darwin_source_root|apple-build/);
  for (const target of [
    'aarch64-apple-ios',
    'aarch64-apple-ios-sim',
    'aarch64-apple-darwin',
  ]) {
    assert.match(apple, new RegExp(`(?:^|\\s)${target.replaceAll('-', '\\-')}(?:\\s|$)`));
  }
  assert.match(apple, /output_dir\/apple\/CitizenSDK\.xcframework/);
  assert.match(apple, /restore_swift_module_artifacts/);
  assert.doesNotMatch(apple, /canonicalize_xcframework_identifiers|LibraryIdentifier \$desired/);
  assert.match(apple, /resolve_xcframework_framework_slice/);
  assert.match(
    restoreSwiftModules,
    /abi\.json private\.swiftinterface swiftdoc swiftinterface swiftmodule swiftsourceinfo/,
  );
  assert.match(
    restoreSwiftModules,
    /source="\$source_root\/Modules\/CitizenSDK\.swiftmodule\/\$module_identity\.\$extension"/,
  );
  assert.match(
    restoreSwiftModules,
    /destination="\$destination_root\/Modules\/CitizenSDK\.swiftmodule\/\$module_identity\.\$extension"/,
  );
  assert.match(restoreSwiftModules, /cmp -s "\$source" "\$destination"/);
  assert.match(restoreSwiftModules, /cp "\$source" "\$destination"/);
  assert.equal(apple.split('compile_apple_flutter_adapter').length - 1, 3);
  assert.equal(apple.split('resolve_xcframework_framework_slice').length - 1, 3);
  assert.match(appleTests, /uname -m.*arm64/);
  assert.equal(appleTests.split('run_apple_test_harness').length - 1, 3);
  assert.match(appleTests, /aarch64-apple-ios[^\n]*iphoneos[^\n]*arm64-apple-ios16\.0/);
  assert.match(appleTests, /aarch64-apple-ios-sim[\s\S]*arm64-apple-ios16\.0-simulator/);
  assert.match(appleTests, /aarch64-apple-darwin[^\n]*macosx[^\n]*arm64-apple-macosx13\.0/);
  assert.match(appleTests, /aarch64-apple-ios Flutter .* compile/);
  assert.match(appleTests, /aarch64-apple-ios-sim Flutter[\s\S]*compile/);
  assert.match(appleTests, /aarch64-apple-darwin FlutterMacOS .* run/);
  assert.match(appleTests, /run_final_apple_consumer_smoke/);
  assert.match(appleTestHarness, /apple-test-harness\/\$slice_name/);
  assert.match(appleTestHarness, /apple-test-scratch\/\$slice_name/);
  assert.match(
    appleTestHarness,
    /run\|compile\) swiftpm_target=\(build --build-tests\)/,
  );
  assert.match(
    appleTestHarness,
    /swift "\$\{swiftpm_target\[@\]\}" "\$\{swiftpm_paths\[@\]\}"/,
  );
  assert.equal(
    appleTestHarness.split('swift test --skip-build "${swiftpm_paths[@]}"').length - 1,
    1,
  );
  assert.match(appleTestHarness, /TMPDIR="\$scratch\/tmp"/);
  assert.match(appleTestPackage, /darwin\/Tests\/CitizenSDKTests/);
  assert.match(appleTestPackage, /darwin\/Tests\/CitizenSDKFlutterTests/);
  assert.match(source, /apple-tests\) build_apple_tests/);
  assert.match(source, /all\) build_android; build_apple; build_apple_tests;/);
  assert.match(smokeShell, /output_dir\/apple\/CitizenSDK\.xcframework/);
  assert.match(smokeShell, /resolve_xcframework_framework_slice/);
  assert.match(smokeShell, /CitizenSDK macos ''/);
  assert.match(smokeShell, /-framework CitizenSDK/);
  assert.match(
    smokeShell,
    /expected_install_name='@rpath\/CitizenSDK\.framework\/Versions\/A\/CitizenSDK'/,
  );
  assert.match(smokeShell, /HOME="\$smoke_root\/home-normal"/);
  assert.match(smokeShell, /HOME="\$smoke_root\/home-supervisor"/);
  assert.match(smokeShell, /logs\/normal\.log/);
  assert.match(smokeShell, /logs\/supervisor\.log/);
  assert.equal(smokeShell.split('"$executable" normal').length - 1, 1);
  assert.equal(smokeShell.split('"$executable" supervisor').length - 1, 1);
  assert.doesNotMatch(smokeShell, /product_ffi_manifest|static_library|darwin_source_root/);
  assert.match(consumerSmoke, /CitizenSDK\.open\(\)/);
  assert.match(consumerSmoke, /capabilities\.statuses\.count == 10/);
  assert.match(consumerSmoke, /capabilities\.revision >= 1/);
  assert.match(consumerSmoke, /CitizenCapabilityName\.allCases/);
  assert.match(consumerSmoke, /sdk\.lifecycle == \.disposed/);
  assert.equal(consumerSmoke.split('try sdk.close()').length - 1, 2);
  assert.match(consumerSmoke, /F_GETPATH/);
  assert.match(consumerSmoke, /public-state-v1\.sqlite3/);
  assert.match(consumerSmoke, /secure-state-v1\.sqlite3/);
  assert.match(consumerSmoke, /abandoned = nil/);
  assert.match(consumerSmoke, /let reopened = try CitizenSDK\.open\(\)/);
  assert.doesNotMatch(consumerSmoke, /\.start\(|hardwareVault|SecretVault/);
  assert.doesNotMatch(apple, /x86_64|universal|libsmoldot\.a|lipo -create/);
  assert.match(host, /--target aarch64-apple-darwin/);
  // “禁止 x86/universal”可以出现在安全注释中；门禁只拒绝真正建立第二条
  // macOS 构建路径的命令或架构设置，避免把说明文字误当成实现。
  assert.doesNotMatch(
    host,
    /--target\s+x86_64-apple-darwin|(?:^|[;&|]\s*)lipo\s+-create|ARCHS\s*=\s*['"]?x86_64/m,
  );
  return {
    apple,
    appleTestHarness,
    appleTestPackage,
    appleTests,
    flutterAdapter,
    host,
    slice,
    restoreSwiftModules,
    verifySlice,
  };
}

// Kotlin 编译器必须把 project persistent state 明确投影到中央 work dir，
// 不能依赖 Gradle/Kotlin 默认值在 android/.kotlin 留下构建记录。
function assertAndroidKotlinPersistentStateContract(source) {
  const marker = 'build_android() {\n';
  const start = source.indexOf(marker);
  assert.notEqual(start, -1, '缺少 build_android');
  const end = source.indexOf('\n}\n', start + marker.length);
  assert.notEqual(end, -1, 'build_android 未闭合');
  const android = source.slice(start, end + 3);
  assert.match(android, /local kotlin_persistent_dir/);
  assert.match(android, /kotlin_persistent_dir="\$work_dir\/kotlin-project-persistent"/);
  assert.match(android, /prepare_safe_directory[\s\S]*"\$kotlin_persistent_dir"/);
  assert.equal(
    android.split('-Pkotlin.project.persistent.dir="$kotlin_persistent_dir"').length - 1,
    1,
  );
  assert.doesNotMatch(android, /sdk_dir\/android\/\.kotlin|android_gradle_project\/\.kotlin/);
  assert.doesNotMatch(source, /mkdir[^\n]*android\/\.kotlin/);
}

test('smoldot Dart Release 合同固定根包生产、测试与来源记录迁移闭集', () => {
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

test('Release 原生产物只允许版本化 macOS framework 五链接并拒绝其它路径链接', () => {
  const root = mkdtempSync(join(workRoot, 'release-native-source-path-test-'));
  try {
    const valid = writeNativeFixture(join(root, 'valid'));
    assert.doesNotThrow(() => assertNativeArtifactSources(valid));

    const malformedMac = writeNativeFixture(join(root, 'malformed-macos'));
    // LibraryIdentifier 是 Xcode 生成的不透明技术标识；测试只使用
    // fixture 内部映射定位，不把产品平台名伪造成目录名。
    const malformedBinary = join(
      malformedMac,
      'apple',
      'CitizenSDK.xcframework',
      appleFixtureSliceIdentifiers.macOS,
      'CitizenSDK.framework',
      'CitizenSDK',
    );
    rmSync(malformedBinary);
    symlinkSync('Versions/A/CitizenSDK', malformedBinary);
    assert.throws(
      () => assertNativeArtifactSources(malformedMac),
      /符号链接目标漂移/,
    );

    const ancestorCase = join(root, 'ancestor-case');
    const ancestorNative = writeNativeFixture(ancestorCase);
    const outsideAndroid = join(root, 'outside-android');
    mkdirSync(join(outsideAndroid, 'arm64-v8a'), { recursive: true });
    writeFileSync(join(outsideAndroid, 'citizensdk.aar'), 'injected\n');
    writeFileSync(join(outsideAndroid, 'arm64-v8a', 'libcitizensdk.so'), 'injected\n');
    writeFileSync(join(outsideAndroid, 'arm64-v8a', 'libcitizensdk_jni.so'), 'injected\n');
    rmSync(join(ancestorNative, 'android'), { recursive: true });
    symlinkSync(outsideAndroid, join(ancestorNative, 'android'), 'dir');
    assert.throws(
      () => assertNativeArtifactSources(ancestorNative),
      /原生产物路径禁止符号链接：android\/citizensdk\.aar/,
    );

    const danglingCase = join(root, 'dangling-case');
    const danglingNative = writeNativeFixture(danglingCase);
    const danglingFramework = join(danglingNative, 'apple', 'CitizenSDK.xcframework');
    rmSync(danglingFramework, { recursive: true });
    symlinkSync(join(root, 'missing-CitizenSDK.xcframework'), danglingFramework, 'dir');
    assert.throws(
      () => assertNativeArtifactSources(danglingNative),
      /原生产物路径禁止符号链接：apple\/CitizenSDK\.xcframework/,
    );
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test('Android AAR 与 Flutter 投影固定同一双库且原生面不引用 Flutter', () => {
  const root = mkdtempSync(join(workRoot, 'release-android-projection-test-'));
  try {
    const valid = join(root, 'valid');
    writeAndroidProjectionFixture(valid);
    assert.doesNotThrow(() => assertAndroidReleaseProjection(valid));

    const mismatched = join(root, 'mismatched');
    writeAndroidProjectionFixture(mismatched);
    writeFileSync(
      join(mismatched, 'android', 'src', 'main', 'jniLibs', 'arm64-v8a', 'libcitizensdk_jni.so'),
      'different-jni',
    );
    assert.throws(
      () => assertAndroidReleaseProjection(mismatched),
      /AAR 与 Flutter 投影的双原生库字节不一致/,
    );

    const extraAbi = join(root, 'extra-abi');
    writeAndroidProjectionFixture(extraAbi, {
      extraEntries: {
        'jni/x86_64/libcitizensdk.so': Buffer.from('wrong-abi'),
      },
    });
    assert.throws(
      () => assertAndroidReleaseProjection(extraAbi),
      /AAR 双库闭集漂移/,
    );

    const flutterReference = join(root, 'flutter-reference');
    writeAndroidProjectionFixture(flutterReference, {
      classEntries: {
        'org/citizen/sdk/CitizenSdk.class': Buffer.from('uses io/flutter/plugin/common'),
        'org/citizen/sdk/CitizenSdkLifecycle.class': Buffer.from('CitizenSDK lifecycle'),
        'org/citizen/sdk/CitizenSdkException.class': Buffer.from('CitizenSDK errors'),
        'org/citizen/sdk/CitizenSdkEvents.class': Buffer.from('CitizenSDK events'),
        'org/citizen/sdk/CitizenWalletProfile.class': Buffer.from('CitizenSDK wallet profile'),
        'org/citizen/sdk/CitizenSdkOperation.class': Buffer.from('CitizenSDK operation'),
        'org/citizen/sdk/internal/CitizenSdkNative.class': Buffer.from('CitizenSDK JNI owner'),
        'org/citizen/sdk/internal/CitizenSdkHardwareVault.class': Buffer.from('CitizenSDK vault'),
        'org/citizen/sdk/internal/CitizenSdkHostServices.class': Buffer.from('CitizenSDK host services'),
        'org/citizen/sdk/internal/CitizenSdkRequestRouter.class': Buffer.from('CitizenSDK request router'),
        'org/citizen/sdk/ui/CitizenSdkWalletFlowActivity.class': Buffer.from('CitizenSDK wallet activity'),
        'org/citizen/sdk/ui/CitizenSdkWalletFlowContract.class': Buffer.from('CitizenSDK wallet contract'),
        'org/citizen/sdk/ui/CitizenSdkWalletFlowCoordinator.class': Buffer.from('CitizenSDK wallet coordinator'),
      },
    });
    assert.throws(
      () => assertAndroidReleaseProjection(flutterReference),
      /原生 AAR 混入或引用 Flutter API/,
    );

    const missingClass = join(root, 'missing-class');
    const classes = {
      'org/citizen/sdk/CitizenSdk.class': Buffer.from('CitizenSDK native facade'),
      'org/citizen/sdk/CitizenSdkLifecycle.class': Buffer.from('CitizenSDK lifecycle'),
      'org/citizen/sdk/CitizenSdkException.class': Buffer.from('CitizenSDK errors'),
      'org/citizen/sdk/CitizenSdkEvents.class': Buffer.from('CitizenSDK events'),
      'org/citizen/sdk/CitizenWalletProfile.class': Buffer.from('CitizenSDK wallet profile'),
      'org/citizen/sdk/CitizenSdkOperation.class': Buffer.from('CitizenSDK operation'),
      'org/citizen/sdk/internal/CitizenSdkNative.class': Buffer.from('CitizenSDK JNI owner'),
      'org/citizen/sdk/internal/CitizenSdkHardwareVault.class': Buffer.from('CitizenSDK vault'),
      'org/citizen/sdk/internal/CitizenSdkHostServices.class': Buffer.from('CitizenSDK host services'),
      'org/citizen/sdk/internal/CitizenSdkRequestRouter.class': Buffer.from('CitizenSDK request router'),
      'org/citizen/sdk/ui/CitizenSdkWalletFlowActivity.class': Buffer.from('CitizenSDK wallet activity'),
      'org/citizen/sdk/ui/CitizenSdkWalletFlowContract.class': Buffer.from('CitizenSDK wallet contract'),
    };
    writeAndroidProjectionFixture(missingClass, { classEntries: classes });
    assert.throws(
      () => assertAndroidReleaseProjection(missingClass),
      /classes\.jar 缺少必需实现.*CitizenSdkWalletFlowCoordinator/,
    );

    const assetDrift = join(root, 'asset-drift');
    writeAndroidProjectionFixture(assetDrift);
    writeFileSync(join(assetDrift, 'assets', 'citizenchain', 'chainspec.json'), 'drift');
    assert.throws(
      () => assertAndroidReleaseProjection(assetDrift),
      /AAR 链资产与候选信任锚字节不一致/,
    );

    const nestedAar = join(root, 'nested-aar');
    writeAndroidProjectionFixture(nestedAar, {
      extraEntries: { 'libs/second-sdk.aar': Buffer.from('nested') },
    });
    assert.throws(
      () => assertAndroidReleaseProjection(nestedAar),
      /混入嵌套 AAR/,
    );
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test('Apple XCFramework 固定三个 arm64 技术变体、产品 ABI、版本与来源投影', () => {
  const root = mkdtempSync(join(workRoot, 'release-apple-projection-test-'));
  try {
    const valid = join(root, 'valid');
    writeAppleProjectionFixture(valid);
    assert.doesNotThrow(() => assertAppleReleaseProjection(valid));
    const validMacFramework = appleFixtureFramework(valid, 'macOS');
    for (const [path, target] of Object.entries(macOSFrameworkSymlinks)) {
      assert.equal(readlinkSync(join(validMacFramework, ...path.split('/'))), target);
    }

    const extraSliceRootEntry = join(root, 'extra-slice-root-entry');
    writeAppleProjectionFixture(extraSliceRootEntry);
    mkdirSync(join(dirname(appleFixtureFramework(extraSliceRootEntry, 'iosDevice')), 'unreviewed'));
    assert.throws(
      () => assertAppleReleaseProjection(extraSliceRootEntry),
      /slice 根闭集漂移/,
    );

    const extraHeaderEntry = join(root, 'extra-header-entry');
    writeAppleProjectionFixture(extraHeaderEntry);
    mkdirSync(join(appleFixtureContentRoot(extraHeaderEntry, 'iosDevice'), 'Headers', 'unreviewed'));
    assert.throws(
      () => assertAppleReleaseProjection(extraHeaderEntry),
      /Headers 目录闭集漂移/,
    );

    const extraModulesEntry = join(root, 'extra-modules-entry');
    writeAppleProjectionFixture(extraModulesEntry);
    mkdirSync(join(appleFixtureContentRoot(extraModulesEntry, 'iosSimulator'),
      'Modules', 'unreviewed'));
    assert.throws(
      () => assertAppleReleaseProjection(extraModulesEntry),
      /Modules 目录闭集漂移/,
    );

    const nonFileSwiftModuleEntry = join(root, 'non-file-swift-module-entry');
    writeAppleProjectionFixture(nonFileSwiftModuleEntry);
    mkdirSync(join(appleFixtureContentRoot(nonFileSwiftModuleEntry, 'macOS'),
      'Modules', 'CitizenSDK.swiftmodule', 'unreviewed'));
    assert.throws(
      () => assertAppleReleaseProjection(nonFileSwiftModuleEntry),
      /Swift module 只允许普通文件/,
    );

    const extraResourcesEntry = join(root, 'extra-resources-entry');
    writeAppleProjectionFixture(extraResourcesEntry);
    mkdirSync(join(appleFixtureContentRoot(extraResourcesEntry, 'iosDevice'),
      'Resources', 'unreviewed'));
    assert.throws(
      () => assertAppleReleaseProjection(extraResourcesEntry),
      /Resources 目录闭集漂移/,
    );

    const extraVersionEntry = join(root, 'extra-version-entry');
    writeAppleProjectionFixture(extraVersionEntry);
    mkdirSync(join(appleFixtureContentRoot(extraVersionEntry, 'macOS'), 'unreviewed'));
    assert.throws(
      () => assertAppleReleaseProjection(extraVersionEntry),
      /版本化 framework 闭集漂移/,
    );

    for (const sliceKey of ['iosDevice', 'iosSimulator']) {
      const linkedIos = join(root, `linked-${sliceKey}`);
      writeAppleProjectionFixture(linkedIos);
      const framework = appleFixtureFramework(linkedIos, sliceKey);
      rmSync(join(framework, 'Headers'), { recursive: true });
      symlinkSync('Resources', join(framework, 'Headers'));
      assert.throws(
        () => assertAppleReleaseProjection(linkedIos),
        /禁止未声明符号链接/,
      );
    }

    const shallowMacOS = join(root, 'shallow-macos');
    writeAppleProjectionFixture(shallowMacOS);
    const shallowFramework = appleFixtureFramework(shallowMacOS, 'macOS');
    const shallowContent = join(shallowFramework, 'Versions', 'A');
    for (const entry of ['CitizenSDK', 'Headers', 'Modules', 'Resources']) {
      rmSync(join(shallowFramework, entry), { recursive: true, force: true });
      cpSync(join(shallowContent, entry), join(shallowFramework, entry), { recursive: true });
    }
    copyFileSync(
      join(shallowFramework, 'Resources', 'Info.plist'),
      join(shallowFramework, 'Info.plist'),
    );
    rmSync(join(shallowFramework, 'Resources', 'Info.plist'));
    rmSync(join(shallowFramework, 'Versions'), { recursive: true });
    assert.throws(
      () => assertAppleReleaseProjection(shallowMacOS),
      /缺少已声明符号链接|framework 根闭集漂移/,
    );

    const macLinkDrifts = [
      ['extra', 'Unexpected', 'Versions/Current/CitizenSDK'],
      ['wrong-target', 'CitizenSDK', 'Versions/A/CitizenSDK'],
      ['absolute-target', 'Headers', '/tmp/CitizenSDK-Headers'],
      ['parent-target', 'Modules', 'Versions/../Versions/Current/Modules'],
      ['escaping-target', 'Resources', '../../../../../../outside-resources'],
    ];
    for (const [name, path, target] of macLinkDrifts) {
      const drift = join(root, `macos-link-${name}`);
      writeAppleProjectionFixture(drift);
      const framework = appleFixtureFramework(drift, 'macOS');
      const link = join(framework, ...path.split('/'));
      rmSync(link, { recursive: true, force: true });
      symlinkSync(target, link);
      assert.throws(
        () => assertAppleReleaseProjection(drift),
        /禁止未声明符号链接|符号链接目标漂移|符号链接越出受控根/,
      );
    }

    const danglingMacOS = join(root, 'macos-link-dangling');
    writeAppleProjectionFixture(danglingMacOS);
    rmSync(join(appleFixtureContentRoot(danglingMacOS, 'macOS'), 'CitizenSDK'));
    assert.throws(
      () => assertAppleReleaseProjection(danglingMacOS),
      /符号链接悬空或成环/,
    );

    const nestedEscape = join(root, 'macos-link-nested-escape');
    writeAppleProjectionFixture(nestedEscape);
    const outside = join(root, 'outside-header');
    writeFileSync(outside, 'outside');
    symlinkSync(outside, join(
      appleFixtureContentRoot(nestedEscape, 'macOS'),
      'Headers',
      'outside.h',
    ));
    assert.throws(
      () => assertAppleReleaseProjection(nestedEscape),
      /禁止未声明符号链接/,
    );

    const missingSymbol = join(root, 'missing-symbol');
    writeAppleProjectionFixture(missingSymbol, {
      iosDevice: { symbols: [...citizenSdkSymbols().slice(0, -1), '$s10CitizenSDK0A0CMa'] },
    });
    assert.throws(
      () => assertAppleReleaseProjection(missingSymbol),
      /精确导出 70 个 citizensdk_/,
    );

    const legacySymbol = join(root, 'legacy-symbol');
    writeAppleProjectionFixture(legacySymbol, {
      macOS: { symbols: [...citizenSdkExportSymbols(), 'smoldot_json_rpc_send'] },
    });
    assert.throws(
      () => assertAppleReleaseProjection(legacySymbol),
      /泄漏 legacy 低层符号/,
    );

    const foreignSymbol = join(root, 'foreign-symbol');
    writeAppleProjectionFixture(foreignSymbol, {
      iosDevice: { symbols: [...citizenSdkExportSymbols(), 'foreign_probe'] },
    });
    assert.throws(
      () => assertAppleReleaseProjection(foreignSymbol),
      /泄漏非 CitizenSDK 产品符号/,
    );

    const missingSwiftExport = join(root, 'missing-swift-export');
    writeAppleProjectionFixture(missingSwiftExport, {
      iosSimulator: { symbols: citizenSdkSymbols() },
    });
    assert.throws(
      () => assertAppleReleaseProjection(missingSwiftExport),
      /缺少 CitizenSDK Swift 模块导出/,
    );

    const wrongInstallName = join(root, 'wrong-install-name');
    writeAppleProjectionFixture(wrongInstallName, {
      iosSimulator: { installName: '/tmp/CitizenSDK.framework/CitizenSDK' },
    });
    assert.throws(
      () => assertAppleReleaseProjection(wrongInstallName),
      /install name 漂移/,
    );

    for (const sliceKey of ['iosDevice', 'iosSimulator']) {
      const versionedIosIdentity = join(root, `versioned-install-name-${sliceKey}`);
      writeAppleProjectionFixture(versionedIosIdentity, {
        [sliceKey]: {
          installName: '@rpath/CitizenSDK.framework/Versions/A/CitizenSDK',
        },
      });
      assert.throws(
        () => assertAppleReleaseProjection(versionedIosIdentity),
        /install name 漂移/,
      );
    }

    for (const [name, installName] of [
      ['shallow', '@rpath/CitizenSDK.framework/CitizenSDK'],
      ['current', '@rpath/CitizenSDK.framework/Versions/Current/CitizenSDK'],
    ]) {
      const wrongMacIdentity = join(root, `macos-install-name-${name}`);
      writeAppleProjectionFixture(wrongMacIdentity, {
        macOS: { installName },
      });
      assert.throws(
        () => assertAppleReleaseProjection(wrongMacIdentity),
        /install name 漂移/,
      );
    }

    const wrongMinimum = join(root, 'wrong-minimum');
    writeAppleProjectionFixture(wrongMinimum, {
      macOS: { minimum: '14.0.0' },
    });
    assert.throws(
      () => assertAppleReleaseProjection(wrongMinimum),
      /平台或最低系统版本漂移/,
    );

    const wrongArchitecture = join(root, 'wrong-architecture');
    writeAppleProjectionFixture(wrongArchitecture, {
      iosDevice: { cpuType: 0x01000007 },
    });
    assert.throws(
      () => assertAppleReleaseProjection(wrongArchitecture),
      /单一 arm64 动态 framework/,
    );

    const universalBinary = join(root, 'universal-binary');
    const fatMachO = Buffer.alloc(32);
    fatMachO.writeUInt32BE(0xcafebabe, 0);
    writeAppleProjectionFixture(universalBinary, {
      macOS: { binary: fatMachO },
    });
    assert.throws(
      () => assertAppleReleaseProjection(universalBinary),
      /thin 64-bit Mach-O/,
    );

    const assetDrift = join(root, 'asset-drift');
    writeAppleProjectionFixture(assetDrift);
    writeFileSync(
      join(appleFixtureContentRoot(assetDrift, 'macOS'),
        'Resources', 'citizenchain', 'chainspec.json'),
      'drift',
    );
    assert.throws(
      () => assertAppleReleaseProjection(assetDrift),
      /Resource 与唯一来源字节不一致/,
    );

    for (const extension of appleSwiftModuleExtensions) {
      const missingModule = join(root, `missing-module-${extension.replaceAll('.', '-')}`);
      writeAppleProjectionFixture(missingModule);
      rmSync(join(
        appleFixtureContentRoot(missingModule, 'iosDevice'),
        'Modules',
        'CitizenSDK.swiftmodule',
        `arm64-apple-ios.${extension}`,
      ));
      assert.throws(
        () => assertAppleReleaseProjection(missingModule),
        /Swift module 六文件闭集或架构身份漂移/,
      );
    }

    for (const [name, addEntry] of [
      ['file', (moduleRoot) => writeFileSync(join(moduleRoot, 'unreviewed.swiftmodule'), 'x')],
      ['directory', (moduleRoot) => mkdirSync(join(moduleRoot, 'unreviewed'))],
    ]) {
      const extraModule = join(root, `extra-swift-module-${name}`);
      writeAppleProjectionFixture(extraModule);
      addEntry(join(
        appleFixtureContentRoot(extraModule, 'iosSimulator'),
        'Modules',
        'CitizenSDK.swiftmodule',
      ));
      assert.throws(
        () => assertAppleReleaseProjection(extraModule),
        /Swift module 只允许普通文件|Swift module 六文件闭集或架构身份漂移/,
      );
    }

    const invalidInterface = join(root, 'invalid-interface');
    writeAppleProjectionFixture(invalidInterface);
    writeFileSync(
      join(
        appleFixtureContentRoot(invalidInterface, 'macOS'),
        'Modules',
        'CitizenSDK.swiftmodule',
        'arm64-apple-macos.swiftinterface',
      ),
      '// swift-interface-format-version: 1.0\n',
    );
    assert.throws(
      () => assertAppleReleaseProjection(invalidInterface),
      /Swift interface 未固定同名 underlying Clang module/,
    );

    const invalidPrivateInterface = join(root, 'invalid-private-interface');
    writeAppleProjectionFixture(invalidPrivateInterface);
    const invalidPrivateModules = join(
      appleFixtureContentRoot(invalidPrivateInterface, 'macOS'),
      'Modules',
      'CitizenSDK.swiftmodule',
    );
    copyFileSync(
      join(invalidPrivateModules, 'arm64-apple-macos.swiftinterface'),
      join(invalidPrivateModules, 'arm64-apple-macos.private.swiftinterface'),
    );
    assert.throws(
      () => assertAppleReleaseProjection(invalidPrivateInterface),
      /public\/private Swift interface 或 CitizenSDKFlutter SPI 闭集漂移/,
    );

    const extraPrivateSpi = join(root, 'extra-private-spi');
    writeAppleProjectionFixture(extraPrivateSpi);
    const extraPrivatePath = join(
      appleFixtureContentRoot(extraPrivateSpi, 'iosDevice'),
      'Modules',
      'CitizenSDK.swiftmodule',
      'arm64-apple-ios.private.swiftinterface',
    );
    writeFileSync(
      extraPrivatePath,
      readFileSync(extraPrivatePath, 'utf8')
        + '@_spi(CitizenSDKFlutter) public func unexpectedSPI()\n',
    );
    assert.throws(
      () => assertAppleReleaseProjection(extraPrivateSpi),
      /CitizenSDKFlutter SPI 闭集漂移/,
    );

    const wrongInterfaceTarget = join(root, 'wrong-interface-target');
    writeAppleProjectionFixture(wrongInterfaceTarget);
    const wrongTargetPath = join(
      wrongInterfaceTarget,
      'darwin',
      'CitizenSDK.xcframework',
      appleFixtureSliceIdentifiers.iosSimulator,
      'CitizenSDK.framework',
      'Modules',
      'CitizenSDK.swiftmodule',
      'arm64-apple-ios-simulator.swiftinterface',
    );
    writeFileSync(
      wrongTargetPath,
      readFileSync(wrongTargetPath, 'utf8')
        .replace('arm64-apple-ios16.0-simulator', 'x86_64-apple-ios16.0-simulator'),
    );
    assert.throws(
      () => assertAppleReleaseProjection(wrongInterfaceTarget),
      /Swift interface target triple 漂移/,
    );

    const leakedPublicType = join(root, 'leaked-public-type');
    writeAppleProjectionFixture(leakedPublicType);
    const leakedModules = join(
      appleFixtureContentRoot(leakedPublicType, 'iosDevice'),
      'Modules',
      'CitizenSDK.swiftmodule',
    );
    for (const extension of ['swiftinterface', 'private.swiftinterface']) {
      const path = join(leakedModules, `arm64-apple-ios.${extension}`);
      writeFileSync(
        path,
        readFileSync(path, 'utf8')
          + 'public struct CitizenSDKNative {}\n',
      );
    }
    assert.throws(
      () => assertAppleReleaseProjection(leakedPublicType),
      /public Swift interface 泄漏底层/,
    );

    const wrongModuleTriple = join(root, 'wrong-module-triple');
    writeAppleProjectionFixture(wrongModuleTriple);
    const simulatorModules = join(
      wrongModuleTriple,
      'darwin',
      'CitizenSDK.xcframework',
      appleFixtureSliceIdentifiers.iosSimulator,
      'CitizenSDK.framework',
      'Modules',
      'CitizenSDK.swiftmodule',
    );
    for (const extension of appleSwiftModuleExtensions) {
      copyFileSync(
        join(simulatorModules, `arm64-apple-ios-simulator.${extension}`),
        join(simulatorModules, `arm64-apple-ios.${extension}`),
      );
      rmSync(join(simulatorModules, `arm64-apple-ios-simulator.${extension}`));
    }
    assert.throws(
      () => assertAppleReleaseProjection(wrongModuleTriple),
      /Swift module 六文件闭集或架构身份漂移/,
    );

    const frameworkInfoDrifts = [
      ['development-region', { CFBundleDevelopmentRegion: 'zh' }],
      ['executable', { CFBundleExecutable: 'CitizenSDKProbe' }],
      ['identifier', { CFBundleIdentifier: 'org.citizen.sdk.probe' }],
      ['info-version', { CFBundleInfoDictionaryVersion: '7.0' }],
      ['name', { CFBundleName: 'CitizenSDKProbe' }],
      ['package-type', { CFBundlePackageType: 'BNDL' }],
      ['short-version', { CFBundleShortVersionString: '1.0.1' }],
      ['supported-platforms', { CFBundleSupportedPlatforms: ['iPhoneOS', 'MacOSX'] }],
      ['bundle-version', { CFBundleVersion: '2' }],
      ['dt-platform', { DTPlatformName: 'macosx' }],
      ['minimum-version', { MinimumOSVersion: '17.0' }],
      ['unknown-key', { UnreviewedPlatformIdentity: 'probe' }],
    ];
    for (const [name, info] of frameworkInfoDrifts) {
      const drift = join(root, `framework-info-${name}`);
      writeAppleProjectionFixture(drift, { iosDevice: { info } });
      assert.throws(
        () => assertAppleReleaseProjection(drift),
        /framework Info\.plist 身份漂移/,
      );
    }

    const extraArchitecture = join(root, 'extra-architecture');
    writeAppleProjectionFixture(extraArchitecture, {
      iosDevice: { architectures: ['arm64', 'x86_64'] },
    });
    assert.throws(
      () => assertAppleReleaseProjection(extraArchitecture),
      /slice 字段闭集漂移|slice 元数据漂移/,
    );

    for (const [identifier, binaryPath] of [
      ['iosDevice', 'CitizenSDK.framework/Versions/A/CitizenSDK'],
      ['iosSimulator', 'CitizenSDK.framework/Versions/A/CitizenSDK'],
      ['macOS', 'CitizenSDK.framework/CitizenSDK'],
    ]) {
      const wrongBinaryPath = join(root, `wrong-binary-path-${identifier}`);
      writeAppleProjectionFixture(wrongBinaryPath, {
        [identifier]: { binaryPath },
      });
      assert.throws(
        () => assertAppleReleaseProjection(wrongBinaryPath),
        /slice 元数据漂移/,
      );
    }

    const unknownLibraryField = join(root, 'unknown-library-field');
    writeAppleProjectionFixture(unknownLibraryField, {
      macOS: { libraryInfo: { UnreviewedBinaryIdentity: 'probe' } },
    });
    assert.throws(
      () => assertAppleReleaseProjection(unknownLibraryField),
      /slice 字段闭集漂移/,
    );

    const wrongXcframeworkFormat = join(root, 'wrong-xcframework-format');
    writeAppleProjectionFixture(wrongXcframeworkFormat, {
      xcframeworkInfo: { fields: { XCFrameworkFormatVersion: '2.0' } },
    });
    assert.throws(
      () => assertAppleReleaseProjection(wrongXcframeworkFormat),
      /Info\.plist 格式或 slice 数量无效/,
    );

    const unknownPlatform = join(root, 'unknown-platform');
    writeAppleProjectionFixture(unknownPlatform, {
      macOS: { supportedPlatform: 'watchos' },
    });
    assert.throws(
      () => assertAppleReleaseProjection(unknownPlatform),
      /slice 元数据漂移/,
    );

    const unexpectedVariant = join(root, 'unexpected-variant');
    writeAppleProjectionFixture(unexpectedVariant, {
      iosDevice: { variant: 'simulator' },
    });
    assert.throws(
      () => assertAppleReleaseProjection(unexpectedVariant),
      /技术变体重复|slice 字段闭集漂移|slice 元数据漂移/,
    );

    const wrongResourceLevel = join(root, 'wrong-resource-level');
    writeAppleProjectionFixture(wrongResourceLevel);
    const resourceRoot = join(
      appleFixtureContentRoot(wrongResourceLevel, 'iosDevice'),
      'Resources',
    );
    copyFileSync(
      join(resourceRoot, 'citizenchain', 'chainspec.json'),
      join(resourceRoot, 'chainspec.json'),
    );
    rmSync(join(resourceRoot, 'citizenchain', 'chainspec.json'));
    assert.throws(
      () => assertAppleReleaseProjection(wrongResourceLevel),
      /Resources 目录闭集漂移/,
    );

    const missingSlice = join(root, 'missing-slice');
    writeAppleProjectionFixture(missingSlice);
    rmSync(
      join(missingSlice, 'darwin', 'CitizenSDK.xcframework',
        appleFixtureSliceIdentifiers.iosSimulator),
      { recursive: true },
    );
    assert.throws(
      () => assertAppleReleaseProjection(missingSlice),
      /三 slice 闭集漂移/,
    );

    const suffixedSlice = join(root, 'suffixed-slice');
    writeAppleProjectionFixture(suffixedSlice);
    const suffixedXcframework = join(suffixedSlice, 'darwin', 'CitizenSDK.xcframework');
    cpSync(
      join(suffixedXcframework, appleFixtureSliceIdentifiers.macOS),
      join(suffixedXcframework, 'unlisted-library'),
      { recursive: true },
    );
    rmSync(join(suffixedXcframework, appleFixtureSliceIdentifiers.macOS), { recursive: true });
    assert.throws(
      () => assertAppleReleaseProjection(suffixedSlice),
      /SDK 候选禁止未声明符号链接：unlisted-library\/CitizenSDK\.framework\/CitizenSDK/,
    );

    const extraSlice = join(root, 'extra-slice');
    writeAppleProjectionFixture(extraSlice);
    mkdirSync(join(extraSlice, 'darwin', 'CitizenSDK.xcframework', 'unlisted-library-extra'));
    assert.throws(
      () => assertAppleReleaseProjection(extraSlice),
      /三 slice 闭集漂移/,
    );
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test('Dart、Android 与 Apple 生产绑定以固定哈希和反向闭集进入 Release', () => {
  const root = mkdtempSync(join(workRoot, 'release-mobile-binding-test-'));
  try {
    cpSync(join(citizenSdkRoot, 'lib'), join(root, 'lib'), { recursive: true });
    cpSync(join(citizenSdkRoot, 'android'), join(root, 'android'), { recursive: true });
    cpSync(join(citizenSdkRoot, 'darwin'), join(root, 'darwin'), { recursive: true });
    assert.doesNotThrow(() => assertMobileBindingSource(root));

    const darwinSourceLink = join(
      root,
      'darwin',
      'Sources',
      'CitizenSDK',
      'CitizenSDKSourceLink.swift',
    );
    symlinkSync('CitizenSDK.swift', darwinSourceLink);
    assert.throws(
      () => assertMobileBindingSource(root),
      /禁止未声明符号链接/,
    );
    rmSync(darwinSourceLink);

    mkdirSync(join(root, 'android', '.kotlin', 'sessions'), { recursive: true });
    assert.throws(
      () => assertMobileBindingSource(root),
      /源码禁止存在 Android Kotlin 持久状态目录/,
    );
    rmSync(join(root, 'android', '.kotlin'), { recursive: true });

    writeFileSync(
      join(root, 'android', 'src', 'main', 'kotlin', 'org', 'citizen', 'sdk', 'Unexpected.kt'),
      'package org.citizen.sdk\n',
    );
    assert.throws(
      () => assertMobileBindingSource(root),
      /移动绑定文件闭集漂移.*Unexpected\.kt/,
    );

    rmSync(join(root, 'android', 'src', 'main', 'kotlin', 'org', 'citizen', 'sdk', 'Unexpected.kt'));
    writeFileSync(
      join(root, 'darwin', 'Sources', 'CitizenSDK', 'Unexpected.swift'),
      'enum Unexpected {}\n',
    );
    assert.throws(
      () => assertMobileBindingSource(root),
      /移动绑定文件闭集漂移.*Unexpected\.swift/,
    );
    rmSync(join(root, 'darwin', 'Sources', 'CitizenSDK', 'Unexpected.swift'));

    writeAppleXcframework(join(root, 'darwin', 'CitizenSDK.xcframework'));
    assert.doesNotThrow(() => assertMobileBindingSource(
      root,
      { allowAppleReleaseProjection: true },
    ));
    assert.throws(
      () => assertMobileBindingSource(root),
      /禁止未声明符号链接/,
    );
    symlinkSync(
      'Versions/Current/CitizenSDK',
      join(appleFixtureFramework(root, 'macOS'), 'Unreviewed'),
    );
    assert.throws(
      () => assertMobileBindingSource(root, { allowAppleReleaseProjection: true }),
      /禁止未声明符号链接/,
    );
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test('provider 递归 registry 闭包与随包 PoW 锁逐项一致且完全离线', () => {
  const root = mkdtempSync(join(workRoot, 'release-provider-lock-parity-test-'));
  try {
    copyFileSync(join(citizenSdkRoot, 'Cargo.lock'), join(root, 'Cargo.lock'));
    const powDirectory = join(root, 'native', 'smoldot', 'pow');
    mkdirSync(powDirectory, { recursive: true });
    copyFileSync(
      join(citizenSdkRoot, 'native', 'smoldot', 'pow', 'Cargo.lock'),
      join(powDirectory, 'Cargo.lock'),
    );
    assert.ok(assertProviderLockParity(root) > 0);

    const rootLock = join(root, 'Cargo.lock');
    const edgeDrift = readFileSync(rootLock, 'utf8').replace(
      /(\[\[package\]\]\nname = "winapi-util"\nversion = "0\.1\.11"[\s\S]*?dependencies = \[\n )"windows-sys 0\.61\.2",/,
      '$1"windows-sys 0.60.2",',
    );
    assert.notEqual(edgeDrift, readFileSync(rootLock, 'utf8'));
    writeFileSync(rootLock, edgeDrift);
    assert.throws(
      () => assertProviderLockParity(root),
      /provider registry 依赖边漂移：winapi-util 0\.1\.11/,
    );

    copyFileSync(join(citizenSdkRoot, 'Cargo.lock'), rootLock);
    const altered = readFileSync(rootLock, 'utf8').replace(
      /(\[\[package\]\]\nname = "hex"\nversion = "0\.4\.3"\nsource = "[^"]+"\nchecksum = ")[0-9a-f]{64}("\n)/,
      `$1${'0'.repeat(64)}$2`,
    );
    assert.notEqual(altered, readFileSync(rootLock, 'utf8'));
    writeFileSync(rootLock, altered);
    assert.throws(
      () => assertProviderLockParity(root),
      /provider registry 锁闭包漂移：hex 0\.4\.3/,
    );

    copyFileSync(join(citizenSdkRoot, 'Cargo.lock'), rootLock);
    const featureUnionDrift = readFileSync(rootLock, 'utf8').replace(
      /(\[\[package\]\]\nname = "unicode-normalization"\nversion = "0\.1\.25"\nsource = "[^"]+"\nchecksum = ")[0-9a-f]{64}("\n)/,
      `$1${'0'.repeat(64)}$2`,
    );
    assert.notEqual(featureUnionDrift, readFileSync(rootLock, 'utf8'));
    writeFileSync(rootLock, featureUnionDrift);
    assert.throws(
      () => assertProviderLockParity(root),
      /provider registry 锁闭包漂移：unicode-normalization 0\.1\.25/,
    );

    copyFileSync(join(citizenSdkRoot, 'Cargo.lock'), rootLock);
    rmSync(join(powDirectory, 'Cargo.lock'));
    assert.throws(
      () => assertProviderLockParity(root),
      /缺少普通smoldot PoW Cargo\.lock/,
    );
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test('根 include 固定三文件闭集并只开放安全 citizensdk_* ABI', () => {
  const root = mkdtempSync(join(workRoot, 'release-public-abi-test-'));
  const include = join(root, 'include');
  const source = join(citizenSdkRoot, 'include');
  try {
    cpSync(source, include, { recursive: true });
    assert.doesNotThrow(() => assertPublicAbiHeaders(root));

    writeFileSync(join(include, 'unreviewed.h'), 'void citizensdk_unreviewed(void);\n');
    assert.throws(
      () => assertPublicAbiHeaders(root),
      /根 include 文件闭集漂移.*额外=include\/unreviewed\.h/,
    );
    rmSync(join(include, 'unreviewed.h'));

    const header = join(include, 'citizensdk.h');
    const original = readFileSync(header, 'utf8');
    const rejectDeclaration = (declaration, pattern) => {
      writeFileSync(header, `${original}\n${declaration}\n`);
      assert.throws(() => assertPublicAbiHeaders(root), pattern);
    };
    rejectDeclaration(
      'CITIZENSDK_API uint32_t foreign_probe(void);',
      /公共 ABI 只允许 citizensdk_\* 函数：foreign_probe/,
    );
    rejectDeclaration(
      'uint32_t citizensdk_unmarked_probe(void);',
      /公共 ABI 只允许带导出标记的 citizensdk_\* 函数：citizensdk_unmarked_probe/,
    );
    rejectDeclaration(
      'CITIZENSDK_API uint32_t smoldot_raw_start(void);',
      /公共 ABI 泄漏非产品符号：smoldot_raw_start/,
    );
    rejectDeclaration(
      'CITIZENSDK_API uint32_t citizen_sr25519_sign(void);',
      /公共 ABI 泄漏非产品符号：citizen_sr25519_sign/,
    );
    rejectDeclaration(
      'CITIZENSDK_API uint32_t account_crypto_export(void);',
      /公共 ABI 泄漏非产品符号：account_crypto_export/,
    );
    rejectDeclaration(
      'CITIZENSDK_API uint32_t citizensdk_rpc(const char *method, const char *params);',
      /公共 ABI 禁止任意 rpc\(method, params\)：citizensdk_rpc/,
    );
    rejectDeclaration(
      'CITIZENSDK_API uint32_t citizensdk_query(const char *method, const char *params);',
      /公共 ABI 禁止任意 rpc\(method, params\)：citizensdk_query/,
    );
    rejectDeclaration(
      'CITIZENSDK_API uint32_t citizensdk_export_private_key(uint8_t *out_private_key);',
      /公共 ABI 禁止助记词、私钥或秘密导出：citizensdk_export_private_key/,
    );
    rejectDeclaration(
      'CITIZENSDK_API uint32_t citizensdk_get_mnemonic(uint8_t *out_mnemonic);',
      /公共 ABI 禁止助记词、私钥或秘密导出：citizensdk_get_mnemonic/,
    );
    rejectDeclaration(
      'CITIZENSDK_API uint32_t citizensdk_copy_secret(uint8_t *out_secret);',
      /公共 ABI 禁止助记词、私钥或秘密导出：citizensdk_copy_secret/,
    );
    rejectDeclaration(
      'CITIZENSDK_API uint32_t citizensdk_import_phrase(citizensdk_bytes_view_t mnemonic);',
      /公共 ABI 禁止助记词、私钥或秘密导出：citizensdk_import_phrase/,
    );
    rejectDeclaration(
      'CITIZENSDK_API uint32_t citizensdk_prepared_wallet_copy_mnemonic(citizensdk_prepared_wallet_handle_t prepared_wallet, uint8_t *buffer, uint64_t capacity, uint64_t *out_required);',
      /助记词备份 ABI 必须绑定所属 instance\/prepared handle/,
    );
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test('scripts 根只保留正式三文件并固定原生生产构建器', () => {
  const root = mkdtempSync(join(workRoot, 'release-script-source-test-'));
  const scripts = join(root, 'scripts');
  try {
    cpSync(join(citizenSdkRoot, 'scripts'), scripts, { recursive: true });
    assert.doesNotThrow(() => assertSdkScriptSource(root));

    const buildNative = join(scripts, 'build-native.sh');
    writeFileSync(buildNative, `${readFileSync(buildNative, 'utf8')}\n`);
    assert.throws(
      () => assertSdkScriptSource(root),
      /生产脚本文件哈希漂移：scripts\/build-native\.sh/,
    );

    copyFileSync(join(citizenSdkRoot, 'scripts', 'build-native.sh'), buildNative);
    writeFileSync(join(scripts, 'unreviewed-build.sh'), '#!/bin/sh\n');
    assert.throws(
      () => assertSdkScriptSource(root),
      /scripts 根闭集漂移.*额外=unreviewed-build\.sh/,
    );
    rmSync(join(scripts, 'unreviewed-build.sh'));

    const releaseSource = join(scripts, 'release.mjs');
    writeFileSync(releaseSource, `${readFileSync(releaseSource, 'utf8')}\n`);
    assert.throws(
      () => assertSdkScriptSource(root),
      /候选 release\.mjs 与当前执行真源不一致/,
    );
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test('CitizenSDK 自有 Core Rust 生产源码固定逐文件哈希', () => {
  const root = mkdtempSync(join(workRoot, 'release-core-rust-source-test-'));
  try {
    writeCoreRustFixture(root);
    assert.doesNotThrow(() => assertCoreRustSource(root));

    const source = join(root, 'native', 'engine', 'src', 'lib.rs');
    writeFileSync(source, `${readFileSync(source, 'utf8')}\n`);
    assert.throws(
      () => assertCoreRustSource(root),
      /Core Rust 来源文件哈希漂移：native\/engine\/src\/lib\.rs/,
    );

    copyFileSync(
      join(citizenSdkRoot, 'native', 'engine', 'src', 'lib.rs'),
      source,
    );
    const ffiSource = join(root, 'native', 'ffi', 'src', 'lib.rs');
    writeFileSync(ffiSource, `${readFileSync(ffiSource, 'utf8')}\n`);
    assert.throws(
      () => assertCoreRustSource(root),
      /Core Rust 来源文件哈希漂移：native\/ffi\/src\/lib\.rs/,
    );

    copyFileSync(
      join(citizenSdkRoot, 'native', 'ffi', 'src', 'lib.rs'),
      ffiSource,
    );
    const walletAbi = join(root, 'native', 'ffi', 'src', 'wallet_abi.rs');
    writeFileSync(walletAbi, `${readFileSync(walletAbi, 'utf8')}\n`);
    assert.throws(
      () => assertCoreRustSource(root),
      /Core Rust 来源文件哈希漂移：native\/ffi\/src\/wallet_abi\.rs/,
    );
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test('Core Rust 合同拒绝额外 build.rs 与未审查 native 产品目录', () => {
  const root = mkdtempSync(join(workRoot, 'release-core-rust-closure-test-'));
  try {
    writeCoreRustFixture(root);
    const buildScript = join(root, 'native', 'contracts', 'build.rs');
    writeFileSync(buildScript, 'fn main() {}\n');
    assert.throws(
      () => assertCoreRustSource(root),
      /Core Rust 文件闭集漂移：native\/contracts.*额外=native\/contracts\/build\.rs/,
    );

    rmSync(buildScript);
    const hostProviders = join(root, 'native', 'ffi', 'src', 'host_providers.rs');
    rmSync(hostProviders);
    assert.throws(
      () => assertCoreRustSource(root),
      /Core Rust 文件闭集漂移：native\/ffi.*缺失=native\/ffi\/src\/host_providers\.rs/,
    );
    copyFileSync(
      join(citizenSdkRoot, 'native', 'ffi', 'src', 'host_providers.rs'),
      hostProviders,
    );

    mkdirSync(join(root, 'native', 'unreviewed-core'));
    assert.throws(
      () => assertCoreRustSource(root),
      /native 根闭集漂移.*额外=unreviewed-core/,
    );
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test('Core Rust 合同拒绝 workspace Cargo manifest 与锁文件漂移', () => {
  const root = mkdtempSync(join(workRoot, 'release-core-rust-workspace-test-'));
  try {
    writeCoreRustFixture(root);
    writeFileSync(join(root, 'Cargo.toml'), 'drift\n');
    assert.throws(
      () => assertCoreRustSource(root),
      /Core Rust 边界文件哈希漂移：Cargo\.toml/,
    );

    copyFileSync(join(citizenSdkRoot, 'Cargo.toml'), join(root, 'Cargo.toml'));
    writeFileSync(join(root, 'Cargo.lock'), 'drift\n');
    assert.throws(
      () => assertCoreRustSource(root),
      /Core Rust 边界文件哈希漂移：Cargo\.lock/,
    );
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test('Core Rust 合同拒绝第三方许可证与来源声明漂移', () => {
  const root = mkdtempSync(join(workRoot, 'release-core-rust-notices-test-'));
  try {
    writeCoreRustFixture(root);
    writeFileSync(join(root, 'THIRD_PARTY_NOTICES.md'), 'drift\n');
    assert.throws(
      () => assertCoreRustSource(root),
      /Core Rust 边界文件哈希漂移：THIRD_PARTY_NOTICES\.md/,
    );
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
    const providerSource = join(
      root,
      'native',
      'smoldot',
      'provider',
      'src',
      'verified_chain_client.rs',
    );
    writeFileSync(providerSource, `${readFileSync(providerSource, 'utf8')}\n`);
    assert.throws(
      () => assertSmoldotRustSource(root),
      /smoldot Rust 文件哈希漂移：provider\/src\/verified_chain_client\.rs/,
    );
    copyFileSync(
      join(
        citizenSdkRoot,
        'native',
        'smoldot',
        'provider',
        'src',
        'verified_chain_client.rs',
      ),
      providerSource,
    );
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

test('smoldot Release 合同覆盖根支持文件并拒绝动态完整闭集漂移', () => {
  const root = mkdtempSync(join(workRoot, 'release-smoldot-closure-test-'));
  const source = join(citizenSdkRoot, 'native', 'smoldot');
  const copy = join(root, 'native', 'smoldot');
  try {
    mkdirSync(join(root, 'native'), { recursive: true });
    cpSync(source, copy, { recursive: true });
    assert.doesNotThrow(() => assertSmoldotRustSource(root));

    const upstreamHeader = join(copy, 'include', 'smoldot.h');
    writeFileSync(upstreamHeader, `${readFileSync(upstreamHeader, 'utf8')}\n`);
    assert.throws(
      () => assertSmoldotRustSource(root),
      /smoldot 支持文件哈希漂移：native\/smoldot\/include\/smoldot\.h/,
    );

    copyFileSync(join(source, 'include', 'smoldot.h'), upstreamHeader);
    writeFileSync(join(copy, 'include', 'citizensdk.h'), '/* duplicate product ABI */\n');
    assert.throws(
      () => assertSmoldotRustSource(root),
      /smoldot 文件闭集漂移.*额外=native\/smoldot\/include\/citizensdk\.h/,
    );
    rmSync(join(copy, 'include', 'citizensdk.h'));
    writeFileSync(join(copy, 'unexpected-release-input.txt'), 'extra\n');
    assert.throws(
      () => assertSmoldotRustSource(root),
      /smoldot 文件闭集漂移.*额外=native\/smoldot\/unexpected-release-input\.txt/,
    );
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test('链资产合同固定根边界说明、manifest、目录说明和两个运行时信任锚', () => {
  const root = mkdtempSync(join(workRoot, 'release-chain-assets-test-'));
  const source = join(citizenSdkRoot, 'assets');
  const copy = join(root, 'assets');
  try {
    cpSync(source, copy, { recursive: true });
    assert.doesNotThrow(() => assertChainAssets(root));

    const chainSpec = join(copy, 'citizenchain', 'chainspec.json');
    writeFileSync(chainSpec, `${readFileSync(chainSpec, 'utf8')}\n`);
    assert.throws(
      () => assertChainAssets(root),
      /链资产文件哈希漂移：assets\/citizenchain\/chainspec\.json/,
    );

    copyFileSync(join(source, 'citizenchain', 'chainspec.json'), chainSpec);
    const manifest = join(copy, 'citizenchain', 'manifest.json');
    writeFileSync(
      manifest,
      readFileSync(manifest, 'utf8').replace(
        '"chain_id": "citizenchain"',
        '"chain_id": "citizenchain-mainnet"',
      ),
    );
    assert.throws(
      () => assertChainAssets(root),
      /链资产文件哈希漂移：assets\/citizenchain\/manifest\.json/,
    );

    copyFileSync(join(source, 'citizenchain', 'manifest.json'), manifest);
    writeFileSync(join(copy, 'citizenchain', 'unexpected.json'), '{}\n');
    assert.throws(
      () => assertChainAssets(root),
      /链资产闭集漂移.*额外=assets\/citizenchain\/unexpected\.json/,
    );
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test('真实 Runtime metadata/events 测试夹具由 Release 固定完整闭集', () => {
  const root = mkdtempSync(join(workRoot, 'release-source-fixture-test-'));
  const fixturePaths = [
    'test/transaction/fixtures/citizenchain-balance-fee-v1.json',
    'test/transaction/fixtures/citizenchain-runtime-system-events.hex',
    'test/transaction/fixtures/citizenchain-runtime-v14-metadata.hex',
    'test/transaction/fixtures/citizenchain-transfer-build-v1.json',
    'test/transaction/fixtures/substrate-v14-system-events-metadata.hex',
    'test/wallet/fixtures/citizenchain-wallet-derivation-v1.json',
    'test/wallet/fixtures/citizenchain-wallet-password-v1.json',
  ];
  try {
    for (const relativePath of fixturePaths) {
      const destination = join(root, ...relativePath.split('/'));
      mkdirSync(dirname(destination), { recursive: true });
      copyFileSync(join(citizenSdkRoot, ...relativePath.split('/')), destination);
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

test('Release 固定根级许可证入口、GPL-3.0 与 MIT 权威许可证原文字节', () => {
  const root = mkdtempSync(join(workRoot, 'release-license-test-'));
  try {
    for (const license of ['LICENSE', 'LICENSE-GPL-3.0', 'LICENSE-MIT']) {
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

test('产品文档固定根说明、架构与平台模块的完整反向闭集', () => {
  const root = mkdtempSync(join(workRoot, 'release-documentation-test-'));
  try {
    copyFileSync(join(citizenSdkRoot, 'README.md'), join(root, 'README.md'));
    for (const relativeRoot of ['docs', 'android', 'darwin', 'lib/src']) {
      const destination = join(root, ...relativeRoot.split('/'));
      mkdirSync(dirname(destination), { recursive: true });
      cpSync(join(citizenSdkRoot, ...relativeRoot.split('/')), destination, {
        recursive: true,
      });
    }
    assert.doesNotThrow(() => assertDocumentationSource(root));

    const extra = join(root, 'docs', 'unreviewed.md');
    writeFileSync(extra, 'unreviewed\n');
    assert.throws(
      () => assertDocumentationSource(root),
      /产品文档闭集漂移.*额外=docs\/unreviewed\.md/,
    );
    rmSync(extra);

    const missing = join(root, 'docs', 'WALLET_MODEL.md');
    rmSync(missing);
    assert.throws(
      () => assertDocumentationSource(root),
      /产品文档闭集漂移.*缺失=docs\/WALLET_MODEL\.md/,
    );
    copyFileSync(join(citizenSdkRoot, 'docs', 'WALLET_MODEL.md'), missing);

    writeFileSync(join(root, 'README.md'), 'drift\n');
    assert.throws(
      () => assertDocumentationSource(root),
      /产品文档文件哈希漂移：README\.md/,
    );
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test('Hosted Package 合同固定过滤规则、变更日志与可解析依赖边界', () => {
  const root = mkdtempSync(join(workRoot, 'release-hosted-package-test-'));
  try {
    cpSync(join(citizenSdkRoot, 'lib'), join(root, 'lib'), { recursive: true });
    for (const path of [
      '.pubignore',
      'CHANGELOG.md',
      'android/build.gradle',
      'darwin/citizen_sdk.podspec',
      'pubspec.yaml',
    ]) {
      const destination = join(root, path);
      mkdirSync(dirname(destination), { recursive: true });
      copyFileSync(join(citizenSdkRoot, path), destination);
    }
    assert.doesNotThrow(() => assertHostedRuntimeDartProjection(root));
    assert.doesNotThrow(() => assertHostedPackageSource(root));

    const requiredRuntime = join(root, 'lib', 'src', 'api', 'citizen_chain.dart');
    rmSync(requiredRuntime);
    assert.throws(
      () => assertHostedRuntimeDartProjection(root),
      /Hosted Dart 运行闭集漂移.*缺失=lib\/src\/api\/citizen_chain\.dart/,
    );
    copyFileSync(join(citizenSdkRoot, 'lib', 'src', 'api', 'citizen_chain.dart'), requiredRuntime);

    const unexpectedRuntime = join(root, 'lib', 'src', 'hosted_private_key_probe.dart');
    writeFileSync(unexpectedRuntime, 'const probe = true;\n');
    assert.throws(
      () => assertHostedRuntimeDartProjection(root),
      /Hosted Dart 运行闭集漂移.*额外=lib\/src\/hosted_private_key_probe\.dart/,
    );
    rmSync(unexpectedRuntime);

    const pubignorePath = join(root, '.pubignore');
    const pubignore = readFileSync(pubignorePath, 'utf8');
    for (const forbiddenRule of [
      '/lib/src/crypto/native_sr25519.dart',
      '/lib/src/node/',
      '/lib/src/smoldot/',
      '/lib/src/transaction/',
      '/lib/src/wallet/',
      '/lib/src/platform/preferences_wallet_repository.dart',
    ]) {
      writeFileSync(pubignorePath, pubignore.replace(`${forbiddenRule}\n`, ''));
      assert.throws(
        () => assertHostedRuntimeDartProjection(root),
        /Hosted Dart 运行闭集漂移.*额外=/,
        `移除 ${forbiddenRule} 必须暴露并拒绝旧实现路径`,
      );
    }
    writeFileSync(pubignorePath, pubignore);

    const androidVersionPath = join(root, 'android', 'build.gradle');
    writeFileSync(
      androidVersionPath,
      readFileSync(androidVersionPath, 'utf8').replace("version = '1.0.0'", "version = '1.0.1'"),
    );
    assert.throws(
      () => assertHostedPackageSource(root),
      /包版本不一致：pubspec\.yaml=1\.0\.0；android\/build\.gradle=1\.0\.1/,
    );
    copyFileSync(
      join(citizenSdkRoot, 'android', 'build.gradle'),
      androidVersionPath,
    );

    writeFileSync(pubignorePath, 'drift\n');
    assert.throws(
      () => assertHostedPackageSource(root),
      /Hosted Package 合同文件哈希漂移：\.pubignore/,
    );

    copyFileSync(join(citizenSdkRoot, '.pubignore'), pubignorePath);
    writeFileSync(join(root, 'CHANGELOG.md'), 'drift\n');
    assert.throws(
      () => assertHostedPackageSource(root),
      /Hosted Package 合同文件哈希漂移：CHANGELOG\.md/,
    );

    copyFileSync(join(citizenSdkRoot, 'CHANGELOG.md'), join(root, 'CHANGELOG.md'));
    const pubspecPath = join(root, 'pubspec.yaml');
    const pubspec = readFileSync(pubspecPath, 'utf8');
    writeFileSync(pubspecPath, pubspec.replace('bip39_mnemonic: ^4.0.1', 'bip39_mnemonic: 4.0.1'));
    assert.throws(
      () => assertHostedPackageSource(root),
      /Hosted Package dev_dependencies 依赖约束漂移：bip39_mnemonic/,
    );

    writeFileSync(pubspecPath, pubspec.replace('crypto: ^3.0.7', 'crypto: ^3.0.6'));
    assert.throws(
      () => assertHostedPackageSource(root),
      /Hosted Package dev_dependencies 依赖约束漂移：crypto/,
    );

    writeFileSync(
      pubspecPath,
      pubspec.replace('  polkadart_keyring: ^0.7.1',
        '  polkadart_keyring: ^0.7.1\n  bip39_mnemonic: ^4.0.1'),
    );
    assert.throws(
      () => assertHostedPackageSource(root),
      /Hosted Package dependencies 闭集漂移/,
    );

    writeFileSync(pubspecPath, pubspec.replace('polkadart_keyring: ^0.7.1', 'polkadart_keyring: ^0.7.0'));
    assert.throws(
      () => assertHostedPackageSource(root),
      /Hosted Package dependencies 依赖约束漂移：polkadart_keyring/,
    );

    writeFileSync(
      pubspecPath,
      pubspec.replace('  path: ^1.9.1', '  path: ^1.9.1\n  local_probe:\n    path: ..'),
    );
    assert.throws(
      () => assertHostedPackageSource(root),
      /Hosted Package 禁止 git\/path 依赖/,
    );

    writeFileSync(pubspecPath, pubspec.replace('name: citizen_sdk', 'name: citizen_sdk\npublish_to: "none"'));
    assert.throws(
      () => assertHostedPackageSource(root),
      /Hosted Package 禁止 publish_to: none/,
    );
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test('Release 拒绝与源码包版本不一致的请求版本', () => {
  const root = mkdtempSync(join(workRoot, 'release-version-drift-test-'));
  try {
    const native = writeNativeFixture(root);
    const output = join(root, 'candidate');
    const archive = join(root, 'citizensdk.tgz');
    assert.throws(
      () => buildCitizenSdkRelease({
        sourcePath: citizenSdkRoot,
        nativePath: native,
        outputPath: output,
        archivePath: archive,
        gitCommitSha: '0'.repeat(40),
        softwareVersion: '0.1.0',
      }),
      /发布版本必须与源码一致：源码=1\.0\.0；请求=0\.1\.0/,
    );
    assert.equal(existsSync(output), false);
    assert.equal(existsSync(archive), false);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test('SDK 自有测试源码固定 Core Rust、FFI、provider、根与平台合同闭集', () => {
  const root = mkdtempSync(join(workRoot, 'release-test-contract-test-'));
  try {
    for (const relativeRoot of [
      'test',
      'native/contracts/tests',
      'native/engine/tests',
      'native/ffi/tests',
      'native/signer/tests',
      'native/smoldot/provider/tests',
      'android/native/src/test',
      'android/native/src/androidTest',
      'android/src/test',
      'darwin/Tests',
    ]) {
      const destination = join(root, ...relativeRoot.split('/'));
      mkdirSync(dirname(destination), { recursive: true });
      cpSync(join(citizenSdkRoot, ...relativeRoot.split('/')), destination, {
        recursive: true,
      });
    }
    for (const relativePath of [
      'native/engine/src/finalized_events_tests.rs',
      'native/engine/src/finalized_history_runtime_tests.rs',
      'native/engine/src/transaction_builder_tests.rs',
      'native/engine/src/transaction_history_tests.rs',
      'native/engine/src/wallet_derivation_tests.rs',
      'native/engine/src/wallet_service_tests.rs',
      'native/engine/src/wallet_transfer_watch_tests.rs',
      'native/ffi/src/composition_tests.rs',
      'native/ffi/src/host_codec_tests.rs',
      'native/ffi/src/wallet_abi_tests.rs',
    ]) {
      const destination = join(root, ...relativePath.split('/'));
      mkdirSync(dirname(destination), { recursive: true });
      copyFileSync(join(citizenSdkRoot, ...relativePath.split('/')), destination);
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
    const ffiTest = join(root, 'native', 'ffi', 'tests', 'symbol_contract.rs');
    writeFileSync(ffiTest, `${readFileSync(ffiTest, 'utf8')}\n`);
    assert.throws(
      () => assertSdkTestContracts(root),
      /测试合同文件哈希漂移：native\/ffi\/tests\/symbol_contract\.rs/,
    );
    copyFileSync(
      join(citizenSdkRoot, 'native', 'ffi', 'tests', 'symbol_contract.rs'),
      ffiTest,
    );

    const walletAbiTest = join(
      root,
      'native',
      'ffi',
      'tests',
      'wallet_abi_contract.rs',
    );
    writeFileSync(walletAbiTest, `${readFileSync(walletAbiTest, 'utf8')}\n`);
    assert.throws(
      () => assertSdkTestContracts(root),
      /测试合同文件哈希漂移：native\/ffi\/tests\/wallet_abi_contract\.rs/,
    );
    copyFileSync(
      join(
        citizenSdkRoot,
        'native',
        'ffi',
        'tests',
        'wallet_abi_contract.rs',
      ),
      walletAbiTest,
    );

    const hostProviderTest = join(
      root,
      'native',
      'ffi',
      'tests',
      'host_provider_contract.rs',
    );
    rmSync(hostProviderTest);
    assert.throws(
      () => assertSdkTestContracts(root),
      /测试文件闭集漂移：native\/ffi\/tests.*缺失=native\/ffi\/tests\/host_provider_contract\.rs/,
    );
    copyFileSync(
      join(
        citizenSdkRoot,
        'native',
        'ffi',
        'tests',
        'host_provider_contract.rs',
      ),
      hostProviderTest,
    );

    const walletWatchTest = join(
      root,
      'native',
      'engine',
      'src',
      'wallet_transfer_watch_tests.rs',
    );
    rmSync(walletWatchTest);
    assert.throws(
      () => assertSdkTestContracts(root),
      /内嵌测试文件闭集漂移：native\/engine\/src.*缺失=native\/engine\/src\/wallet_transfer_watch_tests\.rs/,
    );
    copyFileSync(
      join(
        citizenSdkRoot,
        'native',
        'engine',
        'src',
        'wallet_transfer_watch_tests.rs',
      ),
      walletWatchTest,
    );

    const providerTest = join(
      root,
      'native',
      'smoldot',
      'provider',
      'tests',
      'verified_chain_client_contract.rs',
    );
    writeFileSync(providerTest, `${readFileSync(providerTest, 'utf8')}\n`);
    assert.throws(
      () => assertSdkTestContracts(root),
      /测试合同文件哈希漂移：native\/smoldot\/provider\/tests\/verified_chain_client_contract\.rs/,
    );
    copyFileSync(
      join(
        citizenSdkRoot,
        'native',
        'smoldot',
        'provider',
        'tests',
        'verified_chain_client_contract.rs',
      ),
      providerTest,
    );
    writeFileSync(join(root, 'test', 'unexpected_test.dart'), 'void main() {}\n');
    assert.throws(
      () => assertSdkTestContracts(root),
      /测试文件闭集漂移：test.*额外=test\/unexpected_test\.dart/,
    );

    rmSync(join(root, 'test', 'unexpected_test.dart'));
    writeFileSync(join(root, 'scripts', 'unregistered.test.mjs'), 'export {};\n');
    assert.throws(
      () => assertSdkTestContracts(root),
      /测试文件闭集漂移：scripts.*额外=scripts\/unregistered\.test\.mjs/,
    );

    rmSync(join(root, 'scripts', 'unregistered.test.mjs'));
    const officialAndroidTest = join(
      root,
      'android',
      'src',
      'test',
      'kotlin',
      'org',
      'citizen',
      'sdk',
      'CitizenSdkFlutterCodecTest.kt',
    );
    const flatAndroidTest = join(
      root,
      'android',
      'src',
      'test',
      'kotlin',
      'CitizenSdkFlutterCodecTest.kt',
    );
    copyFileSync(officialAndroidTest, flatAndroidTest);
    rmSync(officialAndroidTest);
    assert.throws(
      () => assertSdkTestContracts(root),
      /测试文件闭集漂移：android\/src\/test.*缺失=android\/src\/test\/kotlin\/org\/citizen\/sdk\/CitizenSdkFlutterCodecTest\.kt.*额外=android\/src\/test\/kotlin\/CitizenSdkFlutterCodecTest\.kt/,
    );

    copyFileSync(
      join(
        citizenSdkRoot,
        'android',
        'src',
        'test',
        'kotlin',
        'org',
        'citizen',
        'sdk',
        'CitizenSdkFlutterCodecTest.kt',
      ),
      officialAndroidTest,
    );
    rmSync(flatAndroidTest);
    const nativeAndroidTest = join(
      root,
      'android',
      'native',
      'src',
      'test',
      'kotlin',
      'org',
      'citizen',
      'sdk',
      'CitizenSdkApiContractTest.kt',
    );
    rmSync(nativeAndroidTest);
    assert.throws(
      () => assertSdkTestContracts(root),
      /测试文件闭集漂移：android\/native\/src\/test.*缺失=android\/native\/src\/test\/kotlin\/org\/citizen\/sdk\/CitizenSdkApiContractTest\.kt/,
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
      /signer 10 文件闭集漂移.*额外=native\/signer\/build\.rs/,
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
  try {
    for (const relativeRoot of [
      'docs/smoldot-dart',
      'lib/src/smoldot',
      'test/smoldot',
    ]) {
      const source = join(citizenSdkRoot, ...relativeRoot.split('/'));
      const copy = join(root, ...relativeRoot.split('/'));
      mkdirSync(dirname(copy), { recursive: true });
      cpSync(source, copy, { recursive: true });
    }
    const bindings = join(root, 'lib', 'src', 'smoldot', 'bindings.dart');
    writeFileSync(bindings, 'drift\n');
    assert.throws(
      () => assertSmoldotDartSource(root),
      /smoldot Dart 文件哈希漂移：lib\/src\/smoldot\/bindings\.dart/,
    );

    copyFileSync(
      join(citizenSdkRoot, 'lib', 'src', 'smoldot', 'bindings.dart'),
      bindings,
    );
    writeFileSync(join(root, 'test', 'smoldot', 'unexpected.txt'), 'extra\n');
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
        softwareVersion: '1.0.0',
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
        softwareVersion: '1.0.0',
      }),
      /符号链接/,
    );
    assert.equal(existsSync(sourceProbe), false);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test('原生构建入口固定 Apple arm64 技术合同/最低版本且在 mkdir 前拒绝穿越和中间符号链接', () => {
  const root = mkdtempSync(join(workRoot, 'native-path-guard-test-'));
  try {
    const nativeBuildScript = readFileSync(
      join(citizenSdkRoot, 'scripts', 'build-native.sh'),
      'utf8',
    );
    assertAppleDeploymentTargetContract(nativeBuildScript);
    assertAndroidKotlinPersistentStateContract(nativeBuildScript);
    assert.throws(() => assertAppleDeploymentTargetContract(
      nativeBuildScript.replace('ios_deployment_target=16.0', 'ios_deployment_target=17.0'),
    ));
    assert.throws(() => assertAppleDeploymentTargetContract(
      nativeBuildScript.replace(
        'macos_deployment_target=13.0',
        'macos_deployment_target=14.0',
      ),
    ));
    assert.throws(() => assertAppleDeploymentTargetContract(
      nativeBuildScript.replace(
        'framework_content_root="$framework/Versions/A"',
        'framework_content_root="$framework"',
      ),
    ));
    assert.throws(() => assertAppleDeploymentTargetContract(
      nativeBuildScript.replace(
        "framework_install_name='@rpath/CitizenSDK.framework/Versions/A/CitizenSDK'",
        "framework_install_name='@rpath/CitizenSDK.framework/CitizenSDK'",
      ),
    ));
    assert.throws(() => assertAppleDeploymentTargetContract(
      nativeBuildScript.replace(
        "expected_install_name='@rpath/CitizenSDK.framework/Versions/A/CitizenSDK'",
        "expected_install_name='@rpath/CitizenSDK.framework/CitizenSDK'",
      ),
    ));
    assert.throws(() => assertAppleDeploymentTargetContract(
      nativeBuildScript.replace(
        'abi.json private.swiftinterface swiftdoc swiftinterface swiftmodule swiftsourceinfo',
        'private.swiftinterface swiftdoc swiftinterface swiftmodule swiftsourceinfo',
      ),
    ));
    assert.throws(() => assertAppleDeploymentTargetContract(
      nativeBuildScript.replace(
        'cmp -s "$source" "$destination" \\\n          || fail "$platform/$variant XCFramework Swift module 产物字节漂移：$extension"',
        'true',
      ),
    ));
    assert.throws(() => assertAppleDeploymentTargetContract(
      nativeBuildScript.replace(
        'run|compile) swiftpm_target=(build --build-tests)',
        'run) swiftpm_target=(test)',
      ),
    ));
    assert.throws(() => assertAppleDeploymentTargetContract(
      nativeBuildScript.replace(
        'swift test --skip-build "${swiftpm_paths[@]}"',
        'swift test "${swiftpm_paths[@]}"',
      ),
    ));
    assert.throws(() => assertAndroidKotlinPersistentStateContract(
      nativeBuildScript.replace(
        'kotlin_persistent_dir="$work_dir/kotlin-project-persistent"',
        'kotlin_persistent_dir="$android_gradle_project/.kotlin"',
      ),
    ));
    const appleSliceStart = nativeBuildScript.indexOf('build_apple_framework_slice() {');
    const appleProductManifest = 'cargo build --manifest-path "$product_ffi_manifest"';
    const appleProductManifestIndex = nativeBuildScript.indexOf(
      appleProductManifest,
      appleSliceStart,
    );
    assert.notEqual(appleSliceStart, -1);
    assert.notEqual(appleProductManifestIndex, -1);
    const legacyAppleManifestMutation = `${nativeBuildScript.slice(0, appleProductManifestIndex)}cargo build --manifest-path "$ffi_manifest"${nativeBuildScript.slice(appleProductManifestIndex + appleProductManifest.length)}`;
    assert.throws(() => assertAppleDeploymentTargetContract(legacyAppleManifestMutation));
    assert.throws(() => assertAppleDeploymentTargetContract(
      nativeBuildScript.replace(
        'aarch64-apple-ios-sim iphonesimulator',
        'x86_64-apple-ios iphonesimulator',
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

test('Android Core 在 AAR 与独立双库投影前只执行一次固定 NDK strip', () => {
  const nativeBuildScript = readFileSync(
    join(citizenSdkRoot, 'scripts', 'build-native.sh'),
    'utf8',
  );
  const stage = 'cp "$source_library" "$core_stage/libcitizensdk.so"';
  const strip = '"$strip_bin" --strip-unneeded "$core_stage/libcitizensdk.so"';
  const verify = 'verify_product_abi_symbols "$core_stage/libcitizensdk.so"';
  const project = 'cp "$core_stage/libcitizensdk.so" "$core_destination"';
  const gradle = 'CITIZENSDK_ANDROID_CORE_DIR="$core_stage"';
  const positions = [stage, strip, verify, project, gradle]
    .map((fragment) => nativeBuildScript.indexOf(fragment));

  assert.equal(positions.every((position) => position >= 0), true);
  assert.deepEqual([...positions].sort((left, right) => left - right), positions);
  assert.equal(nativeBuildScript.split(strip).length - 1, 1);
  assert.doesNotMatch(nativeBuildScript, /keepDebugSymbols|doNotStrip/);
});

test('Android JNI 导出闭集要求唯一版本化 JNI_OnLoad', () => {
  const root = mkdtempSync(join(workRoot, 'android-jni-symbol-test-'));
  try {
    const fakeNm = join(root, 'fake-nm.sh');
    const library = join(root, 'nm-output.txt');
    writeFileSync(
      fakeNm,
      '#!/usr/bin/env bash\nset -euo pipefail\n/bin/cat "${!#}"\n',
    );
    chmodSync(fakeNm, 0o700);
    const runGate = (symbols) => {
      writeFileSync(
        library,
        `${symbols.map((symbol, index) => `${index.toString(16)} T ${symbol}`).join('\n')}\n`,
      );
      return spawnSync(
        '/bin/bash',
        ['scripts/build-native.sh', '__test-jni-symbols'],
        {
          cwd: citizenSdkRoot,
          encoding: 'utf8',
          env: {
            ...process.env,
            CITIZENSDK_BUILD_TEST: '1',
            CITIZENSDK_NATIVE_OUTPUT_DIR: join(root, 'native-output'),
            CITIZENSDK_TEST_LIBRARY: library,
            CITIZENSDK_TEST_NM_BIN: fakeNm,
            CITIZENSDK_WORK_DIR: join(root, 'native-work'),
            GITHUB_ACTIONS: 'true',
          },
        },
      );
    };

    const exact = runGate(['JNI_OnLoad@@CITIZENSDK_JNI_1.0']);
    assert.equal(exact.status, 0, exact.stderr);
    for (const rejected of [
      ['JNI_OnLoad'],
      ['JNI_OnLoad@@CITIZENSDK_JNI_1.0', 'Java_org_citizen_sdk_leak'],
    ]) {
      const result = runGate(rejected);
      assert.notEqual(result.status, 0);
      assert.match(result.stderr, /版本化 JNI_OnLoad/);
    }
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test('Android ELF 固定双库 SONAME 并拒绝 DT_NEEDED 构建机路径', () => {
  const root = mkdtempSync(join(workRoot, 'android-elf-identity-test-'));
  try {
    const fakeReadelf = join(root, 'fake-readelf.sh');
    const core = join(root, 'libcitizensdk.so');
    const jni = join(root, 'libcitizensdk_jni.so');
    writeFileSync(fakeReadelf, '#!/usr/bin/env bash\nset -euo pipefail\n/bin/cat "${!#}"\n');
    chmodSync(fakeReadelf, 0o700);
    const runGate = (coreDynamic, jniDynamic) => {
      writeFileSync(core, coreDynamic);
      writeFileSync(jni, jniDynamic);
      return spawnSync(
        '/bin/bash',
        ['scripts/build-native.sh', '__test-android-elf-identity'],
        {
          cwd: citizenSdkRoot,
          encoding: 'utf8',
          env: {
            ...process.env,
            CITIZENSDK_BUILD_TEST: '1',
            CITIZENSDK_NATIVE_OUTPUT_DIR: join(root, 'native-output'),
            CITIZENSDK_TEST_CORE_LIBRARY: core,
            CITIZENSDK_TEST_JNI_LIBRARY: jni,
            CITIZENSDK_TEST_READELF_BIN: fakeReadelf,
            CITIZENSDK_WORK_DIR: join(root, 'native-work'),
            GITHUB_ACTIONS: 'true',
          },
        },
      );
    };
    const valid = runGate(
      '0 (SONAME) Library soname: [libcitizensdk.so]\n0 (NEEDED) Shared library: [libc.so]\n',
      '0 (SONAME) Library soname: [libcitizensdk_jni.so]\n0 (NEEDED) Shared library: [libcitizensdk.so]\n0 (NEEDED) Shared library: [liblog.so]\n',
    );
    assert.equal(valid.status, 0, valid.stderr);

    const absoluteNeeded = runGate(
      '0 (SONAME) Library soname: [libcitizensdk.so]\n',
      '0 (SONAME) Library soname: [libcitizensdk_jni.so]\n0 (NEEDED) Shared library: [/tmp/build/libcitizensdk.so]\n',
    );
    assert.notEqual(absoluteNeeded.status, 0);
    assert.match(absoluteNeeded.stderr, /DT_NEEDED 禁止包含构建机路径/);

    const missingSoname = runGate(
      '0 (NEEDED) Shared library: [libc.so]\n',
      '0 (SONAME) Library soname: [libcitizensdk_jni.so]\n0 (NEEDED) Shared library: [libcitizensdk.so]\n',
    );
    assert.notEqual(missingSoname.status, 0);
    assert.match(missingSoname.stderr, /Core SONAME/);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test('产品 ABI 从完整 nm 导出集合与头文件精确对拍并拒绝任意额外符号', () => {
  const root = mkdtempSync(join(workRoot, 'product-abi-symbol-gate-test-'));
  try {
    const fakeNm = join(root, 'fake-nm.sh');
    const library = join(root, 'nm-output.txt');
    writeFileSync(
      fakeNm,
      '#!/usr/bin/env bash\nset -euo pipefail\n/bin/cat "${!#}"\n',
    );
    chmodSync(fakeNm, 0o700);

    const header = readFileSync(join(citizenSdkRoot, 'include', 'citizensdk.h'), 'utf8');
    const expected = [...new Set(
      [...header.matchAll(/\b(citizensdk_[a-z0-9_]+)\s*\(/g)]
        .map((match) => match[1]),
    )].sort();
    assert.equal(expected.length, 70);

    const runGate = (symbols, prefix = '') => {
      writeFileSync(
        library,
        `${symbols.map((symbol, index) => `${index.toString(16).padStart(16, '0')} T ${prefix}${symbol}`).join('\n')}\n`,
      );
      return spawnSync(
        '/bin/bash',
        ['scripts/build-native.sh', '__test-product-abi-symbols'],
        {
          cwd: citizenSdkRoot,
          encoding: 'utf8',
          env: {
            ...process.env,
            CITIZENSDK_BUILD_TEST: '1',
            CITIZENSDK_NATIVE_OUTPUT_DIR: join(root, 'native-output'),
            CITIZENSDK_TEST_LIBRARY: library,
            CITIZENSDK_TEST_NM_BIN: fakeNm,
            CITIZENSDK_TEST_SYMBOL_PREFIX: prefix,
            CITIZENSDK_WORK_DIR: join(root, 'native-work'),
            GITHUB_ACTIONS: 'true',
          },
        },
      );
    };

    const elf = runGate(expected);
    assert.equal(elf.status, 0, elf.stderr);
    const machO = runGate(expected, '_');
    assert.equal(machO.status, 0, machO.stderr);

    for (const leaked of ['foreign_probe', 'secret_export']) {
      const rejected = runGate([...expected, leaked]);
      assert.notEqual(rejected.status, 0);
      assert.match(rejected.stderr, new RegExp(`额外=${leaked}`));
    }
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test('原生共用写路径拒绝移动端、产品 ABI、dangling 目标及 Cargo symlink', () => {
  const root = mkdtempSync(join(workRoot, 'native-descendant-path-guard-test-'));
  const outside = join(root, 'outside');
  mkdirSync(outside);
  const runGuard = (name, relative, prepare = () => {}) => {
    const work = join(root, `${name}-work`);
    const output = join(root, `${name}-output`);
    mkdirSync(work, { recursive: true });
    mkdirSync(output, { recursive: true });
    prepare({ output, work });
    return spawnSync(
      '/bin/bash',
      ['scripts/build-native.sh', '__test-safe-output-file'],
      {
        cwd: citizenSdkRoot,
        encoding: 'utf8',
        env: {
          ...process.env,
          CITIZENSDK_BUILD_TEST: '1',
          CITIZENSDK_NATIVE_OUTPUT_DIR: output,
          CITIZENSDK_TEST_OUTPUT_RELATIVE: relative,
          CITIZENSDK_WORK_DIR: work,
          GITHUB_ACTIONS: 'true',
        },
      },
    );
  };
  try {
    const valid = runGuard('valid', 'android/arm64-v8a/libcitizensdk.so');
    assert.equal(valid.status, 0, valid.stderr);

    const mobileAncestor = runGuard(
      'mobile-ancestor',
      'android/arm64-v8a/libcitizensdk.so',
      ({ output }) => symlinkSync(outside, join(output, 'android'), 'dir'),
    );
    assert.notEqual(mobileAncestor.status, 0);
    assert.match(mobileAncestor.stderr, /符号链接/);

    const productAncestor = runGuard(
      'product-ancestor',
      'abi-host/libcitizensdk.so',
      ({ output }) => symlinkSync(outside, join(output, 'abi-host'), 'dir'),
    );
    assert.notEqual(productAncestor.status, 0);
    assert.match(productAncestor.stderr, /符号链接/);

    const danglingDestination = runGuard(
      'dangling-destination',
      'abi-host/libcitizensdk.so',
      ({ output }) => {
        mkdirSync(join(output, 'abi-host'));
        symlinkSync(
          join(root, 'missing-libcitizensdk.so'),
          join(output, 'abi-host', 'libcitizensdk.so'),
          'file',
        );
      },
    );
    assert.notEqual(danglingDestination.status, 0);
    assert.match(danglingDestination.stderr, /已存在或是符号链接/);

    const cargoAncestor = runGuard(
      'cargo-ancestor',
      'android/arm64-v8a/libcitizensdk.so',
      ({ work }) => symlinkSync(outside, join(work, 'cargo'), 'dir'),
    );
    assert.notEqual(cargoAncestor.status, 0);
    assert.match(cargoAncestor.stderr, /Cargo target 目录.*符号链接/);
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
    const manifest = buildCitizenSdkRelease({
      sourcePath: citizenSdkRoot,
      nativePath: native,
      outputPath: output,
      archivePath: archive,
      gitCommitSha: '0'.repeat(40),
      softwareVersion: '1.0.0',
    });
    assert.deepEqual(manifest.platforms, ['Android', 'iOS', 'macOS']);
    assert.deepEqual(
      manifest.files
        .map((entry) => entry.path)
        .filter((path) => /\.(?:aar|so)$/.test(path)
          || (path.startsWith('darwin/CitizenSDK.xcframework/')
            && path.endsWith('/CitizenSDK'))),
      [
        'android/citizensdk.aar',
        'android/src/main/jniLibs/arm64-v8a/libcitizensdk.so',
        'android/src/main/jniLibs/arm64-v8a/libcitizensdk_jni.so',
        `darwin/CitizenSDK.xcframework/${appleFixtureSliceIdentifiers.iosDevice}/CitizenSDK.framework/CitizenSDK`,
        `darwin/CitizenSDK.xcframework/${appleFixtureSliceIdentifiers.iosSimulator}/CitizenSDK.framework/CitizenSDK`,
        `darwin/CitizenSDK.xcframework/${appleFixtureSliceIdentifiers.macOS}/CitizenSDK.framework/Versions/A/CitizenSDK`,
      ],
    );
    const expectedArchivedLinks = Object.fromEntries(
      Object.entries(macOSFrameworkSymlinks).map(([path, target]) => [
        `darwin/CitizenSDK.xcframework/${appleFixtureSliceIdentifiers.macOS}/CitizenSDK.framework/${path}`,
        target,
      ]),
    );
    for (const [path, target] of Object.entries(expectedArchivedLinks)) {
      assert.equal(readlinkSync(join(output, ...path.split('/'))), target);
    }
    assert.deepEqual(archivedSymlinks(readFileSync(archive)), expectedArchivedLinks);
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
