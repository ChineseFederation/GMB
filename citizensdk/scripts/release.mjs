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
  realpathSync,
  readdirSync,
  writeFileSync,
} from 'node:fs';
import { dirname, join, relative, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

const PRODUCT_ID = 'citizensdk';
const PACKAGE_NAME = 'citizen_sdk';
const TATA_CONSOLE_TARGET_ROOT = '/Users/rhett/Only/tataconsole/target/citizensdk';
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
const ROOT_DIRECTORIES = ['android', 'assets', 'docs', 'ios', 'lib', 'native', 'scripts', 'test'];
const FORBIDDEN_DIRECTORIES = new Set([
  '.dart_tool', '.gradle', 'DerivedData', 'Pods', 'build', 'target',
]);
const NATIVE_FILES = Object.freeze({
  'android/src/main/jniLibs/arm64-v8a/libsmoldot.so': 'android/arm64-v8a/libsmoldot.so',
  'ios/libsmoldot.a': 'ios/libsmoldot.a',
  'ios/exported_symbols.txt': 'ios/exported_symbols.txt',
});
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
  'test/transaction/fixtures/citizenchain-runtime-system-events.hex': '2c4d04a69ff994622877786d481dc4780b7a32795e5f7cfa070ae4acb72679ef',
  'test/transaction/fixtures/citizenchain-runtime-v14-metadata.hex': 'da62207dfa342ce5285bb214a116761fd0a38c7c329ab8953506ad52471ed681',
  'test/transaction/fixtures/substrate-v14-system-events-metadata.hex': '95b368e7907511b28ba283a6741f4be551b56fb917c2f0183b4143dbe0ebf95b',
});
// Release 必须保留根级许可入口和两份权威许可证原文；仅检查文件名存在会允许法律文本被替换。
const LICENSE_SOURCE_FILES = Object.freeze({
  'LICENSE': '85cbc4861f93949326d45a484db8df26125af2c19ba78b35f2a9e51bcaa5042a',
  'LICENSE-GPL-3.0': 'aab56b4a581fc1c50b7c782eacf2fc8be05a47cd98e4bf4d836dd9b6dd9c86f4',
  'LICENSE-MIT': '39d4ad97ead876b44da69d6d5a3cdc185cd109e82c508ffa5a29f65897c24e1c',
});
// Hosted Package 不建立第二份候选：官方 Dart 发布工具直接读取已注入 Android/iOS
// 原生库的 GitHub Release 候选，并由这份固定 .pubignore 只筛出运行时闭包。
const HOSTED_PACKAGE_SOURCE_FILES = Object.freeze({
  '.pubignore': '1ca77c41a09b72bd3dd4052a680e823d47d54c3454a359c5f710dfeb35c57421',
  'CHANGELOG.md': 'd6279d94fa9354be319317c41f44fe4aac46c65e0f820b8701a59c2e6a0f45c6',
});
// 根 Flutter、signer、Android、iOS 与 Release 合同测试共同构成 SDK 自有测试闭集。
// 固定测试源码能阻止“删除测试后剩余测试仍全绿”或实现与金标同步漂移进入正式包。
const SDK_TEST_CONTRACT_ROOTS = Object.freeze([
  'test',
  'native/signer/tests',
  'android/src/test',
  'ios/Tests',
]);
const SDK_TEST_CONTRACT_FILES = Object.freeze({
  'android/src/test/README.md': '1febb9bdc7414053cff9844028f10dfb291a7293a270754a6806f7f4f216b57f',
  'android/src/test/kotlin/README.md': 'c9f29a30f65f17d7b43d46982c9a7812418b4ba84420ce77408fb3d3f399436a',
  'android/src/test/kotlin/org/README.md': '2a4c0f4f8a1f6ff813ad4c94d91aded7078bdb81a650db5de54920956dfbbb80',
  'android/src/test/kotlin/org/citizen/README.md': 'af7c4dd6b81841a7b96c4b101c20432b58d8d197b72283f9c5b846b9531af5eb',
  'android/src/test/kotlin/org/citizen/sdk/HardwareSecretVaultTest.kt': '28dac0330e788e4f5de0842d5250655b07d1a8c15c21683e1d83e6e21ca3b816',
  'android/src/test/kotlin/org/citizen/sdk/VaultEnvelopeTest.kt': 'a7c01a8c1794878b6bc7ec3e566f511ec80768d189b2c3430129408f77cfde65',
  'ios/Tests/SecureEnclaveSecretVaultTests.swift': 'a3e5d2433cbf1d426c1fc8ee18ac56fd13473fca7f8c8fe61d39ff332fb409aa',
  'ios/Tests/VaultEnvelopeTests.swift': '348efae4595498c8b591f811390fc318daa8910fd62829ebd3d93a1b5cd6fdc8',
  'native/signer/tests/ffi_contract.rs': 'a12689cd59350505c742612a7c29ea5afd5fe9bf9bfcc9f6e415b42a92cdb787',
  'native/signer/tests/substrate_vectors.rs': '29926f71fe95b44ce2619d7324aed7836995dd0b4c14e362e85fb5a1eb94e23d',
  'scripts/release.test.mjs': 'b65ee3671de2cd3ef547a790bf9ce1e5f89ec0b8f0ee8756507c5858327b94cf',
  'test/citizen_sdk_facade_test.dart': '85e350601517285a808238b641ab1becdf242240a90adc30c6a964228c91182c',
  'test/crypto/derivation_golden_test.dart': '5d924af41c2c5b02be9fcce86f5d296a719d1396216f3357007abdeaa9e73b6e',
  'test/crypto/wallet_password_test.dart': 'b269b7cb28233c9b00cf183d037419e9a7687143613f432477cfa3bf8fa30460',
  'test/node/bootstrap_client_test.dart': '80edc9da38ae330df6717672a2dece53c6ec92a321cff0e5afe10fb4bd978953',
  'test/node/chain_asset_manifest_test.dart': '78fb24dfe5eb7ae7476416bf2e41aa59f16c46e4af89c8875a148de54ffa4696',
  'test/node/chain_assets_test.dart': 'aaf0507df1dd311c4a7cfff4e7bae806f0675e8e1316b769f6079ddb53f449d6',
  'test/node/citizensdk_bootstrap_manifest.json': '33bd8e2c7407abea376f21a7adf7c9df644aedb7a9e985211075bba6cde28a00',
  'test/node/light_client_lifecycle_test.dart': '32f25fce798836b3b13b3ff80c2c9da4c53769bf86569ede81bd9036549bb11f',
  'test/platform/hardware_bound_seed_store_test.dart': 'fb6c3a66f04d9dae6ffabb479d381c017f1a2ba5796ddfd407eb3dcd57480cb3',
  'test/platform/hardware_secret_vault_test.dart': '868cc66b5dc728e6b51186df4ea67c9e66743bf4e35f53a153252c4d3bf2f1f7',
  'test/platform/preferences_chain_database_store_test.dart': '032f34f0a0402444264db190b240b434e52021fe41894e4ed7e2606fca868139',
  'test/platform/preferences_finalized_transaction_repository_test.dart': '3797b1bc9630707765ad73a9c97633573d77e97eff1fac89d7cb8b27bf149530',
  'test/platform/preferences_wallet_repository_test.dart': 'a2b0a095ed96713fa087c5d9648671cadc944932bfc7773e252cdb5e68bdd890',
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
  'test/transaction/fixtures/README.md': 'ff48e406f4eb945544589180acc0453325d5db8be7310879278488a24a70b61b',
  'test/transaction/fixtures/citizenchain-runtime-system-events.hex': '2c4d04a69ff994622877786d481dc4780b7a32795e5f7cfa070ae4acb72679ef',
  'test/transaction/fixtures/citizenchain-runtime-v14-metadata.hex': 'da62207dfa342ce5285bb214a116761fd0a38c7c329ab8953506ad52471ed681',
  'test/transaction/fixtures/substrate-v14-system-events-metadata.hex': '95b368e7907511b28ba283a6741f4be551b56fb917c2f0183b4143dbe0ebf95b',
  'test/transaction/signed_extrinsic_builder_test.dart': '75952dd740d3f37b339177cf9d929127aa4546e11f30bac4a602b679e0171c1f',
  'test/transaction/transaction_status_test.dart': '9afb279e5b70e1e4099a33e6bf01fa4a7da52ed216ce81b704eac0d1366a6c83',
  'test/transaction/transfer_service_test.dart': 'a9ddd0f88149e464ed830660a30938a6cf060a7a7932238617f18541bb5f1af3',
  'test/wallet/secure_seed_store_contract_test.dart': '01456c50783ded684eceb400242cd00afd2c2ddcb470ecfdae8dbc2935a982e4',
  'test/wallet/wallet_service_test.dart': '5f12a0a33bab91355072420f519a1aa6e72c04e2f57163692effe05a9fd643d8',
});
// smoldot Dart 包边界已并入唯一 citizen_sdk 根包。三处迁移目录共同构成固定闭集：
// 生产绑定、来源测试与历史审计资料缺一不可，且不允许重新出现第二份 pubspec 包边界。
const SMOLDOT_DART_ROOTS = Object.freeze([
  'docs/smoldot-dart',
  'lib/src/smoldot',
  'test/smoldot',
]);
const SMOLDOT_DART_FILES = Object.freeze({
  'docs/smoldot-dart/BUILD.md': '8260e070ee9b84eb2f4e4a51623aa93d25a820e7d7fd843839fb0910ef9286e8',
  'docs/smoldot-dart/CHANGELOG.md': 'd9adb01f7c62313a14bb86dbfd7f4077d925745e9c17a14f153eef79c45f8b94',
  'docs/smoldot-dart/INTEGRATION.md': '1ca0a278ebef38f7b795555afb432127865c6f73dc63a7104245526a1bf14e95',
  'docs/smoldot-dart/LICENSE': '4524e4d70a6295dfa882b0411cc49fcca03273e959fea68bbfe7df7ed63e7d78',
  'docs/smoldot-dart/README.md': 'c024610fdaf73b3fbc8d68460c289d87297620dd2090d0c3ba1346b820f7b6be',
  'docs/smoldot-dart/UPSTREAM.md': 'ed3f21bc62a6c6dc76beb870bf6f224914123a2cc95bdbab8b5cb453c4767539',
  'docs/smoldot-dart/example/README.md': '3521a3de97fcef5be155a17137ac52e87d3fa2c5442d555821854bd401b4d445',
  'docs/smoldot-dart/example/smoldot_example.dart': '60aea4e2d738ab7702fbd056626e6647f8c23174739f3c1b7e564133c80ee2e7',
  'docs/smoldot-dart/source-analysis_options.yaml': 'e67b963f89cf75f675a0ed25d258bae038d216832c22b84782e5e3a90b8d3076',
  'docs/smoldot-dart/source-pubspec.lock': '91ad4c26c8abdf6384292e1f01f335ba7ce50443a99b01b45e2f4efa72dab25a',
  'docs/smoldot-dart/source-pubspec.yaml': '408910b7b043d30aa29dc1f226f750f64dbee90ad343b1154478a7ee6ff3d83e',
  'lib/src/smoldot/bindings.dart': '23a5a2add0de238ee8218238acf312193fa349c0806edb4056ff6f63b8b459eb',
  'lib/src/smoldot/chain.dart': '43f3fbc8420f61d335acb0c48ee471a7885ebbd71d320d8b820805b1537d8053',
  'lib/src/smoldot/client.dart': '916fd74c20f4daefca2e17e668e8a2fb16c59219b8f3bdd3148d10454a71ddff',
  'lib/src/smoldot/json_rpc.dart': 'c3a030b236814731f773bb8b1aa9dd1e5789bc7d0809f3c0dd7011d59b401d01',
  'lib/src/smoldot/platform.dart': '640e88e465a80677fa5532f5c667758986dae3d3e801ce31bf82cf1c8b044a61',
  'lib/src/smoldot/smoldot.dart': 'cb1b47bb6873081129fba69b0c64fceef77f69d6aeb354d1824994cbc51b9676',
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
  'native/smoldot/ffi/Cargo.lock': '05190e2ed21987a8ca61c023c47eadc29f9cb415a065308843af5c4ad37537e7',
  'native/smoldot/pow/Cargo.lock': '6d832fb629bbf19ff6c2cce589c6285c3367cbcb3b55f4819beb7e733d9e038b',
});
// 根 signer workspace 与 Flutter 包的解析闭包同样属于正式来源输入；locked 模式
// 只能保证使用当前锁，必须再固定锁文件自身，才能阻止依赖身份随提交静默漂移。
const SDK_ROOT_LOCK_FILES = Object.freeze({
  'Cargo.lock': '62571bec0b3a1f40af270aa22415124ae201f07ebd1d0de35ab23884317d5670',
  'pubspec.lock': '2a8bd55a877f037c425cfd21c279b89820ae3c61db698f48a15f298e6c977c41',
});
// 该清单离线固定 FFI、PoW workspace、light-base 与 lib 的完整文件闭集；
// byte_identical 项来自 CitizenApp 初始稳定基线，adapted/sdk_only 是已审查的
// SDK 边界。清单自身再由此哈希固定，CI/Release 不回指 CitizenApp。
const SMOLDOT_RUST_SOURCE_MANIFEST = Object.freeze({
  path: 'native/smoldot/SOURCE_SHA256.json',
  sha256: 'a2cd085e6b0db65a72c11258f257a5c7fa0bbf6e494fe68a91007537ec4326f2',
});
// 这些文件位于各来源单元之外，但仍属于 Release 的正式输入：许可证、来源说明、
// 公共 ABI 头文件以及由 light-base 示例通过 include_str! 编译引用的链规范。
// 它们与来源清单、213 个 Rust 单元文件共同组成 native/smoldot 的 223 文件完整闭集；
// Dart 绑定已迁出本原生目录并由 SMOLDOT_DART_FILES 独立固定。
const SMOLDOT_SUPPORT_FILES = Object.freeze({
  'native/smoldot/LICENSE': 'aab56b4a581fc1c50b7c782eacf2fc8be05a47cd98e4bf4d836dd9b6dd9c86f4',
  'native/smoldot/LICENSE-APACHE-2.0': '4524e4d70a6295dfa882b0411cc49fcca03273e959fea68bbfe7df7ed63e7d78',
  'native/smoldot/README.md': '5eb02391d53347f28cad43229fde751c5f54bb905ba63a61318dbeb9211ed0e1',
  'native/smoldot/UPSTREAM.md': '9826a09529ebf2eabb253d05bcccbf8b2107e9c39950ee0aa200b06b5e4feb94',
  'native/smoldot/include/README.md': '2ae510563d3b87a852bc990d462ad940d92578b05fbe9809a9c82d63c16503bc',
  'native/smoldot/include/citizensdk.h': '18c476d67cd00822b1a14fe4317330d56195712a7f8e33f39a487d84ad1a0819',
  'native/smoldot/include/smoldot.h': 'f7c2645588809f73f8aa799975b363a4a7b22e8de7149da9d0b4c2ea20c90a20',
  'native/smoldot/pow/demo-chain-specs/polkadot.json': '859c8ade8b740e6a106082e0fdb4ae14075d79f8a277f02124bf9856d8a302aa',
  'native/smoldot/pow/demo-chain-specs/polkadot_asset_hub.json': '4909f824189edd0c7c64e444f81a4082fe5bc433861a5ac9e8b00838203a35ab',
});
// signer 是可编译的 Rust crate，正式输入不能只固定 Cargo.toml 与 lib.rs；README
// 和两份合同测试也必须进入同一 6 文件闭集，任何 build.rs、src/bin 或其他新增文件
// 都会改变 Cargo 行为，因此一律失败关闭。
const SIGNER_FILES = Object.freeze({
  'native/signer/Cargo.toml': '4b063da8dbf821d14798be37b41366be35418f5c14ed2b451420be80d424d3d8',
  'native/signer/README.md': 'c4b6de1df02a82b42e30f520b58266e296d49135fa0abc82804e5f195c2dca26',
  'native/signer/src/README.md': '9e3d90810c32ef0ea73dda76fa4c75745849066cbd45261c841a401f85e373e3',
  'native/signer/src/lib.rs': '4fcdcda78e3050ab2daff782881b2c223ddabf61dc00113f4f83f799b5436f9d',
  'native/signer/tests/ffi_contract.rs': 'a12689cd59350505c742612a7c29ea5afd5fe9bf9bfcc9f6e415b42a92cdb787',
  'native/signer/tests/substrate_vectors.rs': '29926f71fe95b44ce2619d7324aed7836995dd0b4c14e362e85fb5a1eb94e23d',
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

export function assertHostedPackageSource(root) {
  const sourceRoot = resolve(root);
  assertPinnedFiles(sourceRoot, HOSTED_PACKAGE_SOURCE_FILES, 'Hosted Package 合同');
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
  for (const [dependency, constraint] of [
    ['bip39_mnemonic', '^4.0.1'],
    ['crypto', '^3.0.7'],
    ['polkadart_keyring', '^0.7.1'],
  ]) {
    const escaped = constraint.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    if (!new RegExp(`^  ${dependency}: ${escaped}$`, 'm').test(pubspec)) {
      fail(`CitizenSDK Hosted Package 依赖约束漂移：${dependency}`);
    }
  }
  const platformVersions = [
    ['android/build.gradle', /^version = '(\d+\.\d{1,2}\.\d{1,2})'$/m],
    ['ios/citizen_sdk.podspec', /^  s\.version\s+= '(\d+\.\d{1,2}\.\d{1,2})'$/m],
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
  assertPinnedFiles(sourceRoot, SDK_TEST_CONTRACT_FILES, '测试合同');
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
    fail(`CitizenSDK smoldot 223 文件闭集漂移；缺失=${missing.join(',') || '无'}；额外=${extra.join(',') || '无'}`);
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
    fail(`CitizenSDK signer 6 文件闭集漂移；缺失=${missing.join(',') || '无'}；额外=${extra.join(',') || '无'}`);
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

function deterministicTar(candidatePath, excludedPaths = new Set()) {
  const chunks = [];
  for (const relativePath of regularFiles(candidatePath)) {
    if (excludedPaths.has(relativePath)) continue;
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
  assertSmoldotRustSource(candidate);
  assertSignerSource(candidate);
  assertChainAssets(candidate);
  assertSourceFixtures(candidate);
  assertLicenseSources(candidate);
  const hostedSoftwareVersion = assertHostedPackageSource(candidate);
  assertSdkTestContracts(candidate);
  const manifest = JSON.parse(readFileSync(manifestPath, 'utf8'));
  const keys = Object.keys(manifest).sort();
  const expectedKeys = ['files', 'git_commit_sha', 'package_name', 'platforms', 'product_id', 'software_version'];
  if (JSON.stringify(keys) !== JSON.stringify(expectedKeys)) fail('CitizenSDK 正式清单字段集合不正确');
  if (manifest.product_id !== PRODUCT_ID || manifest.package_name !== PACKAGE_NAME) fail('CitizenSDK 候选产品身份不正确');
  if (!/^\d+\.\d{1,2}\.\d{1,2}$/.test(manifest.software_version)) fail('CitizenSDK 候选版本无效');
  if (manifest.software_version !== hostedSoftwareVersion) fail('CitizenSDK 候选 manifest 与包版本不一致');
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
  for (const required of [
    '.pubignore',
    'CHANGELOG.md',
    'LICENSE',
    'pubspec.yaml',
    ...Object.keys(NATIVE_FILES),
  ]) {
    if (!paths.includes(required)) fail(`CitizenSDK 候选缺少必需文件：${required}`);
  }
  const expectedFiles = [
    ...paths,
    'citizensdk-release.json',
    ...(expectExternalSums ? ['SHA256SUMS'] : []),
  ].sort();
  if (JSON.stringify(regularFiles(candidate)) !== JSON.stringify(expectedFiles)) fail('CitizenSDK 候选包含未登记文件');
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
  assertSmoldotRustSource(source);
  assertSignerSource(source);
  assertChainAssets(source);
  assertSourceFixtures(source);
  assertLicenseSources(source);
  const sourceSoftwareVersion = assertHostedPackageSource(source);
  assertSdkTestContracts(source);
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
