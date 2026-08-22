import 'package:flutter/material.dart';
import 'package:citizenapp/my/util/screenshot_guard.dart';
import 'package:citizenapp/wallet/core/wallet_manager.dart';
import 'package:citizenapp/ui/app_layout.dart';

/// 本地 Isar/MDBX 繁忙属于钱包数据库问题，不能提示成区块链网络异常。
bool isWalletLocalStoreError(Object? error) {
  final raw = error.toString().toLowerCase();
  return raw.contains('isar') ||
      raw.contains('mdbx') ||
      raw.contains('active transaction') ||
      raw.contains('database');
}

String walletLocalStoreErrorMessage(Object? error) {
  if (isWalletLocalStoreError(error)) {
    return '本地钱包数据库繁忙，请稍后重试';
  }
  return '本地钱包读取失败：$error';
}

String walletOperationErrorMessage(Object error) {
  if (isWalletLocalStoreError(error)) {
    return walletLocalStoreErrorMessage(error);
  }
  return '$error';
}

/// 创建热钱包完整流程：生成密钥并落库 → 防截屏展示助记词备份弹窗。
///
/// 首启强制创建页共用。创建失败向上抛出，由调用方决定错误展示；返回时钱包已落库。
/// 无根模型：助记词**不持久化**，此弹窗是唯一一次展示，关闭即不可再取回——必须手抄
/// 备份或存入公民钱包，否则无法恢复钱包 / 追加其他账户。
Future<WalletCreationResult> runCreateWalletFlow(
  BuildContext context, {
  required int wordCount,
  String password = '',
}) async {
  final created = await WalletManager().createWallet(
    wordCount: wordCount,
    password: password,
  );
  if (!context.mounted) {
    return created;
  }
  await ScreenshotGuard.enable();
  try {
    if (!context.mounted) {
      return created;
    }
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('请备份助记词'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '公民不保存助记词，关闭本弹窗后将无法再次显示。\n'
                '请立即手抄备份，或在「公民钱包」中妥善保管——这是恢复钱包'
                '与追加其他账户的唯一凭证。设置过钱包密码时，还必须单独备份密码。\n'
                '不支持复制，不支持截屏。',
              ),
              SizedBox(height: AppLayout.scaled(context, 12)),
              Text(
                created.mnemonic,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('我已备份'),
            ),
          ],
        );
      },
    );
  } finally {
    // 页面销毁、弹窗抛错或正常关闭都必须释放本流程持有的保护引用。
    await ScreenshotGuard.disable();
  }
  return created;
}
