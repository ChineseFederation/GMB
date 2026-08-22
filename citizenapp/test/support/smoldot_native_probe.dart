// libsmoldot native 库探测（Chat MLS 与链 RPC 共用同一 .so/.dylib）。
//
// 背景：依赖 native 的测试必须先为当前宿主编译 libsmoldot；官方 CitizenApp CI
// 统一入口 `scripts/citizenapp-test.sh` 会在 `flutter test` 前构建并逐符号验收
// host 库。开发者绕过入口直接执行 `flutter test` 而本机没有宿主库时，dlopen 会失败。
//
// 本探测器让非官方的无库测试环境在「库不可用」时 **skip(带原因)**：不是删测试。
// 真机 / APK 集成构建里 .so 随包，官方 CI 则显式编译宿主库；一轮只 dlopen
// 探一次，结果缓存。
//
// **本地必须真跑一遍**:skip 只是「这轮没验」,不是「验过了」。改 FFI 两侧任一
// (`rust/src/chat_mls.rs` / `lib/chat/crypto/mls_native.dart`)后,必须先产宿主库
// 再跑,否则跨语言字段名漂移会被 skip 静默掩盖 —— 2026-08-04 定位的
// `device_public_key_hex` 读侧断链(设备公钥恒空,Chat 首启必抛)就是这么潜伏的:
//
//   ./scripts/citizenapp-test.sh \
//     test/chat/mls_native_test.dart test/chat/mls_native_session_test.dart
//
// 设备构建会 `cargo clean` 整个 rust/target；统一测试入口与 `citizenapp-run.sh`
// 已共用跨进程锁，设备构建不得在测试中途删除宿主库。设备构建完成后下一次测试入口仍会
// 自动重建 host 库，不依赖历史产物。

import 'package:citizenapp/chat/crypto/mls_native.dart';

bool _probed = false;
String? _reason;

/// libsmoldot native 库的 skip 原因:可加载→`null`(测试照跑);不可加载→文案(skip)。
///
/// 直接传给 `test(..., skip: smoldotNativeSkipReason())` / `testWidgets(..., skip: ...)`。
String? smoldotNativeSkipReason() {
  if (_probed) return _reason;
  _probed = true;
  try {
    // NativeMlsCrypto() 构造即 dlopen libsmoldot(与链 RPC 同一库);成功=库可用。
    NativeMlsCrypto();
    _reason = null;
  } on Object catch (_) {
    _reason = 'libsmoldot native 库不可用；请改用 '
        './scripts/citizenapp-test.sh 运行测试';
  }
  return _reason;
}
