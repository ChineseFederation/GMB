#!/usr/bin/env node

// CitizenSDK 确定性候选打包器。源码只读，所有候选和归档必须落在源码树之外。
import { createHash } from 'node:crypto';
import { gzipSync, inflateRawSync } from 'node:zlib';
import {
  copyFileSync,
  existsSync,
  lstatSync,
  mkdirSync,
  readFileSync,
  readlinkSync,
  realpathSync,
  readdirSync,
  symlinkSync,
  writeFileSync,
} from 'node:fs';
import { dirname, join, relative, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

const PRODUCT_ID = 'citizensdk';
const PACKAGE_NAME = 'citizen_sdk';
const TATA_CONSOLE_TARGET_ROOT = '/Users/rhett/TATA/tataconsole/target/citizensdk';
const ROOT_FILES = [
  '.gitignore',
  '.pubignore',
  'Cargo.lock',
  'Cargo.toml',
  'CHANGELOG.md',
  'LICENSE',
  'LICENSE-GPL-3.0',
  'LICENSE-MIT',
  'README.md',
  'THIRD_PARTY_NOTICES.md',
  'analysis_options.yaml',
  'pubspec.lock',
  'pubspec.yaml',
];
const ROOT_DIRECTORIES = [
  'android',
  'assets',
  'darwin',
  'docs',
  'include',
  'lib',
  'linux',
  'native',
  'scripts',
  'test',
];
const FORBIDDEN_DIRECTORIES = new Set([
  '.build', '.dart_tool', '.gradle', '.kotlin', '.swiftpm', 'CitizenSDK.xcframework',
  'DerivedData', 'Pods', 'build', 'target', 'xcuserdata',
]);
const NATIVE_FILES = Object.freeze({
  'android/citizensdk.aar': 'android/citizensdk.aar',
  'android/src/main/jniLibs/arm64-v8a/libcitizensdk.so': 'android/arm64-v8a/libcitizensdk.so',
  'android/src/main/jniLibs/arm64-v8a/libcitizensdk_jni.so': 'android/arm64-v8a/libcitizensdk_jni.so',
});
// Apple 三个 arm64 技术变体作为一个目录原子注入；源码树只保存 Swift/Flutter
// consumer，唯一 native/ffi Core 只存在于这一个 XCFramework 产物中。
const NATIVE_DIRECTORIES = Object.freeze({
  'darwin/CitizenSDK.xcframework': 'apple/CitizenSDK.xcframework',
});
const APPLE_XCFRAMEWORK_PATH = 'darwin/CitizenSDK.xcframework';
// LibraryIdentifier 由 xcodebuild 生成，必须视为不透明技术标识。
// 下列合同只依赖 Apple 官方 SupportedPlatform/
// SupportedPlatformVariant 元数据，不使用产品名伪造目录标识。
const APPLE_SLICES = Object.freeze([
  Object.freeze({
    label: 'CitizenSDK iOS（设备技术变体）',
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
    variant: null,
  }),
  Object.freeze({
    label: 'CitizenSDK iOS（simulator 技术变体）',
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
  }),
  Object.freeze({
    label: 'CitizenSDK macOS',
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
    variant: null,
  }),
]);
const APPLE_RESOURCE_FILES = Object.freeze({
  'PrivacyInfo.xcprivacy': 'darwin/Sources/CitizenSDK/PrivacyInfo.xcprivacy',
  'citizenchain/chainspec.json': 'assets/citizenchain/chainspec.json',
  'citizenchain/light_sync_state.json': 'assets/citizenchain/light_sync_state.json',
  'citizenchain/manifest.json': 'assets/citizenchain/manifest.json',
});
// macOS framework 必须采用 Apple 标准版本化布局。只有这五个 bundle 内部
// 相对链接属于正式产物；iOS device/Simulator slice、XCFramework 其余位置和
// SDK 源码继续保持零符号链接。固定目标还能同时拒绝绝对路径、`..`、悬空链接
// 和指向 framework 外部的设备文件。
const APPLE_MACOS_FRAMEWORK_SYMLINKS = Object.freeze({
  CitizenSDK: 'Versions/Current/CitizenSDK',
  Headers: 'Versions/Current/Headers',
  Modules: 'Versions/Current/Modules',
  Resources: 'Versions/Current/Resources',
  'Versions/Current': 'A',
});
// 每个 Apple slice 必须携带 Swift 编译器生成的完整六文件模块闭包。
// 任何 sidecar 缺失都会破坏同编译器快速导入、ABI 审计或源码信息；允许额外
// 节点又会把未经审查的架构/模块混入单一 arm64 产物，因此这里使用精确集合。
const APPLE_SWIFT_MODULE_EXTENSIONS = Object.freeze([
  'abi.json',
  'private.swiftinterface',
  'swiftdoc',
  'swiftinterface',
  'swiftmodule',
  'swiftsourceinfo',
]);
// 两份运行时信任锚必须与 CitizenApp 已验证链资产逐字节一致；manifest 再把
// CitizenSDK 产品、CitizenChain 正式链身份、genesis 和两个摘要固定为一个闭集。
const CHAIN_ASSET_FILES = Object.freeze({
  'assets/README.md': '647c1d957cb16ae179813ef2d54867459286d024a857f8eb72bcd791d59eb5dd',
  'assets/citizenchain/README.md': '78f2582c48562bb3b65a224362e285121d58e69353677ae72ba5d69235f5871b',
  'assets/citizenchain/chainspec.json': '6ae934933682a8ffca78663dd4391a730b6ae219bd12abfb5d96b4d8154fc2e0',
  'assets/citizenchain/light_sync_state.json': '014802836a0f6e01a9f1bf7173b8e04c9df8fc3f057565f855abdccdc7361ab6',
  'assets/citizenchain/manifest.json': '73983825dbefac4a74102c80db9913f0ea27ca952eaa110d276ad1c8854835d8',
});
const CHAIN_ASSET_MANIFEST = Object.freeze({
  format_version: 1,
  product_id: 'citizensdk',
  chain_id: 'citizenchain',
  protocol_id: 'citizenchain',
  genesis_hash: '0x18847a5dfd263272f2e7727836fe6582f8c4463ff48609df7b96d5e4d9dd24dd',
  chainspec_sha256: CHAIN_ASSET_FILES['assets/citizenchain/chainspec.json'],
  light_sync_state_sha256: CHAIN_ASSET_FILES['assets/citizenchain/light_sync_state.json'],
  sdk_min_version: '1.0.0',
});
// 真实 Substrate v14 System.Events metadata 夹具及 CitizenChain Runtime 生产
// metadata/events 对为正式解码输入；测试与夹具同时改写不能绕过
// Release 的来源守卫。
const SOURCE_FIXTURE_FILES = Object.freeze({
  'test/transaction/fixtures/citizenchain-balance-fee-v1.json': '2cd5e648703c8cc389c59f07753470b63c034f7cfa63dac8ffa596c8128a0033',
  'test/transaction/fixtures/citizenchain-runtime-system-events.hex': '2c4d04a69ff994622877786d481dc4780b7a32795e5f7cfa070ae4acb72679ef',
  'test/transaction/fixtures/citizenchain-runtime-v14-metadata.hex': 'da62207dfa342ce5285bb214a116761fd0a38c7c329ab8953506ad52471ed681',
  'test/transaction/fixtures/citizenchain-transfer-build-v1.json': 'c43a1f01c22556d2b1e172088fb540358c25b9554c91ffc71f7b483fcd5a469b',
  'test/transaction/fixtures/substrate-v14-system-events-metadata.hex': '95b368e7907511b28ba283a6741f4be551b56fb917c2f0183b4143dbe0ebf95b',
  'test/wallet/fixtures/citizenchain-wallet-derivation-v1.json': '2d9bd9f5feeacea729154475475e0d4525e594bc88ede3a86494ffaf35301769',
  'test/wallet/fixtures/citizenchain-wallet-password-v1.json': '0f8427f6ca542625626c7c1615608eef19246db496c4bb819937f15cfdec7250',
});
// Release 必须保留根级许可入口和两份权威许可证原文；仅检查文件名存在会允许法律文本被替换。
const LICENSE_SOURCE_FILES = Object.freeze({
  'LICENSE': '85cbc4861f93949326d45a484db8df26125af2c19ba78b35f2a9e51bcaa5042a',
  'LICENSE-GPL-3.0': 'aab56b4a581fc1c50b7c782eacf2fc8be05a47cd98e4bf4d836dd9b6dd9c86f4',
  'LICENSE-MIT': '39d4ad97ead876b44da69d6d5a3cdc185cd109e82c508ffa5a29f65897c24e1c',
});
// Hosted Package 不建立第二份候选：官方 Dart 发布工具直接读取已注入 Android/Apple
// 原生库的 GitHub Release 候选，并由这份固定 .pubignore 只筛出运行时闭包。
const HOSTED_PACKAGE_SOURCE_FILES = Object.freeze({
  '.pubignore': '9ff5b60a4b9b59b88c89c4784546fc0dcf8d2215ddb599142be4a3507c0c8cca',
  'CHANGELOG.md': 'b7b7ecf3b3042807285c212f61f1626e9a6729ef5a0b85b960c80392fda74fa7',
});
// pub.dev/Hosted 包只公开产品 API、公开模型、固定 Flutter tuple 与无秘密
// AccountId/SS58 codec。其余 Dart 来源继续留在 GitHub 审计包作迁移差分，
// 但必须被真实 .pubignore 投影排除，宿主不能 implementation-import 绕过 C ABI。
const HOSTED_RUNTIME_DART_FILES = Object.freeze([
  'lib/citizen_sdk.dart',
  'lib/src/api/citizen_chain.dart',
  'lib/src/api/citizen_sdk.dart',
  'lib/src/api/citizen_sdk_error.dart',
  'lib/src/api/citizen_sdk_events.dart',
  'lib/src/api/citizen_transactions.dart',
  'lib/src/api/citizen_wallet.dart',
  'lib/src/crypto/account_codec.dart',
  'lib/src/models/citizen_account.dart',
  'lib/src/models/citizen_capability.dart',
  'lib/src/models/citizen_chain_state.dart',
  'lib/src/models/citizen_transaction.dart',
  'lib/src/models/citizen_wallet.dart',
  'lib/src/platform/citizen_sdk_flutter_codec.dart',
  'lib/src/platform/citizen_sdk_flutter_sessions.dart',
  'lib/src/platform/citizen_sdk_platform.dart',
  'lib/src/platform/flutter_citizen_sdk_platform.dart',
]);
const HOSTED_MAIN_DEPENDENCIES = Object.freeze({
  flutter: null,
  polkadart_keyring: '^0.7.1',
});
const HOSTED_DEV_DEPENDENCIES = Object.freeze({
  bip39_mnemonic: '^4.0.1',
  characters: '^1.3.0',
  convert: '^3.1.1',
  crypto: '^3.0.7',
  ffi: '^2.2.0',
  flutter_lints: '^5.0.0',
  flutter_test: null,
  http: '^1.2.2',
  meta: '^1.15.0',
  path: '^1.9.1',
  polkadart: '^0.7.0',
  shared_preferences: '^2.5.5',
  substrate_bip39: '^0.7.0',
  unorm_dart: '^0.3.2',
});
// 根 include/ 是 CitizenSDK 唯一产品 ABI。三文件完整闭集既固定字节，也阻止
// 上游 smoldot/signer 符号、任意 RPC 和秘密导出接口绕过 citizensdk_* 边界。
const PUBLIC_ABI_FILES = Object.freeze({
  'include/README.md': '924c6467b7e5b23cff9785381cf67aa6f4d5079d4171543d61a19f471e99ba18',
  'include/citizensdk.h': '8c6f23911ab79ccb3beeeac7e646ca81eade2d01fe8b712ef98a52270d54852f',
  'include/citizensdk_types.h': '57923cd2c0ce5b7fb360a52125f36734611e386471e5b9e147db016134c95b4d',
});
// Dart（排除已有独立来源合同的 smoldot 快照）、Android root/native 与
// Apple darwin 生产输入构成一个反向闭集。平台测试、文档和注入的 AAR/
// XCFramework 分别由测试、文档与候选投影合同固定，不能在本表建立第二条来源。
const MOBILE_BINDING_SOURCE_FILE_COUNT = 119;
const MOBILE_BINDING_SOURCE_FILES = Object.freeze({
  'android/build.gradle': '16ab276c8188c7268831ae78c47ea976b5c6165a3df322749dd8c9821608399f',
  'android/gradle.properties': 'cf2c210cd35238888bb6c125c538bcadfebff01d28e97d664b83f96f31fa3160',
  'android/native/build.gradle': 'a5022ef527fcf62a8e99ab9e4a443b5aeb4fb7c021e3f71ee473932c230a0ce2',
  'android/native/consumer-rules.pro': '81c0d229a083f6b87647b45708e1b19ad116a65c5eed33bf5152ac35def7f2c0',
  'android/native/src/main/AndroidManifest.xml': '4af8bd8f81dc572f010d489f9960baa1520f6d6573c7096e5d617033f876239a',
  'android/native/src/main/cpp/CMakeLists.txt': '4cdae89392703d44d47a2961588e1da9623c1f4fb8fdaa4e9517b7e941134105',
  'android/native/src/main/cpp/citizensdk_host_bridge.cpp': '23546edb5d4b2cfcccf5ad7c9bbe743d5fb994dd0b8625dbad7c815124533c3b',
  'android/native/src/main/cpp/citizensdk_host_bridge.hpp': 'a35193fb915bc1c5c5dcfe4277444f7ba710db7d3ceda4d30d4d3927bd2546d4',
  'android/native/src/main/cpp/citizensdk_jni.cpp': '635aedc52efbc7a07c6455d8f771b3759cb5f324594bacd9732aa77a793442e5',
  'android/native/src/main/cpp/citizensdk_jni_support.hpp': '9bd0b22a8536d2c152191ccd1ed4c39816ce9d7bb4680d6afbc5280f76e96188',
  'android/native/src/main/kotlin/org/citizen/sdk/CitizenSdk.kt': '4f0bf9931219ec3717e194ac1fb89baef16adbe7214c77672909bd6d14d48c0e',
  'android/native/src/main/kotlin/org/citizen/sdk/CitizenSdkError.kt': '2e286272bef5a88e9ea425083c28d4f3299f8ff203b92c21c4fefea7fd01c9e9',
  'android/native/src/main/kotlin/org/citizen/sdk/CitizenSdkEvents.kt': '5c749db2c279963599aa3cf24aa942b55abe1fdafb069f4803ec68de5de29a6a',
  'android/native/src/main/kotlin/org/citizen/sdk/CitizenSdkModels.kt': '06d233bc14f0aaf6be08dfc666f5319bef7aa354fe15c310c8188407deace231',
  'android/native/src/main/kotlin/org/citizen/sdk/CitizenSdkOperation.kt': 'f623f51baff06efd8c9b39aade5968af2fd85860cca331e763d7c27bc5f4bc7c',
  'android/native/src/main/kotlin/org/citizen/sdk/CitizenSdkPreparedWallet.kt': '74f08d32ce1ddeac586180d75dd80a034651da50a83387667355b7a5fd92b0ed',
  'android/native/src/main/kotlin/org/citizen/sdk/CitizenSdkRecoveryPhrase.kt': 'a2f90846b60e59fa98339a60e2b19b0c3a9c5692c8caa93038ce2116ca8cfc29',
  'android/native/src/main/kotlin/org/citizen/sdk/internal/CitizenSdkAssets.kt': '28e6eb8a028f5c7b5404f68ef8ef886107c6f188838bd5c0dae2d111dafa7e79',
  'android/native/src/main/kotlin/org/citizen/sdk/internal/CitizenSdkHardwareVault.kt': '3943b3f27b2f9a382acb957f192b519de82140903f85a1b89bfbac659af72911',
  'android/native/src/main/kotlin/org/citizen/sdk/internal/CitizenSdkHostRecord.kt': '6cdb3638939976db4c1b179a5871d8de111dd4bf2a3c94eab378e281cbcc9b49',
  'android/native/src/main/kotlin/org/citizen/sdk/internal/CitizenSdkHostServices.kt': 'e146a12af1ebeb7aae4b5de29451b1f8d6e69478b4f721168a7538ccdf4bb161',
  'android/native/src/main/kotlin/org/citizen/sdk/internal/CitizenSdkNative.kt': '2de2b1f66f666401fe8a0d4dd090fd7e74f4710ae6ce27aa81b60fab7ca2591d',
  'android/native/src/main/kotlin/org/citizen/sdk/internal/CitizenSdkNativeCodec.kt': 'f69f3e8db72febaadcf3e7b691a7e75d17c9ce440456385603762dfbb58ead01',
  'android/native/src/main/kotlin/org/citizen/sdk/internal/CitizenSdkNativeResult.kt': 'a49301c203bf71f62692b66d428c54d33a9b1e3da5e7c137a1db1ad8a7b5a01d',
  'android/native/src/main/kotlin/org/citizen/sdk/internal/CitizenSdkPublicStore.kt': 'd252f511c22e10c70edc4a6a7320f3c0ee94c74ce2f2babdc18203b46067f2c1',
  'android/native/src/main/kotlin/org/citizen/sdk/internal/CitizenSdkRecordKey.kt': 'a43d9a8d303cd2a687bf11004ec5b95eb9e684a2f55befc364ca62b50f1c9a14',
  'android/native/src/main/kotlin/org/citizen/sdk/internal/CitizenSdkRequestRouter.kt': '888163b13007d6d21cd1e7c6372d4e9f591941b0e88d6a494f2b0640a692756a',
  'android/native/src/main/kotlin/org/citizen/sdk/internal/CitizenSdkSecureStore.kt': 'f4bf921761bb07728fb77beb02dc84f0ba019f7e702eee76780d32bf5739f9a8',
  'android/native/src/main/kotlin/org/citizen/sdk/internal/CitizenSdkSensitiveBytes.kt': 'fe2129f7612e3cad88ed7d2f38d66d371488554238794c94d9139c95729337c6',
  'android/native/src/main/kotlin/org/citizen/sdk/internal/CitizenSdkSqlite.kt': '0d8c1546edbe7b14ba24259b97ba77349613ca9ed8dc43952397d207c7a171e4',
  'android/native/src/main/kotlin/org/citizen/sdk/ui/CitizenSdkRecoveryContent.kt': '5de5a80491efaa7f1c7e2573bb14525446b99d466da5b5ef3b89543d85cc72df',
  'android/native/src/main/kotlin/org/citizen/sdk/ui/CitizenSdkWalletFlowActivity.kt': '65a8b4d2e3334c64b9e6c5f2178f35e5b004e5e12c8fd2a89bce627403b79a06',
  'android/native/src/main/kotlin/org/citizen/sdk/ui/CitizenSdkWalletFlowContract.kt': '54e02d8b77767d1ee341aa416c9d435f0a2444dddb6aad6449eb1f68a1d66e46',
  'android/native/src/main/kotlin/org/citizen/sdk/ui/CitizenSdkWalletFlowCoordinator.kt': 'fb3c504300446f8b09c65678baf2dbebbd9f3f48f656885c05774adaab20f140',
  'android/settings.gradle': '762a06e85bef782194d141d475843ef3e96488d7144b087f0012aa308601b453',
  'android/src/main/AndroidManifest.xml': '238e29dda0ae9883bafebcd6f79de39e60837c839993ecfac3407203b5ce22ba',
  'android/src/main/kotlin/org/citizen/sdk/CitizenSdkFlutterCodec.kt': '731bb214510ec1474b505f4c97aeb2c6b02103939baa26109eb58152dd8b5573',
  'android/src/main/kotlin/org/citizen/sdk/CitizenSdkFlutterSessions.kt': 'c75d4c65dd8d3d9ea7893c04652bf6602c16a59d586c31f682c66852f6a63215',
  'android/src/main/kotlin/org/citizen/sdk/CitizenSdkFlutterWalletFlow.kt': 'cd3c960595b5bdbee8659577253ab7c3f758b4d9f080c81304561a9a4045aa51',
  'android/src/main/kotlin/org/citizen/sdk/CitizenSdkPlugin.kt': '92fe14dcf007d368f73854c2b581edd51bce157c439ee9c6b843a9a729f2938a',
  'darwin/Package.swift': '159c504cab86afb641fbef2b1fd35c59c20bbbe81d003cd7cdeec914a3ee91fc',
  'darwin/Sources/CitizenSDK/CitizenSDK-Bridging-Header.h': 'dd01912fc8a386b64dfde1000a3ff2ffbdbe620da94969389f95edbc175de04b',
  'darwin/Sources/CitizenSDK/CitizenSDK.swift': '513acf40672d386abd3da2b858d4165c56952817f2f2e4684fbca48310a67df3',
  'darwin/Sources/CitizenSDK/CitizenSDKAssets.swift': '0a674251ab01920e2d782d5cb2c0357c66693043e098c1876583c498ff4fef81',
  'darwin/Sources/CitizenSDK/CitizenSDKError.swift': '51a7f249764ff7c07ba7a75e228b9462c5bf7a5aef70b553a5d56ef12db2f9d1',
  'darwin/Sources/CitizenSDK/CitizenSDKEvents.swift': '449c39d3a33491b50acb99e4304ff42dbf23ed93fde9edbf08700ad15e745c34',
  'darwin/Sources/CitizenSDK/CitizenSDKHostBridge.swift': 'd18f3e8a3c898eecdab1ca8238c106c224249a81922cfdb94f7a7d399ac04067',
  'darwin/Sources/CitizenSDK/CitizenSDKHostRecord.swift': '70d951817f68a0ca5adb55a0a82323d8919920a1605b062e042c3122b9b391d8',
  'darwin/Sources/CitizenSDK/CitizenSDKInputLimits.swift': '948aa60e444b8eb5bdf8e460529ac7648d47d4116c52d91cd60e03bce067ef67',
  'darwin/Sources/CitizenSDK/CitizenSDKModels.swift': '30009838ae9e9374255baf669f2c670dddcb1e02c035d86b3efc2cf56eb8eebf',
  'darwin/Sources/CitizenSDK/CitizenSDKNative.swift': '7a43c3979992f6a80e9ff2812079a3040c0818520ad61af8ef02c7f9ff43caca',
  'darwin/Sources/CitizenSDK/CitizenSDKNativeCodec.swift': 'f5b705bbd3299773792545c8a8fb190b30de11d9faeba2d2b8f65c686edfffe8',
  'darwin/Sources/CitizenSDK/CitizenSDKOperation.swift': 'a36da7031a4775e90328c80b2ef8749a88af89759c89eec278dcdc561c803646',
  'darwin/Sources/CitizenSDK/CitizenSDKPreparedWallet.swift': 'e405d16b3a45b774400e737300bf0c6a9e0caa7990c15a53ccbc16fa7c522d10',
  'darwin/Sources/CitizenSDK/CitizenSDKPublicStore.swift': '2b71d655f9d45a2e40e1305e05d41be9845a8fc289820d5e19d2fcc48c48566e',
  'darwin/Sources/CitizenSDK/CitizenSDKRecordKey.swift': '391ae299ca0b7b8ecde2dd6dcee43499315c3db9c40141ffcacc9c5b9c076f14',
  'darwin/Sources/CitizenSDK/CitizenSDKRecoveryPhrase.swift': '5600c386b88b6b17299a13e758655337ae2441e1cea4a08426bdd69ed0815a34',
  'darwin/Sources/CitizenSDK/CitizenSDKSQLite.swift': '357aa704f852e09d6d4678bfc52f2ae3719c814119e1cf17800658cdf3f19008',
  'darwin/Sources/CitizenSDK/CitizenSDKScreenSecurity.swift': '8501af1dcf92faf8f62d0113bd8831569f7060cbe825994d1d2915a908469c70',
  'darwin/Sources/CitizenSDK/CitizenSDKSecretVault.swift': '34a25ffba7a2abf0d06616c1576cde627d87c55fabd1eaa95536a1e34d1a6629',
  'darwin/Sources/CitizenSDK/CitizenSDKSecureStore.swift': '2f279244a15e977adf066b4dcb94f262535429f21a561a3d0da33b9a7f1cda72',
  'darwin/Sources/CitizenSDK/CitizenSDKSensitiveBuffer.swift': '2b92446c0fb99663105dcbe070a9bd0718ba492d807ce8ff1966d41a512ed25a',
  'darwin/Sources/CitizenSDK/CitizenSDKWalletFlow.swift': '62db70d6916c973578200c0f2803d93cb9d6cf55acc962a47ea6f400f497ab7e',
  'darwin/Sources/CitizenSDK/CitizenSDKWalletFlowIOS.swift': 'a6721c14bd8b6aadaeb474600843cdf9a888139a5f9c7721b1132e0c14bc474c',
  'darwin/Sources/CitizenSDK/CitizenSDKWalletFlowMacOS.swift': 'ea317b136672538108c73f3e7ad8570e8a0b88e7f942a5955491b5fc43048e92',
  'darwin/Sources/CitizenSDK/PrivacyInfo.xcprivacy': 'bc417321bb94066c1bca08840349eea542c3c13e6addfc8248533791627434f3',
  'darwin/Sources/CitizenSDKFlutter/CitizenSdkFlutterCodec.swift': 'e9622e10686c67964eb105324878480421e812a9bc7d699e6a8a7d9c21e38009',
  'darwin/Sources/CitizenSDKFlutter/CitizenSdkFlutterSessions.swift': '9e91b605f57ed3e09bdc6f6bf1fdea97f34619c301f081e245c82b7ea71dcd2f',
  'darwin/Sources/CitizenSDKFlutter/CitizenSdkFlutterWalletFlow.swift': 'd42155f474abffbd52ede30b6cfb8f4ba0439542e2a1005ba8db82bd52f318ad',
  'darwin/Sources/CitizenSDKFlutter/CitizenSdkPlugin.swift': '7d634d9c4db67486b62339a9e7f95fd99f97bc54fa3e9049be8948f5a86506e5',
  'darwin/citizen_sdk.podspec': '0407e833b3f1d82f19b8c7ef4142e8606a848ef5bf59733ad6766eb5948158e0',
  'lib/citizen_sdk.dart': 'bd1898ad89082355429235224e2f71f24d461e1261fdcee484c34118bf2cd72d',
  'lib/src/api/citizen_chain.dart': '1c5e919a933608cd06896d1e4538534752875ec279e79d4c62329868d610bd72',
  'lib/src/api/citizen_sdk.dart': '6904ebaaff492c206981bdf2abb200aca931bd5362231bd883d7c410625dc68d',
  'lib/src/api/citizen_sdk_error.dart': 'e26382dc9af2da918da3e4eb1921f6340b1d9edb0e8956ba2f374eb9925d3f5f',
  'lib/src/api/citizen_sdk_events.dart': 'c0117d1b2e849e826046f4f4b38fe8313f48d5ab994d58f58ebc62bd310f5cb7',
  'lib/src/api/citizen_transactions.dart': 'bc66a6c4ca6a522d5d0b19221a418e022aced230431ab14cf40da2c314d60bdd',
  'lib/src/api/citizen_wallet.dart': '49f4f10ec1bed6ba7b8b5101b2429f362292e03c0d95dda8be162bfeaa7e4e7f',
  'lib/src/crypto/account_codec.dart': 'ce72262d96193ae47da43a9f675d6141f5c565eed05bb9e9755b575d96fcbc84',
  'lib/src/crypto/citizen_signer.dart': '4745b5992a9116780184b8d87357289e32d65c9ddf904cb88db8d388ec8db161',
  'lib/src/crypto/native_sr25519.dart': '1e3819103c847a051dd9557d47b05587f715af6fcfc704a40ddcceb9eb56568d',
  'lib/src/crypto/wallet_mini_secret.dart': '0ffed1efd9b91350895ef0830c5c69e6ed89afa617e8dc38d3f35e31584653d8',
  'lib/src/crypto/wallet_password.dart': '6e36f405a62829244f8550d848cb683c96a31eb23adaac0c776328eaebb7fa0a',
  'lib/src/models/citizen_account.dart': '086319ca3010b0c848eba635954299c6425519b8c4eefd84b18ec26b2763ec4f',
  'lib/src/models/citizen_capability.dart': 'f5d80517cc18ccb4b026742f5d4caf2d360ba979d9abc7e3cf286a7b81ed0ee0',
  'lib/src/models/citizen_chain_state.dart': 'f1a32d30a294106a23d03a3479792d85decdf184f6d828c83bae27a56713cc89',
  'lib/src/models/citizen_transaction.dart': 'f16ed24a536254b3023b34e2fa5f7f21160aeaab83c460265f86e74e2466f94a',
  'lib/src/models/citizen_wallet.dart': '2bf4da3e2e8fe8b833ba20175eb40acf1e54852cfe5922e90f4dcb9f99b8ea52',
  'lib/src/node/bootstrap_client.dart': '66d4d47b0d49c374c47be4d98d880718c5d8be205280f179748079c29060afbd',
  'lib/src/node/bootstrap_manifest.dart': 'a80c053de76e901a9fda3fe0c763032db8a8412570675eb020fe9c36b64d6245',
  'lib/src/node/chain_asset_manifest.dart': '6225ff05bf0a9a47721e457845a3db0ea71043b101563fd57ee2c88d687ed26b',
  'lib/src/node/chain_assets.dart': 'c4305884a3535f4f9fdeeb6f827e5b98e2afcb7e893c71ba5dbdd0d4ff4cf34f',
  'lib/src/node/chain_database_store.dart': '648ba15ad86c9b9afba41d4a6d923c916be72f84318fc906e5b70b79658bf30a',
  'lib/src/node/chain_event_subscription.dart': 'e6020c9e247b4a37e0bb27397798c72b462024340a8274974a867e241afad05a',
  'lib/src/node/chain_health.dart': 'bb85e68ccf12f1d305b7834352ce4e11729e568c53e36267f04ffb1e437a7edc',
  'lib/src/node/light_client.dart': 'dda86c3cc22434d8761612cbbe311cf977fb904aafcee10be4057363fa643c78',
  'lib/src/node/sdk_log.dart': '668bcb7b520c573b8bf5cd7592337c55a8c445d6168ed7d1ee07a6fa11fc352b',
  'lib/src/platform/citizen_sdk_flutter_codec.dart': '4921673ba75062ac4018270f38a3df0d50ac28c577a5d9da243fe5d6ef532ce1',
  'lib/src/platform/citizen_sdk_flutter_sessions.dart': 'c34155c9c7b37eb4c71cd4adb378e0811ae5825e95817f83a58a409a74e9cf10',
  'lib/src/platform/citizen_sdk_platform.dart': '295798fba26533cdbba0ec993acd215cf48889b9b744b43c2192e6566fe29f6c',
  'lib/src/platform/flutter_citizen_sdk_platform.dart': '05ab45cfeefd1e39e4a89355d5f0e845b596c8695f7b4d79639b1ffa4dbd8953',
  'lib/src/platform/preferences_chain_database_store.dart': '8cf0647a688af0e2cc87c6d86b934b340f6255397e76e326f38de2505da35337',
  'lib/src/platform/preferences_data_store.dart': '0ee490b8d0dbd342963de640576779fd44c290ee9a698c54b35e0a0e7a0028c7',
  'lib/src/platform/preferences_finalized_transaction_repository.dart': '34c7e373f808ba57cadbccf6344397053a8392c4603ed41ea5754e4460fbc4b6',
  'lib/src/platform/preferences_wallet_repository.dart': 'b71885a2c1d0b27cf6e79169a6c3c5e963c49b2e170476ac138c77581d34aae8',
  'lib/src/transaction/chain_rpc.dart': 'c1cbf31295d33ef24fb418004c7f1ae4ce833f3ecd62b7ed57c0692ac805d1ad',
  'lib/src/transaction/chain_transfer_event_decoder.dart': 'ec30b3169737865f637d398cc5910bd143e0c8de346b7afd72cbd376b392da61',
  'lib/src/transaction/finalized_transaction_models.dart': '3ab3e57840c4a27059b8164fd76e04a1fe25a6fdf3fe6e24cd5f92c55897e9e4',
  'lib/src/transaction/finalized_transaction_repository.dart': '4515ef75b4972e793f8483f8e09b7230dc77c2e4696d1dc532cdfa48c9649761',
  'lib/src/transaction/finalized_transaction_scanner.dart': 'd84db8b521093b8063e0bff7e36bc6d422f80a9cd8c403aa55e42be42f7a21f5',
  'lib/src/transaction/pallet_registry.dart': 'dbbd0bb7752a41b8ba59be1631b55059b4559ed7f6449906d03ff5bccef7592b',
  'lib/src/transaction/signed_extrinsic_builder.dart': '2e3727b7622c3962dfdfbaa0c00901040716800defe08f0ce0e242fa89b71395',
  'lib/src/transaction/transaction_status.dart': '9ab379df29ece36b6b5cf8fdecd8398cba76841e3d7d610d0828d8f30d7261a2',
  'lib/src/transaction/transfer_service.dart': '4b9333055406abf10bd49498b9f5dc4b352681bb1666d3f254e6907d9548fa1a',
  'lib/src/wallet/models.dart': '19d86fc05978e5ca06565ee4b49e26d97ac88c9e5790e6b9518c20d84971cef4',
  'lib/src/wallet/secure_seed_store.dart': '571c0fa8b1de6cebfb3f341600ab2afdea413d4f8d7a5317e721332dda5ca46f',
  'lib/src/wallet/wallet_error.dart': '58afeaf234b1c6b7c18a75cf2c5a86f8206f1a51348965ce4d88ceb43247217b',
  'lib/src/wallet/wallet_repository.dart': '08ca473679979ab5627d2807754aeb61667b9f9f5eb46dae43acc91d448225bf',
  'lib/src/wallet/wallet_service.dart': '9fdaf97646524c90c2545696cb85c7f90e981f0ca646a7b3d4e57ecd34d6b9c3',
});
// Linux C/C++ Host 是根产品 ABI 的宿主投影，不是第二份 Core。测试和
// README 分别由测试、文档闭集固定；其余 CMake、公共头与实现逐字节进入
// 独立来源闭集，后续 Flutter adapter 只能显式扩展，不能悄然混入。
const LINUX_BINDING_SOURCE_FILE_COUNT = 49;
const LINUX_BINDING_SOURCE_DIRECTORIES = Object.freeze([
  'cmake',
  'include',
  'include/citizen_sdk',
  'src',
  'test',
]);
const LINUX_BINDING_SOURCE_FILES = Object.freeze({
  'linux/CMakeLists.txt': '71af5c303804fb31d6488dd9d9209d25bff27397913d9ab387d40a0325becb3c',
  'linux/cmake/CitizenSDKConfig.cmake.in': '0f3981dcfdab1fbea6f893af38f2bfe3dd093aac9258a5deb8a26ee6a666f211',
  'linux/cmake/CitizenSDKConfigVersion.cmake.in': 'b2dd2bb6bb58f1255b6e9eca0f61b635f589ee2809537f7ba7fa45d46e3d7685',
  'linux/cmake/CitizenSDKDependencies.cmake': 'c0ab6dffc4577ebfff8b3eb467f37f2b8c7fb45158bf3f64b7e8d753b9d8f5d0',
  'linux/cmake/citizensdk_host.map': '715e804778195c26411262ac345da2a1194de1ceff931c1150bdff250eaa1bf4',
  'linux/include/citizen_sdk/citizen_sdk.hpp': '2f52a24513deec45db84b52f04989f6c657b6f03d207be210ea230bd0f5870df',
  'linux/include/citizen_sdk/citizen_sdk_config.hpp': '0bca7aa1112da959b2b68768854bd31a47af709c6558edf1f256f62d2729229e',
  'linux/include/citizen_sdk/citizen_sdk_error.hpp': 'ad835a6ecaded36731a23b18aa6959b806d1515ef8f41cf940026341065e0bd0',
  'linux/include/citizen_sdk/citizen_sdk_events.hpp': '32c2f64beb04bc2ec274c909ff9776e47ab3c05a0face18e879a16d5a4069dc7',
  'linux/include/citizen_sdk/citizen_sdk_models.hpp': 'bad7dded29d0f341524cd4dad9161847d4adcf2bfd3c40bff3e2581bd1c7fb3e',
  'linux/include/citizen_sdk/citizen_sdk_wallet_flow.hpp': '48e1fc188ddfae60c0f01d050d7e9144ba6a1f7e64aee28eab55a47e6f7d561c',
  'linux/include/citizen_sdk/citizensdk_host.h': 'cf8713368176b833193ebdeafff90420e5dcda72e89f143ffc580b5c2e9f34a7',
  'linux/src/citizen_sdk_assets.cc': 'b663b653299c22d62a44a7f242e1e57f2d8471408d0d3d81728bbe37929d0cb6',
  'linux/src/citizen_sdk_assets.hpp': '44d30123c623ea266030235126552e4a9334839f0d5d44adb5931f56d8b93401',
  'linux/src/citizen_sdk_gtk_parent.cc': '17bb6d9ae4296ce2d2e2c0101ffcec75859c393e740952fc530b4ae128b8a654',
  'linux/src/citizen_sdk_gtk_parent.hpp': '891a3fb929951b7a51a0e76854d50aa289a72795ca90c3f8c7140292a19a8cad',
  'linux/src/citizen_sdk_host_api.cc': '6b9f50f402c68d2811f0df98788dc94d8d10dd5742eb775b57c05d729e29ac1a',
  'linux/src/citizen_sdk_host_bridge.cc': '7132d4539f47c16ad7e6a8d49209469dcc983d4cc3cef42c29c8f8d00aa04b08',
  'linux/src/citizen_sdk_host_bridge.hpp': 'a582609b525ba60a9606ea3d56ae4eaccf6890bf4279d6de53b1f4f097a5c4a5',
  'linux/src/citizen_sdk_host_record.cc': '68fea5575759fadbc9bd9257a32bbb00779bad9961908e76135329c3fcc110c3',
  'linux/src/citizen_sdk_host_record.hpp': 'd3c5b9cfaf91c85ee47bf86713f1299f204ef220614035257adb1c2d56be5742',
  'linux/src/citizen_sdk_input_limits.cc': 'f01656812df1df0447be7a4a9a8fbdf40f14bf24f5b5ce447f238b8963ad7b41',
  'linux/src/citizen_sdk_input_limits.hpp': '984f3e033ee2a918199512280217c0eb84220f313673aebe8b99454079edae9c',
  'linux/src/citizen_sdk_lifecycle.cc': '8319aaed8e1f102aa204968a71e3f0c4f7af8f5e77ca25c8ec5efd441068a457',
  'linux/src/citizen_sdk_lifecycle.hpp': '2a900f5ec113868f666819e7a2c5a80c098394a2d21b964e75b026f754a71602',
  'linux/src/citizen_sdk_operation.cc': 'f8bdcd552140bb1995e9255549381c48019637555eb975bd1fb530acf8ae2c1e',
  'linux/src/citizen_sdk_operation.hpp': '77becb3dd81f8ae63d4a50ad893989133b81b5fd41f8bf5a573359bc94855bf2',
  'linux/src/citizen_sdk_public_store.cc': 'f0af676d08d4bf41fae06f4beeef8e3b031089d3ba2ca928d854f288dde3380d',
  'linux/src/citizen_sdk_public_store.hpp': '81ce101979a04edcca47db6768cbf7b66c8446ad18cb4e8f02ad2c4c49370351',
  'linux/src/citizen_sdk_record_key.cc': '80425cd8dffa7b537ab6634018b8877f2bac365949dc41667c8f0b8945be193e',
  'linux/src/citizen_sdk_record_key.hpp': '267aca52f7d0e0647f5d716eebc08cb2c77be5c093d491365baa7c01e0118bdd',
  'linux/src/citizen_sdk_secret_vault.cc': '55aa703896b98a5aabc2b38a74b93d18cc318a8742c4001bb7647af1bf4a161f',
  'linux/src/citizen_sdk_secret_vault.hpp': '2b26c83d812a265bba7b8dfbaf8f727979411e23a18002a84056e998781d2d52',
  'linux/src/citizen_sdk_secure_store.cc': '462995e5ab08c313ca9e798823b372edc1d57563080a2ee30bcfdf3c2c2cfdbe',
  'linux/src/citizen_sdk_secure_store.hpp': '7fd52a836df5cc796c0a9c287d24ae92e5d07715a31af9a44506718f0ddebced',
  'linux/src/citizen_sdk_sensitive_buffer.cc': '3904d22d1d02bf03512d84fb5a06d30912793b7e5abecba283b30ba3b15d1e90',
  'linux/src/citizen_sdk_sensitive_buffer.hpp': 'ea8254eb8420c7abe4b7adc338d87fdf0ce9cc8a44ca42ec305618c3788b1046',
  'linux/src/citizen_sdk_sqlite.cc': 'de6eda567302e95476a452100f98be395e58f5c7cb58740c2be679acf182d42c',
  'linux/src/citizen_sdk_sqlite.hpp': 'de27dec91b0609268db4619673e7e8cb2082f38eec50c495894c6bd90447ae87',
  'linux/src/citizen_sdk_tpm2.cc': 'c3cf57f48d80d755b319c45f6f54a5bde6a315bf1e8a680f59f862331ffbf549',
  'linux/src/citizen_sdk_tpm2.hpp': '56c834c03e93723b43612740e4fc60fa4a4c800445fb1627278b1728d131f8b9',
  'linux/src/citizen_sdk_user_auth.cc': '294bc99ed0dd30303d9eb6b1bde57706c6c4a6a0ba9106f247a14530fb331f01',
  'linux/src/citizen_sdk_user_auth.hpp': 'e37f54727a9c0d2b5ef33e51ae5c857d5fc65aff09d750ffd2a39218c5184a5f',
  'linux/src/citizen_sdk_wallet_flow.cc': 'f4f29ec018afd8fecc12277d9706224da99a506f37e6e89df8b27d53c05bc4f8',
  'linux/src/citizen_sdk_wallet_flow.hpp': 'c15c72439549ef7cab23c018d8c08b4c8a1e22e0a9dd759b2842d191cd8c3a5e',
  'linux/src/citizen_sdk_wallet_validation.cc': 'f433f8883d433a074e6464134fa614a89da439bec57fec9f247d0b4b23a45767',
  'linux/src/citizen_sdk_wallet_validation.hpp': '328199df424051f3a026c2c3ec61578d8de3d01368891a4c55f41708f2f05d3c',
  'linux/src/citizen_sdk_wallet_window.cc': '3c3b778ec0248ccf91362040058aeb9a2698f4532843cdac7babf55aa9a8abdb',
  'linux/src/citizen_sdk_wallet_window.hpp': '7839809c6a389c5a31c89befc155c9457ad20b79088ba7dd2b52b90d9d2e9eec',
});
// 产品根说明、架构文档及平台/Dart 模块说明共同构成 33 文件文档闭集。
// docs/smoldot-dart、测试说明、许可证、CHANGELOG、
// THIRD_PARTY_NOTICES、资产/include/Core/signer/smoldot/test 说明分别由既有
// 更窄的权威来源合同固定，不能在这里建立第二套来源流程。
const DOCUMENTATION_FILE_COUNT = 33;
const DOCUMENTATION_SHA256 = Object.freeze({
  'README.md': 'a1067360005dfd8b660baabaa2bad02e975f838ea814af4bebf3ec2909710b32',
  'android/README.md': 'b3140a230ccf7d11e92e54b2131c3a89b2cf87dd1c2de91bc2137d77c9ea0e10',
  'android/native/README.md': '1aae20d765e59f40ea37332c901bfed6e51a354442824b6e36e72d3331eb7b60',
  'android/native/src/main/cpp/README.md': 'ccbd436d19620fa3069f2407236765366358d27c8f4f72cddf0a6fd91044b289',
  'android/native/src/main/kotlin/README.md': 'c3d0c931f7b5f57ca2ebeeb37fa4ca7dedd96668735bb4cd7bc60f8255942bc8',
  'android/native/src/main/kotlin/org/README.md': '578730640cf686d61ae0855d726ca55de4e701be90241261197eb8b5c4f4c5b2',
  'android/native/src/main/kotlin/org/citizen/README.md': 'fee4f0a93cde3cad9fef94095215b2e64f8784086ee1a5217f8bfc78e3b01444',
  'android/native/src/main/kotlin/org/citizen/sdk/README.md': '1543e3d000eb835e60bb48c4875939de2f28934bc2d0d1449b33556fa8a2a7a0',
  'android/native/src/main/kotlin/org/citizen/sdk/internal/README.md': '106769b2d73004597d4dbcf1829d138792b949809168e5f278bc2d747401eae7',
  'android/native/src/main/kotlin/org/citizen/sdk/ui/README.md': '2b285d5e5855414cb3728ed3a97b78d7f1c2a16fa24b84eb7acacbc3551e7c60',
  'android/src/main/kotlin/README.md': 'cd06f97683e5b86c1a4ce4e5a5e19ca7e91239d2130b45594b58d27320582fdd',
  'android/src/main/kotlin/org/README.md': '74cbcbc590e49ae488097691b67911df3b001aba71b553f463e6dbd2eb36e53b',
  'android/src/main/kotlin/org/citizen/README.md': '1a7193606a774df8d6ad9d7c3c64dbb0b28a0cc7f6f61d0052a71726ec5400ef',
  'darwin/README.md': '22c44aba138b6d14732f96f495d16b9861ed1b28a30fc8013d6bb6acc45e93af',
  'darwin/Sources/CitizenSDKFlutter/README.md': '5bc38bab7a72890919779f6cfb01bd43e91e82a5f420b9ccdf9883f089d6a8c3',
  'docs/ARCHITECTURE.md': '6d102fc0392e79438247c5cc2e188d016418ed0181905fa6ab1ab5af63661e75',
  'docs/C_ABI.md': 'ae469d18b3ae8ce459b794667f88a838f4feebd834d99793feffae451fd368d0',
  'docs/DART_API.md': 'c4e58cccae9ba0a07ea79c1946874b95edbef4325eab7b734b918c179fd49d52',
  'docs/LINUX_PLATFORM.md': '01531fab692ed6a7265607518eaba2b6262c652b68234a39ec025b5aafa72e74',
  'docs/MOBILE_PLATFORM.md': '2858dd74a436a559e00d8065568ce6036edcd2b69a6714f08cb3c937755842ef',
  'docs/NATIVE_PACKAGING.md': 'f3a64cdd470e33150e8958fa49427714d2932a3fbea37ab3996b17ddc26fdb03',
  'docs/SECURITY.md': 'b464c1b364199bfc3f56bdc31b677cf2bf4dabfdb9a204f5a7ef5c00bb99cf49',
  'docs/SOURCE_PROVENANCE.md': '6350e2fbb13d34d554aaae8c352fb06ccd5e64c230fc4a84df02e7afb27bc2d6',
  'docs/WALLET_MODEL.md': '7c056ef4b773864beca0c0f06c3e030f542a41afeeeba21f4ce7a438c89fc154',
  'lib/src/api/README.md': 'd01476719b57985939e77459c1c5f4fe6953501f89df1705834a29ad4915ef02',
  'lib/src/crypto/README.md': 'f5d051b65879c9d361ee42700be7c694f3d83dc28145bd3e57e573af145353a6',
  'lib/src/models/README.md': '5506efb021f3c238a8c2cc2badebc7d1f442a5352c16182e5dcd9241b0a6224a',
  'lib/src/node/README.md': 'da9c040a876ccafa424ee88475621637e2c0b99777d41321c4a354cb1c358984',
  'lib/src/platform/README.md': 'a150304fce16ac86bd0ac1c269bc3aa7195e5257dc90b8dbb5e99c165cf8fa4f',
  'lib/src/transaction/README.md': '464649ceb1e05e32c21cb53bccfd985aa96b9f95593837ed99186b327244418c',
  'lib/src/wallet/README.md': '7caa07c6b73fe1cc1583e537eee43b660520d403f2e7e1a9cb06c2371d83cf25',
  'linux/README.md': '02fd0406dc914d54812ddfa6f347a83b4c22ef72e07bcb0bd0660a1cc84824c1',
  'linux/include/README.md': '1b64fdfd14665868845fdb0fe151514a24343f76fedb9ddecbcc8e1f2e88bbd5',
});
// 根 Flutter、Core Rust/FFI、smoldot provider、signer、Android、Apple 与
// Release 合同测试共同构成 SDK 自有 157 文件反向测试闭集。
// 固定测试源码能阻止“删除测试后剩余测试仍全绿”或实现与金标同步漂移进入正式包。
const SDK_TEST_CONTRACT_FILE_COUNT = 157;
const SDK_TEST_CONTRACT_ROOTS = Object.freeze([
  'test',
  'native/contracts/tests',
  'native/engine/tests',
  'native/ffi/tests',
  'native/signer/tests',
  'native/smoldot/provider/tests',
  'android/src/test',
  'android/native/src/test',
  'android/native/src/androidTest',
  'darwin/Tests',
  'linux/test',
]);
// scripts/ 同时包含生产构建器，不能把整个目录误当成测试目录；只反向枚举
// Node 正式测试命名 `*.test.mjs`，避免新增测试未进入固定闭集却仍被文档宣称已覆盖。
const SDK_SCRIPT_TEST_ROOT = 'scripts';
const SDK_EMBEDDED_TEST_ROOTS = Object.freeze([
  'native/engine/src',
  'native/ffi/src',
]);
// scripts/ 只允许一个已固定的生产构建器、当前正在执行的 Release 真源和一份
// 已由 SDK_TEST_CONTRACT_FILES 固定的合同测试。release.mjs 不能自哈希，否则任何
// 合法更新都会形成不可解的自引用循环。
const SDK_SCRIPT_ENTRIES = Object.freeze({
  'build-native.sh': 'pinned-production',
  'release.mjs': 'executing-source',
  'release.test.mjs': 'pinned-test',
});
const SDK_PRODUCTION_SCRIPT_FILES = Object.freeze({
  'scripts/build-native.sh': 'fafde6e2b421fa15b4458ee0ce9ff2b522e271730b0b611b770ef18f34c983e8',
});
const SDK_TEST_CONTRACT_FILES = Object.freeze({
  'android/native/src/androidTest/README.md': 'fc7724688dc94982b92077881caec5f5126e79c15eb7317dcde2aff8bdbdca54',
  'android/native/src/androidTest/kotlin/README.md': 'd44a06282ecd8c781d7b954acae7496a847bb8b80a1f36a7cdab5ff8c2a73cec',
  'android/native/src/androidTest/kotlin/org/README.md': '0e29cc6c8238a1e6dac76629c85a79da9e4ac8f07fae0a74ffc41f714f48c5cb',
  'android/native/src/androidTest/kotlin/org/citizen/README.md': 'd93747837a96c766ea95954a17ace8e68715967327caba1b6794dbcce5759d5a',
  'android/native/src/androidTest/kotlin/org/citizen/sdk/CitizenSdkHardwareVaultTest.kt': 'b0839202b8035eb5104c2ffb3a353f0ae11a6f8e66f1074a71141f0c072e929a',
  'android/native/src/androidTest/kotlin/org/citizen/sdk/CitizenSdkLifecycleTest.kt': 'f3dcb93ebfa32033e83db309e75aa9a1dad8f76d83fbfae31e02dfdd65f08767',
  'android/native/src/androidTest/kotlin/org/citizen/sdk/CitizenSdkNativeAbiTest.kt': 'cf94a45afecdd321e1d1bbd23ec57ca78100e89279b97c3c95aed3769f1e9bc5',
  'android/native/src/androidTest/kotlin/org/citizen/sdk/CitizenSdkStateStoreTest.kt': 'a6b61d018d63ae999be84ea7e9ffc19bb9b605bcf2d97b6c296e9c96d81a6fd9',
  'android/native/src/androidTest/kotlin/org/citizen/sdk/README.md': '4ab5a2940f4c8de302b4306b6e6b477fefe2f173fa5439f557196198cb05cbc9',
  'android/native/src/androidTest/kotlin/org/citizen/sdk/ui/CitizenSdkWalletFlowCancellationTest.kt': '43437c234ac4ae9b8305220347b0c0d3c1aed399f8f14646fa91489e20625ee1',
  'android/native/src/androidTest/kotlin/org/citizen/sdk/ui/CitizenSdkWalletFlowSecretBoundaryTest.kt': 'e34e53d30e322f229eb62bedb61e02303fae0e49c43155b73d71138b73775ba2',
  'android/native/src/androidTest/kotlin/org/citizen/sdk/ui/README.md': 'b26206bf92c79821995478fccf87990d54f6d20b72d9d45c6ee1aed313993c7a',
  'android/native/src/test/README.md': 'eb01e909e3f6e64ff5c0f000d945426fa5df9fdd517f65c9ba505d9d5cd0e54e',
  'android/native/src/test/java/README.md': '5e6309edd00fcf1e85c1d0cab7892b0b72906ec34794059427a66e1604be4f1f',
  'android/native/src/test/java/org/README.md': '42bebe2ea2fc58bdcf36dfaac6f2acd8086c3e854bf7bbb22ba46ec2ab6ce2ad',
  'android/native/src/test/java/org/citizen/README.md': '0b8e34c20efe7a80718f67546da599ad1a26f5d6719905fa8f8552be09c3ccd5',
  'android/native/src/test/java/org/citizen/sdk/CitizenSdkJavaApiTest.java': '14831f3885786a8c04bb8425b257f2baa7bf4205f42e579236ca3fa63c75506f',
  'android/native/src/test/java/org/citizen/sdk/CitizenSdkJavaOwnershipTest.java': '102ff8ef18cf144d7b99405e0cde3e3c5d959df3da5856b40085471ea1c8145b',
  'android/native/src/test/java/org/citizen/sdk/README.md': '7ed4d84adc7605077103fe72eea4bdd897f9bc302f98312d181df8336eab3b67',
  'android/native/src/test/kotlin/README.md': '1aa4f5e20f051146479c58b35b480aa68f55c6dc357e8e604a52cf480c64cff2',
  'android/native/src/test/kotlin/org/README.md': 'b84fc49220742e4ab75fc629d0c884dc075895c1592f2507f503e5d5e771a0be',
  'android/native/src/test/kotlin/org/citizen/README.md': '6f52d6e4728845e0bb1fe128af3e284bc18cbd76df974dca9828530ab8e6423a',
  'android/native/src/test/kotlin/org/citizen/sdk/CitizenSdkApiContractTest.kt': '9111361e575ab2b58a26601013d3a75a7c547729306212815f4fef6eecb68f5f',
  'android/native/src/test/kotlin/org/citizen/sdk/CitizenSdkPreparedWalletTest.kt': 'a790f3a925dde741cfd593c1c222443fb568e2696ec5646d3a3256ea35e55064',
  'android/native/src/test/kotlin/org/citizen/sdk/README.md': '8a4ebb109480a809238e1a088f8c775d7e042696f206976965620979b07e2e0c',
  'android/native/src/test/kotlin/org/citizen/sdk/internal/CitizenSdkHostOperationTest.kt': '3bce1aa84f6c58967413e1fb4bfeeced4eb25e87377d97823b297f310afbf427',
  'android/native/src/test/kotlin/org/citizen/sdk/internal/CitizenSdkRecordKeyTest.kt': 'b83832d2431e40caaea3b9356390c3ea7c03624c93733fc821d3a6f832aed634',
  'android/native/src/test/kotlin/org/citizen/sdk/internal/CitizenSdkVaultIdentityTest.kt': '995a25c4742c3098e96f869379ea4f7e77289e2230cd4c211462712ec4ba1acb',
  'android/native/src/test/kotlin/org/citizen/sdk/internal/README.md': '5fd0f31750c10c5b8e32f72534fa1c735422d6873f590d831f1131a09b1642ef',
  'android/src/test/README.md': '6a56d6f908206de3385bf9fd5838293dd1789586bb5d7245e0ea5c242d50866f',
  'android/src/test/kotlin/README.md': 'ef036e967503cb908827489c5a2098f6f358abec5599af81b4bb7d60551ed501',
  'android/src/test/kotlin/org/README.md': 'e8d1bd08d668ab54c7facc744de1d6361d0bdac00881dda3e7ef8c0a8df3f50c',
  'android/src/test/kotlin/org/citizen/README.md': 'ef7a2cca8d60f9be88c34ba98da89514ac023056977aa4265a60eb72d7b07189',
  'android/src/test/kotlin/org/citizen/sdk/CitizenSdkFlutterCodecTest.kt': '98bd042948ca5a12b3f7c1ee86bd0f8c701894f2b36e465cf6c7837eced6de57',
  'android/src/test/kotlin/org/citizen/sdk/CitizenSdkFlutterSessionsTest.kt': '87542c022211cc3a3b51edfc40adc2e73bce819cee334be8e238041deb3b62c8',
  'android/src/test/kotlin/org/citizen/sdk/CitizenSdkFlutterWalletFlowTest.kt': '7fd69e4894919703e26d8220bb9198c67965abe5344321aa373c6d3cc46cb048',
  'darwin/Tests/CitizenSDKFlutterTests/CitizenSDKFlutterCodecTests.swift': 'c5965014e3c959677f37561f67184f73bf8f6948af07aa40a75064da03931b8b',
  'darwin/Tests/CitizenSDKFlutterTests/CitizenSDKFlutterPluginTests.swift': 'd905fda42ad2303ec3fdf7e7b1e6993694747be02b2fb949de1089164aa71923',
  'darwin/Tests/CitizenSDKFlutterTests/CitizenSDKFlutterSecretBoundaryTests.swift': '8cbf137577e52f58f532c52f3877ec1775836e180900bfe5f1b9bc6fd3816f99',
  'darwin/Tests/CitizenSDKFlutterTests/CitizenSDKFlutterSessionsTests.swift': '1c0846a45d14d9c11ae34cd44035c462376495ca320706954b9bb4bd86d05fd1',
  'darwin/Tests/CitizenSDKFlutterTests/CitizenSDKFlutterWalletFlowTests.swift': 'f0608acf7375703d4eadd2c16e9e127fba33486737ec9eacb1d4f71fbb5720f5',
  'darwin/Tests/CitizenSDKTests/CitizenSDKApiContractTests.swift': '34c229f12902b1e05dd98394746ad575862188150f5afba5844602a52121773c',
  'darwin/Tests/CitizenSDKTests/CitizenSDKHostOperationTests.swift': '109be3ae384db564139db63537895b0151fe29b59fc7c2370d51553e7fe5f3c5',
  'darwin/Tests/CitizenSDKTests/CitizenSDKLifecycleTests.swift': '0f28e4c5f8de8338dc97bc24c4d66e0e0743abb4762b4b7086e5cc0c14d96707',
  'darwin/Tests/CitizenSDKTests/CitizenSDKNativeAbiTests.swift': '29150ee5925cd5af930847d9a1acd5acc419d6fa0249a028acf592692b1b150f',
  'darwin/Tests/CitizenSDKTests/CitizenSDKPublicStoreTests.swift': '827fe701c78f4bf56677704411b91ebb2c699e5caef038fd0377094887266fbc',
  'darwin/Tests/CitizenSDKTests/CitizenSDKRecordKeyTests.swift': 'a212973d86872255c092305a9989e728c9da7d98e3c369d0bfd3c8baf9c9829e',
  'darwin/Tests/CitizenSDKTests/CitizenSDKSecretVaultTests.swift': '5ef8f62597d4245c9d0d80888b3ed1d3eb8be0f5be8b80ae65f1417040b6fcf7',
  'darwin/Tests/CitizenSDKTests/CitizenSDKSecureStoreTests.swift': 'af1ee11996f8706b419494d4615fe9ba268480792e2786b1d4cddbe2118271d3',
  'darwin/Tests/CitizenSDKTests/CitizenSDKSensitiveBufferTests.swift': 'd5163c7df3fd41897dceb3f1f1e175ef4982d92918eef498e0b6817bbdb93cbc',
  'darwin/Tests/CitizenSDKTests/CitizenSDKWalletFlowTests.swift': 'd3575c5c889f68197d5022e97d2160d7da08ada34942ba77d925515b44007c9c',
  'darwin/Tests/README.md': '9cbc9287f49340f3cc26474654490f619f7d74f0436b4d47b58356481743acf9',
  'linux/test/CMakeLists.txt': '087d9fdd216ad895095bd854dd6528c39b870ec99aaa8ab49cd31fd339da2dbd',
  'linux/test/README.md': '0f3c89fba25f3e98cf1b09fc8defa547d75e48c9b22ee0fe6ac63dbfc38dba3d',
  'linux/test/citizen_sdk_api_contract_test.cc': 'a7ab7774e1c0cb214efcf087edb1decda349c0daa47d2efff6d347c47a28cf3a',
  'linux/test/citizen_sdk_assets_test.cc': '9d5b6f2ad9e23fc55c759deed22e0a50bdca8886608ebe53dd80d0696f5f9e08',
  'linux/test/citizen_sdk_host_operation_test.cc': '13c8f93d0178f9452a13a2c579a0bf796bebf8550cb77719f31a7ff521dd905e',
  'linux/test/citizen_sdk_lifecycle_test.cc': 'd1aef6a02d527618d00a618daf6b24eeff8d17e53b1a1635783767731ac7cbfc',
  'linux/test/citizen_sdk_public_store_test.cc': '0d39dd11b5104596a53a8bf3489232a221d181ab23dd047ca3e26f3569fcc23c',
  'linux/test/citizen_sdk_record_key_test.cc': '11871f6372b6983d7265fddb1714ed9b283d9ff43a9f6e782759d47dd5c74e4d',
  'linux/test/citizen_sdk_secret_boundary_test.cc': 'e3f6a4593e9471f3bf15cb4551f2f3a2173c08aa673e8471137009e39c8b76bc',
  'linux/test/citizen_sdk_secret_vault_test.cc': '8c5c727abad2b7ab16ebb5995367b978a9fba1f8d762075aee51ec544e84d577',
  'linux/test/citizen_sdk_secure_store_test.cc': '77fa181b5a50ce83b78abecba48ad8ed8b0791367b37617bee2d51f757855164',
  'linux/test/citizen_sdk_sensitive_buffer_test.cc': 'e82855221fde7e20ce07ef194619c18cd1c25ed7b8c9ae5a85fd8f94256a5ec0',
  'linux/test/citizen_sdk_test_support.hpp': '44aa52fe606af4e69b9e14a423658864b51b191e8dd32580a37ad4ed4063c263',
  'linux/test/citizen_sdk_tpm2_test.cc': 'c3df6181e76f34655c29b7c884e2ac7d196b80924cd0b5a549d5ceb857311c47',
  'linux/test/citizen_sdk_wallet_flow_test.cc': 'afb55607f7f44cd89b0e4d4fc61d10dccfe554aa99ecd4839b55754fa63be7d8',
  'native/contracts/tests/account_contract.rs': '2f2af9930ccaba2cf73a21c1ea3593295a6e7d8633a95db05fbcb642e7c74992',
  'native/contracts/tests/capability_contract.rs': '7a94545fbf1572e127d12a4d4a9ce1478fa3dcc22fb7aa688fde747135a89f7f',
  'native/contracts/tests/chain_contract.rs': '69e216bee1d74258348f84e6b8086b474a44d6b68470bd0cef22cbfa4ed75100',
  'native/contracts/tests/secret_contract.rs': 'e5585e0a2b584f3955a2516f6dff11615ca1fe299764a41289d0313d71ff1554',
  'native/contracts/tests/state_store_contract.rs': '71c582e47b278a5930ec8565c643a33c4c70f37f00bd76f8badf4dc86cd9b0cc',
  'native/contracts/tests/transaction_build_contract.rs': 'e3652344c31dbb01e6b3273b240296929bdaf2ed1aa2c2f1c7727a723ef649f0',
  'native/engine/src/finalized_events_tests.rs': 'a1bfa1b974e36a03cd6124b5f6f7f8fd611735eef17734872e3908a792b070b7',
  'native/engine/src/finalized_history_runtime_tests.rs': 'dd907c135ff8d3645fab2f354c321f37a61df607c96842322474851b9fce3b57',
  'native/engine/src/transaction_builder_tests.rs': '64fb03ac64e86d07ce1bc0b0cd2429eb3150d6f561f3a58877d85e4df1680c6e',
  'native/engine/src/transaction_history_tests.rs': '1ffe7303ad77af6222d443bb38ffb44e97418f462290d4123c9c442c06005d65',
  'native/engine/src/wallet_derivation_tests.rs': '6f81cc64f0f3c82d3510ea316aa04705ae40c27d53237f25293480fcfa504e5f',
  'native/engine/src/wallet_service_tests.rs': 'f480b8a776be7d0d5c5e46b74e21e476e5b9d5590a316f4c626dc206e46fa5a0',
  'native/engine/src/wallet_transfer_watch_tests.rs': 'ab6e5595dacc4fb5fcecf599195c75d1c85bbe6e1b58521a30b59805ab9d9b1c',
  'native/engine/tests/account_state.rs': '3271646a267cfb325ae4a4ccd2142975c00325383d81380d62e424822230208a',
  'native/engine/tests/capabilities.rs': '8878d8cbbbdca8fa6ef4f5eefdb4f808bd21260d0ea7dcae31f593538ba37046',
  'native/engine/tests/chain_access.rs': 'af994070a14732dafaa9aa53804ee6383522854a8619d6dd0112993689f01fba',
  'native/engine/tests/engine_boundary.rs': '6c8493c39561fb5784c17814a7a999a062f9627e24d2eadf9e7cc08aeea32050',
  'native/engine/tests/runtime_context.rs': 'e5eb9f999668b6664d29ba61a0c8b2fd8b2e9fe37f7830bb4f4b7732b9c4fe43',
  'native/engine/tests/state_import.rs': '6937752568de3531a32b8ad35b1fd7270abad120c4b5aac423ae7df970d3f917',
  'native/engine/tests/transaction_outcome.rs': '24422882e1cb4f929fef69263de854f053cb45343fc5c5b4224d2e8a4e7a2946',
  'native/ffi/src/composition_tests.rs': 'ddec359df53dc28bf778ac4b035bb8b2431a131e42f2c85bbefbbcbfebe2b82e',
  'native/ffi/src/host_codec_tests.rs': 'b8490a7f85d446f50c4b3330c93debfaaa39e73c6570d47e0e8dd386df2c9422',
  'native/ffi/src/wallet_abi_tests.rs': '411b86c63277473e7ed8c39466713287577a89320898c79a4697350b6850c5a4',
  'native/ffi/tests/abi_layout.rs': '5ccba7c43fdfe78c317d3ffd23de627df4af1cad13e895aae11bf7a75527113f',
  'native/ffi/tests/asset_boundary.rs': 'a0a56cba330088ce01e807ac37191195b8d90013aba895ac2c7acf98b9a6ecfe',
  'native/ffi/tests/c_header_c11.c': '26f90252182189932277d77236d8ef50a44410b60c8fa17e30b4169f542edf73',
  'native/ffi/tests/c_header_cpp17.cc': 'bc9e01786ef55af8ac47396960028483205207c711fb380195506065e52e9eb5',
  'native/ffi/tests/capability_contract.rs': 'd0ba2b94dab377dfbead8f2c341cf1a42697189f461572ed5ce5986c5d8dca38',
  'native/ffi/tests/error_contract.rs': 'ae585490b05768b64401b1e6774789ba1beb1eede552e4d3e70a99cd1d395d91',
  'native/ffi/tests/event_contract.rs': 'e39b153cbebf7510d8f72af6692cf99ac8aec43f254bcc305dc5c741b063fd11',
  'native/ffi/tests/handle_contract.rs': '9823bfe3ddf579c021bac6c33bea7a43e9dc828ad946f0ee1a10baed654e494a',
  'native/ffi/tests/host_provider_contract.rs': 'a1aabe53e73e31e5eefe0669c1eceb3f4f0b09f5c9d65bb2661a9c142793e209',
  'native/ffi/tests/ownership_contract.rs': 'b75c13b228598177b1f8fabaa9a2cf5b1e62d8674a5dff662fed06616308ba0e',
  'native/ffi/tests/request_contract.rs': '816038c6de732cac1b85bdd15c72bfaac7b0eec2ace307937ce410f280204e42',
  'native/ffi/tests/symbol_contract.rs': 'f307bb95a762e0dcc618f5c92aaa5db567bc71af3ca5ba551c0734e11f5c9559',
  'native/ffi/tests/wallet_abi_contract.rs': '845070da4704549b9bd48c460de978da6dfb0c2fb93a372d7f9fcf3afd639449',
  'native/signer/tests/chain_signer_contract.rs': 'd4e53512dffab3f75ee213a08b71909dbc6c667b4b287df39cd9ac3e62824b31',
  'native/signer/tests/ffi_contract.rs': 'bf38f650394011e7f68219ee8ba435453f616281f91649634c536b8620407038',
  'native/signer/tests/legacy_parity.rs': '984a1521042d8a5b2285a43459383ef3972058db20e8f05154c1f75a2a11d70f',
  'native/signer/tests/substrate_vectors.rs': 'f5587dbce91f9c2014c559bece142e56fe65c81c7cf097df66b6c8125d45eef9',
  'native/smoldot/provider/tests/account_nonce_contract.rs': '13f2d194df11c94527fd5b513228cc1ec917f3735b12f3326c239b600821b754',
  'native/smoldot/provider/tests/legacy_parity.rs': '7db2b3ef4959a7bd1c83b22597666b0448f48b3079b82821f624efd2ccb7d9dc',
  'native/smoldot/provider/tests/verified_chain_client_contract.rs': '62ba6c74801b2f50ff8458fd7da73bc85c522347a7bd81c01ec0ef2060e6d6a4',
  'scripts/release.test.mjs': '24ed61389312d27a87524e70e5ac15015bd326d7a577198ba24c744238f5bfe1',
  'test/api/README.md': 'bd927ce1488fc609ab3d1199ef7e3c859c741fae14628d4ef4bd79aa8d8b7144',
  'test/api/citizen_sdk_test.dart': '037b35aec6ebb55cfb05316a1e7ae595e42601c9679b602d31eca5c1b675b2b8',
  'test/api/citizen_transaction_test.dart': 'e380a35918b6c4accaf94235cf373650ca12d61c352e88884e2ca858334ec4b2',
  'test/api/citizen_wallet_flow_test.dart': '0d6c9a8264eff89fef16610cbef9712e362b31b217c1f7109d4bfa5e341550b1',
  'test/api/public_api_contract_test.dart': '5d645eaca54597de223ee85d06fe8b98407b37972140414abccca65227b0301a',
  'test/citizen_sdk_facade_test.dart': '5135b62ca569676fddf23bda0156e88ba592eed008499db0603e43c4f4aa168a',
  'test/crypto/derivation_golden_test.dart': '5d924af41c2c5b02be9fcce86f5d296a719d1396216f3357007abdeaa9e73b6e',
  'test/crypto/wallet_password_test.dart': 'b269b7cb28233c9b00cf183d037419e9a7687143613f432477cfa3bf8fa30460',
  'test/models/README.md': '4cd13881d38d345f2a43767e6101413943cd60628c9474e4e7a8c81f086e3813',
  'test/models/public_models_test.dart': '579164a13fb5359598d7ed68372444445f90bc0d26ad537662ad72cda1b675a5',
  'test/models/u128_codec_test.dart': 'e406f077258130ed22481af2e228066a4030dab19b765731eaefcfdc2f0ca6f5',
  'test/node/bootstrap_client_test.dart': '80edc9da38ae330df6717672a2dece53c6ec92a321cff0e5afe10fb4bd978953',
  'test/node/chain_asset_manifest_test.dart': '78fb24dfe5eb7ae7476416bf2e41aa59f16c46e4af89c8875a148de54ffa4696',
  'test/node/chain_assets_test.dart': 'aaf0507df1dd311c4a7cfff4e7bae806f0675e8e1316b769f6079ddb53f449d6',
  'test/node/citizensdk_bootstrap_manifest.json': '33bd8e2c7407abea376f21a7adf7c9df644aedb7a9e985211075bba6cde28a00',
  'test/node/light_client_lifecycle_test.dart': '2c124a81c80a5521aa4568fcd866c67d0ce83736fb94ff76172da8a339d18f3c',
  'test/platform/flutter_codec_test.dart': '5b75c0c67a109509238e8716920e46be0a18e32d93fca6eaa7012d9b958391ea',
  'test/platform/flutter_secret_boundary_test.dart': 'd2a6926afb33882417551539d00b78e8c027895df2adf271993fdbdc8d58d214',
  'test/platform/flutter_sessions_test.dart': 'b3937d559a02121eb26fce501aff9b551cd3bcc909f57f8b24df0faec3254238',
  'test/platform/preferences_chain_database_store_test.dart': 'e02e7ca4fa428817b474a0776d5284599e42c73fb42a9ead4103785a5ad5e0cb',
  'test/platform/preferences_finalized_transaction_repository_test.dart': '3797b1bc9630707765ad73a9c97633573d77e97eff1fac89d7cb8b27bf149530',
  'test/platform/preferences_wallet_repository_test.dart': '44a70bc5055da5bedf182ca91b9032b5bbf75a577ba60cc4bf0da70d5db3dcee',
  'test/smoldot/chain_info_test.dart': '5de74abf31c75c579716366d72a457e91339352972a4a118ec7fe18de005b158',
  'test/smoldot/client_basic_test.dart': '4617fc86f8fc4a555e837f04ad747a25b501d93532532f8f0565e1d51e17a5cc',
  'test/smoldot/ffi_basic_test.dart': 'd7f16ab19bfd842f4414f43e989a3536d6725a1ba9e2eab78ac6f53dd7fa6cef',
  'test/smoldot/fixtures/polkadot.json': '1d5079040595c54f56f31900beea91254cf2a3a25e245bcdd26fe1ccc4672a9b',
  'test/smoldot/fixtures/westend.json': '5457a3c8322b8f2a2d7c2c713c113a7e0b1ee7e646d3f00abc4fa21198ea879d',
  'test/smoldot/json_rpc_test.dart': 'c61e7bf8eaebdc199a5cd2228e4de7f3b94e17715f7bdc7a53297b9be2e3fa94',
  'test/smoldot/smoldot_test.dart': '144f3a7d3385e0f8ece9c28762ae19862cffa1e2db8e449b51ed6e56dbcf6cce',
  'test/smoldot/subscription_test.dart': '18cce5adff77d300f4f6adb6e20db9237a1e0206a05f9308133689319636e677',
  'test/transaction/chain_rpc_test.dart': 'faeeb377f4bfc3608868594f0784a933a19f59814dacffd38405560a864ab733',
  'test/transaction/chain_transfer_event_decoder_test.dart': 'b1599e10a16401cf19beb4b1400f4c4ae52acf43a78ad7df1ac7670df4c736ad',
  'test/transaction/finalized_transaction_scanner_test.dart': 'e7dc85abf5ec51a3086de248a02c194ac74e1180d490075efc82e9c3738ab1b1',
  'test/transaction/fixtures/README.md': 'b53b5ea9a0b6cb027223538d8ce2a3644b07498d2ccd862743dc2e7deba60940',
  'test/transaction/fixtures/citizenchain-balance-fee-v1.json': '2cd5e648703c8cc389c59f07753470b63c034f7cfa63dac8ffa596c8128a0033',
  'test/transaction/fixtures/citizenchain-runtime-system-events.hex': '2c4d04a69ff994622877786d481dc4780b7a32795e5f7cfa070ae4acb72679ef',
  'test/transaction/fixtures/citizenchain-runtime-v14-metadata.hex': 'da62207dfa342ce5285bb214a116761fd0a38c7c329ab8953506ad52471ed681',
  'test/transaction/fixtures/citizenchain-transfer-build-v1.json': 'c43a1f01c22556d2b1e172088fb540358c25b9554c91ffc71f7b483fcd5a469b',
  'test/transaction/fixtures/substrate-v14-system-events-metadata.hex': '95b368e7907511b28ba283a6741f4be551b56fb917c2f0183b4143dbe0ebf95b',
  'test/transaction/signed_extrinsic_builder_test.dart': '75952dd740d3f37b339177cf9d929127aa4546e11f30bac4a602b679e0171c1f',
  'test/transaction/transaction_status_test.dart': '9afb279e5b70e1e4099a33e6bf01fa4a7da52ed216ce81b704eac0d1366a6c83',
  'test/transaction/transfer_service_test.dart': 'a9ddd0f88149e464ed830660a30938a6cf060a7a7932238617f18541bb5f1af3',
  'test/wallet/fixtures/citizenchain-wallet-derivation-v1.json': '2d9bd9f5feeacea729154475475e0d4525e594bc88ede3a86494ffaf35301769',
  'test/wallet/fixtures/citizenchain-wallet-password-v1.json': '0f8427f6ca542625626c7c1615608eef19246db496c4bb819937f15cfdec7250',
  'test/wallet/secure_seed_store_contract_test.dart': 'a2e338bd081c4a572467cfa17227285440b9b19a64713c9a7a7f0bda8cdc6c86',
  'test/wallet/wallet_service_test.dart': 'ccedd39fc259fa762979621ac976842b4f28921a011a36e54bfe22cb204ec3d2',
});
// smoldot Dart 包边界已并入唯一 citizen_sdk 根包。三处迁移目录共同构成固定闭集：
// 生产绑定、来源测试与历史审计资料缺一不可，且不允许重新出现第二份 pubspec 包边界。
const SMOLDOT_DART_ROOTS = Object.freeze([
  'docs/smoldot-dart',
  'lib/src/smoldot',
  'test/smoldot',
]);
const SMOLDOT_DART_FILES = Object.freeze({
  'docs/smoldot-dart/BUILD.md': 'd8b96bbe7af577351eb915c3b66751fbb57071296cc3559454c7fdd5a7a1406b',
  'docs/smoldot-dart/CHANGELOG.md': 'd9adb01f7c62313a14bb86dbfd7f4077d925745e9c17a14f153eef79c45f8b94',
  'docs/smoldot-dart/INTEGRATION.md': '1ca0a278ebef38f7b795555afb432127865c6f73dc63a7104245526a1bf14e95',
  'docs/smoldot-dart/LICENSE': '4524e4d70a6295dfa882b0411cc49fcca03273e959fea68bbfe7df7ed63e7d78',
  'docs/smoldot-dart/README.md': 'f401fa7644079d509e86d2a4a3fbe87321cdf54f1d036ec69915a4a722fc59e0',
  'docs/smoldot-dart/UPSTREAM.md': 'ed3f21bc62a6c6dc76beb870bf6f224914123a2cc95bdbab8b5cb453c4767539',
  'docs/smoldot-dart/example/README.md': 'ab4a278a713916ab98b90db57078bc8142a903ac459f3986bd600f3e7d8f349a',
  'docs/smoldot-dart/example/smoldot_example.dart': '60aea4e2d738ab7702fbd056626e6647f8c23174739f3c1b7e564133c80ee2e7',
  'docs/smoldot-dart/source-analysis_options.yaml': 'e67b963f89cf75f675a0ed25d258bae038d216832c22b84782e5e3a90b8d3076',
  'docs/smoldot-dart/source-pubspec.lock': '91ad4c26c8abdf6384292e1f01f335ba7ce50443a99b01b45e2f4efa72dab25a',
  'docs/smoldot-dart/source-pubspec.yaml': '408910b7b043d30aa29dc1f226f750f64dbee90ad343b1154478a7ee6ff3d83e',
  'lib/src/smoldot/bindings.dart': '23a5a2add0de238ee8218238acf312193fa349c0806edb4056ff6f63b8b459eb',
  'lib/src/smoldot/chain.dart': '43f3fbc8420f61d335acb0c48ee471a7885ebbd71d320d8b820805b1537d8053',
  'lib/src/smoldot/client.dart': '916fd74c20f4daefca2e17e668e8a2fb16c59219b8f3bdd3148d10454a71ddff',
  'lib/src/smoldot/json_rpc.dart': 'c3a030b236814731f773bb8b1aa9dd1e5789bc7d0809f3c0dd7011d59b401d01',
  'lib/src/smoldot/platform.dart': 'f64a0c05aa615eeea49554e3cb918496e7507788910acf27dbbe452c1a45d24f',
  'lib/src/smoldot/smoldot.dart': '8e13185cd86609faf7d96f1da22a2457ce2e129f1d8e637c8220a2a481147758',
  'lib/src/smoldot/types.dart': 'e20b6f97d0b6e289c2b492e12dd66afafc1133adc0fc5fe5a547106ed3338e89',
  'test/smoldot/chain_info_test.dart': '5de74abf31c75c579716366d72a457e91339352972a4a118ec7fe18de005b158',
  'test/smoldot/client_basic_test.dart': '4617fc86f8fc4a555e837f04ad747a25b501d93532532f8f0565e1d51e17a5cc',
  'test/smoldot/ffi_basic_test.dart': 'd7f16ab19bfd842f4414f43e989a3536d6725a1ba9e2eab78ac6f53dd7fa6cef',
  'test/smoldot/fixtures/polkadot.json': '1d5079040595c54f56f31900beea91254cf2a3a25e245bcdd26fe1ccc4672a9b',
  'test/smoldot/fixtures/westend.json': '5457a3c8322b8f2a2d7c2c713c113a7e0b1ee7e646d3f00abc4fa21198ea879d',
  'test/smoldot/json_rpc_test.dart': 'c61e7bf8eaebdc199a5cd2228e4de7f3b94e17715f7bdc7a53297b9be2e3fa94',
  'test/smoldot/smoldot_test.dart': '144f3a7d3385e0f8ece9c28762ae19862cffa1e2db8e449b51ed6e56dbcf6cce',
  'test/smoldot/subscription_test.dart': '18cce5adff77d300f4f6adb6e20db9237a1e0206a05f9308133689319636e677',
});
// 两份锁文件都从 CitizenApp 已验证结果机械裁掉 SDK 明确排除的产品/全节点闭包后固定；
// 保留的 registry 包必须继续使用 CitizenApp 已验证的版本与校验和，且不得在
// CI、Release 或本机编译时更新。
const SMOLDOT_LOCK_FILES = Object.freeze({
  'native/smoldot/ffi/Cargo.lock': '117c9ca6ad5cb034c8fc5792028d9085dbc6483194e1aae25123b536c8c0cddb',
  'native/smoldot/pow/Cargo.lock': '6d832fb629bbf19ff6c2cce589c6285c3367cbcb3b55f4819beb7e733d9e038b',
});
// 根 signer workspace 与 Flutter 包的解析闭包同样属于正式来源输入；locked 模式
// 只能保证使用当前锁，必须再固定锁文件自身，才能阻止依赖身份随提交静默漂移。
const SDK_ROOT_LOCK_FILES = Object.freeze({
  'Cargo.lock': '338e8db350d4c5abf9bdcbd9cc067a35f8c77bbe6eafcd125335b5eedaed8b32',
  'pubspec.lock': '358c27199fd644fc0644fe5da0a398f1c88a60666e8d6a93c658579493866836',
});
// Cargo.lock 会按 registry package 合并整个根 workspace 的 feature。Engine 为钱包
// 显式启用 BIP-39 NFKD 后，smoldot 闭包里的同一个 bip39 条目会多出这一项依赖；它不是
// PoW 来源依赖漂移。例外必须同时由准确 checksum 和一个本地 workspace owner 的直接依赖
// 证明，新增任何其它 root-only 闭包项仍失败关闭。
const PROVIDER_LOCK_FEATURE_UNION_EXCEPTIONS = Object.freeze({
  'unicode-normalization 0.1.25': Object.freeze({
    checksum: '5fd4f6878c9cb28d874b009da9e8d183b5abc80117c40bbd187a1fde336be6e8',
    owner: 'citizen-sdk-engine',
  }),
});
// 同一 registry package 也可能因为根 workspace 启用更多 feature 而拥有比 PoW 锁更多的
// 依赖边。这里逐 owner 固定全部、且仅有的额外边；未登记边、PoW 边缺失或解析到不同版本
// 都必须失败，避免“包集合相同但实际依赖图不同”绕过来源闭包证明。
const PROVIDER_LOCK_FEATURE_UNION_EDGE_EXCEPTIONS = Object.freeze({
  'bip39 2.2.2': Object.freeze([
    'serde 1.0.229',
    'unicode-normalization 0.1.25',
    'zeroize 1.9.0',
  ]),
  'futures 0.3.34': Object.freeze([
    'futures-executor 0.3.34',
  ]),
  'pbkdf2 0.12.2': Object.freeze([
    'hmac 0.12.1',
  ]),
});
// contracts、engine 与产品 ffi 是 CitizenSDK 自有、可编译的 Rust 核心。它们不能借用
// smoldot 的来源清单：这里独立固定三个目录的 88 文件完整反向闭集，任何 build.rs、bin、
// 示例或未登记文件都会改变编译/发布语义并因此失败关闭。
const CORE_RUST_FILE_COUNT = 88;
const CORE_RUST_ROOTS = Object.freeze([
  'native/contracts',
  'native/engine',
  'native/ffi',
]);
const CORE_RUST_FILES = Object.freeze({
  'native/contracts/Cargo.toml': '9bda2e7d8b80ba215bff5d0157bc7210fb0fbd891d1d16e0404f204c1c922c14',
  'native/contracts/README.md': '91fdddf0168658ed2edf433e5c9ef7220c643dc062328719121f3a7d27495f38',
  'native/contracts/src/account.rs': 'c9e128bbfecf910d574c2a8a8467214e580452a900ebc321b5c89463b09297f3',
  'native/contracts/src/capability.rs': '6de3134866cf48c514caaddcdf5faca5b926cd2971c7039d77d07d04e20f6eae',
  'native/contracts/src/chain.rs': 'a3fc4698b67b5db3731f93b67d2abcfd11880193686c04661ddef4be1055556b',
  'native/contracts/src/chain_signer.rs': 'c20cf42f83f5be8607894934074d7608467d2f9a0d020e4a13b90bc31be12b16',
  'native/contracts/src/error.rs': '14d17404dd5b30916b358b846c63ae4f8cf306281adc0f1babfc8a40f3a4bbc3',
  'native/contracts/src/lib.rs': '5d2d4053dc939d1be67edce3bd648309c23ab8ba27654bebef44462757003f09',
  'native/contracts/src/secret_vault.rs': 'd79cc63b96f917c09eb40164df7aa24e65a83f6c780cd34118aded0da9d01c27',
  'native/contracts/src/store/chain_database.rs': '31a2e46f046fc8259de01fd776050625b0cfbfb4d8f516cc8695a7d5d1ce9c13',
  'native/contracts/src/store/encrypted_secret_blob.rs': '619588b892cfb736ceea543ea75d694257430460efc8548c6813223f4d05b2d2',
  'native/contracts/src/store/mod.rs': 'e90fd25990d365187ae728ed2c73f1a992d5342fb6ef5929e887c04265b5a190',
  'native/contracts/src/store/runtime_cache.rs': '152597dcc7b8f7bab6add541d1b9e638898c537e0b022d1e33f3f0b8b28675ac',
  'native/contracts/src/store/transaction_history.rs': 'e9426fe6075c92a8efddee7dcc7d0894284a8e3c4288b12c6830eb5d9d7ce05c',
  'native/contracts/src/store/wallet_profile.rs': '9f22dc1da0f370ed70f9a5cb2e165319b8519789a7b494747929f96eb683b481',
  'native/contracts/src/transaction.rs': 'f028a9e00bc160cbdb3ba88f752be0b95f35df9db00b3fc96718d3463096b723',
  'native/contracts/src/transaction_build.rs': 'e32422a4bcd9c9c5c6a185a4ff78da1846710eb646e54183b7729f9f94127889',
  'native/contracts/src/wallet.rs': 'bb1e39788ee3198732f0bc683b1fbe90485ed83cde14c2b89c7f46619731f88a',
  'native/contracts/tests/account_contract.rs': '2f2af9930ccaba2cf73a21c1ea3593295a6e7d8633a95db05fbcb642e7c74992',
  'native/contracts/tests/capability_contract.rs': '7a94545fbf1572e127d12a4d4a9ce1478fa3dcc22fb7aa688fde747135a89f7f',
  'native/contracts/tests/chain_contract.rs': '69e216bee1d74258348f84e6b8086b474a44d6b68470bd0cef22cbfa4ed75100',
  'native/contracts/tests/secret_contract.rs': 'e5585e0a2b584f3955a2516f6dff11615ca1fe299764a41289d0313d71ff1554',
  'native/contracts/tests/state_store_contract.rs': '71c582e47b278a5930ec8565c643a33c4c70f37f00bd76f8badf4dc86cd9b0cc',
  'native/contracts/tests/transaction_build_contract.rs': 'e3652344c31dbb01e6b3273b240296929bdaf2ed1aa2c2f1c7727a723ef649f0',
  'native/engine/Cargo.toml': '6df564b67cef7597161d8f832a5405333ed40b8b80efe75acc702c1df77120ce',
  'native/engine/README.md': '1e9c666ddda971b3a7c26de336994db8792fd84ec3ae9cc5fecc54134efa6fd5',
  'native/engine/src/account_state.rs': '4c933ad2fd5877e62078c3830971d8d28ff00776f30a7efa3a153d76476bfd0a',
  'native/engine/src/capabilities.rs': 'eb5f10ff24a2a2b9cbdc8781509f312e65f998d78a66d025e7d47de7602bef77',
  'native/engine/src/engine.rs': '6b50f7f62447c77686147f7bfd341ba56ca6d27fb9dc22b8612da9cba2d08d2a',
  'native/engine/src/error.rs': '5c8ca237baf1bccbe16ae575d93a3806d59093f1816fc7b4eea4ff0a22988064',
  'native/engine/src/finalized_events.rs': 'ca9c271317338d6173bb97b84e3a662148c4cf116e6f0f3ab93e2ec1c943fdd0',
  'native/engine/src/finalized_events_tests.rs': 'a1bfa1b974e36a03cd6124b5f6f7f8fd611735eef17734872e3908a792b070b7',
  'native/engine/src/finalized_history_runtime.rs': 'dcad4516037c139eda7b89107c80ce5976a1dc8740300afb4de107f5adc279a9',
  'native/engine/src/finalized_history_runtime_tests.rs': 'dd907c135ff8d3645fab2f354c321f37a61df607c96842322474851b9fce3b57',
  'native/engine/src/lib.rs': '1f768a8b3bedebeb9398280350aa8d2176d60b80f458b0cb4e55b83bb73a0ed5',
  'native/engine/src/runtime_context.rs': '947335419cb7d814a41900c7ff6b8d6be55183a178b196a3cfe574757148b0d3',
  'native/engine/src/state_import.rs': '1308efbbc2626bfd5f9cc936a8e3c6e4984dbc6e2e2dda9dc0917b24d98eaa01',
  'native/engine/src/system_events.rs': 'c9d0837979617ee46a5aab5645fd33099cb306623218654e0ca2c8acb64c28ee',
  'native/engine/src/transaction_builder.rs': '671fff14a7b6070e245fa459c111ae19dc12e644f8b8d4059d1b6eafd1114cbf',
  'native/engine/src/transaction_builder_tests.rs': '64fb03ac64e86d07ce1bc0b0cd2429eb3150d6f561f3a58877d85e4df1680c6e',
  'native/engine/src/transaction_history.rs': 'ca206d547b68d9be280e6b7941b2a8f5d05a33e308ac5df8df44a05d9986bade',
  'native/engine/src/transaction_history_tests.rs': '1ffe7303ad77af6222d443bb38ffb44e97418f462290d4123c9c442c06005d65',
  'native/engine/src/transaction_outcome.rs': 'a8efac7d37f2d119ad435e3d162dcb82dd0991367ccdd40ce4aed6b73152c1ed',
  'native/engine/src/wallet_derivation.rs': 'd54cf20571aeed9433062393311df0656d2e6357a4e8e01587efa4531f581c07',
  'native/engine/src/wallet_derivation_tests.rs': '6f81cc64f0f3c82d3510ea316aa04705ae40c27d53237f25293480fcfa504e5f',
  'native/engine/src/wallet_service.rs': '5fe503bdae8299da0f2b208965197567389e89dc6f9c7ec7890b3d5f9fd50f2d',
  'native/engine/src/wallet_service_tests.rs': 'f480b8a776be7d0d5c5e46b74e21e476e5b9d5590a316f4c626dc206e46fa5a0',
  'native/engine/src/wallet_transfer_watch.rs': 'dfc32284e3d99002603de398c813ed37149b9a24991da57fc73b1ad0f6c5e12c',
  'native/engine/src/wallet_transfer_watch_tests.rs': 'ab6e5595dacc4fb5fcecf599195c75d1c85bbe6e1b58521a30b59805ab9d9b1c',
  'native/engine/tests/account_state.rs': '3271646a267cfb325ae4a4ccd2142975c00325383d81380d62e424822230208a',
  'native/engine/tests/capabilities.rs': '8878d8cbbbdca8fa6ef4f5eefdb4f808bd21260d0ea7dcae31f593538ba37046',
  'native/engine/tests/chain_access.rs': 'af994070a14732dafaa9aa53804ee6383522854a8619d6dd0112993689f01fba',
  'native/engine/tests/engine_boundary.rs': '6c8493c39561fb5784c17814a7a999a062f9627e24d2eadf9e7cc08aeea32050',
  'native/engine/tests/runtime_context.rs': 'e5eb9f999668b6664d29ba61a0c8b2fd8b2e9fe37f7830bb4f4b7732b9c4fe43',
  'native/engine/tests/state_import.rs': '6937752568de3531a32b8ad35b1fd7270abad120c4b5aac423ae7df970d3f917',
  'native/engine/tests/transaction_outcome.rs': '24422882e1cb4f929fef69263de854f053cb45343fc5c5b4224d2e8a4e7a2946',
  'native/ffi/Cargo.toml': '5b4497bd4b992cc8c2cab4d273ad2e32a12240928db43d030aeff5f79e65a38c',
  'native/ffi/README.md': '56d0a54b02f7ddaef3444d61ed538bd3fe17b46cf126987881eeddd6c5a65804',
  'native/ffi/src/abi.rs': '5554ffa80f39d84e5f3e8fe46ea5d385eb41e0fe21a45f7d4510a5b2524d3a82',
  'native/ffi/src/assets.rs': '38ec1fc759746e68967ced815b7fcd4d1312be8ccc8da80cc4f8c60b4278ac67',
  'native/ffi/src/capabilities.rs': '491634510b9e76374d6101f408e57b2ee1c576569dc2f69e5a70e5952e2b5506',
  'native/ffi/src/composition.rs': 'd9ad0e306e9d555a2514def9d0d48353cd43a7ab3c5f9257db8e1812c5007ddb',
  'native/ffi/src/composition_tests.rs': 'ddec359df53dc28bf778ac4b035bb8b2431a131e42f2c85bbefbbcbfebe2b82e',
  'native/ffi/src/error.rs': '5599d3082a3250093b2193ce08327866f2c9e08a75309c006a43737d8bc3d875',
  'native/ffi/src/events.rs': 'c06490cb0f334261f19e3f8f6d41544332b6555c05cafe1572cb5745d4f0f7da',
  'native/ffi/src/handles.rs': '9e248ecb6fb9506b85d098172b731c22787f9860ccb53926ebc793da1fffd0c9',
  'native/ffi/src/host_codec.rs': '2844085303370ffc6bf25599debee01fb9738eb01c6d0cf601d40b4f83d7fbbd',
  'native/ffi/src/host_codec_tests.rs': 'b8490a7f85d446f50c4b3330c93debfaaa39e73c6570d47e0e8dd386df2c9422',
  'native/ffi/src/host_providers.rs': 'b1a7d456e475d014aec8a2399ce117bf83552ed84a6f11811207a67860b3f2d1',
  'native/ffi/src/lib.rs': '5e56243f734fe722df60beb72332b0d9845ce924158fd691f2207293fd0ef914',
  'native/ffi/src/ownership.rs': '107c8420dd1979e101fd18b7b5e7671e6368310529c612963acf4c2ff55c4eb8',
  'native/ffi/src/requests.rs': '3b9f1aa5f8cfc2727e563a80b9f5198b095420c8bd944ff5931cd2193ad7ece4',
  'native/ffi/src/runtime.rs': '505e3a0226e3ca66da82977fe728fef2d96574291c4aa8354e63e0be999f6d29',
  'native/ffi/src/wallet_abi.rs': '04250c979567342e14ec25af5364aba3d3daa488acc2d1cc62c278a4b2686217',
  'native/ffi/src/wallet_abi_tests.rs': '411b86c63277473e7ed8c39466713287577a89320898c79a4697350b6850c5a4',
  'native/ffi/tests/abi_layout.rs': '5ccba7c43fdfe78c317d3ffd23de627df4af1cad13e895aae11bf7a75527113f',
  'native/ffi/tests/asset_boundary.rs': 'a0a56cba330088ce01e807ac37191195b8d90013aba895ac2c7acf98b9a6ecfe',
  'native/ffi/tests/c_header_c11.c': '26f90252182189932277d77236d8ef50a44410b60c8fa17e30b4169f542edf73',
  'native/ffi/tests/c_header_cpp17.cc': 'bc9e01786ef55af8ac47396960028483205207c711fb380195506065e52e9eb5',
  'native/ffi/tests/capability_contract.rs': 'd0ba2b94dab377dfbead8f2c341cf1a42697189f461572ed5ce5986c5d8dca38',
  'native/ffi/tests/error_contract.rs': 'ae585490b05768b64401b1e6774789ba1beb1eede552e4d3e70a99cd1d395d91',
  'native/ffi/tests/event_contract.rs': 'e39b153cbebf7510d8f72af6692cf99ac8aec43f254bcc305dc5c741b063fd11',
  'native/ffi/tests/handle_contract.rs': '9823bfe3ddf579c021bac6c33bea7a43e9dc828ad946f0ee1a10baed654e494a',
  'native/ffi/tests/host_provider_contract.rs': 'a1aabe53e73e31e5eefe0669c1eceb3f4f0b09f5c9d65bb2661a9c142793e209',
  'native/ffi/tests/ownership_contract.rs': 'b75c13b228598177b1f8fabaa9a2cf5b1e62d8674a5dff662fed06616308ba0e',
  'native/ffi/tests/request_contract.rs': '816038c6de732cac1b85bdd15c72bfaac7b0eec2ace307937ce410f280204e42',
  'native/ffi/tests/symbol_contract.rs': 'f307bb95a762e0dcc618f5c92aaa5db567bc71af3ca5ba551c0734e11f5c9559',
  'native/ffi/tests/wallet_abi_contract.rs': '845070da4704549b9bd48c460de978da6dfb0c2fb93a372d7f9fcf3afd639449',
});
// native 根只能拥有这些已审核直接条目，防止出现第二个未审查的 Rust 产品边界。
const NATIVE_ROOT_ENTRIES = Object.freeze({
  'README.md': 'file',
  contracts: 'directory',
  engine: 'directory',
  ffi: 'directory',
  signer: 'directory',
  smoldot: 'directory',
});
// Core Rust 的 workspace 入口、解析闭包、边界说明和法律声明必须与源码闭集
// 同步审核；每个边界文件都固定最终审核字节，任何后续漂移均失败关闭。
const CORE_RUST_BOUNDARY_FILES = Object.freeze({
  'Cargo.toml': 'c2001e230187da0e5ca7df7227696d60e4c99d0f44622e389ba8dac8ee949b24',
  'Cargo.lock': '338e8db350d4c5abf9bdcbd9cc067a35f8c77bbe6eafcd125335b5eedaed8b32',
  'docs/C_ABI.md': 'ae469d18b3ae8ce459b794667f88a838f4feebd834d99793feffae451fd368d0',
  'native/README.md': '44689181344a51f45d3135f612f49439fe52c99deba946dbf5fc39b0d087c479',
  'THIRD_PARTY_NOTICES.md': '649f73986ca1e49e2dd4789a40ba9b1db093c4039f5825c73ed33edb37dbd484',
});
// 该清单离线固定 FFI、PoW workspace、light-base 与 lib 的完整文件闭集；
// byte_identical 项来自 CitizenApp 初始稳定基线，adapted/sdk_only 是已审查的
// SDK 边界。清单自身再由此哈希固定，CI/Release 不回指 CitizenApp。
const SMOLDOT_RUST_SOURCE_MANIFEST = Object.freeze({
  path: 'native/smoldot/SOURCE_SHA256.json',
  sha256: '3034428a2e76054e8c02b949153d5881932545745d5a4973b5aa342291e881f3',
});
// 这些文件位于各来源单元之外，但仍属于 Release 的正式输入：许可证、来源说明、
// smoldot 原始 ABI 头文件以及由 light-base 示例通过 include_str! 编译引用的链规范。
// 它们与来源清单中的全部来源单元共同组成 native/smoldot 的动态完整闭集；
// Dart 绑定已迁出本原生目录并由 SMOLDOT_DART_FILES 独立固定。
const SMOLDOT_SUPPORT_FILES = Object.freeze({
  'native/smoldot/LICENSE': 'aab56b4a581fc1c50b7c782eacf2fc8be05a47cd98e4bf4d836dd9b6dd9c86f4',
  'native/smoldot/LICENSE-APACHE-2.0': '4524e4d70a6295dfa882b0411cc49fcca03273e959fea68bbfe7df7ed63e7d78',
  'native/smoldot/README.md': 'ce7f4547b25e0709e13a097994269b0db5ad93f9334511803eeee32570b5bdb5',
  'native/smoldot/UPSTREAM.md': 'e0953f44b2382f50882acbd3d775ec1fe80b60e8a40b3d74e216e638a9a9b16b',
  'native/smoldot/include/README.md': '23118f58f9bdedfeb5e744a4507eb047a1c806fb937e2dd44ad160fca4a4000c',
  'native/smoldot/include/smoldot.h': 'f7c2645588809f73f8aa799975b363a4a7b22e8de7149da9d0b4c2ea20c90a20',
  'native/smoldot/pow/demo-chain-specs/polkadot.json': '859c8ade8b740e6a106082e0fdb4ae14075d79f8a277f02124bf9856d8a302aa',
  'native/smoldot/pow/demo-chain-specs/polkadot_asset_hub.json': '4909f824189edd0c7c64e444f81a4082fe5bc433861a5ac9e8b00838203a35ab',
});
// signer 是可编译的 Rust crate，正式输入不能只固定 Cargo.toml 与 lib.rs；README
// sr25519 单一实现、ChainSigner 适配和四份合同测试共同进入同一 10 文件闭集；
// 任何 build.rs、src/bin 或其他新增文件
// 都会改变 Cargo 行为，因此一律失败关闭。
const SIGNER_FILES = Object.freeze({
  'native/signer/Cargo.toml': 'fe18e5a7729c7f42060bdfa53aad214452ee4ca70bd5650cef6bd7a0dc5be8d0',
  'native/signer/README.md': '0a2d15098cc2740e35e1826e5f159997e8cfdefbb63e34069251d58c4180b440',
  'native/signer/src/README.md': '98d378a78c4bc45a74907c868259278a73266b0f9b521875fd80fbfc3cacaa8c',
  'native/signer/src/chain_signer.rs': '3461762743fb5723575b892171465ef31801b781262e1f3963ae5cbe12958a36',
  'native/signer/src/lib.rs': 'd1d2a35a70a8fbd7453e02f441a875f5c482cb22a98ccb27695594f7b006a869',
  'native/signer/src/sr25519.rs': 'c1159ff1a357b6c08b59d8a22d14a6b4a6cee313166ad0a435487192754f8ab4',
  'native/signer/tests/chain_signer_contract.rs': 'd4e53512dffab3f75ee213a08b71909dbc6c667b4b287df39cd9ac3e62824b31',
  'native/signer/tests/ffi_contract.rs': 'bf38f650394011e7f68219ee8ba435453f616281f91649634c536b8620407038',
  'native/signer/tests/legacy_parity.rs': '984a1521042d8a5b2285a43459383ef3972058db20e8f05154c1f75a2a11d70f',
  'native/signer/tests/substrate_vectors.rs': 'f5587dbce91f9c2014c559bece142e56fe65c81c7cf097df66b6c8125d45eef9',
});

function fail(message) {
  throw new Error(message);
}

function sha256File(path) {
  return createHash('sha256').update(readFileSync(path)).digest('hex');
}

function lstatExists(path) {
  try {
    lstatSync(path);
    return true;
  } catch (error) {
    if (error?.code === 'ENOENT') return false;
    throw error;
  }
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
  const sourcePath = resolve(source);
  const resolvedSource = existsSync(sourcePath) ? realpathSync(sourcePath) : sourcePath;
  const sourcePrefix = `${resolvedSource}${sep}`;
  const resolvedTarget = resolve(target);
  if (resolvedTarget === resolvedSource || resolvedTarget.startsWith(sourcePrefix)) {
    fail(`${label} 禁止位于 CitizenSDK 源码树：${resolvedTarget}`);
  }
}

function assertSafeTargetPath(path, label) {
  if (typeof path !== 'string' || path.length === 0 || resolve(path) !== path) {
    fail(`${label} 必须使用不含 .、.. 或重复分隔符的绝对规范路径：${path || '<empty>'}`);
  }
  const resolved = resolve(path);
  let current = sep;
  const segments = resolved.split(sep).filter(Boolean);
  for (let index = 0; index < segments.length; index += 1) {
    current = join(current, segments[index]);
    let info;
    try {
      info = lstatSync(current);
    } catch (error) {
      if (error?.code === 'ENOENT') break;
      throw error;
    }
    if (info.isSymbolicLink()) fail(`${label} 的既存路径祖先禁止使用符号链接：${current}`);
    if (index < segments.length - 1 && !info.isDirectory()) {
      fail(`${label} 的既存路径祖先不是目录：${current}`);
    }
  }
  return resolved;
}

function assertLocalTarget(path, label) {
  const target = assertSafeTargetPath(path, label);
  if (process.env.GITHUB_ACTIONS === 'true') return target;
  const root = assertSafeTargetPath(TATA_CONSOLE_TARGET_ROOT, 'TataConsole 中央目录');
  if (!existsSync(root) || !lstatSync(root).isDirectory()) {
    fail(`TataConsole 中央目录不存在或不是普通目录：${root}`);
  }
  if (target !== root && !target.startsWith(`${root}${sep}`)) {
    fail(`${label} 的本地路径必须位于 ${root}：${target}`);
  }
  return target;
}

function ensureNewDirectory(path, source, label) {
  assertSafeTargetPath(path, label);
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
  if (/\.(?:a|aar|dylib|dll|exe|o|so)$/i.test(relativePath) || relativePath.endsWith('/exported_symbols.txt')) {
    fail(`SDK 源码树包含原生编译产物：${relativePath}`);
  }
  const destination = join(output, ...relativePath.split('/'));
  mkdirSync(dirname(destination), { recursive: true, mode: 0o700 });
  copyFileSync(sourcePath, destination);
}

function prefixedSymlinkContract(prefix, contract) {
  return Object.freeze(Object.fromEntries(
    Object.entries(contract).map(([path, target]) => [
      prefix.length === 0 ? path : `${prefix}/${path}`,
      target,
    ]),
  ));
}

function appleMacOSLibraryIdentifier(xcframework) {
  const infoPath = join(xcframework, 'Info.plist');
  if (!existsSync(infoPath) || lstatSync(infoPath).isSymbolicLink()
      || !lstatSync(infoPath).isFile()) {
    fail('CitizenSDK.xcframework 缺少普通 Info.plist');
  }
  const info = parseXmlPlist(
    readFileSync(infoPath),
    'CitizenSDK.xcframework Info.plist',
  );
  const matches = Array.isArray(info.AvailableLibraries)
    ? info.AvailableLibraries.filter(
      (library) => library?.SupportedPlatform === 'macos'
        && library.SupportedPlatformVariant === undefined,
    )
    : [];
  if (matches.length !== 1) {
    fail('CitizenSDK macOS XCFramework slice 元数据漂移');
  }
  const identifier = matches[0].LibraryIdentifier;
  if (typeof identifier !== 'string'
      || !/^[A-Za-z0-9][A-Za-z0-9._-]*$/.test(identifier)) {
    fail('CitizenSDK.xcframework macOS LibraryIdentifier 无效');
  }
  return identifier;
}

function appleXcframeworkSymlinkContract(xcframework, prefix = '') {
  const framework = `${appleMacOSLibraryIdentifier(xcframework)}/CitizenSDK.framework`;
  return prefixedSymlinkContract(
    prefix.length === 0 ? framework : `${prefix}/${framework}`,
    APPLE_MACOS_FRAMEWORK_SYMLINKS,
  );
}

/**
 * Enumerate a tree without following links and fail closed on every non-file
 * entry. A caller may admit a complete, exact link contract; every declared
 * link must exist, must keep its literal relative target, and must resolve
 * inside the enumerated root. This is intentionally not a generic
 * "allow symlinks" switch.
 */
function treeEntries(root, allowedSymlinks = Object.freeze({})) {
  const files = [];
  const symlinks = [];
  const seenSymlinks = new Set();
  const treeRoot = resolve(root);
  if (!existsSync(treeRoot) || lstatSync(treeRoot).isSymbolicLink()
      || !lstatSync(treeRoot).isDirectory()) {
    fail(`SDK 候选树根必须是普通目录：${treeRoot}`);
  }
  const realTreeRoot = realpathSync(treeRoot);
  const visit = (directory) => {
    for (const name of readdirSync(directory).sort()) {
      const path = join(directory, name);
      const info = lstatSync(path);
      const relativePath = relative(treeRoot, path).split(sep).join('/');
      if (info.isSymbolicLink()) {
        const expectedTarget = allowedSymlinks[relativePath];
        if (expectedTarget === undefined) {
          fail(`SDK 候选禁止未声明符号链接：${relativePath}`);
        }
        const actualTarget = readlinkSync(path);
        if (actualTarget !== expectedTarget
            || actualTarget.startsWith('/')
            || actualTarget.split('/').includes('..')) {
          fail(`SDK 候选符号链接目标漂移：${relativePath}`);
        }
        let realTarget;
        try {
          realTarget = realpathSync(path);
        } catch (error) {
          if (error?.code === 'ENOENT' || error?.code === 'ELOOP') {
            fail(`SDK 候选符号链接悬空或成环：${relativePath}`);
          }
          throw error;
        }
        if (realTarget !== realTreeRoot && !realTarget.startsWith(`${realTreeRoot}${sep}`)) {
          fail(`SDK 候选符号链接越出受控根：${relativePath}`);
        }
        symlinks.push(relativePath);
        seenSymlinks.add(relativePath);
        continue;
      }
      if (info.isDirectory()) visit(path);
      else if (info.isFile()) files.push(relativePath);
      else fail(`SDK 候选只允许普通文件和目录：${relativePath}`);
    }
  };
  visit(treeRoot);
  const expectedSymlinks = Object.keys(allowedSymlinks).sort();
  const actualSymlinks = [...seenSymlinks].sort();
  if (JSON.stringify(actualSymlinks) !== JSON.stringify(expectedSymlinks)) {
    const actual = new Set(actualSymlinks);
    const missing = expectedSymlinks.filter((path) => !actual.has(path));
    fail(`SDK 候选缺少已声明符号链接：${missing.join(',') || '无'}`);
  }
  return { files: files.sort(), symlinks: actualSymlinks };
}

function regularFiles(root) {
  return treeEntries(root).files;
}

// File-only closures cannot detect a newly added empty/generated directory.
// Linux CMake state is especially prone to leaving such paths behind, so the
// platform source contract also closes the directory topology without ever
// following links.
function regularDirectories(root) {
  const treeRoot = resolve(root);
  if (!existsSync(treeRoot) || lstatSync(treeRoot).isSymbolicLink()
      || !lstatSync(treeRoot).isDirectory()) {
    fail(`SDK 候选树根必须是普通目录：${treeRoot}`);
  }
  const directories = [];
  const visit = (directory) => {
    for (const name of readdirSync(directory).sort()) {
      const path = join(directory, name);
      const info = lstatSync(path);
      const relativePath = relative(treeRoot, path).split(sep).join('/');
      if (info.isSymbolicLink()) {
        fail(`SDK 候选禁止未声明符号链接：${relativePath}`);
      }
      if (info.isDirectory()) {
        directories.push(relativePath);
        visit(path);
      } else if (!info.isFile()) {
        fail(`SDK 候选只允许普通文件和目录：${relativePath}`);
      }
    }
  };
  visit(treeRoot);
  return directories.sort();
}

function releaseCandidateEntries(root) {
  const candidate = resolve(root);
  const xcframework = join(candidate, ...APPLE_XCFRAMEWORK_PATH.split('/'));
  const symlinks = existsSync(xcframework)
    && !lstatSync(xcframework).isSymbolicLink()
    && lstatSync(xcframework).isDirectory()
    ? appleXcframeworkSymlinkContract(xcframework, APPLE_XCFRAMEWORK_PATH)
    : Object.freeze({});
  return treeEntries(candidate, symlinks);
}

/**
 * Verify the complete, immutable smoldot Dart source snapshot under [root].
 *
 * The check is applied both before copying a source tree and while verifying a
 * finished candidate, so neither an omitted test nor a self-consistent but
 * modified release manifest can hide source drift.
 */
export function assertSmoldotDartSource(root) {
  const sourceRoot = resolve(root);
  const actualPaths = [];
  for (const relativeRoot of SMOLDOT_DART_ROOTS) {
    const directory = join(sourceRoot, ...relativeRoot.split('/'));
    if (!existsSync(directory)
        || lstatSync(directory).isSymbolicLink()
        || !lstatSync(directory).isDirectory()) {
      fail(`CitizenSDK 缺少普通 smoldot Dart 迁移目录：${relativeRoot}`);
    }
    actualPaths.push(
      ...regularFiles(directory).map((path) => `${relativeRoot}/${path}`),
    );
  }
  actualPaths.sort();
  const expectedPaths = Object.keys(SMOLDOT_DART_FILES).sort();
  if (JSON.stringify(actualPaths) !== JSON.stringify(expectedPaths)) {
    const actual = new Set(actualPaths);
    const expected = new Set(expectedPaths);
    const missing = expectedPaths.filter((path) => !actual.has(path));
    const extra = actualPaths.filter((path) => !expected.has(path));
    fail(`smoldot Dart 文件闭集漂移；缺失=${missing.join(',') || '无'}；额外=${extra.join(',') || '无'}`);
  }
  for (const relativePath of expectedPaths) {
    const actualHash = sha256File(join(sourceRoot, ...relativePath.split('/')));
    if (actualHash !== SMOLDOT_DART_FILES[relativePath]) {
      fail(`smoldot Dart 文件哈希漂移：${relativePath}`);
    }
  }
}

export function assertSmoldotLocks(root) {
  const sourceRoot = resolve(root);
  for (const [relativePath, expectedHash] of Object.entries(SMOLDOT_LOCK_FILES)) {
    const path = join(sourceRoot, ...relativePath.split('/'));
    if (!existsSync(path) || !lstatSync(path).isFile() || lstatSync(path).isSymbolicLink()) {
      fail(`CitizenSDK 缺少普通锁文件：${relativePath}`);
    }
    if (sha256File(path) !== expectedHash) {
      fail(`CitizenSDK smoldot 锁文件漂移：${relativePath}`);
    }
  }
}

export function assertSdkRootLocks(root) {
  assertPinnedFiles(root, SDK_ROOT_LOCK_FILES, 'SDK 根锁');
}

function cargoLockString(block, field, label, required = true) {
  const pattern = new RegExp(`^${field} = ("(?:[^"\\\\]|\\\\.)*")$`, 'gm');
  const matches = [...block.matchAll(pattern)];
  if (matches.length === 0 && !required) return null;
  if (matches.length !== 1) fail(`${label} 的 ${field} 字段必须精确出现一次`);
  try {
    return JSON.parse(matches[0][1]);
  } catch {
    fail(`${label} 的 ${field} 不是有效字符串`);
  }
}

function parseCargoLock(path, label) {
  if (!existsSync(path) || lstatSync(path).isSymbolicLink() || !lstatSync(path).isFile()) {
    fail(`CitizenSDK 缺少普通${label}：${path}`);
  }
  const source = readFileSync(path, 'utf8');
  if (!/^version = 4$/m.test(source)) fail(`CitizenSDK ${label}必须是 Cargo.lock v4`);
  const blocks = source.split(/^\[\[package\]\]\s*$/m).slice(1);
  if (blocks.length === 0) fail(`CitizenSDK ${label}没有 package 条目`);
  return blocks.map((block, index) => {
    const entryLabel = `${label} package[${index}]`;
    const name = cargoLockString(block, 'name', entryLabel);
    const version = cargoLockString(block, 'version', entryLabel);
    const registrySource = cargoLockString(block, 'source', entryLabel, false);
    const checksum = cargoLockString(block, 'checksum', entryLabel, false);
    const dependenciesMatch = block.match(/^dependencies = \[\n([\s\S]*?)^\]$/m);
    const dependencies = [];
    if (dependenciesMatch) {
      for (const line of dependenciesMatch[1].split('\n')) {
        if (line.trim().length === 0) continue;
        const match = line.match(/^ ("(?:[^"\\]|\\.)*"),$/);
        if (!match) fail(`${entryLabel} 含无法解析的 dependency 行`);
        try {
          dependencies.push(JSON.parse(match[1]));
        } catch {
          fail(`${entryLabel} 含无效 dependency 字符串`);
        }
      }
    }
    if (registrySource !== null) {
      if (registrySource !== 'registry+https://github.com/rust-lang/crates.io-index'
          || !/^[0-9a-f]{64}$/.test(checksum ?? '')) {
        fail(`${entryLabel} 不是带固定 checksum 的官方 registry 包`);
      }
    } else if (checksum !== null) {
      fail(`${entryLabel} 的 path 包禁止携带孤立 checksum`);
    }
    return { name, version, source: registrySource, checksum, dependencies };
  });
}

function resolveCargoDependency(packages, dependency, ownerLabel) {
  const match = dependency.match(/^([^ ]+)(?: ([^ ]+))?(?: \(([^)]+)\))?$/);
  if (!match) fail(`${ownerLabel} 含无法解析的依赖引用：${dependency}`);
  const [, name, version, source] = match;
  const candidates = packages.filter((entry) => entry.name === name
    && (version === undefined || entry.version === version)
    && (source === undefined || entry.source === source));
  if (candidates.length !== 1) {
    fail(`${ownerLabel} 的依赖引用不唯一或缺失：${dependency}`);
  }
  return candidates[0];
}

function cargoPackageIdentity(entry) {
  return `${entry.name}\u0000${entry.version}\u0000${entry.source ?? 'path'}`;
}

function cargoRegistryEdgeIdentity(entry) {
  if (entry.source === null) return null;
  return `${entry.name} ${entry.version}`;
}

function collectCargoClosure(packages, rootEntry, label) {
  const closure = new Map();
  const pending = [rootEntry];
  while (pending.length > 0) {
    const current = pending.pop();
    const identity = cargoPackageIdentity(current);
    if (closure.has(identity)) continue;
    closure.set(identity, current);
    for (const dependency of current.dependencies) {
      pending.push(resolveCargoDependency(
        packages,
        dependency,
        `${label} ${current.name} ${current.version}`,
      ));
    }
  }
  return closure;
}

/**
 * Prove offline that every registry package recursively reachable through the
 * product provider's bundled `smoldot-light` edge has the exact
 * name/version/checksum already fixed by the bundled PoW smoldot lock. The only
 * permitted root-only item is an exact, checksum-pinned Cargo feature-union
 * dependency that is also a direct dependency of its declared local workspace
 * owner. Provider-only dependencies remain pinned by the root-lock byte hash;
 * they are not falsely claimed to originate in the upstream PoW lock. No Cargo
 * invocation or network fallback is allowed here.
 */
export function assertProviderLockParity(root) {
  const sourceRoot = resolve(root);
  const rootPackages = parseCargoLock(join(sourceRoot, 'Cargo.lock'), '根 Cargo.lock');
  const powPackages = parseCargoLock(
    join(sourceRoot, 'native', 'smoldot', 'pow', 'Cargo.lock'),
    'smoldot PoW Cargo.lock',
  );
  const providers = rootPackages.filter((entry) => entry.name === 'citizen-sdk-smoldot-provider');
  if (providers.length !== 1 || providers[0].source !== null) {
    fail('CitizenSDK 根锁必须精确包含一个本地 smoldot provider');
  }

  const smoldotDependencies = providers[0].dependencies
    .map((dependency) => resolveCargoDependency(
      rootPackages,
      dependency,
      '根 Cargo.lock citizen-sdk-smoldot-provider',
    ))
    .filter((entry) => entry.name === 'smoldot-light' && entry.source === null);
  if (smoldotDependencies.length !== 1) {
    fail('CitizenSDK provider 必须唯一依赖随包 smoldot-light');
  }

  const rootClosure = collectCargoClosure(
    rootPackages,
    smoldotDependencies[0],
    '根 Cargo.lock',
  );
  const registryClosure = new Map(
    [...rootClosure].filter(([, entry]) => entry.source !== null),
  );
  if (registryClosure.size === 0) {
    fail('CitizenSDK provider 的随包 smoldot-light 锁闭包没有 registry 依赖');
  }

  const powSmoldotDependencies = powPackages.filter(
    (entry) => entry.name === 'smoldot-light' && entry.source === null,
  );
  if (powSmoldotDependencies.length !== 1) {
    fail('smoldot PoW 锁必须精确包含一个本地 smoldot-light');
  }
  const powClosure = collectCargoClosure(
    powPackages,
    powSmoldotDependencies[0],
    'smoldot PoW Cargo.lock',
  );

  for (const [identity, entry] of registryClosure) {
    const matchedEntry = powClosure.get(identity);
    if (matchedEntry?.checksum === entry.checksum) continue;

    const exception = PROVIDER_LOCK_FEATURE_UNION_EXCEPTIONS[`${entry.name} ${entry.version}`];
    const owners = rootPackages.filter((candidate) => candidate.name === exception?.owner
      && candidate.source === null);
    const ownerHasExactDependency = owners.length === 1 && owners[0].dependencies.some(
      (dependency) => resolveCargoDependency(
        rootPackages,
        dependency,
        `根 Cargo.lock ${owners[0].name} ${owners[0].version}`,
      ) === entry,
    );
    if (!exception
        || entry.checksum !== exception.checksum
        || !ownerHasExactDependency) {
      fail(`CitizenSDK provider registry 锁闭包漂移：${entry.name} ${entry.version}`);
    }
  }

  for (const [identity, entry] of registryClosure) {
    const matchedEntry = powClosure.get(identity);
    if (matchedEntry === undefined) continue;

    const rootEdges = entry.dependencies.map((dependency) => cargoRegistryEdgeIdentity(
      resolveCargoDependency(
        rootPackages,
        dependency,
        `根 Cargo.lock ${entry.name} ${entry.version}`,
      ),
    )).filter((edge) => edge !== null).sort();
    const powEdges = matchedEntry.dependencies.map((dependency) => cargoRegistryEdgeIdentity(
      resolveCargoDependency(
        powPackages,
        dependency,
        `smoldot PoW Cargo.lock ${matchedEntry.name} ${matchedEntry.version}`,
      ),
    )).filter((edge) => edge !== null).sort();
    const rootEdgeSet = new Set(rootEdges);
    const powEdgeSet = new Set(powEdges);
    const missing = powEdges.filter((edge) => !rootEdgeSet.has(edge));
    const extra = rootEdges.filter((edge) => !powEdgeSet.has(edge));
    const owner = `${entry.name} ${entry.version}`;
    const allowedExtra = [...(PROVIDER_LOCK_FEATURE_UNION_EDGE_EXCEPTIONS[owner] ?? [])]
      .sort();
    if (missing.length > 0 || JSON.stringify(extra) !== JSON.stringify(allowedExtra)) {
      fail(`CitizenSDK provider registry 依赖边漂移：${owner}`);
    }
  }
  return registryClosure.size;
}

/**
 * Verify the complete CitizenSDK-owned Rust core and its workspace boundary.
 *
 * This contract deliberately does not share smoldot's imported-source manifest:
 * contracts/engine/ffi are maintained by CitizenSDK and therefore have their own
 * reverse-enumerated closure. The native root is also closed so a new crate
 * cannot enter a release merely because ROOT_DIRECTORIES recursively copies it.
 */
export function assertCoreRustSource(root) {
  const sourceRoot = resolve(root);
  if (Object.keys(CORE_RUST_FILES).length !== CORE_RUST_FILE_COUNT) {
    fail(`CitizenSDK Core Rust 固定清单必须精确为 ${CORE_RUST_FILE_COUNT} 文件`);
  }
  const nativeRoot = join(sourceRoot, 'native');
  if (!existsSync(nativeRoot)
      || lstatSync(nativeRoot).isSymbolicLink()
      || !lstatSync(nativeRoot).isDirectory()) {
    fail('CitizenSDK 缺少普通 native 根目录');
  }

  const actualNativeEntries = readdirSync(nativeRoot).sort();
  const expectedNativeEntries = Object.keys(NATIVE_ROOT_ENTRIES).sort();
  if (JSON.stringify(actualNativeEntries) !== JSON.stringify(expectedNativeEntries)) {
    const actual = new Set(actualNativeEntries);
    const expected = new Set(expectedNativeEntries);
    const missing = expectedNativeEntries.filter((path) => !actual.has(path));
    const extra = actualNativeEntries.filter((path) => !expected.has(path));
    fail(`CitizenSDK native 根闭集漂移；缺失=${missing.join(',') || '无'}；额外=${extra.join(',') || '无'}`);
  }
  for (const [name, expectedType] of Object.entries(NATIVE_ROOT_ENTRIES)) {
    const path = join(nativeRoot, name);
    const info = lstatSync(path);
    if (info.isSymbolicLink()
        || (expectedType === 'file' ? !info.isFile() : !info.isDirectory())) {
      fail(`CitizenSDK native 根条目类型漂移：${name}`);
    }
  }

  for (const relativeRoot of CORE_RUST_ROOTS) {
    const coreRoot = join(sourceRoot, ...relativeRoot.split('/'));
    if (!existsSync(coreRoot)
        || lstatSync(coreRoot).isSymbolicLink()
        || !lstatSync(coreRoot).isDirectory()) {
      fail(`CitizenSDK 缺少普通 Core Rust 来源目录：${relativeRoot}`);
    }
    const actualPaths = regularFiles(coreRoot)
      .map((path) => `${relativeRoot}/${path}`)
      .sort();
    const expectedPaths = Object.keys(CORE_RUST_FILES)
      .filter((path) => path.startsWith(`${relativeRoot}/`))
      .sort();
    if (JSON.stringify(actualPaths) !== JSON.stringify(expectedPaths)) {
      const actual = new Set(actualPaths);
      const expected = new Set(expectedPaths);
      const missing = expectedPaths.filter((path) => !actual.has(path));
      const extra = actualPaths.filter((path) => !expected.has(path));
      fail(`CitizenSDK Core Rust 文件闭集漂移：${relativeRoot}；缺失=${missing.join(',') || '无'}；额外=${extra.join(',') || '无'}`);
    }
  }
  assertPinnedFiles(sourceRoot, CORE_RUST_FILES, 'Core Rust 来源');
  assertPinnedFiles(sourceRoot, CORE_RUST_BOUNDARY_FILES, 'Core Rust 边界');
}

function assertPinnedFiles(root, files, label) {
  const sourceRoot = resolve(root);
  for (const [relativePath, expectedHash] of Object.entries(files)) {
    const path = join(sourceRoot, ...relativePath.split('/'));
    if (!existsSync(path) || lstatSync(path).isSymbolicLink() || !lstatSync(path).isFile()) {
      fail(`CitizenSDK 缺少普通${label}文件：${relativePath}`);
    }
    if (sha256File(path) !== expectedHash) {
      fail(`CitizenSDK ${label}文件哈希漂移：${relativePath}`);
    }
  }
}

function stripCComments(source) {
  return source
    .replace(/\/\*[\s\S]*?\*\//g, ' ')
    .replace(/\/\/[^\r\n]*/g, ' ');
}

/** Verify the root C/C++ header closure and its product-only safety boundary. */
export function assertPublicAbiHeaders(root) {
  const sourceRoot = resolve(root);
  const includeRoot = join(sourceRoot, 'include');
  if (!existsSync(includeRoot)
      || lstatSync(includeRoot).isSymbolicLink()
      || !lstatSync(includeRoot).isDirectory()) {
    fail('CitizenSDK 缺少普通根 include 目录');
  }
  const actualPaths = readdirSync(includeRoot).map((path) => `include/${path}`).sort();
  const expectedPaths = Object.keys(PUBLIC_ABI_FILES).sort();
  if (JSON.stringify(actualPaths) !== JSON.stringify(expectedPaths)) {
    const actual = new Set(actualPaths);
    const expected = new Set(expectedPaths);
    const missing = expectedPaths.filter((path) => !actual.has(path));
    const extra = actualPaths.filter((path) => !expected.has(path));
    fail(`CitizenSDK 根 include 文件闭集漂移；缺失=${missing.join(',') || '无'}；额外=${extra.join(',') || '无'}`);
  }
  for (const relativePath of expectedPaths) {
    const path = join(sourceRoot, ...relativePath.split('/'));
    if (lstatSync(path).isSymbolicLink() || !lstatSync(path).isFile()) {
      fail(`CitizenSDK 根 include 条目必须是普通文件：${relativePath}`);
    }
  }

  const headers = expectedPaths
    .filter((path) => path.endsWith('.h'))
    .map((path) => readFileSync(join(sourceRoot, ...path.split('/')), 'utf8'))
    .join('\n');
  const publicSource = stripCComments(headers);
  const forbiddenSymbol = publicSource.match(
    /\b(?:smoldot|citizen_sr25519|account_crypto)_[A-Za-z0-9_]*\b/,
  );
  if (forbiddenSymbol) {
    fail(`CitizenSDK 公共 ABI 泄漏非产品符号：${forbiddenSymbol[0]}`);
  }

  const withoutDirectives = publicSource.replace(/^[ \t]*#.*$/gm, ' ');
  const apparentFunctions = [
    ...withoutDirectives.matchAll(
      /^[ \t]*(?!typedef\b)((?:CITIZENSDK_API[ \t]+)?[A-Za-z_][A-Za-z0-9_]*(?:[ \t*]+[A-Za-z_][A-Za-z0-9_]*)*[ \t*\r\n]+([A-Za-z_][A-Za-z0-9_]*)\s*\([^;{}]*\)\s*;)/gm,
    ),
  ];
  for (const prototype of apparentFunctions) {
    if (!prototype[1].trimStart().startsWith('CITIZENSDK_API ')) {
      fail(`CitizenSDK 公共 ABI 只允许带导出标记的 citizensdk_* 函数：${prototype[2]}`);
    }
  }

  const declarations = [
    ...publicSource.matchAll(/^[ \t]*CITIZENSDK_API\b([\s\S]*?);/gm),
  ];
  if (declarations.length === 0) fail('CitizenSDK 公共 ABI 没有导出函数');
  for (const declaration of declarations) {
    const normalized = declaration[1].replace(/\s+/g, ' ').trim();
    const functionName = normalized.match(/\b([A-Za-z_][A-Za-z0-9_]*)\s*\(/)?.[1];
    if (!functionName || !/^citizensdk_[a-z0-9_]+$/.test(functionName)) {
      fail(`CitizenSDK 公共 ABI 只允许 citizensdk_* 函数：${functionName ?? '<unparsed>'}`);
    }
    const hasMethodAndParams = /method/i.test(normalized) && /params/i.test(normalized);
    if (/(?:^|_)rpc(?:_|$)/i.test(functionName) || hasMethodAndParams) {
      fail(`CitizenSDK 公共 ABI 禁止任意 rpc(method, params)：${functionName}`);
    }
    const forbiddenPrivateMaterial = /(?:private_?key|mini_?secret|child_?secret|(?:^|_)seed(?:_|$))/i
      .test(normalized);
    const carriesGenericSecret = /(?:^|_)secret(?:_|\b)/i.test(normalized);
    const carriesMnemonic = /mnemonic/i.test(normalized);
    const mnemonicFunctions = new Set([
      'citizensdk_import_wallet',
      'citizensdk_add_wallet_accounts',
      'citizensdk_prepared_wallet_copy_mnemonic',
    ]);
    if (forbiddenPrivateMaterial
        || carriesGenericSecret
        || (carriesMnemonic && !mnemonicFunctions.has(functionName))) {
      fail(`CitizenSDK 公共 ABI 禁止助记词、私钥或秘密导出：${functionName}`);
    }
    if (functionName === 'citizensdk_prepared_wallet_copy_mnemonic'
        && (!/\bcitizensdk_handle_t\s+handle\b/.test(normalized)
          || !/\bcitizensdk_prepared_wallet_handle_t\s+prepared_wallet\b/.test(normalized)
          || /\bout_[A-Za-z0-9_]*mnemonic[A-Za-z0-9_]*\b/i.test(normalized))) {
      fail('CitizenSDK 助记词备份 ABI 必须绑定所属 instance/prepared handle，并只写调用方通用缓冲区');
    }
  }
  assertPinnedFiles(sourceRoot, PUBLIC_ABI_FILES, '公共 ABI');
}

export function assertChainAssets(root) {
  const sourceRoot = resolve(root);
  const assetsRoot = join(sourceRoot, 'assets');
  if (!existsSync(assetsRoot)
      || lstatSync(assetsRoot).isSymbolicLink()
      || !lstatSync(assetsRoot).isDirectory()) {
    fail('CitizenSDK 缺少普通链资产目录');
  }
  const actualPaths = regularFiles(assetsRoot).map((path) => `assets/${path}`);
  const expectedPaths = Object.keys(CHAIN_ASSET_FILES).sort();
  if (JSON.stringify(actualPaths) !== JSON.stringify(expectedPaths)) {
    const actual = new Set(actualPaths);
    const expected = new Set(expectedPaths);
    const missing = expectedPaths.filter((path) => !actual.has(path));
    const extra = actualPaths.filter((path) => !expected.has(path));
    fail(`CitizenSDK 链资产闭集漂移；缺失=${missing.join(',') || '无'}；额外=${extra.join(',') || '无'}`);
  }
  assertPinnedFiles(sourceRoot, CHAIN_ASSET_FILES, '链资产');

  const manifestPath = join(assetsRoot, 'citizenchain', 'manifest.json');
  let manifest;
  try {
    manifest = JSON.parse(readFileSync(manifestPath, 'utf8'));
  } catch {
    fail('CitizenSDK 链资产 manifest 不是有效 JSON');
  }
  if (!manifest || Array.isArray(manifest) || typeof manifest !== 'object') {
    fail('CitizenSDK 链资产 manifest 必须是 JSON 对象');
  }
  const actualManifestKeys = Object.keys(manifest).sort();
  const expectedManifestKeys = Object.keys(CHAIN_ASSET_MANIFEST).sort();
  if (JSON.stringify(actualManifestKeys) !== JSON.stringify(expectedManifestKeys)) {
    fail('CitizenSDK 链资产 manifest 字段闭集漂移');
  }
  for (const [field, expected] of Object.entries(CHAIN_ASSET_MANIFEST)) {
    if (manifest[field] !== expected) {
      fail(`CitizenSDK 链资产 manifest 字段漂移：${field}`);
    }
  }
}

export function assertSourceFixtures(root) {
  assertPinnedFiles(root, SOURCE_FIXTURE_FILES, '逐字节来源夹具');
}

export function assertLicenseSources(root) {
  assertPinnedFiles(root, LICENSE_SOURCE_FILES, '许可证原文');
}

function isDocumentationFile(relativePath) {
  const name = relativePath.split('/').at(-1);
  return /\.(?:adoc|md|rst|txt)$/i.test(name)
    || /^(?:CHANGELOG|LICENSE|README|UPSTREAM)(?:[-.].*)?$/i.test(name);
}

function isAndroidTestPath(relativePath) {
  return relativePath.startsWith('src/test/')
    || relativePath.startsWith('native/src/test/')
    || relativePath.startsWith('native/src/androidTest/');
}

function isInjectedAndroidArtifact(relativePath) {
  return relativePath === 'citizensdk.aar'
    || relativePath.startsWith('src/main/jniLibs/');
}

function isDarwinTestOrInjectedArtifact(relativePath) {
  return relativePath.startsWith('Tests/')
    || relativePath === 'CitizenSDK.xcframework'
    || relativePath.startsWith('CitizenSDK.xcframework/');
}

// 源码检查默认不允许 Darwin 树出现任何链接。只有最终候选的调用点可以显式
// 开启 Apple 产物投影；即使开启，也必须逐条匹配 macOS framework 的标准五
// 链接，iOS 设备/simulator 技术变体和 Darwin 其余路径仍保持零链接。
function darwinBindingFiles(darwinRoot, allowAppleReleaseProjection) {
  const xcframework = join(darwinRoot, 'CitizenSDK.xcframework');
  const allowedSymlinks = allowAppleReleaseProjection
    ? appleXcframeworkSymlinkContract(xcframework, 'CitizenSDK.xcframework')
    : Object.freeze({});
  return treeEntries(darwinRoot, allowedSymlinks).files;
}

/** Verify every non-smoldot Dart, Android and Apple production input. */
export function assertMobileBindingSource(
  root,
  { allowAppleReleaseProjection = false } = {},
) {
  const sourceRoot = resolve(root);
  if (Object.keys(MOBILE_BINDING_SOURCE_FILES).length !== MOBILE_BINDING_SOURCE_FILE_COUNT) {
    fail(`CitizenSDK 移动绑定固定清单必须精确为 ${MOBILE_BINDING_SOURCE_FILE_COUNT} 文件`);
  }
  const libRoot = join(sourceRoot, 'lib');
  const androidRoot = join(sourceRoot, 'android');
  const darwinRoot = join(sourceRoot, 'darwin');
  for (const [path, label] of [
    [libRoot, 'lib'],
    [androidRoot, 'android'],
    [darwinRoot, 'darwin'],
  ]) {
    if (!existsSync(path) || lstatSync(path).isSymbolicLink() || !lstatSync(path).isDirectory()) {
      fail(`CitizenSDK 缺少普通移动绑定来源目录：${label}`);
    }
  }
  // Kotlin 编译器的 project persistent state 只能写入 TataConsole 中央
  // work dir；即使 android/.kotlin 为空，也不能让它进入源码或候选闭包。
  const kotlinSourceState = join(androidRoot, '.kotlin');
  if (existsSync(kotlinSourceState) || lstatExists(kotlinSourceState)) {
    fail('CitizenSDK 源码禁止存在 Android Kotlin 持久状态目录：android/.kotlin');
  }
  const actualPaths = [
    ...regularFiles(libRoot)
      .filter((path) => path.endsWith('.dart') && !path.startsWith('src/smoldot/'))
      .map((path) => `lib/${path}`),
    ...regularFiles(androidRoot)
      .filter((path) => !isAndroidTestPath(path)
        && !isInjectedAndroidArtifact(path)
        && (!isDocumentationFile(path) || path.endsWith('/CMakeLists.txt')))
      .map((path) => `android/${path}`),
    ...darwinBindingFiles(darwinRoot, allowAppleReleaseProjection)
      .filter((path) => !isDarwinTestOrInjectedArtifact(path)
        && !isDocumentationFile(path))
      .map((path) => `darwin/${path}`),
  ].sort();
  const expectedPaths = Object.keys(MOBILE_BINDING_SOURCE_FILES).sort();
  if (JSON.stringify(actualPaths) !== JSON.stringify(expectedPaths)) {
    const actual = new Set(actualPaths);
    const expected = new Set(expectedPaths);
    const missing = expectedPaths.filter((path) => !actual.has(path));
    const extra = actualPaths.filter((path) => !expected.has(path));
    fail(`CitizenSDK 移动绑定文件闭集漂移；缺失=${missing.join(',') || '无'}；额外=${extra.join(',') || '无'}`);
  }
  assertPinnedFiles(sourceRoot, MOBILE_BINDING_SOURCE_FILES, '移动绑定来源');
}

/**
 * Verify the source-only LinuxARM/LinuxAMD Host projection.
 *
 * Step 7.1 intentionally does not admit ELF artifacts, a Flutter plugin, or
 * public Release platforms. README files and linux/test are owned by their
 * narrower documentation/test contracts; every other Linux file and every
 * directory is closed here so an empty CMake cache cannot bypass hashing.
 */
export function assertLinuxBindingSource(root) {
  const sourceRoot = resolve(root);
  const linuxRoot = join(sourceRoot, 'linux');
  if (!existsSync(linuxRoot)
      || lstatSync(linuxRoot).isSymbolicLink()
      || !lstatSync(linuxRoot).isDirectory()) {
    fail('CitizenSDK 缺少普通 Linux Host 来源目录：linux');
  }
  if (Object.keys(LINUX_BINDING_SOURCE_FILES).length
      !== LINUX_BINDING_SOURCE_FILE_COUNT) {
    fail(`CitizenSDK Linux Host 固定清单必须精确为 ${LINUX_BINDING_SOURCE_FILE_COUNT} 文件`);
  }
  const actualDirectories = regularDirectories(linuxRoot);
  if (JSON.stringify(actualDirectories)
      !== JSON.stringify([...LINUX_BINDING_SOURCE_DIRECTORIES])) {
    const actual = new Set(actualDirectories);
    const expected = new Set(LINUX_BINDING_SOURCE_DIRECTORIES);
    const missing = LINUX_BINDING_SOURCE_DIRECTORIES
      .filter((path) => !actual.has(path));
    const extra = actualDirectories.filter((path) => !expected.has(path));
    fail(`CitizenSDK Linux Host 目录闭集漂移；缺失=${missing.join(',') || '无'}；额外=${extra.join(',') || '无'}`);
  }
  const actualPaths = regularFiles(linuxRoot)
    .filter((path) => !path.startsWith('test/'))
    .filter((path) => path === 'CMakeLists.txt' || !isDocumentationFile(path))
    .map((path) => `linux/${path}`)
    .sort();
  const expectedPaths = Object.keys(LINUX_BINDING_SOURCE_FILES).sort();
  if (JSON.stringify(actualPaths) !== JSON.stringify(expectedPaths)) {
    const actual = new Set(actualPaths);
    const expected = new Set(expectedPaths);
    const missing = expectedPaths.filter((path) => !actual.has(path));
    const extra = actualPaths.filter((path) => !expected.has(path));
    fail(`CitizenSDK Linux Host 文件闭集漂移；缺失=${missing.join(',') || '无'}；额外=${extra.join(',') || '无'}`);
  }
  assertPinnedFiles(sourceRoot, LINUX_BINDING_SOURCE_FILES, 'Linux Host 来源');

  const cmake = readFileSync(join(linuxRoot, 'CMakeLists.txt'), 'utf8');
  const matches = [...cmake.matchAll(
    /^project\(CitizenSDKHost VERSION (\d+\.\d{1,2}\.\d{1,2}) LANGUAGES C CXX\)$/gm,
  )];
  if (matches.length !== 1) {
    fail('CitizenSDK Linux Host CMake 产品身份或版本字段不唯一');
  }
  return matches[0][1];
}

/**
 * Verify the CitizenSDK-owned documentation that was not already closed by a
 * narrower source contract. The top-level docs/ product documents are closed
 * as an entire subtree except for docs/smoldot-dart/, whose imported snapshot
 * remains authoritative in SMOLDOT_DART_FILES. Android, Apple and Dart trees
 * contain production sources, so only documentation-shaped files are listed.
 */
export function assertDocumentationSource(
  root,
  { allowAppleReleaseProjection = false } = {},
) {
  const sourceRoot = resolve(root);
  if (Object.keys(DOCUMENTATION_SHA256).length !== DOCUMENTATION_FILE_COUNT) {
    fail(`CitizenSDK 文档固定清单必须精确为 ${DOCUMENTATION_FILE_COUNT} 文件`);
  }

  const actualPaths = [];
  const rootReadme = join(sourceRoot, 'README.md');
  if (existsSync(rootReadme)) {
    const info = lstatSync(rootReadme);
    if (info.isSymbolicLink() || !info.isFile()) {
      fail('CitizenSDK 根 README.md 必须是普通文件');
    }
    actualPaths.push('README.md');
  }

  const docsRoot = join(sourceRoot, 'docs');
  if (!existsSync(docsRoot)
      || lstatSync(docsRoot).isSymbolicLink()
      || !lstatSync(docsRoot).isDirectory()) {
    fail('CitizenSDK 缺少普通产品文档目录：docs');
  }
  actualPaths.push(...regularFiles(docsRoot)
    .map((path) => `docs/${path}`)
    .filter((path) => !path.startsWith('docs/smoldot-dart/')));

  for (const relativeRoot of ['android', 'darwin', 'lib/src', 'linux']) {
    const documentationRoot = join(sourceRoot, ...relativeRoot.split('/'));
    if (!existsSync(documentationRoot)
        || lstatSync(documentationRoot).isSymbolicLink()
        || !lstatSync(documentationRoot).isDirectory()) {
      fail(`CitizenSDK 缺少普通产品文档来源目录：${relativeRoot}`);
    }
    const documentationFiles = relativeRoot === 'darwin'
      ? darwinBindingFiles(documentationRoot, allowAppleReleaseProjection)
      : regularFiles(documentationRoot);
    actualPaths.push(...documentationFiles
      .filter((path) => isDocumentationFile(path)
        && path !== 'native/src/main/cpp/CMakeLists.txt'
        && (relativeRoot !== 'linux' || path !== 'CMakeLists.txt')
        && (relativeRoot !== 'android' || !isAndroidTestPath(path))
        && (relativeRoot !== 'darwin' || !isDarwinTestOrInjectedArtifact(path)))
      .filter((path) => relativeRoot !== 'linux' || !path.startsWith('test/'))
      .map((path) => `${relativeRoot}/${path}`));
  }

  actualPaths.sort();
  const expectedPaths = Object.keys(DOCUMENTATION_SHA256).sort();
  if (JSON.stringify(actualPaths) !== JSON.stringify(expectedPaths)) {
    const actual = new Set(actualPaths);
    const expected = new Set(expectedPaths);
    const missing = expectedPaths.filter((path) => !actual.has(path));
    const extra = actualPaths.filter((path) => !expected.has(path));
    fail(`CitizenSDK 产品文档闭集漂移；缺失=${missing.join(',') || '无'}；额外=${extra.join(',') || '无'}`);
  }
  assertPinnedFiles(sourceRoot, DOCUMENTATION_SHA256, '产品文档');
}

function compileRootedPubignoreRule(rawRule) {
  const negated = rawRule.startsWith('!');
  const rule = negated ? rawRule.slice(1) : rawRule;
  if (!rule.startsWith('/')) {
    fail(`CitizenSDK .pubignore 只允许可审计的根路径规则：${rawRule}`);
  }
  const directory = rule.endsWith('/');
  const pattern = directory ? rule.slice(1, -1) : rule.slice(1);
  let expression = '';
  for (let index = 0; index < pattern.length; index += 1) {
    const character = pattern[index];
    if (character === '*') {
      if (pattern[index + 1] === '*') {
        expression += '.*';
        index += 1;
      } else {
        expression += '[^/]*';
      }
    } else if (character === '?') {
      expression += '[^/]';
    } else {
      expression += character.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    }
  }
  return {
    ignored: !negated,
    pattern: new RegExp(`^${expression}${directory ? '(?:/.*)?' : ''}$`),
  };
}

function hostedPubignoreRules(sourceRoot) {
  const path = join(sourceRoot, '.pubignore');
  if (!existsSync(path) || lstatSync(path).isSymbolicLink() || !lstatSync(path).isFile()) {
    fail('CitizenSDK 缺少普通 .pubignore');
  }
  return readFileSync(path, 'utf8')
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter((line) => line && !line.startsWith('#'))
    .map(compileRootedPubignoreRule);
}

function isHostedIgnored(relativePath, rules) {
  let ignored = false;
  for (const rule of rules) {
    if (rule.pattern.test(relativePath)) ignored = rule.ignored;
  }
  return ignored;
}

/** Verify the Dart files that the real pinned .pubignore exposes to Hosted consumers. */
export function assertHostedRuntimeDartProjection(root) {
  const sourceRoot = resolve(root);
  const libRoot = join(sourceRoot, 'lib');
  if (!existsSync(libRoot) || lstatSync(libRoot).isSymbolicLink()
      || !lstatSync(libRoot).isDirectory()) {
    fail('CitizenSDK Hosted Package 缺少普通 lib 目录');
  }
  const rules = hostedPubignoreRules(sourceRoot);
  const actualPaths = regularFiles(libRoot)
    .filter((path) => path.endsWith('.dart'))
    .map((path) => `lib/${path}`)
    .filter((path) => !isHostedIgnored(path, rules))
    .sort();
  const expectedPaths = [...HOSTED_RUNTIME_DART_FILES].sort();
  if (JSON.stringify(actualPaths) !== JSON.stringify(expectedPaths)) {
    const actual = new Set(actualPaths);
    const expected = new Set(expectedPaths);
    const missing = expectedPaths.filter((path) => !actual.has(path));
    const extra = actualPaths.filter((path) => !expected.has(path));
    fail(`CitizenSDK Hosted Dart 运行闭集漂移；缺失=${missing.join(',') || '无'}；额外=${extra.join(',') || '无'}`);
  }
  const facade = readFileSync(join(sourceRoot, 'lib/src/api/citizen_sdk.dart'), 'utf8');
  const forbiddenFacadeName = ['CitizenSdk', 'Client'].join('');
  if (!/\bfinal\s+class\s+CitizenSdk\b/.test(facade)
      || facade.includes(forbiddenFacadeName)) {
    fail('CitizenSDK Hosted Dart 唯一公开门面必须精确命名为 CitizenSdk，禁止任何旧别名');
  }
}

function yamlTopLevelSection(source, name) {
  const lines = source.split(/\r?\n/);
  const start = lines.findIndex((line) => line === `${name}:`);
  if (start < 0) fail(`CitizenSDK Hosted Package 缺少 ${name}`);
  const section = [];
  for (let index = start + 1; index < lines.length; index += 1) {
    if (/^[A-Za-z_][A-Za-z0-9_-]*:/.test(lines[index])) break;
    section.push(lines[index]);
  }
  return section.join('\n');
}

function assertHostedDependencySection(pubspec, name, expected) {
  const section = yamlTopLevelSection(pubspec, name);
  const direct = [...section.matchAll(/^  ([A-Za-z_][A-Za-z0-9_-]*):(.*)$/gm)]
    .map((match) => [match[1], match[2].trim()]);
  const actualNames = direct.map(([dependency]) => dependency).sort();
  const expectedNames = Object.keys(expected).sort();
  if (JSON.stringify(actualNames) !== JSON.stringify(expectedNames)) {
    fail(`CitizenSDK Hosted Package ${name} 闭集漂移：${actualNames.join(',') || '无'}`);
  }
  for (const [dependency, constraint] of Object.entries(expected)) {
    const value = direct.find(([name]) => name === dependency)?.[1];
    if (constraint === null) {
      const escaped = dependency.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
      if (value !== '' || !new RegExp(`^  ${escaped}:\\n    sdk: flutter$`, 'm').test(section)) {
        fail(`CitizenSDK Hosted Package ${name} SDK 依赖漂移：${dependency}`);
      }
    } else if (value !== constraint) {
      fail(`CitizenSDK Hosted Package ${name} 依赖约束漂移：${dependency}`);
    }
  }
}

export function assertHostedPackageSource(root) {
  const sourceRoot = resolve(root);
  assertPinnedFiles(sourceRoot, HOSTED_PACKAGE_SOURCE_FILES, 'Hosted Package 合同');
  assertHostedRuntimeDartProjection(sourceRoot);
  const pubspecPath = join(sourceRoot, 'pubspec.yaml');
  if (!existsSync(pubspecPath)
      || lstatSync(pubspecPath).isSymbolicLink()
      || !lstatSync(pubspecPath).isFile()) {
    fail('CitizenSDK 缺少普通 Hosted Package pubspec.yaml');
  }
  const pubspec = readFileSync(pubspecPath, 'utf8');
  const pubspecVersion = pubspec.match(/^version: (\d+\.\d{1,2}\.\d{1,2})$/m)?.[1];
  if (!/^name: citizen_sdk$/m.test(pubspec) || !pubspecVersion) {
    fail('CitizenSDK Hosted Package 身份或版本无效');
  }
  if (/^publish_to:\s*["']?none["']?\s*$/m.test(pubspec)) {
    fail('CitizenSDK Hosted Package 禁止 publish_to: none');
  }
  // 两格缩进的 `path` 可以是合法 Hosted 依赖包名；只有依赖声明内部四格以上的
  // `path:`/`git:` 才表示 pub.dev 禁止的非 Hosted 来源。
  if (/^[ \t]{4,}(?:git|path):/m.test(pubspec)) {
    fail('CitizenSDK Hosted Package 禁止 git/path 依赖');
  }
  assertHostedDependencySection(pubspec, 'dependencies', HOSTED_MAIN_DEPENDENCIES);
  assertHostedDependencySection(pubspec, 'dev_dependencies', HOSTED_DEV_DEPENDENCIES);
  const platformVersions = [
    ['android/build.gradle', /^version = '(\d+\.\d{1,2}\.\d{1,2})'$/m],
    ['darwin/citizen_sdk.podspec', /^  spec\.version\s+= '(\d+\.\d{1,2}\.\d{1,2})'$/m],
    ['linux/CMakeLists.txt', /^project\(CitizenSDKHost VERSION (\d+\.\d{1,2}\.\d{1,2}) LANGUAGES C CXX\)$/m],
  ].map(([relativePath, pattern]) => {
    const path = join(sourceRoot, ...relativePath.split('/'));
    if (!existsSync(path) || lstatSync(path).isSymbolicLink() || !lstatSync(path).isFile()) {
      fail(`CitizenSDK 缺少普通平台版本文件：${relativePath}`);
    }
    const version = readFileSync(path, 'utf8').match(pattern)?.[1];
    if (!version) fail(`CitizenSDK 平台版本字段无效：${relativePath}`);
    return [relativePath, version];
  });
  for (const [relativePath, version] of platformVersions) {
    if (version !== pubspecVersion) {
      fail(`CitizenSDK 包版本不一致：pubspec.yaml=${pubspecVersion}；${relativePath}=${version}`);
    }
  }
  return pubspecVersion;
}

export function assertSdkTestContracts(root) {
  const sourceRoot = resolve(root);
  if (Object.keys(SDK_TEST_CONTRACT_FILES).length !== SDK_TEST_CONTRACT_FILE_COUNT) {
    fail(`CitizenSDK 测试合同固定清单必须精确为 ${SDK_TEST_CONTRACT_FILE_COUNT} 文件`);
  }
  for (const relativeRoot of SDK_TEST_CONTRACT_ROOTS) {
    const testRoot = join(sourceRoot, ...relativeRoot.split('/'));
    if (!existsSync(testRoot)
        || lstatSync(testRoot).isSymbolicLink()
        || !lstatSync(testRoot).isDirectory()) {
      fail(`CitizenSDK 缺少普通测试目录：${relativeRoot}`);
    }
    const actualPaths = regularFiles(testRoot)
      .map((path) => `${relativeRoot}/${path}`)
      .sort();
    const expectedPaths = Object.keys(SDK_TEST_CONTRACT_FILES)
      .filter((path) => path.startsWith(`${relativeRoot}/`))
      .sort();
    if (JSON.stringify(actualPaths) !== JSON.stringify(expectedPaths)) {
      const actual = new Set(actualPaths);
      const expected = new Set(expectedPaths);
      const missing = expectedPaths.filter((path) => !actual.has(path));
      const extra = actualPaths.filter((path) => !expected.has(path));
      fail(`CitizenSDK 测试文件闭集漂移：${relativeRoot}；缺失=${missing.join(',') || '无'}；额外=${extra.join(',') || '无'}`);
    }
  }
  for (const relativeRoot of SDK_EMBEDDED_TEST_ROOTS) {
    const testRoot = join(sourceRoot, ...relativeRoot.split('/'));
    const actualPaths = regularFiles(testRoot)
      .filter((path) => path.endsWith('_tests.rs'))
      .map((path) => `${relativeRoot}/${path}`)
      .sort();
    const expectedPaths = Object.keys(SDK_TEST_CONTRACT_FILES)
      .filter((path) => path.startsWith(`${relativeRoot}/`) && path.endsWith('_tests.rs'))
      .sort();
    if (JSON.stringify(actualPaths) !== JSON.stringify(expectedPaths)) {
      const actual = new Set(actualPaths);
      const expected = new Set(expectedPaths);
      const missing = expectedPaths.filter((path) => !actual.has(path));
      const extra = actualPaths.filter((path) => !expected.has(path));
      fail(`CitizenSDK 内嵌测试文件闭集漂移：${relativeRoot}；缺失=${missing.join(',') || '无'}；额外=${extra.join(',') || '无'}`);
    }
  }
  const scriptRoot = join(sourceRoot, SDK_SCRIPT_TEST_ROOT);
  if (!existsSync(scriptRoot)
      || lstatSync(scriptRoot).isSymbolicLink()
      || !lstatSync(scriptRoot).isDirectory()) {
    fail(`CitizenSDK 缺少普通测试目录：${SDK_SCRIPT_TEST_ROOT}`);
  }
  const actualScriptTests = regularFiles(scriptRoot)
    .map((path) => `${SDK_SCRIPT_TEST_ROOT}/${path}`)
    .filter((path) => path.endsWith('.test.mjs'))
    .sort();
  const expectedScriptTests = Object.keys(SDK_TEST_CONTRACT_FILES)
    .filter((path) => path.startsWith(`${SDK_SCRIPT_TEST_ROOT}/`) && path.endsWith('.test.mjs'))
    .sort();
  if (JSON.stringify(actualScriptTests) !== JSON.stringify(expectedScriptTests)) {
    const actual = new Set(actualScriptTests);
    const expected = new Set(expectedScriptTests);
    const missing = expectedScriptTests.filter((path) => !actual.has(path));
    const extra = actualScriptTests.filter((path) => !expected.has(path));
    fail(`CitizenSDK 测试文件闭集漂移：${SDK_SCRIPT_TEST_ROOT}；缺失=${missing.join(',') || '无'}；额外=${extra.join(',') || '无'}`);
  }
  assertPinnedFiles(sourceRoot, SDK_TEST_CONTRACT_FILES, '测试合同');
}

export function assertSdkScriptSource(root) {
  const sourceRoot = resolve(root);
  const scriptRoot = join(sourceRoot, 'scripts');
  if (!existsSync(scriptRoot)
      || lstatSync(scriptRoot).isSymbolicLink()
      || !lstatSync(scriptRoot).isDirectory()) {
    fail('CitizenSDK 缺少普通 scripts 目录');
  }
  const actualEntries = readdirSync(scriptRoot).sort();
  const expectedEntries = Object.keys(SDK_SCRIPT_ENTRIES).sort();
  if (JSON.stringify(actualEntries) !== JSON.stringify(expectedEntries)) {
    const actual = new Set(actualEntries);
    const expected = new Set(expectedEntries);
    const missing = expectedEntries.filter((path) => !actual.has(path));
    const extra = actualEntries.filter((path) => !expected.has(path));
    fail(`CitizenSDK scripts 根闭集漂移；缺失=${missing.join(',') || '无'}；额外=${extra.join(',') || '无'}`);
  }
  for (const name of expectedEntries) {
    const path = join(scriptRoot, name);
    if (lstatSync(path).isSymbolicLink() || !lstatSync(path).isFile()) {
      fail(`CitizenSDK scripts 条目必须是普通文件：${name}`);
    }
  }
  const executingRelease = readFileSync(fileURLToPath(import.meta.url));
  if (!readFileSync(join(scriptRoot, 'release.mjs')).equals(executingRelease)) {
    fail('CitizenSDK 候选 release.mjs 与当前执行真源不一致');
  }
  assertPinnedFiles(sourceRoot, SDK_PRODUCTION_SCRIPT_FILES, '生产脚本');
}

export function assertSmoldotRustSource(root) {
  const sourceRoot = resolve(root);
  const manifestPath = join(
    sourceRoot,
    ...SMOLDOT_RUST_SOURCE_MANIFEST.path.split('/'),
  );
  if (!existsSync(manifestPath)
      || lstatSync(manifestPath).isSymbolicLink()
      || !lstatSync(manifestPath).isFile()) {
    fail('CitizenSDK 缺少普通 smoldot Rust 来源清单');
  }
  if (sha256File(manifestPath) !== SMOLDOT_RUST_SOURCE_MANIFEST.sha256) {
    fail('CitizenSDK smoldot Rust 来源清单漂移');
  }

  const manifest = JSON.parse(readFileSync(manifestPath, 'utf8'));
  if (manifest.schema !== 'citizensdk.smoldot.source-sha256.v1'
      || !manifest.units || typeof manifest.units !== 'object') {
    fail('CitizenSDK smoldot Rust 来源清单 schema 无效');
  }
  const providerUnit = manifest.units.provider;
  if (!providerUnit || providerUnit.root !== 'native/smoldot/provider'
      || providerUnit.recursive !== true) {
    fail('CitizenSDK smoldot Rust 来源清单缺少递归 provider 单元');
  }
  const manifestPaths = [];
  for (const [name, unit] of Object.entries(manifest.units)) {
    if (!unit || typeof unit !== 'object' || typeof unit.root !== 'string'
        || !unit.root.startsWith('native/smoldot/')
        || typeof unit.recursive !== 'boolean') {
      fail(`CitizenSDK smoldot Rust 来源单元无效：${name}`);
    }
    const unitRoot = join(sourceRoot, ...unit.root.split('/'));
    if (!existsSync(unitRoot)
        || lstatSync(unitRoot).isSymbolicLink()
        || !lstatSync(unitRoot).isDirectory()) {
      fail(`CitizenSDK smoldot Rust 来源目录缺失：${unit.root}`);
    }
    const entries = ['byte_identical', 'adapted', 'sdk_only']
      .flatMap((category) => {
        if (!Array.isArray(unit[category])) {
          fail(`CitizenSDK smoldot Rust 来源分类无效：${name}/${category}`);
        }
        return unit[category];
      });
    const expectedPaths = entries.map((entry) => entry?.path).sort();
    if (entries.some((entry) => !entry
          || typeof entry.path !== 'string'
          || !/^[A-Za-z0-9._/-]+$/.test(entry.path)
          || entry.path.split('/').includes('..')
          || !/^[0-9a-f]{64}$/.test(entry.sha256))
        || new Set(expectedPaths).size !== expectedPaths.length) {
      fail(`CitizenSDK smoldot Rust 来源条目无效：${name}`);
    }
    const actualPaths = unit.recursive
      ? regularFiles(unitRoot)
      : readdirSync(unitRoot).filter((path) => {
          const absolute = join(unitRoot, path);
          return !lstatSync(absolute).isSymbolicLink() && lstatSync(absolute).isFile();
        }).sort();
    if (JSON.stringify(actualPaths) !== JSON.stringify(expectedPaths)) {
      fail(`CitizenSDK smoldot Rust 文件闭集漂移：${name}`);
    }
    for (const entry of entries) {
      const absolutePath = join(unitRoot, ...entry.path.split('/'));
      if (sha256File(absolutePath) !== entry.sha256) {
        fail(`CitizenSDK smoldot Rust 文件哈希漂移：${name}/${entry.path}`);
      }
      manifestPaths.push(`${unit.root}/${entry.path}`);
    }
    if (!Array.isArray(unit.excluded)) {
      fail(`CitizenSDK smoldot Rust 排除集合无效：${name}`);
    }
    for (const relativePath of unit.excluded) {
      if (typeof relativePath !== 'string'
          || relativePath.split('/').includes('..')
          || existsSync(join(unitRoot, ...relativePath.split('/')))) {
        fail(`CitizenSDK smoldot Rust 排除项漂移：${name}/${relativePath}`);
      }
    }
  }

  for (const [relativePath, expectedHash] of Object.entries(SMOLDOT_SUPPORT_FILES)) {
    const path = join(sourceRoot, ...relativePath.split('/'));
    if (!existsSync(path) || lstatSync(path).isSymbolicLink() || !lstatSync(path).isFile()) {
      fail(`CitizenSDK 缺少普通 smoldot 支持文件：${relativePath}`);
    }
    if (sha256File(path) !== expectedHash) {
      fail(`CitizenSDK smoldot 支持文件哈希漂移：${relativePath}`);
    }
  }

  const smoldotRoot = join(sourceRoot, 'native', 'smoldot');
  const actualClosure = regularFiles(smoldotRoot)
    .map((path) => `native/smoldot/${path}`)
    .sort();
  const expectedClosure = [
    SMOLDOT_RUST_SOURCE_MANIFEST.path,
    ...manifestPaths,
    ...Object.keys(SMOLDOT_SUPPORT_FILES),
  ].sort();
  if (new Set(expectedClosure).size !== expectedClosure.length) {
    fail('CitizenSDK smoldot 来源合同存在重复路径');
  }
  if (JSON.stringify(actualClosure) !== JSON.stringify(expectedClosure)) {
    const actual = new Set(actualClosure);
    const expected = new Set(expectedClosure);
    const missing = expectedClosure.filter((path) => !actual.has(path));
    const extra = actualClosure.filter((path) => !expected.has(path));
    fail(`CitizenSDK smoldot 文件闭集漂移；缺失=${missing.join(',') || '无'}；额外=${extra.join(',') || '无'}`);
  }
}

export function assertSignerSource(root) {
  const sourceRoot = resolve(root);
  for (const [relativePath, expectedHash] of Object.entries(SIGNER_FILES)) {
    const path = join(sourceRoot, ...relativePath.split('/'));
    if (!existsSync(path) || !lstatSync(path).isFile() || lstatSync(path).isSymbolicLink()) {
      fail(`CitizenSDK 缺少普通 signer 源文件：${relativePath}`);
    }
    if (sha256File(path) !== expectedHash) {
      fail(`CitizenSDK signer 来源字节漂移：${relativePath}`);
    }
  }
  const signerRoot = join(sourceRoot, 'native', 'signer');
  const actualClosure = regularFiles(signerRoot)
    .map((path) => `native/signer/${path}`)
    .sort();
  const expectedClosure = Object.keys(SIGNER_FILES).sort();
  if (JSON.stringify(actualClosure) !== JSON.stringify(expectedClosure)) {
    const actual = new Set(actualClosure);
    const expected = new Set(expectedClosure);
    const missing = expectedClosure.filter((path) => !actual.has(path));
    const extra = actualClosure.filter((path) => !expected.has(path));
    fail(`CitizenSDK signer 10 文件闭集漂移；缺失=${missing.join(',') || '无'}；额外=${extra.join(',') || '无'}`);
  }
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
  replaceExact(join(output, 'darwin/citizen_sdk.podspec'), /^  spec\.version\s+= '\d+\.\d{1,2}\.\d{1,2}'$/gm, `  spec.version          = '${version}'`, 'citizen_sdk.podspec');
  replaceExact(join(output, 'linux/CMakeLists.txt'), /^project\(CitizenSDKHost VERSION \d+\.\d{1,2}\.\d{1,2} LANGUAGES C CXX\)$/gm, `project(CitizenSDKHost VERSION ${version} LANGUAGES C CXX)`, 'linux/CMakeLists.txt');
}

function nativeArtifactSource(nativeRoot, sourcePath, expectedType = 'file') {
  const components = sourcePath.split('/');
  let current = nativeRoot;
  for (let index = 0; index < components.length; index += 1) {
    current = join(current, components[index]);
    let info;
    try {
      info = lstatSync(current);
    } catch (error) {
      if (error?.code === 'ENOENT') fail(`缺少原生产物：${sourcePath}`);
      throw error;
    }
    if (info.isSymbolicLink()) {
      fail(`原生产物路径禁止符号链接：${sourcePath}`);
    }
    const isFinal = index === components.length - 1;
    const finalTypeMatches = expectedType === 'file' ? info.isFile() : info.isDirectory();
    if ((!isFinal && !info.isDirectory()) || (isFinal && !finalTypeMatches)) {
      fail(`原生产物路径类型无效：${sourcePath}`);
    }
  }
  const realSource = realpathSync(current);
  if (!realSource.startsWith(`${nativeRoot}${sep}`)) {
    fail(`原生产物真实路径越出受控根：${sourcePath}`);
  }
  return current;
}

/**
 * Reject every native-input link except the five exact versioned-macOS
 * framework links. The XCFramework directory itself and all ancestors remain
 * ordinary directories, so an allowed internal link cannot redirect the
 * native source root.
 */
export function assertNativeArtifactSources(nativeRoot) {
  const root = assertSafeTargetPath(nativeRoot, '原生产物目录');
  if (!existsSync(root) || lstatSync(root).isSymbolicLink() || !lstatSync(root).isDirectory()) {
    fail('CitizenSDK 原生产物目录不存在或不是普通目录');
  }
  if (realpathSync(root) !== root) fail('CitizenSDK 原生产物目录真实路径漂移');
  const files = Object.fromEntries(
    Object.entries(NATIVE_FILES).map(([destinationPath, sourcePath]) => [
      destinationPath,
      nativeArtifactSource(root, sourcePath),
    ]),
  );
  const directories = Object.fromEntries(
    Object.entries(NATIVE_DIRECTORIES).map(([destinationPath, sourcePath]) => {
      const source = nativeArtifactSource(root, sourcePath, 'directory');
      // 这里只承认标准 macOS framework 的五个精确内部链接；遍历不会跟随
      // 链接，并会拒绝 iOS slice 或其它位置出现的任何链接。
      const entries = treeEntries(source, appleXcframeworkSymlinkContract(source));
      if (entries.files.length === 0) fail(`原生产物目录为空：${sourcePath}`);
      return [destinationPath, source];
    }),
  );
  return { directories, files };
}

function copyNativeFiles(nativeRoot, output) {
  const sources = assertNativeArtifactSources(nativeRoot);
  for (const [destinationPath, source] of Object.entries(sources.files)) {
    const destination = join(output, ...destinationPath.split('/'));
    mkdirSync(dirname(destination), { recursive: true, mode: 0o700 });
    copyFileSync(source, destination);
  }
  for (const [destinationPath, source] of Object.entries(sources.directories)) {
    const destinationRoot = join(output, ...destinationPath.split('/'));
    if (existsSync(destinationRoot)) fail(`原生产物目录目标已存在：${destinationPath}`);
    mkdirSync(destinationRoot, { recursive: true, mode: 0o700 });
    const symlinkContract = appleXcframeworkSymlinkContract(source);
    const entries = treeEntries(source, symlinkContract);
    for (const relativePath of entries.files) {
      const destination = join(destinationRoot, ...relativePath.split('/'));
      mkdirSync(dirname(destination), { recursive: true, mode: 0o700 });
      copyFileSync(join(source, ...relativePath.split('/')), destination);
    }
    // 不复制任意来源链接；只按已验证的文字合同重建五个相对链接。
    for (const relativePath of entries.symlinks) {
      const destination = join(destinationRoot, ...relativePath.split('/'));
      mkdirSync(dirname(destination), { recursive: true, mode: 0o700 });
      symlinkSync(
        symlinkContract[relativePath],
        destination,
      );
    }
  }
}

function zipEntries(bytes, label) {
  const minimumEocd = 22;
  const maximumComment = 0xffff;
  let eocd = -1;
  for (let offset = bytes.length - minimumEocd;
    offset >= Math.max(0, bytes.length - minimumEocd - maximumComment);
    offset -= 1) {
    if (bytes.readUInt32LE(offset) === 0x06054b50) {
      eocd = offset;
      break;
    }
  }
  if (eocd < 0) fail(`${label} 不是普通 ZIP`);
  const disk = bytes.readUInt16LE(eocd + 4);
  const centralDisk = bytes.readUInt16LE(eocd + 6);
  const diskEntries = bytes.readUInt16LE(eocd + 8);
  const entryCount = bytes.readUInt16LE(eocd + 10);
  const centralSize = bytes.readUInt32LE(eocd + 12);
  const centralOffset = bytes.readUInt32LE(eocd + 16);
  const commentLength = bytes.readUInt16LE(eocd + 20);
  if (disk !== 0 || centralDisk !== 0 || diskEntries !== entryCount
      || entryCount === 0 || entryCount === 0xffff
      || centralSize === 0xffffffff || centralOffset === 0xffffffff
      || entryCount > 10000 || eocd + minimumEocd + commentLength !== bytes.length
      || centralOffset + centralSize !== eocd) {
    fail(`${label} ZIP 中央目录无效或使用了不支持的 ZIP64/分卷格式`);
  }

  const entries = new Map();
  let cursor = centralOffset;
  for (let index = 0; index < entryCount; index += 1) {
    if (cursor + 46 > eocd || bytes.readUInt32LE(cursor) !== 0x02014b50) {
      fail(`${label} ZIP 中央目录条目无效`);
    }
    const flags = bytes.readUInt16LE(cursor + 8);
    const method = bytes.readUInt16LE(cursor + 10);
    const compressedSize = bytes.readUInt32LE(cursor + 20);
    const uncompressedSize = bytes.readUInt32LE(cursor + 24);
    const nameLength = bytes.readUInt16LE(cursor + 28);
    const extraLength = bytes.readUInt16LE(cursor + 30);
    const entryCommentLength = bytes.readUInt16LE(cursor + 32);
    const localOffset = bytes.readUInt32LE(cursor + 42);
    const next = cursor + 46 + nameLength + extraLength + entryCommentLength;
    if (next > eocd || nameLength === 0 || (flags & 0x1) !== 0
        || ![0, 8].includes(method) || compressedSize === 0xffffffff
        || uncompressedSize === 0xffffffff || localOffset === 0xffffffff) {
      fail(`${label} ZIP 条目属性无效`);
    }
    const nameBytes = bytes.subarray(cursor + 46, cursor + 46 + nameLength);
    const name = nameBytes.toString('utf8');
    if (!Buffer.from(name, 'utf8').equals(nameBytes)
        || name.includes('\0') || name.includes('\\') || name.startsWith('/')
        || name.split('/').includes('..') || entries.has(name)) {
      fail(`${label} ZIP 条目路径无效或重复`);
    }
    if (localOffset + 30 > centralOffset || bytes.readUInt32LE(localOffset) !== 0x04034b50) {
      fail(`${label} ZIP local header 无效`);
    }
    const localFlags = bytes.readUInt16LE(localOffset + 6);
    const localMethod = bytes.readUInt16LE(localOffset + 8);
    const localNameLength = bytes.readUInt16LE(localOffset + 26);
    const localExtraLength = bytes.readUInt16LE(localOffset + 28);
    const localNameStart = localOffset + 30;
    const dataStart = localNameStart + localNameLength + localExtraLength;
    const dataEnd = dataStart + compressedSize;
    if (localFlags !== flags || localMethod !== method || dataEnd > centralOffset
        || !bytes.subarray(localNameStart, localNameStart + localNameLength).equals(nameBytes)) {
      fail(`${label} ZIP local/central 条目不一致`);
    }
    const compressed = bytes.subarray(dataStart, dataEnd);
    let content;
    try {
      content = method === 0 ? Buffer.from(compressed) : inflateRawSync(compressed);
    } catch {
      fail(`${label} ZIP 条目无法解压：${name}`);
    }
    if (content.length !== uncompressedSize) {
      fail(`${label} ZIP 条目长度不一致：${name}`);
    }
    entries.set(name, content);
    cursor = next;
  }
  if (cursor !== eocd) fail(`${label} ZIP 中央目录包含未解析字节`);
  return entries;
}

/** Verify the Android AAR and Flutter projection are the same two native bytes. */
export function assertAndroidReleaseProjection(root) {
  const candidate = resolve(root);
  const aarPath = join(candidate, 'android', 'citizensdk.aar');
  const corePath = join(
    candidate,
    'android',
    'src',
    'main',
    'jniLibs',
    'arm64-v8a',
    'libcitizensdk.so',
  );
  const jniPath = join(
    candidate,
    'android',
    'src',
    'main',
    'jniLibs',
    'arm64-v8a',
    'libcitizensdk_jni.so',
  );
  for (const [path, label] of [
    [aarPath, 'Android AAR'],
    [corePath, 'Flutter Android Core 库'],
    [jniPath, 'Flutter Android JNI 库'],
  ]) {
    if (!existsSync(path) || lstatSync(path).isSymbolicLink() || !lstatSync(path).isFile()) {
      fail(`CitizenSDK 候选缺少普通${label}`);
    }
  }

  const aarEntries = zipEntries(readFileSync(aarPath), 'CitizenSDK Android AAR');
  const nativeEntries = [...aarEntries.keys()]
    .filter((path) => path.startsWith('jni/') && !path.endsWith('/'))
    .sort();
  const expectedNativeEntries = [
    'jni/arm64-v8a/libcitizensdk.so',
    'jni/arm64-v8a/libcitizensdk_jni.so',
  ];
  if (JSON.stringify(nativeEntries) !== JSON.stringify(expectedNativeEntries)) {
    fail(`CitizenSDK Android AAR 双库闭集漂移：${nativeEntries.join(',') || '无'}`);
  }
  for (const required of ['AndroidManifest.xml', 'classes.jar']) {
    if (!aarEntries.has(required)) fail(`CitizenSDK Android AAR 缺少 ${required}`);
  }
  const packagedAssets = [...aarEntries.keys()]
    .filter((path) => path.startsWith('assets/') && !path.endsWith('/'))
    .sort();
  const expectedAssets = Object.keys(CHAIN_ASSET_FILES).sort();
  if (JSON.stringify(packagedAssets) !== JSON.stringify(expectedAssets)) {
    fail(`CitizenSDK Android AAR 链资产闭集漂移：${packagedAssets.join(',') || '无'}`);
  }
  for (const required of expectedAssets) {
    if (!aarEntries.get(required).equals(
      readFileSync(join(candidate, ...required.split('/')),
    ))) {
      fail(`CitizenSDK Android AAR 链资产与候选信任锚字节不一致：${required}`);
    }
  }
  if ([...aarEntries.keys()].some((path) => path.endsWith('.aar')
      || /(?:^|\/)(?:libsmoldot|libc\+\+_shared)\.so$/.test(path))) {
    fail('CitizenSDK Android AAR 混入嵌套 AAR、legacy 或共享 C++ 运行库');
  }
  if (!aarEntries.get(expectedNativeEntries[0]).equals(readFileSync(corePath))
      || !aarEntries.get(expectedNativeEntries[1]).equals(readFileSync(jniPath))) {
    fail('CitizenSDK Android AAR 与 Flutter 投影的双原生库字节不一致');
  }

  const classEntries = zipEntries(aarEntries.get('classes.jar'), 'CitizenSDK Android classes.jar');
  for (const required of [
    'org/citizen/sdk/CitizenSdk.class',
    'org/citizen/sdk/CitizenSdkLifecycle.class',
    'org/citizen/sdk/CitizenSdkException.class',
    'org/citizen/sdk/CitizenSdkEvents.class',
    'org/citizen/sdk/CitizenWalletProfile.class',
    'org/citizen/sdk/CitizenSdkOperation.class',
    'org/citizen/sdk/internal/CitizenSdkNative.class',
    'org/citizen/sdk/internal/CitizenSdkHardwareVault.class',
    'org/citizen/sdk/internal/CitizenSdkHostServices.class',
    'org/citizen/sdk/internal/CitizenSdkRequestRouter.class',
    'org/citizen/sdk/ui/CitizenSdkWalletFlowActivity.class',
    'org/citizen/sdk/ui/CitizenSdkWalletFlowContract.class',
    'org/citizen/sdk/ui/CitizenSdkWalletFlowCoordinator.class',
  ]) {
    if (!classEntries.has(required)) {
      fail(`CitizenSDK Android classes.jar 缺少必需实现：${required}`);
    }
  }
  for (const [path, content] of classEntries) {
    if (path.startsWith('io/flutter/') || content.includes(Buffer.from('io/flutter/'))) {
      fail('CitizenSDK Android 原生 AAR 混入或引用 Flutter API');
    }
  }
  const aarFiles = regularFiles(join(candidate, 'android'))
    .filter((path) => path.endsWith('.aar'))
    .sort();
  if (JSON.stringify(aarFiles) !== JSON.stringify(['citizensdk.aar'])) {
    fail(`CitizenSDK Android 候选 AAR 闭集漂移：${aarFiles.join(',') || '无'}`);
  }
}

function decodePlistXmlText(value, label) {
  return value.replace(/&(?:#(x[0-9a-fA-F]+|[0-9]+)|amp|apos|gt|lt|quot);/g, (entity, number) => {
    if (number !== undefined) {
      const radix = number.startsWith('x') ? 16 : 10;
      const digits = number.startsWith('x') ? number.slice(1) : number;
      const codePoint = Number.parseInt(digits, radix);
      if (!Number.isSafeInteger(codePoint) || codePoint > 0x10ffff) {
        fail(`${label} plist 含无效字符实体`);
      }
      return String.fromCodePoint(codePoint);
    }
    return {
      '&amp;': '&',
      '&apos;': "'",
      '&gt;': '>',
      '&lt;': '<',
      '&quot;': '"',
    }[entity];
  });
}

/** Parse the small XML-plist subset emitted for framework metadata. */
function parseXmlPlist(bytes, label) {
  let source = bytes.toString('utf8');
  source = source
    .replace(/^\uFEFF/, '')
    .replace(/<\?xml[\s\S]*?\?>/g, '')
    .replace(/<!DOCTYPE[\s\S]*?>/g, '')
    .replace(/<!--[\s\S]*?-->/g, '')
    .trim();
  const tokens = [...source.matchAll(/<[^>]+>|[^<]+/g)]
    .map((match) => match[0])
    .filter((token) => token.startsWith('<') || token.trim().length > 0);
  let cursor = 0;
  const take = () => tokens[cursor++];
  const expect = (expected) => {
    const actual = take();
    if (actual !== expected) fail(`${label} plist 结构无效；期望=${expected}；实际=${actual ?? '<eof>'}`);
  };
  const parseValue = () => {
    const token = take();
    if (token === '<dict>') {
      const value = Object.create(null);
      while (tokens[cursor] !== '</dict>') {
        expect('<key>');
        const keyText = take();
        if (!keyText || keyText.startsWith('<')) fail(`${label} plist key 无效`);
        expect('</key>');
        const key = decodePlistXmlText(keyText.trim(), label);
        if (Object.hasOwn(value, key)) fail(`${label} plist key 重复：${key}`);
        value[key] = parseValue();
      }
      cursor += 1;
      return value;
    }
    if (token === '<array>') {
      const value = [];
      while (tokens[cursor] !== '</array>') value.push(parseValue());
      cursor += 1;
      return value;
    }
    if (token === '<true/>') return true;
    if (token === '<false/>') return false;
    const scalar = token?.match(/^<(string|integer)>$/)?.[1];
    if (!scalar) fail(`${label} plist 含不支持的值：${token ?? '<eof>'}`);
    const text = take();
    if (text === `</${scalar}>`) return scalar === 'integer' ? 0 : '';
    if (!text || text.startsWith('<')) fail(`${label} plist 标量无效`);
    expect(`</${scalar}>`);
    const decoded = decodePlistXmlText(text.trim(), label);
    if (scalar === 'string') return decoded;
    if (!/^-?(?:0|[1-9][0-9]*)$/.test(decoded)) fail(`${label} plist integer 无效`);
    const integer = Number(decoded);
    if (!Number.isSafeInteger(integer)) fail(`${label} plist integer 超界`);
    return integer;
  };
  if (!/^<plist(?: version="1\.0")?>$/.test(tokens[cursor] ?? '')) {
    fail(`${label} 不是 XML plist 1.0`);
  }
  cursor += 1;
  const value = parseValue();
  expect('</plist>');
  if (cursor !== tokens.length) fail(`${label} plist 含尾随内容`);
  return value;
}

function encodedMachOVersion(value) {
  return `${value >>> 16}.${(value >>> 8) & 0xff}.${value & 0xff}`;
}

function machOCString(bytes, start, end, label) {
  const zero = bytes.indexOf(0, start);
  if (start < 0 || start >= end || zero < start || zero >= end) {
    fail(`${label} Mach-O 字符串越界或未终止`);
  }
  return bytes.subarray(start, zero).toString('utf8');
}

/** Read the thin arm64 Mach-O identity and external defined symbol table. */
function readAppleMachO(bytes, label) {
  if (bytes.length < 32 || bytes.readUInt32LE(0) !== 0xfeedfacf) {
    fail(`${label} 必须是 thin 64-bit Mach-O`);
  }
  const cpuType = bytes.readUInt32LE(4);
  const fileType = bytes.readUInt32LE(12);
  const commandCount = bytes.readUInt32LE(16);
  const commandBytes = bytes.readUInt32LE(20);
  if (cpuType !== 0x0100000c || fileType !== 6
      || commandCount === 0 || commandCount > 4096
      || commandBytes > bytes.length - 32) {
    fail(`${label} 必须是单一 arm64 动态 framework 二进制`);
  }
  let cursor = 32;
  const commandEnd = cursor + commandBytes;
  let identity = null;
  let build = null;
  let symbolTable = null;
  for (let index = 0; index < commandCount; index += 1) {
    if (cursor + 8 > commandEnd) fail(`${label} Mach-O load command 截断`);
    const command = bytes.readUInt32LE(cursor);
    const size = bytes.readUInt32LE(cursor + 4);
    if (size < 8 || cursor + size > commandEnd) fail(`${label} Mach-O load command 越界`);
    if (command === 0x0d) {
      if (identity !== null || size < 24) fail(`${label} LC_ID_DYLIB 无效或重复`);
      const nameOffset = bytes.readUInt32LE(cursor + 8);
      identity = machOCString(bytes, cursor + nameOffset, cursor + size, label);
    } else if (command === 0x32) {
      if (build !== null || size < 24) fail(`${label} LC_BUILD_VERSION 无效或重复`);
      build = {
        platform: bytes.readUInt32LE(cursor + 8),
        minimum: encodedMachOVersion(bytes.readUInt32LE(cursor + 12)),
      };
    } else if (command === 0x02) {
      if (symbolTable !== null || size < 24) fail(`${label} LC_SYMTAB 无效或重复`);
      symbolTable = {
        symbolOffset: bytes.readUInt32LE(cursor + 8),
        symbolCount: bytes.readUInt32LE(cursor + 12),
        stringOffset: bytes.readUInt32LE(cursor + 16),
        stringSize: bytes.readUInt32LE(cursor + 20),
      };
    }
    cursor += size;
  }
  if (cursor !== commandEnd || identity === null || build === null || symbolTable === null) {
    fail(`${label} 缺少唯一 install name、build version 或 symbol table`);
  }
  const symbolsEnd = symbolTable.symbolOffset + symbolTable.symbolCount * 16;
  const stringsEnd = symbolTable.stringOffset + symbolTable.stringSize;
  if (symbolTable.symbolCount > 1000000 || symbolsEnd > bytes.length
      || symbolTable.stringSize === 0 || stringsEnd > bytes.length) {
    fail(`${label} Mach-O symbol table 越界`);
  }
  const symbols = new Set();
  for (let index = 0; index < symbolTable.symbolCount; index += 1) {
    const offset = symbolTable.symbolOffset + index * 16;
    const stringIndex = bytes.readUInt32LE(offset);
    const type = bytes[offset + 4];
    const isDebug = (type & 0xe0) !== 0;
    const isPrivateExternal = (type & 0x10) !== 0;
    const isExternal = (type & 0x01) !== 0;
    const isUndefined = (type & 0x0e) === 0;
    // ld64 keeps hidden symbols as N_PEXT in the ordinary symbol table. They
    // remain usable inside the image but are not part of the dynamic product
    // boundary, so only public external defined symbols belong in this set.
    if (isDebug || isPrivateExternal || !isExternal || isUndefined) continue;
    if (stringIndex === 0 || stringIndex >= symbolTable.stringSize) {
      fail(`${label} Mach-O symbol string index 越界`);
    }
    const name = machOCString(
      bytes,
      symbolTable.stringOffset + stringIndex,
      stringsEnd,
      label,
    );
    symbols.add(name.startsWith('_') ? name.slice(1) : name);
  }
  return { build, identity, symbols };
}

function expectedCitizenSdkSymbols(root) {
  const header = readFileSync(join(root, 'include', 'citizensdk.h'), 'utf8');
  const symbols = [...new Set(
    [...header.matchAll(/\b(citizensdk_[a-z0-9_]+)\s*\(/g)].map((match) => match[1]),
  )].sort();
  if (symbols.length !== 70) fail('CitizenSDK 产品头必须精确声明 70 个 citizensdk_* 函数');
  return symbols;
}

function assertAppleFrameworkSlice(candidate, xcframework, identifier, contract) {
  const label = contract.label;
  const sliceRoot = join(xcframework, identifier);
  const framework = join(sliceRoot, 'CitizenSDK.framework');
  if (!existsSync(sliceRoot) || lstatSync(sliceRoot).isSymbolicLink()
      || !lstatSync(sliceRoot).isDirectory()
      || JSON.stringify(readdirSync(sliceRoot).sort())
        !== JSON.stringify(['CitizenSDK.framework'])) {
    fail(`${label} slice 根闭集漂移`);
  }
  if (!existsSync(framework) || lstatSync(framework).isSymbolicLink()
      || !lstatSync(framework).isDirectory()) {
    fail(`${label} framework 缺失或不是普通目录`);
  }
  const isMacOS = contract.supportedPlatform === 'macos';
  // 单 slice 校验也必须独立关闭链接边界，不能依赖外层调用顺序。
  treeEntries(
    framework,
    isMacOS ? APPLE_MACOS_FRAMEWORK_SYMLINKS : Object.freeze({}),
  );
  const expectedTopEntries = isMacOS
    ? ['CitizenSDK', 'Headers', 'Modules', 'Resources', 'Versions']
    : ['CitizenSDK', 'Headers', 'Info.plist', 'Modules', 'Resources'];
  const topEntries = readdirSync(framework).sort();
  if (JSON.stringify(topEntries) !== JSON.stringify(expectedTopEntries)) {
    fail(`${label} framework 根闭集漂移`);
  }
  const contentRoot = isMacOS ? join(framework, 'Versions', 'A') : framework;
  if (isMacOS) {
    const versionEntries = readdirSync(join(framework, 'Versions')).sort();
    const contentEntries = readdirSync(contentRoot).sort();
    if (JSON.stringify(versionEntries) !== JSON.stringify(['A', 'Current'])
        || JSON.stringify(contentEntries)
          !== JSON.stringify(['CitizenSDK', 'Headers', 'Modules', 'Resources'])) {
      fail(`${label} 版本化 framework 闭集漂移`);
    }
  }
  const binaryPath = join(contentRoot, 'CitizenSDK');
  if (!existsSync(binaryPath) || lstatSync(binaryPath).isSymbolicLink()
      || !lstatSync(binaryPath).isFile()) {
    fail(`${label} 二进制必须是普通文件`);
  }
  const binary = readAppleMachO(readFileSync(binaryPath), label);
  if (binary.identity !== contract.installName) {
    fail(`${label} install name 漂移`);
  }
  if (binary.build.platform !== contract.platform
      || binary.build.minimum !== contract.minimum) {
    fail(`${label} 平台或最低系统版本漂移`);
  }
  const expectedSymbols = expectedCitizenSdkSymbols(candidate);
  const allSymbols = [...binary.symbols].sort();
  const actualSymbols = allSymbols
    .filter((symbol) => symbol.startsWith('citizensdk_'))
    .sort();
  if (JSON.stringify(actualSymbols) !== JSON.stringify(expectedSymbols)) {
    fail(`${label} 必须精确导出 70 个 citizensdk_* 产品符号`);
  }
  const forbidden = [...binary.symbols]
    .filter((symbol) => /^(?:smoldot_|citizen_sr25519_|account_crypto_)/.test(symbol))
    .sort();
  if (forbidden.length > 0) fail(`${label} 泄漏 legacy 低层符号：${forbidden.join(',')}`);
  const swiftSymbols = allSymbols.filter((symbol) => symbol.startsWith('$s10CitizenSDK'));
  if (swiftSymbols.length === 0) fail(`${label} 缺少 CitizenSDK Swift 模块导出`);
  const foreign = allSymbols.filter(
    (symbol) => !symbol.startsWith('citizensdk_')
      && !symbol.startsWith('$s10CitizenSDK'),
  );
  if (foreign.length > 0) {
    fail(`${label} 泄漏非 CitizenSDK 产品符号：${foreign.join(',')}`);
  }

  const headersRoot = join(contentRoot, 'Headers');
  if (JSON.stringify(readdirSync(headersRoot).sort())
      !== JSON.stringify(['citizensdk.h', 'citizensdk_types.h'])) {
    fail(`${label} Headers 目录闭集漂移`);
  }
  const headerPaths = regularFiles(headersRoot);
  const expectedHeaders = ['citizensdk.h', 'citizensdk_types.h'];
  if (JSON.stringify(headerPaths) !== JSON.stringify(expectedHeaders)) {
    fail(`${label} 产品头闭集漂移`);
  }
  for (const header of expectedHeaders) {
    if (!readFileSync(join(headersRoot, header)).equals(
      readFileSync(join(candidate, 'include', header)),
    )) {
      fail(`${label} 产品头与根 ABI 字节不一致：${header}`);
    }
  }

  const modulesRoot = join(contentRoot, 'Modules');
  const moduleMapPath = join(modulesRoot, 'module.modulemap');
  const swiftModuleRoot = join(modulesRoot, 'CitizenSDK.swiftmodule');
  if (!existsSync(moduleMapPath) || lstatSync(moduleMapPath).isSymbolicLink()
      || !lstatSync(moduleMapPath).isFile()
      || !existsSync(swiftModuleRoot) || lstatSync(swiftModuleRoot).isSymbolicLink()
      || !lstatSync(swiftModuleRoot).isDirectory()) {
    fail(`${label} Clang/Swift module 不完整`);
  }
  if (JSON.stringify(readdirSync(modulesRoot).sort())
      !== JSON.stringify(['CitizenSDK.swiftmodule', 'module.modulemap'])) {
    fail(`${label} Modules 目录闭集漂移`);
  }
  const moduleMap = readFileSync(moduleMapPath, 'utf8');
  if (!moduleMap.includes('framework module CitizenSDK')
      || !moduleMap.includes('umbrella header "citizensdk.h"')
      || /(?:smoldot_|citizen_sr25519_|account_crypto_)/.test(moduleMap)) {
    fail(`${label} module.modulemap 边界无效`);
  }
  const swiftModules = regularFiles(swiftModuleRoot);
  if (readdirSync(swiftModuleRoot).some((path) => {
    const info = lstatSync(join(swiftModuleRoot, path));
    return info.isSymbolicLink() || !info.isFile();
  })) {
    fail(`${label} Swift module 只允许普通文件`);
  }
  const expectedSwiftModules = APPLE_SWIFT_MODULE_EXTENSIONS
    .map((extension) => `${contract.module}.${extension}`)
    .sort();
  if (JSON.stringify(swiftModules) !== JSON.stringify(expectedSwiftModules)) {
    fail(`${label} Swift module 六文件闭集或架构身份漂移`);
  }
  const publicInterface = readFileSync(
    join(swiftModuleRoot, `${contract.module}.swiftinterface`), 'utf8',
  );
  const privateInterface = readFileSync(
    join(swiftModuleRoot, `${contract.module}.private.swiftinterface`), 'utf8',
  );
  for (const [kind, swiftInterface] of [
    ['public', publicInterface],
    ['private', privateInterface],
  ]) {
    if (!/^\/\/ swift-interface-format-version:/m.test(swiftInterface)
        || !/^@_exported import CitizenSDK$/m.test(swiftInterface)) {
      fail(`${label} ${kind} Swift interface 未固定同名 underlying Clang module`);
    }
    const moduleFlags = swiftInterface.match(/^\/\/ swift-module-flags:.*$/gm) ?? [];
    if (moduleFlags.length !== 1
        || !new RegExp(`(?:^| )-target ${contract.swiftTarget.replaceAll('.', '\\.')}(?: |$)`)
          .test(moduleFlags[0])) {
      fail(`${label} ${kind} Swift interface target triple 漂移`);
    }
  }
  const expectedSpi = [
    '  @_spi(CitizenSDKFlutter) final public func supervisedClose() async throws',
    '  @_spi(CitizenSDKFlutter) final public func enqueueForSupervisedClose()',
  ];
  const publicSpi = publicInterface.split('\n').filter((line) => line.includes('@_spi('));
  const privateSpi = privateInterface.split('\n').filter((line) => line.includes('@_spi('));
  if (publicSpi.length !== 0
      || JSON.stringify(privateSpi) !== JSON.stringify(expectedSpi)
      || privateInterface.split('\n').filter((line) => !expectedSpi.includes(line)).join('\n')
        !== publicInterface) {
    fail(`${label} public/private Swift interface 或 CitizenSDKFlutter SPI 闭集漂移`);
  }
  if (/\b(?:CitizenSDKNative|CitizenSdkNativeResult|CitizenSDKPreparedWallet|CitizenSDKHandle|CitizenSDKSecretVault)\b/.test(publicInterface)) {
    fail(`${label} public Swift interface 泄漏底层 native/secret/handle 类型`);
  }

  const resourcesRoot = join(contentRoot, 'Resources');
  const expectedResourceEntries = [
    'PrivacyInfo.xcprivacy',
    'citizenchain',
    ...(isMacOS ? ['Info.plist'] : []),
  ].sort();
  if (JSON.stringify(readdirSync(resourcesRoot).sort())
      !== JSON.stringify(expectedResourceEntries)
      || JSON.stringify(readdirSync(join(resourcesRoot, 'citizenchain')).sort())
        !== JSON.stringify(['chainspec.json', 'light_sync_state.json', 'manifest.json'])) {
    fail(`${label} Resources 目录闭集漂移`);
  }
  const resources = regularFiles(resourcesRoot);
  const expectedResources = [
    ...Object.keys(APPLE_RESOURCE_FILES),
    ...(isMacOS ? ['Info.plist'] : []),
  ].sort();
  if (JSON.stringify(resources) !== JSON.stringify(expectedResources)) {
    fail(`${label} Resources 闭集漂移`);
  }
  for (const [resource, source] of Object.entries(APPLE_RESOURCE_FILES)) {
    if (!readFileSync(join(resourcesRoot, ...resource.split('/'))).equals(
      readFileSync(join(candidate, ...source.split('/'))),
    )) {
      fail(`${label} Resource 与唯一来源字节不一致：${resource}`);
    }
  }

  const frameworkInfo = parseXmlPlist(
    readFileSync(isMacOS
      ? join(resourcesRoot, 'Info.plist')
      : join(framework, 'Info.plist')),
    `${label} Info.plist`,
  );
  const sdkVersion = readFileSync(join(candidate, 'pubspec.yaml'), 'utf8')
    .match(/^version: (\d+\.\d{1,2}\.\d{1,2})$/m)?.[1];
  const expectedInfoKeys = [
    'CFBundleDevelopmentRegion',
    'CFBundleExecutable',
    'CFBundleIdentifier',
    'CFBundleInfoDictionaryVersion',
    'CFBundleName',
    'CFBundlePackageType',
    'CFBundleShortVersionString',
    'CFBundleSupportedPlatforms',
    'CFBundleVersion',
    'DTPlatformName',
    contract.minimumKey,
  ].sort();
  if (!sdkVersion
      || JSON.stringify(Object.keys(frameworkInfo).sort()) !== JSON.stringify(expectedInfoKeys)
      || frameworkInfo.CFBundleDevelopmentRegion !== 'en'
      || frameworkInfo.CFBundleExecutable !== 'CitizenSDK'
      || frameworkInfo.CFBundleIdentifier !== 'org.citizen.sdk'
      || frameworkInfo.CFBundleInfoDictionaryVersion !== '6.0'
      || frameworkInfo.CFBundleName !== 'CitizenSDK'
      || frameworkInfo.CFBundlePackageType !== 'FMWK'
      || frameworkInfo.CFBundleShortVersionString !== sdkVersion
      || frameworkInfo.CFBundleVersion !== sdkVersion
      || JSON.stringify(frameworkInfo.CFBundleSupportedPlatforms)
        !== JSON.stringify([contract.bundlePlatform])
      || frameworkInfo.DTPlatformName !== contract.dtPlatform
      || frameworkInfo[contract.minimumKey] !== contract.minimum.replace(/\.0$/, '')) {
    fail(`${label} framework Info.plist 身份漂移`);
  }
}

/** Verify one Apple product whose public platforms are exactly iOS and macOS. */
export function assertAppleReleaseProjection(root) {
  const candidate = resolve(root);
  const xcframework = join(candidate, ...APPLE_XCFRAMEWORK_PATH.split('/'));
  if (!existsSync(xcframework) || lstatSync(xcframework).isSymbolicLink()
      || !lstatSync(xcframework).isDirectory()) {
    fail('CitizenSDK 候选缺少普通 CitizenSDK.xcframework');
  }
  // 全树只允许 macOS framework 的标准五链接；这同时保证两个 iOS slice、
  // XCFramework Info.plist 和所有资源/模块均不存在链接旁路。
  treeEntries(xcframework, appleXcframeworkSymlinkContract(xcframework));
  const info = parseXmlPlist(
    readFileSync(join(xcframework, 'Info.plist')),
    'CitizenSDK.xcframework Info.plist',
  );
  if (JSON.stringify(Object.keys(info).sort()) !== JSON.stringify([
    'AvailableLibraries',
    'CFBundlePackageType',
    'XCFrameworkFormatVersion',
  ])
      || info.CFBundlePackageType !== 'XFWK'
      || info.XCFrameworkFormatVersion !== '1.0'
      || !Array.isArray(info.AvailableLibraries)
      || info.AvailableLibraries.length !== APPLE_SLICES.length) {
    fail('CitizenSDK.xcframework Info.plist 格式或 slice 数量无效');
  }
  const identifiers = new Set();
  const libraries = new Map();
  for (const library of info.AvailableLibraries) {
    if (!library || Array.isArray(library) || typeof library !== 'object'
        || typeof library.LibraryIdentifier !== 'string'
        || !/^[A-Za-z0-9][A-Za-z0-9._-]*$/.test(library.LibraryIdentifier)
        || identifiers.has(library.LibraryIdentifier)) {
      fail('CitizenSDK.xcframework LibraryIdentifier 无效或重复');
    }
    identifiers.add(library.LibraryIdentifier);
    const identity = `${library.SupportedPlatform}/${library.SupportedPlatformVariant ?? ''}`;
    if (libraries.has(identity)) fail(`CitizenSDK.xcframework 技术变体重复：${identity}`);
    libraries.set(identity, library);
  }
  const resolvedSlices = [];
  for (const contract of APPLE_SLICES) {
    const identity = `${contract.supportedPlatform}/${contract.variant ?? ''}`;
    const library = libraries.get(identity);
    const identifier = library?.LibraryIdentifier;
    if (!library
        || library.BinaryPath !== contract.binaryPath
        || library.LibraryPath !== 'CitizenSDK.framework'
        || JSON.stringify(library.SupportedArchitectures) !== JSON.stringify(['arm64'])
        || library.SupportedPlatform !== contract.supportedPlatform
        || (library.SupportedPlatformVariant ?? null) !== contract.variant) {
      fail(`${contract.label} XCFramework slice 元数据漂移`);
    }
    const expectedKeys = [
      'BinaryPath',
      'LibraryIdentifier',
      'LibraryPath',
      'SupportedArchitectures',
      'SupportedPlatform',
      ...(contract.variant === null ? [] : ['SupportedPlatformVariant']),
    ].sort();
    if (JSON.stringify(Object.keys(library).sort()) !== JSON.stringify(expectedKeys)) {
      fail(`${contract.label} XCFramework slice 字段闭集漂移`);
    }
    resolvedSlices.push({ contract, identifier });
  }
  const expectedEntries = [
    'Info.plist',
    ...resolvedSlices.map(({ identifier }) => identifier),
  ].sort();
  const entries = readdirSync(xcframework).sort();
  if (JSON.stringify(entries) !== JSON.stringify(expectedEntries)) {
    fail(`CitizenSDK.xcframework 三 slice 闭集漂移：${entries.join(',') || '无'}`);
  }
  for (const { contract, identifier } of resolvedSlices) {
    assertAppleFrameworkSlice(candidate, xcframework, identifier, contract);
  }
}

export function assertNoSecrets(root) {
  const forbiddenName = /(^|\/)(\.env(?:\.|$)|\.dev\.vars(?:\.|$)|.*\.(?:jks|keystore|p8|p12|pem))$/i;
  // 分段构造使扫描器源码本身不携带完整 PEM 标记，同时仍逐字节检查候选内容。
  const privateMaterial = Buffer.from(['PRIVATE', ' KEY-----'].join(''));
  for (const relativePath of releaseCandidateEntries(root).files) {
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

function writeUstarPath(header, relativePath) {
  if (Buffer.byteLength(relativePath) <= 100) {
    header.write(relativePath, 0, 100, 'utf8');
    return;
  }
  const separators = [...relativePath.matchAll(/\//g)].map((match) => match.index);
  for (let index = separators.length - 1; index >= 0; index -= 1) {
    const separator = separators[index];
    const prefix = relativePath.slice(0, separator);
    const name = relativePath.slice(separator + 1);
    if (Buffer.byteLength(prefix) <= 155 && Buffer.byteLength(name) <= 100) {
      header.write(name, 0, 100, 'utf8');
      header.write(prefix, 345, 155, 'utf8');
      return;
    }
  }
  fail(`CitizenSDK 归档路径超过 ustar 限制：${relativePath}`);
}

function deterministicTar(candidatePath, excludedPaths = new Set()) {
  const chunks = [];
  const candidateEntries = releaseCandidateEntries(candidatePath);
  const entries = [
    ...candidateEntries.files.map((path) => ({ path, type: 'file' })),
    ...candidateEntries.symlinks.map((path) => ({
      path,
      target: appleXcframeworkSymlinkContract(
        join(candidatePath, ...APPLE_XCFRAMEWORK_PATH.split('/')),
        APPLE_XCFRAMEWORK_PATH,
      )[path],
      type: 'symlink',
    })),
  ].sort((left, right) => left.path.localeCompare(right.path));
  for (const entry of entries) {
    const relativePath = entry.path;
    if (excludedPaths.has(relativePath)) continue;
    const path = join(candidatePath, ...relativePath.split('/'));
    const content = entry.type === 'file' ? readFileSync(path) : Buffer.alloc(0);
    const header = Buffer.alloc(512);
    writeUstarPath(header, relativePath);
    writeOctal(
      header,
      100,
      8,
      entry.type === 'symlink'
        ? 0o777
        : ((lstatSync(path).mode & 0o111) === 0 ? 0o600 : 0o700),
    );
    writeOctal(header, 108, 8, 0);
    writeOctal(header, 116, 8, 0);
    writeOctal(header, 124, 12, content.length);
    writeOctal(header, 136, 12, 0);
    header.fill(0x20, 148, 156);
    header[156] = (entry.type === 'symlink' ? '2' : '0').charCodeAt(0);
    if (entry.type === 'symlink') {
      if (Buffer.byteLength(entry.target) > 100) {
        fail(`CitizenSDK 归档链接目标超过 ustar 限制：${relativePath}`);
      }
      header.write(entry.target, 157, 100, 'utf8');
    }
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

function verifyCandidatePayload(candidatePath, expectedGitSha = null, expectExternalSums = false) {
  const candidate = assertSafeTargetPath(candidatePath, '候选目录');
  if (!existsSync(candidate) || lstatSync(candidate).isSymbolicLink() || !lstatSync(candidate).isDirectory()) {
    fail('CitizenSDK 候选目录不存在或不是普通目录');
  }
  const manifestPath = join(candidate, 'citizensdk-release.json');
  const sumsPath = join(candidate, 'SHA256SUMS');
  if (!existsSync(manifestPath) || (expectExternalSums && !existsSync(sumsPath))) {
    fail('CitizenSDK 候选缺少正式清单');
  }
  assertSmoldotDartSource(candidate);
  assertSmoldotLocks(candidate);
  assertSdkRootLocks(candidate);
  assertProviderLockParity(candidate);
  assertCoreRustSource(candidate);
  assertSmoldotRustSource(candidate);
  assertSignerSource(candidate);
  assertPublicAbiHeaders(candidate);
  assertMobileBindingSource(candidate, { allowAppleReleaseProjection: true });
  assertLinuxBindingSource(candidate);
  assertChainAssets(candidate);
  assertSourceFixtures(candidate);
  assertLicenseSources(candidate);
  assertDocumentationSource(candidate, { allowAppleReleaseProjection: true });
  const hostedSoftwareVersion = assertHostedPackageSource(candidate);
  assertSdkTestContracts(candidate);
  assertSdkScriptSource(candidate);
  assertAndroidReleaseProjection(candidate);
  assertAppleReleaseProjection(candidate);
  const manifest = JSON.parse(readFileSync(manifestPath, 'utf8'));
  const keys = Object.keys(manifest).sort();
  const expectedKeys = ['files', 'git_commit_sha', 'package_name', 'platforms', 'product_id', 'software_version'];
  if (JSON.stringify(keys) !== JSON.stringify(expectedKeys)) fail('CitizenSDK 正式清单字段集合不正确');
  if (manifest.product_id !== PRODUCT_ID || manifest.package_name !== PACKAGE_NAME) fail('CitizenSDK 候选产品身份不正确');
  if (!/^\d+\.\d{1,2}\.\d{1,2}$/.test(manifest.software_version)) fail('CitizenSDK 候选版本无效');
  if (manifest.software_version !== hostedSoftwareVersion) fail('CitizenSDK 候选 manifest 与包版本不一致');
  if (!/^[0-9a-f]{40}$/.test(manifest.git_commit_sha)) fail('CitizenSDK 候选 Git SHA 无效');
  if (expectedGitSha !== null && manifest.git_commit_sha !== expectedGitSha) fail('CitizenSDK 候选 Git SHA 不匹配');
  const expectedPlatforms = ['Android', 'iOS', 'macOS'];
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
  for (const required of [
    '.pubignore',
    'CHANGELOG.md',
    'LICENSE',
    'pubspec.yaml',
    ...Object.keys(NATIVE_FILES),
    `${APPLE_XCFRAMEWORK_PATH}/Info.plist`,
  ]) {
    if (!paths.includes(required)) fail(`CitizenSDK 候选缺少必需文件：${required}`);
  }
  const expectedFiles = [
    ...paths,
    'citizensdk-release.json',
    ...(expectExternalSums ? ['SHA256SUMS'] : []),
  ].sort();
  if (JSON.stringify(releaseCandidateEntries(candidate).files)
      !== JSON.stringify(expectedFiles)) {
    fail('CitizenSDK 候选包含未登记文件');
  }
  assertNoSecrets(candidate);
  return { candidate, manifest, manifestPath, sumsPath };
}

/// 反向核验最终 gzip/tar 字节、外层下载校验和与候选闭集。
///
/// `SHA256SUMS` 是 GitHub Release 的外部资产，不进入 tgz，从而可以覆盖 tgz
/// 自身而不存在循环哈希。归档必须逐字节等于本打包器从候选重建出的规范 gzip。
export function verifyCitizenSdkRelease(candidatePath, archivePath, expectedGitSha = null) {
  const verified = verifyCandidatePayload(candidatePath, expectedGitSha, true);
  const archive = assertSafeTargetPath(archivePath, '归档');
  if (!existsSync(archive) || lstatSync(archive).isSymbolicLink() || !lstatSync(archive).isFile()) {
    fail('CitizenSDK 归档不存在或不是普通文件');
  }
  const expectedArchive = gzipSync(
    deterministicTar(verified.candidate, new Set(['SHA256SUMS'])),
    { level: 9, mtime: 0 },
  );
  if (!readFileSync(archive).equals(expectedArchive)) {
    fail('CitizenSDK 归档不是候选闭集的规范 gzip/tar 字节');
  }
  const checksums = [
    { path: 'citizensdk-release.json', sha256: sha256File(verified.manifestPath) },
    { path: 'citizensdk.tgz', sha256: sha256File(archive) },
  ].sort((left, right) => left.path.localeCompare(right.path));
  const expectedSums = `${checksums.map(({ sha256, path }) => `${sha256}  ${path}`).join('\n')}\n`;
  if (readFileSync(verified.sumsPath, 'utf8') !== expectedSums) {
    fail('CitizenSDK 外层 SHA256SUMS 不一致');
  }
  return verified.manifest;
}

export function buildCitizenSdkRelease({ sourcePath, nativePath, outputPath, archivePath, gitCommitSha, softwareVersion }) {
  const source = resolve(sourcePath);
  const native = assertSafeTargetPath(nativePath, '原生产物目录');
  const output = assertSafeTargetPath(outputPath, '候选目录');
  const archive = assertSafeTargetPath(archivePath, '归档');
  if (!existsSync(source) || !lstatSync(source).isDirectory()) fail('CitizenSDK 源码目录不存在');
  if (!existsSync(native) || !lstatSync(native).isDirectory()) fail('CitizenSDK 原生产物目录不存在');
  assertSmoldotDartSource(source);
  assertSmoldotLocks(source);
  assertSdkRootLocks(source);
  assertProviderLockParity(source);
  assertCoreRustSource(source);
  assertSmoldotRustSource(source);
  assertSignerSource(source);
  assertPublicAbiHeaders(source);
  assertMobileBindingSource(source);
  assertLinuxBindingSource(source);
  assertChainAssets(source);
  assertSourceFixtures(source);
  assertLicenseSources(source);
  assertDocumentationSource(source);
  const sourceSoftwareVersion = assertHostedPackageSource(source);
  assertSdkTestContracts(source);
  assertSdkScriptSource(source);
  if (!/^[0-9a-f]{40}$/.test(gitCommitSha)) fail('Git commit SHA 必须是 40 位小写十六进制');
  if (!/^\d+\.\d{1,2}\.\d{1,2}$/.test(softwareVersion)) fail('CitizenSDK 软件版本无效');
  if (softwareVersion !== sourceSoftwareVersion) {
    fail(`CitizenSDK 发布版本必须与源码一致：源码=${sourceSoftwareVersion}；请求=${softwareVersion}`);
  }
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
  const payloadPaths = releaseCandidateEntries(output).files;
  const manifest = {
    product_id: PRODUCT_ID,
    package_name: PACKAGE_NAME,
    software_version: softwareVersion,
    git_commit_sha: gitCommitSha,
    platforms: ['Android', 'iOS', 'macOS'],
    files: fileEntries(output, payloadPaths),
  };
  const manifestPath = join(output, 'citizensdk-release.json');
  writeFileSync(manifestPath, prettyStableJson(manifest), { mode: 0o600 });
  verifyCandidatePayload(output, gitCommitSha);
  mkdirSync(dirname(archive), { recursive: true, mode: 0o700 });
  writeFileSync(
    archive,
    gzipSync(deterministicTar(output), { level: 9, mtime: 0 }),
    { mode: 0o600 },
  );
  const checksums = [
    { path: 'citizensdk-release.json', sha256: sha256File(manifestPath) },
    { path: 'citizensdk.tgz', sha256: sha256File(archive) },
  ].sort((left, right) => left.path.localeCompare(right.path));
  writeFileSync(join(output, 'SHA256SUMS'), `${checksums.map(({ sha256, path }) => `${sha256}  ${path}`).join('\n')}\n`, { mode: 0o600 });
  verifyCitizenSdkRelease(output, archive, gitCommitSha);
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
      if (!values.archive) fail('候选校验缺少参数 --archive');
      const manifest = verifyCitizenSdkRelease(
        values.verify,
        values.archive,
        values['expected-git-sha'] || null,
      );
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
