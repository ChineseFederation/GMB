import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:polkadart_keyring/polkadart_keyring.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gmb_wallet_password/wallet_mini_secret.dart';
import 'package:citizenapp/isar/wallet_isar.dart';
import 'package:citizenapp/isar/user_isar.dart';
import 'package:citizenapp/security/local_cipher.dart';
import 'package:citizenapp/security/local_data_key.dart';
import 'package:citizenapp/wallet/core/secure_seed_store.dart';
import 'package:citizenapp/wallet/core/hardware_bound_seed_vault.dart';
import 'package:citizenapp/wallet/core/device_subkey.dart';
import 'package:citizenapp/wallet/core/device_data_key_vault.dart';
import 'package:citizenapp/wallet/core/sign_mode.dart';
import 'package:citizenapp/wallet/core/wallet_manager.dart';
import 'package:citizenapp/wallet/core/native_sr25519.dart';

import '../support/fake_secure_seed_store.dart';
import '../support/isar_test_env.dart';
import '../support/smoldot_native_probe.dart';

const _mnemonicA =
    'legal winner thank year wave sausage worth useful legal winner thank yellow';
// 另一条合法但派生不同公钥的助记词（独立导入与私钥存储校验用）。
const _mnemonicB =
    'abandon abandon abandon abandon abandon abandon abandon abandon '
    'abandon abandon abandon about';

String _coldSs58(int byte) =>
    Keyring().encodeAddress(List<int>.filled(32, byte), 2027);

String _hex(List<int> b) =>
    b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

const _genesisHash =
    '0x1111111111111111111111111111111111111111111111111111111111111111';

Future<void> _activateAccountDataBinding(
  WalletManager manager, {
  required String cidNumber,
  required int bindingRevision,
  required String accountId,
}) async {
  await manager.activateAccountDataBinding(
    genesisHash: _genesisHash,
    cidNumber: cidNumber,
    bindingRevision: bindingRevision,
    accountId: accountId,
  );
}

/// 助记词 → 母种子（master mini-secret，32B）。
Future<Uint8List> _masterSeed(String mnemonic) async {
  return WalletMiniSecret.fromMnemonic(mnemonic);
}

/// 复现 WalletManager 的账户 child mini-secret 派生（金标同源）。
List<int> _childMiniSecret(List<int> seed, int index) {
  // 与生产同一条原生路径(NativeSr25519),测试不另立第二套实现。
  return NativeSr25519.deriveHard(
    seed,
    WalletMiniSecret.hardJunctionChainCode(index),
  );
}

/// 安全不变量断言：存的必须是账户0(`//0`) 的 child，绝不是母种子。
Future<void> _expectChildStoredNotSeed(
  String mnemonic,
  Uint8List stored,
) async {
  final master = await _masterSeed(mnemonic);
  final child = _childMiniSecret(master, 0);
  try {
    expect(stored, orderedEquals(child), reason: '严档存的必须是账户0 //0 的 child');
    expect(stored, isNot(orderedEquals(master)), reason: '绝不持久化母种子');
  } finally {
    WalletMiniSecret.clear(master);
    WalletMiniSecret.clear(child);
  }
}

String _accountIdForByte(int byte) => '0x${_hex(List<int>.filled(32, byte))}';

class _MemoryBlobStore implements VaultBlobStore {
  final Map<String, String> values = <String, String>{};
  final Set<String> failingReads = <String>{};

  @override
  Future<String?> read(String key) async {
    if (failingReads.contains(key)) throw StateError('测试索引读取失败');
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

class _RecordingDeviceSubkey extends DeviceSubkey {
  final List<String> deletedCidNumbers = <String>[];
  final Map<String, int> failingCidDeleteCounts = <String, int>{};
  final Map<String, int> lingeringCidContainsCounts = <String, int>{};

  @override
  Future<String> publicKeyHex(String cidNumber) async =>
      '04${List<String>.filled(64, '11').join()}';

  @override
  Future<void> delete(String cidNumber) async {
    deletedCidNumbers.add(cidNumber);
    final remaining = failingCidDeleteCounts[cidNumber] ?? 0;
    if (remaining > 0) {
      failingCidDeleteCounts[cidNumber] = remaining - 1;
      throw StateError('测试 CID 设备子钥删除失败');
    }
  }

  @override
  Future<bool> contains(String cidNumber) async {
    final remaining = lingeringCidContainsCounts[cidNumber] ?? 0;
    if (remaining <= 0) return false;
    lingeringCidContainsCounts[cidNumber] = remaining - 1;
    return true;
  }
}

/// 纯内存设备数据钥金库。测试验证钱包层状态机，不依赖原生 Keystore/SE 通道。
class _MemoryDeviceDataKeyVault extends DeviceDataKeyVault {
  final Map<int, Map<String, Uint8List>> values =
      <int, Map<String, Uint8List>>{};
  final List<int> deletedWalletIndexes = <int>[];
  final Set<int> failingWalletIndexes = <int>{};
  final Map<int, int> lingeringContainsCounts = <int, int>{};
  int sealCount = 0;
  int openCount = 0;
  int? failSealAt;

  String _aadKey(Uint8List aad) => _hex(aad);

  @override
  Future<String> seal({
    required int walletIndex,
    required Uint8List plaintext,
    required Uint8List aad,
  }) async {
    sealCount++;
    if (sealCount == failSealAt) {
      throw const DeviceDataKeyVaultException('测试设备数据钥封装失败');
    }
    values.putIfAbsent(walletIndex, () => <String, Uint8List>{})[_aadKey(aad)] =
        Uint8List.fromList(plaintext);
    return 'sealed:$walletIndex:${_aadKey(aad)}';
  }

  @override
  Future<Uint8List> open({
    required int walletIndex,
    required String blob,
    required Uint8List aad,
  }) async {
    openCount++;
    final value = values[walletIndex]?[_aadKey(aad)];
    if (value == null) {
      throw const DeviceDataKeyVaultException('测试设备数据钥不存在');
    }
    return Uint8List.fromList(value);
  }

  @override
  Future<void> delete(int walletIndex) async {
    deletedWalletIndexes.add(walletIndex);
    if (failingWalletIndexes.contains(walletIndex)) {
      throw const DeviceDataKeyVaultException('测试设备数据钥删除失败');
    }
    values.remove(walletIndex);
  }

  @override
  Future<bool> contains(int walletIndex) async {
    final remaining = lingeringContainsCounts[walletIndex] ?? 0;
    if (remaining > 0) {
      lingeringContainsCounts[walletIndex] = remaining - 1;
      return true;
    }
    return values.containsKey(walletIndex);
  }
}

class _DeleteFailingSeedStore extends FakeSecureSeedStore {
  bool failAccountKeyDeletion = false;

  @override
  Future<void> deleteAccountKey({
    required int walletIndex,
    required String accountId,
  }) async {
    if (failAccountKeyDeletion) {
      throw StateError('账户 child 删除失败');
    }
    await super.deleteAccountKey(
      walletIndex: walletIndex,
      accountId: accountId,
    );
  }
}

/// 可把下一次硬件密钥写入停在 Isar 事实已经提交之后，并可在释放时抛错。
/// 由此验证 WalletManager 的事实门禁覆盖真实异步窗口和完整回滚，而非只测纯函数。
class _ControllableSeedStore extends FakeSecureSeedStore {
  Completer<void>? _putEntered;
  Completer<void>? _releasePut;
  Completer<void>? _readEntered;
  Completer<void>? _releaseRead;
  bool _failHeldPut = false;
  bool _writeBeforeHeldFailure = false;

  ({Future<void> entered, void Function() release}) holdNextPut({
    bool fail = false,
    bool writeBeforeFailure = false,
  }) {
    final entered = Completer<void>();
    final release = Completer<void>();
    _putEntered = entered;
    _releasePut = release;
    _failHeldPut = fail;
    _writeBeforeHeldFailure = writeBeforeFailure;
    return (
      entered: entered.future,
      release: () => release.complete(),
    );
  }

  ({Future<void> entered, void Function() release}) holdNextRead() {
    final entered = Completer<void>();
    final release = Completer<void>();
    _readEntered = entered;
    _releaseRead = release;
    return (
      entered: entered.future,
      release: () => release.complete(),
    );
  }

  @override
  Future<Uint8List?> readAccountKey({
    required int walletIndex,
    required String accountId,
  }) async {
    final plaintext = await super.readAccountKey(
      walletIndex: walletIndex,
      accountId: accountId,
    );
    final entered = _readEntered;
    final release = _releaseRead;
    if (entered != null && release != null) {
      _readEntered = null;
      _releaseRead = null;
      entered.complete();
      await release.future;
    }
    return plaintext;
  }

  @override
  Future<void> putAccountKey({
    required int walletIndex,
    required String accountId,
    required Uint8List childMiniSecret,
  }) async {
    final entered = _putEntered;
    final release = _releasePut;
    if (entered != null && release != null) {
      _putEntered = null;
      _releasePut = null;
      entered.complete();
      await release.future;
      if (_failHeldPut) {
        if (_writeBeforeHeldFailure) {
          await super.putAccountKey(
            walletIndex: walletIndex,
            accountId: accountId,
            childMiniSecret: childMiniSecret,
          );
        }
        _failHeldPut = false;
        _writeBeforeHeldFailure = false;
        throw StateError('测试硬件密钥写入失败');
      }
      _failHeldPut = false;
      _writeBeforeHeldFailure = false;
    }
    await super.putAccountKey(
      walletIndex: walletIndex,
      accountId: accountId,
      childMiniSecret: childMiniSecret,
    );
  }
}

class _CapturingFailingPutSeedStore extends FakeSecureSeedStore {
  Uint8List? capturedPlaintext;

  @override
  Future<void> putAccountKey({
    required int walletIndex,
    required String accountId,
    required Uint8List childMiniSecret,
  }) async {
    capturedPlaintext = childMiniSecret;
    throw StateError('测试 append 失败');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  useIsolatedIsar();

  late FakeSecureSeedStore fakeStore;
  late _MemoryBlobStore contactBlobStore;
  late _RecordingDeviceSubkey deviceSubkey;
  late _MemoryDeviceDataKeyVault deviceDataKeyVault;

  // 动钱动权验证已上移到 WalletManager 的硬件金库读 child；单测里把 local_auth
  // channel 打桩为「验证通过」，让纯 Dart 环境不因缺插件而抛。
  const localAuthChannel = MethodChannel('plugins.flutter.io/local_auth');

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    fakeStore = FakeSecureSeedStore();
    WalletManager.debugSeedStore = fakeStore;
    contactBlobStore = _MemoryBlobStore();
    WalletManager.debugContactKeyStore = contactBlobStore;
    deviceSubkey = _RecordingDeviceSubkey();
    WalletManager.debugDeviceSubkey = deviceSubkey;
    deviceDataKeyVault = _MemoryDeviceDataKeyVault();
    WalletManager.debugDeviceDataKeyVault = deviceDataKeyVault;
    WalletManager.debugAccountDataKeyDeriver = null;
    WalletManager.debugWalletPersistedVerifier = null;
    WalletManager.subkeyRegistrar = null;
    WalletManager.coldDeviceBindingSigner = null;
    WalletManager.coldAccountDataKeyProvider = null;
    WalletManager.debugWalletPersistedVerifier = null;
    WalletManager.debugAccountDataKeyDeriver = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(localAuthChannel, (call) async {
      switch (call.method) {
        case 'authenticate':
          return true;
        case 'getAvailableBiometrics':
          return <String>['fingerprint', 'face'];
        case 'isDeviceSupported':
        case 'deviceSupportsBiometrics':
        case 'canCheckBiometrics':
          return true;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    WalletManager.subkeyRegistrar = null;
    WalletManager.coldDeviceBindingSigner = null;
    WalletManager.coldAccountDataKeyProvider = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(localAuthChannel, null);
  });

  group('WalletManager — 热钱包创建/导入/删除（ROOTLESS）', () {
    test('通讯录已有用途钥静默读取；实际缺钥时只鉴权一次生成', () async {
      final manager = WalletManager();
      final created = await manager.importWallet(_mnemonicA);
      final accountId = created.accountId;
      const cidNumber = 'GD-CTZN1-TEST';
      await _activateAccountDataBinding(
        manager,
        cidNumber: cidNumber,
        bindingRevision: 1,
        accountId: accountId,
      );

      fakeStore.readCount = 0;
      final material = await manager.ensureContactKeyMaterialForAccountId(
        accountId,
      );
      expect(material.encryptionKey, hasLength(32));
      expect(material.indexKey, hasLength(32));
      expect(material.encryptionKey, isNot(material.indexKey));
      expect(fakeStore.readCount, 1, reason: '真实缺钥只允许读取一次账户 child');

      final second = await manager.ensureContactKeyMaterialForAccountId(
        accountId,
      );
      expect(second.encryptionKey, material.encryptionKey);
      expect(second.indexKey, material.indexKey);
      expect(fakeStore.readCount, 1, reason: '已有用途钥必须直接静默使用');
      expect(deviceDataKeyVault.sealCount, 7);
      expect(deviceDataKeyVault.openCount, 4);
    });

    test('设备数据钥实际丢失时鉴权一次重建，后续静默读取', () async {
      final manager = WalletManager();
      final created = await manager.importWallet(_mnemonicA);
      final accountId = created.accountId;
      await _activateAccountDataBinding(
        manager,
        cidNumber: 'GD-CTZN1-TEST',
        bindingRevision: 1,
        accountId: accountId,
      );

      final first = await manager.ensureContactKeyMaterialForAccountId(
        accountId,
      );
      first.dispose();
      fakeStore.readCount = 0;
      // 模拟 Keystore / Secure Enclave 中的设备数据钥真实丢失，
      // 但公开绑定和密文仍在；这才是允许读取账户 child 的鉴权场景。
      deviceDataKeyVault.values.clear();

      final rebuilt = await manager.ensureContactKeyMaterialForAccountId(
        accountId,
      );
      expect(rebuilt.encryptionKey, hasLength(32));
      expect(rebuilt.indexKey, hasLength(32));
      expect(fakeStore.readCount, 1, reason: '硬件数据钥真实丢失只允许鉴权一次');

      final silent = await manager.ensureContactKeyMaterialForAccountId(
        accountId,
      );
      expect(silent.encryptionKey, rebuilt.encryptionKey);
      expect(silent.indexKey, rebuilt.indexKey);
      expect(fakeStore.readCount, 1, reason: '重建后必须恢复设备金库静默读取');
    });

    test('create/import/delete 只存账户0 child，不存种子/助记词', () async {
      final manager = WalletManager();

      final created = await manager.createWallet();
      expect(created.profile.walletIndex, 1);
      expect(created.profile.alg, 'sr25519');
      expect(created.profile.ss58, 2027);
      expect(created.profile.signMode, SignMode.hot);
      expect(created.mnemonic.trim().split(RegExp(r'\s+')).length, 12);
      // 严档只落账户0 child（32 字节）；无母种子、无助记词档。
      final createdKey = fakeStore.accountKeys[created.profile.accountId];
      expect(createdKey, isNotNull);
      expect(createdKey!.length, 32);
      await _expectChildStoredNotSeed(created.mnemonic, createdKey);
      // 助记词绝不出现在任何持久化条目里（只一次性返回供备份）。
      expect(fakeStore.accountKeys.values, isNot(contains(created.mnemonic)));
      expect(fakeStore.accountKeys.length, 1);
      // 账户0 作为锚点账户同步落库,出现在 getAccounts。
      final createdAccounts = await manager.getAccounts(
        created.profile.accountId,
      );
      expect(createdAccounts.map((a) => a.accountIndex).toList(), [0]);

      // 一台设备仅一个热钱包:删掉当前热钱包后才能导入下一只。
      final createdDeletion = await manager.deleteWallet(
        walletIndex: created.profile.walletIndex,
        expectedAccountId: created.profile.accountId,
      );
      expect(await manager.getWallets(), isEmpty);
      expect(fakeStore.accountKeys, isEmpty);
      expect(deviceDataKeyVault.deletedWalletIndexes, [
        created.profile.walletIndex,
      ]);
      for (final plan in createdDeletion.cleanupPlans) {
        await manager.acknowledgeWalletCleanupPlan(plan.planId);
      }

      final imported = await manager.importWallet(_mnemonicA);
      expect(imported.walletIndex, 1);
      expect(imported.signMode, SignMode.hot);
      final importedKey = fakeStore.accountKeys[imported.accountId];
      expect(importedKey, isNotNull);
      await _expectChildStoredNotSeed(_mnemonicA, importedKey!);

      await manager.deleteWallet(
        walletIndex: imported.walletIndex,
        expectedAccountId: imported.accountId,
      );
      expect(fakeStore.accountKeys.containsKey(imported.accountId), isFalse);
      expect(await manager.getWallet(), isNull);
      expect(await manager.getWallets(), isEmpty);
      expect(fakeStore.accountKeys, isEmpty);
      expect(deviceDataKeyVault.deletedWalletIndexes, [
        created.profile.walletIndex,
        imported.walletIndex,
      ]);
    });

    test('非法模式先拒绝签名与新建，再由同账户本机私钥证明重标为 Hot', () async {
      final manager = WalletManager();
      final imported = await manager.importWallet(_mnemonicA);
      await WalletIsar.instance.writeTxn((isar) async {
        final row = await isar.walletProfileEntitys
            .filter()
            .walletIndexEqualTo(imported.walletIndex)
            .findFirst();
        row!.signMode = 'broken';
        await isar.walletProfileEntitys.put(row);
      });

      final invalid = (await manager.getWallets()).single;
      expect(invalid.signMode, isNull);
      expect(
          () => invalid.requiresHotSign, throwsA(isA<WalletAuthException>()));
      await expectLater(
        manager.importWallet(_mnemonicB),
        throwsA(isA<WalletAuthException>()),
      );

      final repaired = await manager.repairHotSignMode(
        walletIndex: imported.walletIndex,
        accountId: imported.accountId,
        genesisHash: Uint8List.fromList(List<int>.filled(32, 0x11)),
      );

      expect(repaired.signMode, SignMode.hot);
      expect(repaired.requiresHotSign, isTrue);
    });

    test('本机私钥不能掩盖损坏的 AccountId 与 SS58 公开事实', () async {
      final manager = WalletManager();
      final imported = await manager.importWallet(_mnemonicA);
      await WalletIsar.instance.writeTxn((isar) async {
        final row = await isar.walletProfileEntitys
            .filter()
            .walletIndexEqualTo(imported.walletIndex)
            .findFirst();
        row!
          ..signMode = 'broken'
          ..ss58Address = 'broken-address';
        await isar.walletProfileEntitys.put(row);
      });

      await expectLater(
        manager.repairHotSignMode(
          walletIndex: imported.walletIndex,
          accountId: imported.accountId,
          genesisHash: Uint8List.fromList(List<int>.filled(32, 0x11)),
        ),
        throwsA(isA<WalletAuthException>()),
      );
      expect((await manager.getWallets()).single.signMode, isNull);
    });

    test('删除非末账户只清账户秘密，删除整钱包才清共享设备子钥', () async {
      final manager = WalletManager();
      final wallet = await manager.importWallet(_mnemonicA);
      final account1 = await manager.addNextAccount(
        wallet.accountId,
        _mnemonicA,
      );
      expect(
        await manager.walletIndexForAccountId(account1.accountId),
        wallet.walletIndex,
        reason: '设备子钥必须按当前 account_id 定位其实际所属热钱包',
      );

      await _activateAccountDataBinding(
        manager,
        cidNumber: 'GD-CTZN1-TEST',
        bindingRevision: 1,
        accountId: account1.accountId,
      );
      const contactKey = 'user.contact.book:GD-CTZN1-TEST';
      await UserIsar.instance.writeTxn((isar) async {
        await isar.userContactStateEntitys.putByStateKey(
          UserContactStateEntity()
            ..stateKey = contactKey
            ..ownerCidNumber = 'GD-CTZN1-TEST'
            ..stateKind = 'book'
            ..sealedPayload = 'CID 通讯录密文',
        );
      });
      await manager.deleteAccount(account1.accountId);

      expect(deviceDataKeyVault.deletedWalletIndexes, isEmpty);
      expect(fakeStore.accountKeys.containsKey(account1.accountId), isFalse);
      expect(
        await UserIsar.instance.read(
          (isar) => isar.userContactStateEntitys.getByStateKey(contactKey),
        ),
        isNotNull,
        reason: '删除换绑后的此前账户不得删除永久 CID 的本机数据',
      );

      await manager.deleteWallet(
        walletIndex: wallet.walletIndex,
        expectedAccountId: wallet.accountId,
      );
      expect(deviceDataKeyVault.deletedWalletIndexes, [wallet.walletIndex]);
      expect(contactBlobStore.values, isEmpty);
      expect(
        await UserIsar.instance.read(
          (isar) => isar.userContactStateEntitys.getByStateKey(contactKey),
        ),
        isNotNull,
        reason: '钱包删除不得跨域删除独立 UserIsar 的身份和通讯录事实',
      );
    });

    test('签名等待期外部复用 walletIndex 不得用 A 授权删除 B', () async {
      final store = _ControllableSeedStore();
      WalletManager.debugSeedStore = store;
      final manager = WalletManager();
      final walletA = await manager.importWallet(_mnemonicA);
      final hold = store.holdNextRead();

      final signedDeletion = manager.signAndDeleteWallet(
        walletIndex: walletA.walletIndex,
        accountId: walletA.accountId,
      );
      await hold.entered;
      final externalDeletion = await manager.deleteWallet(
        walletIndex: walletA.walletIndex,
        expectedAccountId: walletA.accountId,
      );
      for (final plan in externalDeletion.cleanupPlans) {
        await manager.acknowledgeWalletCleanupPlan(plan.planId);
      }
      final walletB = await manager.importWallet(_mnemonicB);
      expect(walletB.walletIndex, walletA.walletIndex);

      hold.release();
      await expectLater(
        signedDeletion,
        throwsA(isA<WalletAuthException>()),
      );

      expect(
        (await manager.getWallets()).single.accountId,
        walletB.accountId,
      );
    });

    test('clearWallet 清全部账户秘密并只删除热钱包设备子钥', () async {
      final manager = WalletManager();
      final hot = await manager.importWallet(_mnemonicA);
      await manager.importColdWallet(ss58Address: _coldSs58(0x44));
      await _activateAccountDataBinding(
        manager,
        cidNumber: 'GD-CTZN1-TEST',
        bindingRevision: 1,
        accountId: hot.accountId,
      );

      await manager.clearWallet();

      expect(await manager.getWallets(), isEmpty);
      expect(fakeStore.accountKeys, isEmpty);
      expect(contactBlobStore.values, isEmpty);
      expect(deviceDataKeyVault.deletedWalletIndexes, [hot.walletIndex]);
    });

    test('账户 child 清理失败仍继续删除钱包 KEK 与设备数据钥', () async {
      final failingStore = _DeleteFailingSeedStore();
      WalletManager.debugSeedStore = failingStore;
      final manager = WalletManager();
      final wallet = await manager.importWallet(_mnemonicA);
      failingStore.failAccountKeyDeletion = true;
      deviceDataKeyVault.failingWalletIndexes.add(wallet.walletIndex);

      await expectLater(
        manager.deleteWallet(
          walletIndex: wallet.walletIndex,
          expectedAccountId: wallet.accountId,
        ),
        throwsA(
          isA<WalletLocalCleanupException>().having(
            (error) => error.failures.join('\n'),
            'failures',
            allOf(
              contains('账户 child 删除失败'),
              contains('设备数据钥删除失败'),
            ),
          ),
        ),
      );

      expect(await manager.getWallets(), isEmpty);
      expect(failingStore.deletedWalletKeyIndexes, [wallet.walletIndex]);
      expect(deviceDataKeyVault.deletedWalletIndexes, [wallet.walletIndex]);
    });

    test('删除后秘密清理失败可由新 Manager 按持久计划重试并确认', () async {
      final failingStore = _DeleteFailingSeedStore();
      WalletManager.debugSeedStore = failingStore;
      final manager = WalletManager();
      final wallet = await manager.importWallet(_mnemonicA);
      failingStore.failAccountKeyDeletion = true;

      await expectLater(
        manager.deleteWallet(
          walletIndex: wallet.walletIndex,
          expectedAccountId: wallet.accountId,
        ),
        throwsA(isA<WalletLocalCleanupException>()),
      );
      expect(await manager.getWallets(), isEmpty);
      expect(failingStore.accountKeys, contains(wallet.accountId));

      final pending = await WalletManager().getPendingWalletCleanupPlans();
      expect(pending, hasLength(1));
      expect(pending.single.walletIndex, wallet.walletIndex);
      expect(pending.single.accountIds, <String>{wallet.accountId});
      expect(pending.single.deleteAccountKeys, isTrue);
      expect(pending.single.deleteWalletWideKeys, isTrue);

      // 模拟进程重启后安全存储恢复；新实例不依赖删除前页面快照即可完成全清。
      failingStore.failAccountKeyDeletion = false;
      final restartedManager = WalletManager();
      await restartedManager.retryWalletCleanupPlan(pending.single);
      expect(failingStore.accountKeys, isEmpty);
      expect(
        await failingStore.hasWalletKey(walletIndex: wallet.walletIndex),
        isFalse,
      );

      // 上层清算行缓存也确认完成后，整项计划才允许一次性 ack。
      await restartedManager.acknowledgeWalletCleanupPlan(
        pending.single.planId,
      );
      expect(await restartedManager.getPendingWalletCleanupPlans(), isEmpty);
    });

    test('设备数据硬件钥 delete 返回后回读仍存在时持久计划可重试', () async {
      final manager = WalletManager();
      final wallet = await manager.importWallet(_mnemonicA);
      deviceDataKeyVault.lingeringContainsCounts[wallet.walletIndex] = 1;

      await expectLater(
        manager.deleteWallet(
          walletIndex: wallet.walletIndex,
          expectedAccountId: wallet.accountId,
        ),
        throwsA(
          isA<WalletLocalCleanupException>().having(
            (error) => error.failures.join('\n'),
            'failures',
            contains('设备数据钥硬件钥'),
          ),
        ),
      );
      final pending = await manager.getPendingWalletCleanupPlans();
      expect(pending, hasLength(1));

      await manager.retryWalletCleanupPlan(pending.single);

      expect(deviceDataKeyVault.deletedWalletIndexes, <int>[
        wallet.walletIndex,
        wallet.walletIndex,
      ]);
      expect(await deviceDataKeyVault.contains(wallet.walletIndex), isFalse);
    });

    test('绑定索引读取失败仍继续全部不依赖安全清理', () async {
      final manager = WalletManager();
      final wallet = await manager.importWallet(_mnemonicA);
      await _activateAccountDataBinding(
        manager,
        cidNumber: 'GD-CTZN1-READ-FAIL',
        bindingRevision: 1,
        accountId: wallet.accountId,
      );
      contactBlobStore.failingReads.add(
        AccountDataBindingStore.bindingCidNumbersKey,
      );

      await expectLater(
        manager.deleteWallet(
          walletIndex: wallet.walletIndex,
          expectedAccountId: wallet.accountId,
        ),
        throwsA(
          isA<WalletLocalCleanupException>().having(
            (error) => error.failures.join('\n'),
            'failures',
            contains('测试索引读取失败'),
          ),
        ),
      );

      expect(fakeStore.accountKeys, isEmpty, reason: '账户 child 必须继续删除');
      expect(fakeStore.deletedWalletKeyIndexes, [wallet.walletIndex]);
      expect(deviceDataKeyVault.deletedWalletIndexes, [wallet.walletIndex]);
    });

    test('设备子钥失败保留绑定元数据，重试成功后才清除', () async {
      const cidNumber = 'GD-CTZN1-BINDING-RETRY';
      final manager = WalletManager();
      final wallet = await manager.importWallet(_mnemonicA);
      await _activateAccountDataBinding(
        manager,
        cidNumber: cidNumber,
        bindingRevision: 1,
        accountId: wallet.accountId,
      );
      deviceSubkey.failingCidDeleteCounts[cidNumber] = 1;

      await expectLater(
        manager.deleteWallet(
          walletIndex: wallet.walletIndex,
          expectedAccountId: wallet.accountId,
        ),
        throwsA(isA<WalletLocalCleanupException>()),
      );
      expect(
        await manager.readAccountDataBindingForCid(cidNumber),
        isNotNull,
        reason: '密钥未全清时必须保留可定位 tombstone',
      );

      await manager.retryDeletedAccountDataBindingCleanup(
        <String>{wallet.accountId},
      );

      expect(await manager.readAccountDataBindingForCid(cidNumber), isNull);
      expect(deviceSubkey.deletedCidNumbers, [cidNumber, cidNumber]);
    });

    test('设备子钥 delete 返回后回读仍存在时保留计划和绑定，重试才清除', () async {
      const cidNumber = 'GD-CTZN1-BINDING-READBACK';
      final manager = WalletManager();
      final wallet = await manager.importWallet(_mnemonicA);
      await _activateAccountDataBinding(
        manager,
        cidNumber: cidNumber,
        bindingRevision: 1,
        accountId: wallet.accountId,
      );
      deviceSubkey.lingeringCidContainsCounts[cidNumber] = 1;

      await expectLater(
        manager.deleteWallet(
          walletIndex: wallet.walletIndex,
          expectedAccountId: wallet.accountId,
        ),
        throwsA(
          isA<WalletLocalCleanupException>().having(
            (error) => error.failures.join('\n'),
            'failures',
            contains('硬件子钥仍存在'),
          ),
        ),
      );
      expect(await manager.readAccountDataBindingForCid(cidNumber), isNotNull);
      final pending = await manager.getPendingWalletCleanupPlans();
      expect(pending, hasLength(1));

      await manager.retryWalletCleanupPlan(pending.single);

      expect(await manager.readAccountDataBindingForCid(cidNumber), isNull);
      expect(deviceSubkey.deletedCidNumbers, [cidNumber, cidNumber]);
    });

    test('importWallet 拒绝非法助记词', () async {
      final manager = WalletManager();
      expect(
        () => manager.importWallet('hello world'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('助记词无效'),
          ),
        ),
      );
    });

    test('getDefaultWallet 忽略冷钱包（WalletGate 门禁判定依据）', () async {
      final manager = WalletManager();

      expect(await manager.getDefaultWallet(), isNull);

      await manager.importColdWallet(ss58Address: _coldSs58(0x22));
      expect(await manager.getDefaultWallet(), isNull);

      final imported = await manager.importWallet(_mnemonicA);
      final def = await manager.getDefaultWallet();
      expect(def, isNotNull);
      expect(def!.walletIndex, imported.walletIndex);
      expect(def.isHotWallet, isTrue);
    });

    test('换绑到不同钱包后新账户不能直接解密此前账户历史私有密文', () async {
      const cidNumber = 'CN220-CTZN2-198805200-2026';
      final aad = '${LocalKeyPurpose.chat.domain}|message-before-rebind';
      final manager = WalletManager();
      final walletA = await manager.importWallet(_mnemonicA);
      await _activateAccountDataBinding(
        manager,
        cidNumber: cidNumber,
        bindingRevision: 1,
        accountId: walletA.accountId,
      );
      final bindingA = await manager.accountDataBindingForAccountId(
        walletA.accountId,
      );
      await manager.ensureDeviceDataKeysForBinding(bindingA);
      final keyA = await manager.readDataKeyForCurrentBinding(
        walletA.accountId,
        LocalKeyPurpose.chat,
      );
      final oldCiphertext = await LocalCipher.encryptString(
        key: keyA,
        plaintext: 'A 钱包时期的 CID 私有数据',
        aad: aad,
      );

      // 删除 A 整只热钱包后只剩此前密文；系统没有可供 B 领取的额外数据密钥。
      await manager.deleteWallet(
        walletIndex: walletA.walletIndex,
        expectedAccountId: walletA.accountId,
      );
      expect(fakeStore.accountKeys, isEmpty);
      expect(
        await manager.readAccountDataBindingForCid(cidNumber),
        isNull,
      );

      final walletB = await manager.importWallet(_mnemonicB);
      expect(walletB.accountId, isNot(walletA.accountId));
      await _activateAccountDataBinding(
        manager,
        cidNumber: cidNumber,
        bindingRevision: 2,
        accountId: walletB.accountId,
      );
      final bindingB = await manager.accountDataBindingForAccountId(
        walletB.accountId,
      );
      await manager.ensureDeviceDataKeysForBinding(bindingB);
      final keyB = await manager.readDataKeyForCurrentBinding(
        walletB.accountId,
        LocalKeyPurpose.chat,
      );
      expect(keyB, isNot(keyA));
      await expectLater(
        LocalCipher.decryptString(key: keyB, blob: oldCiphertext, aad: aad),
        throwsA(isA<LocalCipherException>()),
      );
      expect(fakeStore.accountKeys.containsKey(walletA.accountId), isFalse);
    });

    test('换绑用途钥第二项派生失败时立即清零此前已派生明文', () async {
      final manager = WalletManager();
      final wallet = await manager.importWallet(_mnemonicA);
      await _activateAccountDataBinding(
        manager,
        cidNumber: 'GD-CTZN1-HANDOVER-CLEAR',
        bindingRevision: 1,
        accountId: wallet.accountId,
      );
      final binding =
          await manager.accountDataBindingForAccountId(wallet.accountId);

      Uint8List? firstDerived;
      var deriveCount = 0;
      WalletManager.debugAccountDataKeyDeriver = ({
        required List<int> accountSecret,
        required AccountDataBinding binding,
        required LocalKeyPurpose purpose,
        String? context,
      }) async {
        deriveCount += 1;
        if (deriveCount == 2) {
          throw StateError('测试第二用途派生失败');
        }
        final key = Uint8List.fromList(List<int>.filled(32, 0x5a));
        firstDerived = key;
        return key;
      };

      await expectLater(
        manager.deriveDataKeysForBindingHandover(
          binding,
          const <({LocalKeyPurpose purpose, String? context})>[
            (purpose: LocalKeyPurpose.chat, context: null),
            (purpose: LocalKeyPurpose.chatIndex, context: null),
          ],
        ),
        throwsA(isA<StateError>()),
      );

      expect(deriveCount, 2);
      expect(firstDerived, isNotNull);
      expect(firstDerived, everyElement(0),
          reason: '第二项失败后，首项明文仍归 WalletManager，必须立即全量清零');
    });

    test('换绑 intent 由 WalletManager 薄代理在 Wallet typed 状态原子推进并精确清除', () async {
      final manager = WalletManager();
      final wallet = await manager.importWallet(_mnemonicA);
      final source = AccountDataBinding(
        genesisHash: _genesisHash,
        cidNumber: 'GD-CTZN1-HANDOVER-INTENT',
        bindingRevision: 1,
        accountId: wallet.accountId,
      );
      final target = AccountDataBinding(
        genesisHash: _genesisHash,
        cidNumber: source.cidNumber,
        bindingRevision: 2,
        accountId: _accountIdForByte(0x77),
      );

      await manager.recordPendingAccountDataHandover(
        source: source,
        target: target,
      );
      expect(
        contactBlobStore.values,
        isNot(contains(AccountDataBindingStore.pendingHandoverKey)),
        reason: '顶层 intent 的唯一真源是 Wallet typed 状态，不写安全 blob 影子值',
      );
      expect(
        (await manager.readPendingAccountDataHandover())?.state,
        AccountDataHandoverState.preparing,
      );

      await manager.markPendingAccountDataHandoverReady(
        source: source,
        target: target,
      );
      expect(
        (await manager.readPendingAccountDataHandover())?.state,
        AccountDataHandoverState.ready,
      );
      await manager.clearPendingAccountDataHandover(
        source: source,
        target: target,
      );
      expect(await manager.readPendingAccountDataHandover(), isNull);
    });

    test('D3：无锁屏设备拒绝创建热钱包（fail-closed）', () async {
      fakeStore.noDeviceLock = true;
      final manager = WalletManager();
      await expectLater(
        manager.createWallet(),
        throwsA(isA<WalletAuthException>()),
      );
      // 未落库、未写密钥。
      expect(await manager.getWallets(), isEmpty);
      expect(fakeStore.accountKeys, isEmpty);
    });

    test('create append 失败仍立即清零账户0明文 child', () async {
      final store = _CapturingFailingPutSeedStore();
      WalletManager.debugSeedStore = store;

      await expectLater(
        WalletManager().createWallet(),
        throwsA(isA<StateError>()),
      );

      expect(store.capturedPlaintext, isNotNull);
      expect(store.capturedPlaintext, everyElement(0));
      expect(await WalletManager().getWallets(), isEmpty);
    });
  }, skip: smoldotNativeSkipReason());

  group('WalletManager — 钱包事实 mutation gate', () {
    test('create/import 在 Isar 已写而硬件钥等待期间保持门禁，首尾各推进 revision', () async {
      final store = _ControllableSeedStore();
      WalletManager.debugSeedStore = store;
      final manager = WalletManager();

      final createRevision = WalletManager.walletsRevision.value;
      final createHold = store.holdNextPut();
      final creating = manager.createWallet();
      await createHold.entered;

      expect(WalletManager.walletFactsMutationActive, isTrue);
      expect(WalletManager.walletFactsMutationDepth, 1);
      expect(WalletManager.walletsRevision.value, createRevision + 1);
      expect(await manager.getWallets(), hasLength(1),
          reason: '真实窗口中 Isar 钱包事实已经可见，但页面门禁仍必须开启');

      createHold.release();
      final created = await creating;
      expect(WalletManager.walletFactsMutationActive, isFalse);
      expect(WalletManager.walletFactsMutationDepth, 0);
      expect(WalletManager.walletsRevision.value, createRevision + 2);

      await manager.deleteWallet(
        walletIndex: created.profile.walletIndex,
        expectedAccountId: created.profile.accountId,
      );
      final importRevision = WalletManager.walletsRevision.value;
      final importHold = store.holdNextPut();
      final importing = manager.importWallet(_mnemonicA);
      await importHold.entered;

      expect(WalletManager.walletFactsMutationActive, isTrue);
      expect(WalletManager.walletFactsMutationDepth, 1);
      expect(WalletManager.walletsRevision.value, importRevision + 1);
      expect(await manager.getWallets(), hasLength(1));

      importHold.release();
      await importing;
      expect(WalletManager.walletFactsMutationActive, isFalse);
      expect(WalletManager.walletFactsMutationDepth, 0);
      expect(WalletManager.walletsRevision.value, importRevision + 2);
    });

    test('addAccounts 硬件钥失败前中间事实不可提交，回滚后解除门禁并推进 end revision', () async {
      final store = _ControllableSeedStore();
      WalletManager.debugSeedStore = store;
      final manager = WalletManager();
      final wallet = await manager.importWallet(_mnemonicA);
      final revisionBefore = WalletManager.walletsRevision.value;
      final hold = store.holdNextPut(fail: true);

      final adding = manager.addAccounts(
        wallet.accountId,
        _mnemonicA,
        const <int>[1],
      );
      await hold.entered;

      expect(WalletManager.walletFactsMutationActive, isTrue);
      expect(WalletManager.walletFactsMutationDepth, 1);
      expect(WalletManager.walletsRevision.value, revisionBefore + 1);
      expect(
        (await manager.getAccounts(wallet.accountId))
            .map((account) => account.accountIndex),
        <int>[0, 1],
        reason: '证明测试命中 Isar 已提交、硬件钥未结束的真实危险窗口',
      );

      hold.release();
      await expectLater(adding, throwsA(isA<StateError>()));

      expect(
        (await manager.getAccounts(wallet.accountId))
            .map((account) => account.accountIndex),
        <int>[0],
        reason: '硬件写失败必须删除本批账户事实并恢复默认账户顺序',
      );
      expect(store.accountKeys, contains(wallet.accountId));
      expect(store.accountKeys, hasLength(1));
      expect(WalletManager.walletFactsMutationActive, isFalse);
      expect(WalletManager.walletFactsMutationDepth, 0);
      expect(WalletManager.walletsRevision.value, revisionBefore + 2);
    });

    test('importColdWallet 事务后复核等待期仍保持 gate', () async {
      final manager = WalletManager();
      final entered = Completer<void>();
      final release = Completer<void>();
      WalletManager.debugWalletPersistedVerifier = (profile) async {
        if (!profile.isColdWallet) return;
        entered.complete();
        await release.future;
      };
      final revisionBefore = WalletManager.walletsRevision.value;

      final importing = manager.importColdWallet(
        ss58Address: _coldSs58(0x61),
      );
      await entered.future;

      expect(WalletManager.walletFactsMutationActive, isTrue);
      expect(WalletManager.walletsRevision.value, revisionBefore + 1);
      expect(await manager.getWallets(), hasLength(1));

      release.complete();
      await importing;
      expect(WalletManager.walletFactsMutationActive, isFalse);
      expect(WalletManager.walletsRevision.value, revisionBefore + 2);
    });

    test('importColdWallet 事务后复核抛错时以真实已提交事实收敛', () async {
      final manager = WalletManager();
      WalletManager.debugWalletPersistedVerifier = (_) async {
        throw StateError('测试事务后复核失败');
      };
      final revisionBefore = WalletManager.walletsRevision.value;

      final imported = await manager.importColdWallet(
        ss58Address: _coldSs58(0x62),
      );

      expect((await manager.getWallets()).single.accountId, imported.accountId);
      expect(WalletManager.walletFactsMutationActive, isFalse);
      expect(WalletManager.walletsRevision.value, revisionBefore + 2);
    });

    test('createWallet 并发真实写事务最多只有一只 Hot 钱包成功', () async {
      Future<Object> capture(Future<Object> operation) async {
        try {
          return await operation;
        } on Object catch (error) {
          return error;
        }
      }

      final manager = WalletManager();
      final outcomes = await Future.wait<Object>(<Future<Object>>[
        capture(manager.createWallet()),
        capture(manager.createWallet()),
      ]);

      expect(outcomes.whereType<WalletCreationResult>(), hasLength(1));
      expect((await manager.getWallets()).where((row) => row.isHotWallet),
          hasLength(1));
    });

    test('importWallet 并发真实写事务最多只有一只 Hot 钱包成功', () async {
      Future<Object> capture(Future<Object> operation) async {
        try {
          return await operation;
        } on Object catch (error) {
          return error;
        }
      }

      final manager = WalletManager();
      final outcomes = await Future.wait<Object>(<Future<Object>>[
        capture(manager.importWallet(_mnemonicA)),
        capture(manager.importWallet(_mnemonicB)),
      ]);

      expect(outcomes.whereType<WalletProfile>(), hasLength(1));
      expect((await manager.getWallets()).where((row) => row.isHotWallet),
          hasLength(1));
    });

    test('addAccounts 密文真实写入后抛错也清除当前 attempted secret', () async {
      final store = _ControllableSeedStore();
      WalletManager.debugSeedStore = store;
      final manager = WalletManager();
      final wallet = await manager.importWallet(_mnemonicA);
      final hold = store.holdNextPut(
        fail: true,
        writeBeforeFailure: true,
      );

      final adding = manager.addAccounts(
        wallet.accountId,
        _mnemonicA,
        const <int>[1],
      );
      await hold.entered;
      hold.release();
      await expectLater(adding, throwsA(isA<StateError>()));

      expect(store.accountKeys.keys, <String>[wallet.accountId]);
      expect(
        (await manager.getAccounts(wallet.accountId))
            .map((account) => account.accountIndex),
        <int>[0],
      );
    });
  }, skip: smoldotNativeSkipReason());

  group('实际缺钥一次生成：页面门禁不参与', () {
    tearDown(() => WalletManager.subkeyRegistrar = null);

    /// 一旦被调用即抛，用来证明建钱包/导入根本不会走到子钥注册。
    Future<void> failingRegistrar({
      required String cidNumber,
      required int bindingRevision,
      required String accountId,
      required signBinding,
    }) async {
      throw Exception('建钱包阶段不应注册设备子钥');
    }

    test('createWallet 不注册子钥：即使 registrar 必抛也照常建成', () async {
      // 子钥只服务广场 / 聊天 / 通讯录等需 CID 的场景，而建钱包这一刻账户还没有 CID
      // （后端 device/register 要求已绑 CID）。只用钱包和交易的用户根本不需要子钥，
      // 更不该因为后端不可用就建不出钱包。
      WalletManager.subkeyRegistrar = failingRegistrar;
      final manager = WalletManager();
      final created = await manager.createWallet();
      expect((await manager.getWallets()).length, 1);
      expect(fakeStore.accountKeys[created.profile.accountId], isNotNull);
    });

    test('importWallet 不注册子钥：即使 registrar 必抛也照常导入', () async {
      WalletManager.subkeyRegistrar = failingRegistrar;
      final manager = WalletManager();
      final profile = await manager.importWallet(_mnemonicA);
      expect((await manager.getWallets()).length, 1);
      expect(fakeStore.accountKeys[profile.accountId], isNotNull);
    });

    test('真实通讯录数据缺钥只生成本地数据钥，登记后端失败也不受影响', () async {
      WalletManager.subkeyRegistrar = failingRegistrar;
      final manager = WalletManager();
      final profile = await manager.importWallet(_mnemonicA);
      await _activateAccountDataBinding(
        manager,
        cidNumber: 'CN220-CTZN2-198805200-2026',
        bindingRevision: 1,
        accountId: profile.accountId,
      );
      fakeStore.readCount = 0;

      final material = await manager.ensureContactKeyMaterialForAccountId(
        profile.accountId,
      );

      expect(material.encryptionKey, hasLength(32));
      expect(material.indexKey, hasLength(32));
      expect(fakeStore.readCount, 1);
      expect(deviceDataKeyVault.sealCount, 7);
    });

    test('Worker 确认未登记后才按 CID 当前账户签 P-256 绑定证明', () async {
      String? seenCidNumber;
      int? seenBindingRevision;
      String? seenAccountId;
      final manager = WalletManager();
      final created = await manager.createWallet();
      // 建钱包、页面门禁和数据钥生成都不调用 registrar；只有 Worker 确认设备未登记
      // 后才进入远端登记入口。
      WalletManager.subkeyRegistrar = ({
        required String cidNumber,
        required int bindingRevision,
        required String accountId,
        required signBinding,
      }) async {
        seenCidNumber = cidNumber;
        seenBindingRevision = bindingRevision;
        seenAccountId = accountId;
        final signature = await signBinding(
          payload: Uint8List(0),
          signingMessage: Uint8List(32),
          devicePublicKey: '04${'11' * 64}',
          issuedAtMillis: 1,
        );
        expect(signature.startsWith('0x'), isTrue);
      };
      await _activateAccountDataBinding(
        manager,
        cidNumber: 'CN220-CTZN2-198805200-2026',
        bindingRevision: 1,
        accountId: created.profile.accountId,
      );
      final binding = await manager.accountDataBindingForAccountId(
        created.profile.accountId,
      );
      fakeStore.readCount = 0;
      expect(fakeStore.readCount, 0);
      await manager.registerDeviceSubkeyForBinding(binding);
      expect(seenCidNumber, 'CN220-CTZN2-198805200-2026');
      expect(seenBindingRevision, 1);
      expect(seenAccountId, created.profile.accountId);
      expect(fakeStore.readCount, 1);
    });

    test('本地数据钥并发生成全局去重，只读取一次 child，且绝不登记 P-256', () async {
      var registrations = 0;
      final manager = WalletManager();
      final created = await manager.createWallet();
      WalletManager.subkeyRegistrar = ({
        required String cidNumber,
        required int bindingRevision,
        required String accountId,
        required signBinding,
      }) async {
        registrations++;
        await signBinding(
          payload: Uint8List(0),
          signingMessage: Uint8List(32),
          devicePublicKey: '04${'11' * 64}',
          issuedAtMillis: 1,
        );
      };
      await _activateAccountDataBinding(
        manager,
        cidNumber: 'CN220-CTZN2-198805200-2026',
        bindingRevision: 1,
        accountId: created.profile.accountId,
      );
      final binding = await manager.accountDataBindingForAccountId(
        created.profile.accountId,
      );
      fakeStore.readCount = 0;

      await Future.wait(<Future<void>>[
        WalletManager().ensureDeviceDataKeysForBinding(binding),
        WalletManager().ensureDeviceDataKeysForBinding(binding),
        manager.ensureDeviceDataKeysForBinding(binding),
      ]);
      expect(registrations, 0);
      expect(fakeStore.readCount, 1);
      expect(deviceDataKeyVault.sealCount, 7);

      await manager.ensureDeviceDataKeysForBinding(binding);
      expect(registrations, 0);
      expect(fakeStore.readCount, 1, reason: '已有数据钥的相同账户不得再次读取 child');
    });

    test('P-256 登记拥有独立全局并发去重，不生成本地设备数据钥', () async {
      var registrations = 0;
      final manager = WalletManager();
      final created = await manager.createWallet();
      WalletManager.subkeyRegistrar = ({
        required String cidNumber,
        required int bindingRevision,
        required String accountId,
        required signBinding,
      }) async {
        registrations++;
        await signBinding(
          payload: Uint8List(0),
          signingMessage: Uint8List(32),
          devicePublicKey: '04${'11' * 64}',
          issuedAtMillis: 1,
        );
      };
      await _activateAccountDataBinding(
        manager,
        cidNumber: 'CN220-CTZN2-198805200-2026',
        bindingRevision: 1,
        accountId: created.profile.accountId,
      );
      final binding = await manager.accountDataBindingForAccountId(
        created.profile.accountId,
      );
      fakeStore.readCount = 0;

      await Future.wait(<Future<void>>[
        WalletManager().registerDeviceSubkeyForBinding(binding),
        WalletManager().registerDeviceSubkeyForBinding(binding),
        manager.registerDeviceSubkeyForBinding(binding),
      ]);

      expect(registrations, 1);
      expect(fakeStore.readCount, 1);
      expect(deviceDataKeyVault.sealCount, 0);
    });

    test('本地数据钥只补缺少的用途，不覆盖已经存在的用途密文', () async {
      final manager = WalletManager();
      final created = await manager.createWallet();
      await _activateAccountDataBinding(
        manager,
        cidNumber: 'CN220-CTZN2-198805200-2026',
        bindingRevision: 1,
        accountId: created.profile.accountId,
      );
      final binding = await manager.accountDataBindingForAccountId(
        created.profile.accountId,
      );
      await manager.ensureDeviceDataKeysForBinding(binding);
      final dataBlobNames = contactBlobStore.values.keys
          .where((key) => key.startsWith('citizenapp_device_data_key_'))
          .toList(growable: false);
      expect(dataBlobNames, hasLength(7));
      final retained = <String, String>{
        for (final name in dataBlobNames.skip(1))
          name: contactBlobStore.values[name]!,
      };
      await contactBlobStore.delete(dataBlobNames.first);
      fakeStore.readCount = 0;

      await manager.ensureDeviceDataKeysForBinding(binding);

      expect(fakeStore.readCount, 1);
      expect(deviceDataKeyVault.sealCount, 8, reason: '只允许补封装缺少的一把用途钥');
      for (final entry in retained.entries) {
        expect(contactBlobStore.values[entry.key], entry.value);
      }
    });

    test('本地数据钥生成失败只回滚本次数据 blob，不写本地 P-256 登记标记', () async {
      var registrations = 0;
      final manager = WalletManager();
      final created = await manager.createWallet();
      WalletManager.subkeyRegistrar = ({
        required String cidNumber,
        required int bindingRevision,
        required String accountId,
        required signBinding,
      }) async {
        registrations++;
        await signBinding(
          payload: Uint8List(0),
          signingMessage: Uint8List(32),
          devicePublicKey: '04${'11' * 64}',
          issuedAtMillis: 1,
        );
      };
      await _activateAccountDataBinding(
        manager,
        cidNumber: 'CN220-CTZN2-198805200-2026',
        bindingRevision: 1,
        accountId: created.profile.accountId,
      );
      final binding = await manager.accountDataBindingForAccountId(
        created.profile.accountId,
      );
      await manager.registerDeviceSubkeyForBinding(binding);
      deviceDataKeyVault.failSealAt = 3;

      await expectLater(
        manager.ensureDeviceDataKeysForBinding(binding),
        throwsA(isA<DeviceDataKeyVaultException>()),
      );

      expect(registrations, 1);
      expect(
        contactBlobStore.values.keys.where(
          (key) => key.startsWith('citizenapp_device_data_key_'),
        ),
        isEmpty,
      );
    });

    test('相同 account_id 不得用新 revision 伪装换绑，两类入口拒绝前均不读 child', () async {
      final manager = WalletManager();
      final created = await manager.createWallet();
      await _activateAccountDataBinding(
        manager,
        cidNumber: 'CN220-CTZN2-198805200-2026',
        bindingRevision: 1,
        accountId: created.profile.accountId,
      );
      fakeStore.readCount = 0;
      final invalid = AccountDataBinding(
        genesisHash: _genesisHash,
        cidNumber: 'CN220-CTZN2-198805200-2026',
        bindingRevision: 2,
        accountId: created.profile.accountId,
      );

      await expectLater(
        manager.ensureDeviceDataKeysForBinding(invalid),
        throwsA(isA<WalletAuthException>()),
      );
      await expectLater(
        manager.registerDeviceSubkeyForBinding(invalid),
        throwsA(isA<WalletAuthException>()),
      );
      expect(fakeStore.readCount, 0);
    });

    test('P-256 登记失败不删除已生成的数据钥，重试也不重新封装数据钥', () async {
      var registrations = 0;
      final manager = WalletManager();
      final created = await manager.createWallet();
      WalletManager.subkeyRegistrar = ({
        required String cidNumber,
        required int bindingRevision,
        required String accountId,
        required signBinding,
      }) async {
        registrations++;
        if (registrations == 1) throw Exception('后端登记失败');
      };
      await _activateAccountDataBinding(
        manager,
        cidNumber: 'CN220-CTZN2-198805200-2026',
        bindingRevision: 1,
        accountId: created.profile.accountId,
      );
      final binding = await manager.accountDataBindingForAccountId(
        created.profile.accountId,
      );
      await manager.ensureDeviceDataKeysForBinding(binding);
      final dataBlobs = Map<String, String>.fromEntries(
        contactBlobStore.values.entries.where(
          (entry) => entry.key.startsWith('citizenapp_device_data_key_'),
        ),
      );
      expect(dataBlobs, hasLength(7));
      expect(deviceDataKeyVault.sealCount, 7);
      fakeStore.readCount = 0;

      await expectLater(
        manager.registerDeviceSubkeyForBinding(binding),
        throwsA(isA<Exception>()),
      );
      expect(
        Map<String, String>.fromEntries(
          contactBlobStore.values.entries.where(
            (entry) => entry.key.startsWith('citizenapp_device_data_key_'),
          ),
        ),
        dataBlobs,
      );
      await manager.registerDeviceSubkeyForBinding(binding);
      expect(registrations, 2);
      expect(fakeStore.readCount, 2, reason: '两次远端登记尝试各鉴权一次');
      expect(deviceDataKeyVault.sealCount, 7, reason: '登记失败与重试不得碰数据钥');
    });
  }, skip: smoldotNativeSkipReason());

  group('WalletManager — 统一签名', () {
    final payload = Uint8List.fromList(List<int>.generate(32, (i) => i));

    test('统一签名：每次都读一次 child（无会话缓存）', () async {
      final manager = WalletManager();
      await manager.importWallet(_mnemonicA);
      fakeStore.readCount = 0;

      final sig = await manager.signWithWallet(1, payload);
      await manager.signWithWallet(1, payload);

      expect(sig.length, 64);
      // 两次签名 = 两次读 child（两次验证），不复用、无会话密钥。
      expect(fakeStore.readCount, 2);
    });

    test('AuthCancelled 上抛，绝不吞没', () async {
      final manager = WalletManager();
      final imported = await manager.importWallet(_mnemonicA);
      fakeStore.putCount = 0;
      fakeStore.cancelReads.add(imported.accountId);

      await expectLater(
        manager.signWithWallet(1, payload),
        throwsA(isA<AuthCancelled>()),
      );
      // 无根 = 无自愈重写。
      expect(fakeStore.putCount, 0);
    });
  }, skip: smoldotNativeSkipReason());

  group('WalletManager — 设备私钥失效 fail-closed', () {
    final payload = Uint8List.fromList(List<int>.generate(32, (_) => 7));

    test('KEK 失效 → 只报告设备安全存储异常，绝不自动重写 child', () async {
      final manager = WalletManager();
      final imported = await manager.importWallet(_mnemonicA);
      fakeStore.putCount = 0;
      fakeStore.invalidatedAccountIds.add(imported.accountId);

      await expectLater(
        manager.signWithWallet(1, payload),
        throwsA(
          isA<WalletAuthException>().having(
            (e) => e.message,
            'message',
            contains('设备安全存储'),
          ),
        ),
      );
      // App 不持久化母种子 / 助记词，查看或签名流程绝不重派生、重写。
      expect(fakeStore.putCount, 0);
    });

    test('child 条目缺失 → 只报告设备安全存储中没有账户私钥', () async {
      final manager = WalletManager();
      final imported = await manager.importWallet(_mnemonicA);
      fakeStore.accountKeys.remove(imported.accountId);

      await expectLater(
        manager.signWithWallet(1, payload),
        throwsA(
          isA<WalletAuthException>().having(
            (e) => e.message,
            'message',
            contains('没有该账户私钥'),
          ),
        ),
      );
    });

    test('另一钱包导入后也只从严档读取账户 child，不保存助记词', () async {
      final manager = WalletManager();
      final imported = await manager.importWallet(_mnemonicB);
      final key = fakeStore.accountKeys[imported.accountId];
      expect(key, isNotNull);
      await _expectChildStoredNotSeed(_mnemonicB, key!);
    });
  }, skip: smoldotNativeSkipReason());

  group('WalletManager — 冷钱包', () {
    test('signModeForAccountId 只按账户事实返回 Hot/Cold，未知账户返回 null', () async {
      final manager = WalletManager();
      final hot = await manager.importWallet(_mnemonicA);
      final cold = await manager.importColdWallet(ss58Address: _coldSs58(0x10));

      expect(await manager.signModeForAccountId(hot.accountId), SignMode.hot);
      expect(await manager.signModeForAccountId(cold.accountId), SignMode.cold);
      expect(
        await manager.signModeForAccountId(_accountIdForByte(0x7f)),
        isNull,
      );
    });

    test('importColdWallet 只存公开账户资料，child 金库无条目', () async {
      final manager = WalletManager();
      final cold = await manager.importColdWallet(ss58Address: _coldSs58(0x11));
      expect(cold.signMode, SignMode.cold);
      expect(fakeStore.accountKeys.containsKey(cold.accountId), isFalse);
    });

    test('冷账户用途钥只走扫码提供器并封装到本机设备金库', () async {
      final manager = WalletManager();
      final cold = await manager.importColdWallet(ss58Address: _coldSs58(0x21));
      const cidNumber = 'CN220-CTZN2-198805221-2026';
      await _activateAccountDataBinding(
        manager,
        cidNumber: cidNumber,
        bindingRevision: 2,
        accountId: cold.accountId,
      );
      final binding = await manager.accountDataBindingForAccountId(
        cold.accountId,
      );
      var providerCalls = 0;
      WalletManager.coldAccountDataKeyProvider = ({
        required binding,
        required requests,
      }) async {
        providerCalls += 1;
        expect(binding.accountId, cold.accountId);
        expect(binding.cidNumber, cidNumber);
        expect(requests, hasLength(7));
        return <Uint8List>[
          for (var index = 0; index < requests.length; index++)
            Uint8List.fromList(List<int>.filled(32, index + 1)),
        ];
      };
      fakeStore.readCount = 0;

      await manager.ensureDeviceDataKeysForBinding(binding);

      expect(providerCalls, 1);
      expect(fakeStore.readCount, 0, reason: '冷账户不得读取本机热钱包 child');
      expect(deviceDataKeyVault.sealCount, 7);
      final chatKey = await manager.readDataKeyForCurrentBinding(
        cold.accountId,
        LocalKeyPurpose.chat,
      );
      expect(chatKey, List<int>.filled(32, 1));
      chatKey.fillRange(0, chatKey.length, 0);

      await manager.ensureDeviceDataKeysForBinding(binding);
      expect(providerCalls, 1, reason: '已有用途钥时不得重复发起扫码');
    });

    test('冷账户登记 P-256 子钥只走 0x1C 冷签回调，不读取热钱包 child', () async {
      final manager = WalletManager();
      final cold = await manager.importColdWallet(ss58Address: _coldSs58(0x12));
      const cidNumber = 'CN220-CTZN2-198805212-2026';
      await manager.activateAccountDataBinding(
        genesisHash: _genesisHash,
        cidNumber: cidNumber,
        bindingRevision: 1,
        accountId: cold.accountId,
      );
      AccountDataBinding? signedBinding;
      WalletManager.coldDeviceBindingSigner = ({
        required binding,
        required payload,
        required signingMessage,
        required devicePublicKey,
        required issuedAtMillis,
      }) async {
        signedBinding = binding;
        expect(payload, [1, 2]);
        expect(signingMessage, [3, 4]);
        expect(devicePublicKey, '04${'11' * 64}');
        return '0x${'55' * 64}';
      };
      WalletManager.subkeyRegistrar = ({
        required cidNumber,
        required bindingRevision,
        required accountId,
        required signBinding,
      }) async {
        expect(cidNumber, 'CN220-CTZN2-198805212-2026');
        expect(accountId, cold.accountId);
        await signBinding(
          payload: Uint8List.fromList([1, 2]),
          signingMessage: Uint8List.fromList([3, 4]),
          devicePublicKey: '04${'11' * 64}',
          issuedAtMillis: 1700000000000,
        );
      };
      fakeStore.readCount = 0;

      final binding = await manager.accountDataBindingForAccountId(
        cold.accountId,
      );
      await manager.registerDeviceSubkeyForBinding(binding);

      expect(signedBinding?.cidNumber, cidNumber);
      expect(fakeStore.readCount, 0);
    });

    test('deleteWallet 冷钱包不影响 child 金库', () async {
      final manager = WalletManager();
      final cold = await manager.importColdWallet(ss58Address: _coldSs58(0x11));
      final result = await manager.deleteWallet(
        walletIndex: cold.walletIndex,
        expectedAccountId: cold.accountId,
      );
      final wallets = await manager.getWallets();
      expect(wallets.where((w) => w.walletIndex == cold.walletIndex), isEmpty);
      expect(deviceSubkey.deletedCidNumbers, isEmpty);
      expect(result.factCommitted, isTrue);
      expect(result.deletedAccountIds, <String>{cold.accountId});
      final plans = await manager.getPendingWalletCleanupPlans();
      expect(plans, hasLength(1));
      expect(plans.single.accountIds, <String>{cold.accountId});
      expect(plans.single.walletIndex, cold.walletIndex);
      expect(plans.single.deleteAccountKeys, isFalse);
      expect(plans.single.deleteWalletWideKeys, isFalse);
    });

    test('待清理计划占用 accountId，完成并确认前拒绝重新导入', () async {
      final manager = WalletManager();
      final ss58Address = _coldSs58(0x61);
      final deleted = await manager.importColdWallet(ss58Address: ss58Address);
      final deletion = await manager.deleteWallet(
        walletIndex: deleted.walletIndex,
        expectedAccountId: deleted.accountId,
      );

      await expectLater(
        manager.importColdWallet(ss58Address: ss58Address),
        throwsA(
          isA<WalletAccountConflictException>()
              .having(
                (error) => error.kind,
                'kind',
                WalletAccountConflictKind.pendingLocalCleanup,
              )
              .having(
                (error) => error.message,
                'message',
                contains('删除后清理尚未完成'),
              ),
        ),
      );

      await manager.acknowledgeWalletCleanupPlan(
        deletion.cleanupPlans.single.planId,
      );
      final importedAgain =
          await manager.importColdWallet(ss58Address: ss58Address);
      expect(importedAgain.accountId, deleted.accountId);
    });

    test('旧余额 RPC 不得写入复用同 walletIndex 的新钱包', () async {
      final manager = WalletManager();
      final walletA = await manager.importColdWallet(
        ss58Address: _coldSs58(0x71),
      );
      final oldRevision = WalletManager.walletsRevision.value;
      await manager.deleteWallet(
        walletIndex: walletA.walletIndex,
        expectedAccountId: walletA.accountId,
      );
      final walletB = await manager.importColdWallet(
        ss58Address: _coldSs58(0x72),
      );
      expect(walletB.walletIndex, walletA.walletIndex);

      final committed = await manager.setWalletBalance(
        walletIndex: walletA.walletIndex,
        accountId: walletA.accountId,
        expectedWalletsRevision: oldRevision,
        balance: 987654,
      );

      expect(committed, isFalse);
      expect((await manager.getWalletByIndex(walletB.walletIndex))!.balance, 0);
    });

    test('并发删除 merge 与逐账户 ack 不丢其它待清理 ID', () async {
      final manager = WalletManager();
      final walletA = await manager.importColdWallet(
        ss58Address: _coldSs58(0x73),
      );
      final walletB = await manager.importColdWallet(
        ss58Address: _coldSs58(0x74),
      );
      await manager.deleteWallet(
        walletIndex: walletA.walletIndex,
        expectedAccountId: walletA.accountId,
      );
      final planA = (await manager.getPendingWalletCleanupPlans()).single;

      await Future.wait<void>(<Future<void>>[
        manager.deleteWallet(
          walletIndex: walletB.walletIndex,
          expectedAccountId: walletB.accountId,
        ),
        manager.acknowledgeWalletCleanupPlan(planA.planId),
      ]);

      final pending = await manager.getPendingWalletCleanupPlans();
      expect(pending, hasLength(1));
      expect(pending.single.accountIds, <String>{walletB.accountId});
    });

    test('热钱包任一账户都不能再导入为冷钱包', () async {
      final manager = WalletManager();
      final account0Id = _accountIdForByte(0x31);
      final account1Id = _accountIdForByte(0x32);
      final account0Address = _coldSs58(0x31);
      final account1Address = _coldSs58(0x32);
      await WalletIsar.instance.writeTxn((isar) async {
        final profile = WalletProfileEntity()
          ..walletIndex = 1
          ..walletName = '热钱包'
          ..walletIcon = 'wallet'
          ..balance = 0
          ..accountId = account0Id
          ..masterId = account0Id
          ..ss58Address = account0Address
          ..alg = 'sr25519'
          ..ss58 = 2027
          ..createdAtMillis = 0
          ..source = 'test'
          ..signMode = SignMode.hot.name;
        await isar.walletProfileEntitys.put(profile);
        for (final account in <({String id, String address, int index})>[
          (id: account0Id, address: account0Address, index: 0),
          (id: account1Id, address: account1Address, index: 1),
        ]) {
          final row = AccountEntity()
            ..masterId = account0Id
            ..accountIndex = account.index
            ..accountId = account.id
            ..ss58Address = account.address
            ..accountName = '账户${account.index}'
            ..createdAtMillis = 0;
          await isar.accountEntitys.put(row);
        }
      });

      await expectLater(
        manager.importColdWallet(ss58Address: account1Address),
        throwsA(
          isA<WalletAccountConflictException>()
              .having(
                (error) => error.kind,
                'kind',
                WalletAccountConflictKind.existingHotAccount,
              )
              .having(
                (error) => error.message,
                'message',
                contains('不能重复保存为冷钱包'),
              ),
        ),
      );

      final wallets = await manager.getWallets();
      expect(wallets, hasLength(1));
      expect(wallets.single.signMode, SignMode.hot);
    });

    test('已存在冷钱包的 AccountId 不能追加为热钱包账户', () async {
      final manager = WalletManager();
      final cold = await manager.importColdWallet(ss58Address: _coldSs58(0x41));

      await expectLater(
        manager.debugEnsureAccountIdAvailable(
          cold.accountId,
          requestedSignMode: SignMode.hot,
        ),
        throwsA(
          isA<WalletAccountConflictException>()
              .having(
                (error) => error.kind,
                'kind',
                WalletAccountConflictKind.existingColdWallet,
              )
              .having(
                (error) => error.message,
                'message',
                contains('不能保存为热钱包账户'),
              ),
        ),
      );

      expect((await manager.getWallets()).single.accountId, cold.accountId);
    });

    test('重复导入冷钱包明确拒绝且不覆盖原记录', () async {
      final manager = WalletManager();
      final first = await manager.importColdWallet(
        ss58Address: _coldSs58(0x22),
      );

      await expectLater(
        manager.importColdWallet(ss58Address: first.ss58Address),
        throwsA(
          isA<WalletAccountConflictException>().having(
            (error) => error.kind,
            'kind',
            WalletAccountConflictKind.existingColdWallet,
          ),
        ),
      );

      final wallets = await manager.getWallets();
      expect(wallets, hasLength(1));
      expect(wallets.single.walletIndex, first.walletIndex);
      expect(wallets.single.accountId, first.accountId);
    });

    test('非法 signMode 且无本机私钥事实时，同账户重新导入可确认为 Cold', () async {
      final manager = WalletManager();
      final accountId = _accountIdForByte(0x51);
      final ss58Address = _coldSs58(0x51);
      await WalletIsar.instance.writeTxn((isar) async {
        final row = WalletProfileEntity()
          ..walletIndex = 7
          ..walletName = '异常钱包'
          ..walletIcon = 'wallet'
          ..balance = 0
          ..accountId = accountId
          ..masterId = accountId
          ..ss58Address = ss58Address
          ..alg = 'sr25519'
          ..ss58 = 2027
          ..createdAtMillis = 0
          ..source = 'test'
          ..signMode = 'unknown';
        await isar.walletProfileEntitys.put(row);
      });

      final repaired = await manager.importColdWallet(
        ss58Address: ss58Address,
      );

      expect(repaired.walletIndex, 7);
      expect(repaired.signMode, SignMode.cold);
      expect((await manager.getWallets()).single.signMode, SignMode.cold);
    });
  });
}
