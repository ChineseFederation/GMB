import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:citizenapp/8964/chain/square_chain_service.dart';
import 'package:citizenapp/8964/services/square_identity_state.dart';
import 'package:citizenapp/8964/services/square_publish_service.dart';
import 'package:citizenapp/8964/services/square_api_client.dart';
import 'package:citizenapp/qr/pages/qr_sign_session_page.dart';
import 'package:citizenapp/qr/qr_protocols.dart';
import 'package:citizenapp/wallet/core/device_subkey.dart';
import 'package:citizenapp/wallet/core/wallet_manager.dart';

/// 广场公文、文章和视频共用的发布签名器。
///
/// 登录挑战 = 后端会话握手 → **P-256 硬件设备子钥静默签名**（不读 seed、不弹）。
/// 发布上链属于钱包账户签名：Hot 只能调用本机私钥，Cold 只能进入 CitizenWallet
/// 扫码签名；模式缺失时直接拒绝。设备子钥与钱包账户签名模式相互独立。
class SquareComposeSigners {
  SquareComposeSigners({
    required this.context,
    required this.identity,
    DeviceSubkey? deviceSubkey,
    WalletManager? walletManager,
  })  : _walletManager = walletManager ?? WalletManager(),
        _deviceSubkey = deviceSubkey ?? DeviceSubkey() {
    _walletAccountSigner = WalletAccountSigner(
      walletManager: _walletManager,
    );
  }

  final BuildContext context;
  final SquareIdentityState identity;
  final WalletManager _walletManager;
  final DeviceSubkey _deviceSubkey;
  late final WalletAccountSigner _walletAccountSigner;

  Future<String> signLogin(
    SquareLoginContext loginContext,
    Uint8List loginMessage,
  ) async {
    final cidNumber = identity.cidNumber ?? '';
    if (cidNumber.isEmpty ||
        loginContext.cidNumber != cidNumber ||
        loginContext.accountId != identity.accountId) {
      throw const SquarePublishException('Cloudflare 登录挑战与当前发布身份不一致');
    }
    // 会话握手 = 非用户动权 → P-256 硬件子钥静默签名 signing_message(0x1B) 摘要，后端 ES256 验。
    // P-256 子钥按 CID 隔离，与冷热钱包签名方式无关。
    final raw = await _deviceSubkey.signRawHex(cidNumber, loginMessage);
    return '0x$raw';
  }

  Future<Uint8List> signChain(Uint8List payload) {
    // 发布上链 = 动钱动权 → 读硬件金库 seed 时弹一次生物识别验证。
    return _sign(
      payload: payload,
      action: QrActions.chain(
        SquareChainService.palletIndex,
        SquareChainService.publishPostCallIndex,
      ),
      requestPrefix: 'square-post-',
    );
  }

  Future<Uint8List> _sign({
    required Uint8List payload,
    required int action,
    required String requestPrefix,
  }) async {
    final accountId = identity.accountId;
    if (accountId.isEmpty) {
      throw const SquarePublishException('当前钱包信息不完整');
    }
    try {
      return await _walletAccountSigner.sign(
        context: context,
        accountId: accountId,
        signMode: identity.signMode,
        payload: payload,
        action: action,
        requestPrefix: requestPrefix,
      );
    } on WalletAuthException catch (error) {
      throw SquarePublishException(error.message);
    }
  }
}
