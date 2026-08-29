// CitizenSDK 无根热钱包的 HD 派生金标。
//
// 契约：一套助记词 -> 一个 master mini-secret -> 全部 `//index` 硬派生
//（账户0 也是 `//0`，不存在 bare root 账户）-> 每个账户独立的 child
// mini-secret、AccountId 与公民链 SS58 地址。
//
// 这些向量逐字节收编自 CitizenApp/CitizenWallet 已共同验证的金标。测试同时用
// polkadart Keyring 作为外部参照，避免 SDK 的派生、编码和验签实现互相印证却
// 一起漂移。
import 'dart:typed_data';

import 'package:citizen_sdk/src/crypto/account_codec.dart';
import 'package:citizen_sdk/src/crypto/native_sr25519.dart';
import 'package:citizen_sdk/src/crypto/wallet_mini_secret.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polkadart_keyring/polkadart_keyring.dart';

/// Substrate 开发助记词；全网公开，只允许用于测试。
const String _devPhrase =
    'bottom drive obey lake curtain smoke basket hold race lonely fit walk';

/// Substrate 权威向量：开发助记词 `//Alice` 的 sr25519 AccountId。
const String _alicePublicKey =
    'd43593c715fdd31c61141abd04a99fd6822c8558854ccde39a5684e7a56da27d';

/// `//0`、`//1`、`//2` 的 (AccountId, SS58, child mini-secret) 金标。
const List<(String, String, String)> _goldenAccounts = [
  (
    '0x2afba9278e30ccf6a6ceb3a8b6e336b70068f045c666f2e7f4f9cc5f47db8972',
    'w5CZACAABUbK4jspzPB5be9trhtSgRCRZFafGe7kvFPvxq8M2',
    '0x914dded06277afbe5b0e8a30bce539ec8a9552a784d08e530dc7c2915c478393',
  ),
  (
    '0xb606fc73f57f03cdb4c932d475ab426043e429cecc2ffff0d2672b0df8398c48',
    'w5FhUDLW4BxsE1QXK4sNjPZ8rqSnK2QeVpUfXzqczpWdxChxV',
    '0x4433c3ada0cf37c3050d5435321872f4f84ef53d8b5f1f1560689d500b882245',
  ),
  (
    '0x46f136b564e1fad55031404dd84e5cd3fa76bfe7cc7599b39d38fd06663bbc0a',
    'w5DBpRvbgkersZohanGQiXa4qQLS1n7VQaSFwBaq4irJmgDn5',
    '0x5418179cea7224f2d9d2ab437773c2fdb266e52ef7fa52c0d9c15c6ca6068748',
  ),
];

/// `subkey inspect --password 'Aa1!中华' '<助记词>//index'` 金标。
const String _password = 'Aa1!中华';
const List<(String, String)> _passwordGoldenAccounts = [
  (
    '0x582cdc8c9b4c0ab469a54850285004eec274d08baa1ccd885300697c1410a939',
    '0xd2db5cb0ab33f2b28d460ecc98d44606a582560e15217f993dcd0890dc637883',
  ),
  (
    '0xb2e853e5b2338b391203393805fb99b3e698b72a27be2d881ceb5883b8f1ae0e',
    '0x17662e95a4cebb837b63d0a803d30dd183541f6ecb0a3f26fd1e911e30f3a3e0',
  ),
  (
    '0xee6b0534f98e4dd14802f59e44dd962741dd18dfcbdf4614980719b9809b7a61',
    '0xde45491978a38d3f3960e3f7aece9e5d619c81dd2c4cabe1904aa8fef4442201',
  ),
];

String _hex(List<int> bytes) =>
    bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

Uint8List _deriveChild(List<int> master, int index) {
  final chainCode = WalletMiniSecret.hardJunctionChainCode(index);
  try {
    return NativeSr25519.deriveHard(master, chainCode);
  } finally {
    WalletMiniSecret.clear(chainCode);
  }
}

void main() {
  test('junction 硬派生外部参照对齐 Substrate 权威 Alice', () async {
    final alice = await Keyring().fromUri('$_devPhrase//Alice');
    alice.ss58Format = citizenSs58Prefix;
    expect(_hex(alice.bytes().toList(growable: false)), _alicePublicKey);
  });

  test('fromSeed(child) 与外部 Keyring 的 mnemonic//index 逐项一致', () async {
    final master = await WalletMiniSecret.fromMnemonic(_devPhrase);
    try {
      for (var index = 0; index < _goldenAccounts.length; index++) {
        final child = _deriveChild(master, index);
        try {
          final actualPublic = NativeSr25519.publicKeyOf(child);
          final reference = await Keyring().fromUri('$_devPhrase//$index');
          reference.ss58Format = citizenSs58Prefix;
          final accountId = citizenAccountIdFromBytes(actualPublic);
          expect(
            _hex(actualPublic),
            _hex(reference.bytes().toList(growable: false)),
            reason: '//$index 公钥与外部参照不一致',
          );
          expect(
            citizenSs58FromAccountId(accountId),
            reference.address,
            reason: '//$index SS58 与外部参照不一致',
          );
        } finally {
          WalletMiniSecret.clear(child);
        }
      }
    } finally {
      WalletMiniSecret.clear(master);
    }
  });

  test('//0 //1 //2 的 child、AccountId 与 SS58 逐字节钉死', () async {
    final master = await WalletMiniSecret.fromMnemonic(_devPhrase);
    try {
      for (var index = 0; index < _goldenAccounts.length; index++) {
        final child = _deriveChild(master, index);
        try {
          final accountId = citizenAccountIdFromBytes(
            NativeSr25519.publicKeyOf(child),
          );
          final (expectedId, expectedSs58, expectedChild) =
              _goldenAccounts[index];
          expect(accountId, expectedId, reason: '//$index AccountId 漂移');
          expect(
            citizenSs58FromAccountId(accountId),
            expectedSs58,
            reason: '//$index SS58 漂移',
          );
          expect(
            '0x${_hex(child)}',
            expectedChild,
            reason: '//$index child mini-secret 漂移',
          );
        } finally {
          WalletMiniSecret.clear(child);
        }
      }
    } finally {
      WalletMiniSecret.clear(master);
    }
  });

  test('非空 password 对齐 Subkey 的 //0 //1 //2 金标', () async {
    final master = await WalletMiniSecret.fromMnemonic(
      _devPhrase,
      password: _password,
    );
    try {
      for (var index = 0; index < _passwordGoldenAccounts.length; index++) {
        final child = _deriveChild(master, index);
        try {
          final (expectedId, expectedChild) = _passwordGoldenAccounts[index];
          expect(
            citizenAccountIdFromBytes(NativeSr25519.publicKeyOf(child)),
            expectedId,
            reason: 'password //$index AccountId 漂移',
          );
          expect(
            '0x${_hex(child)}',
            expectedChild,
            reason: 'password //$index child mini-secret 漂移',
          );
        } finally {
          WalletMiniSecret.clear(child);
        }
      }
    } finally {
      WalletMiniSecret.clear(master);
    }
  });
}
