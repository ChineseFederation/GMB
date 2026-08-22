//! CitizenWallet 冷钱包原生密码学库。
//!
//! 本 crate 只调用两个共享 crate 的导出宏：`citizen-signer` 生成四个 sr25519
//! 入口，`account-crypto` 生成四个用途钥派生/加密交付入口。两者均与 CitizenApp
//! **共用同一份源码**，这里绝不允许另写任何密码学实现。
//!
//! 冷钱包永久离线，除签名外仅在扫码时派生并加密交付账户用途钥；产物仍是独立小库，
//! 不包含轻节点或链上业务。
//!
//! 符号检查（注意平台差异，用错标志会误判为 0）：
//! - Android/ELF   `llvm-nm -D libcitizenwallet_signer.so    | grep -c citizen_sr25519` 应为 4
//! - iOS/Mach-O    `llvm-nm -g libcitizenwallet_signer.dylib | grep -c citizen_sr25519` 应为 4
//! - 两个平台 `grep -c account_crypto_` 均应为 4

citizen_signer::export_citizen_signer_ffi!();
// 冷端用途钥派生与交付使用共享实现，禁止在 CitizenWallet 另写密码学分支。
account_crypto::export_account_crypto_ffi!();
