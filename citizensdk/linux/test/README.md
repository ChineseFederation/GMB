# CitizenSDK Linux Host 合同测试

本目录只测试 LinuxARM、LinuxAMD 共用 Host 投影，不复制 Rust Core 的账户、钱包、轻节点、
sr25519 或交易测试。测试目标直接编译对应 Host 生产源码，并通过根产品头验证相同 C ABI。

测试范围：

- `citizen_sdk_api_contract_test.cc`：ABI 版本、稳定枚举、固定宽度布局、Host 函数闭集、非法
  config、`application_id/citizensdk/v1` 状态隔离，以及构建期/安装期唯一 Core 与
  `CitizenSDK::Host` CMake 导出合同；同时冻结统一 closing admission、公开 API lease、callback/
  parent 线性化和 destroy 前资源退休；
- `citizen_sdk_assets_test.cc`：三项 CitizenChain 资产闭集、普通文件与路径失败关闭；
- `citizen_sdk_host_operation_test.cc`：Core 前预分配 completion handler、接受后无分配绑定、
  exact-once completion、96 路并发同步早回调无损路由，以及无人认领 result 释放；
- `citizen_sdk_lifecycle_test.cc`：单调 teardown、失败重试和借用上下文存活；
- `citizen_sdk_public_store_test.cc`：chain/history CAS、runtime cache 隔离、openat SQLite VFS
  路径替换抵抗、精确 schema/PRAGMA/COMMIT、0700/0600、符号链接/hardlink/非普通节点拒绝、
  有效 UID 所有权合同和损坏 revision/blob 失败关闭；
- `citizen_sdk_record_key_test.cc`：generation/owner/account 与 block hash 的精确 record key，
  并拒绝旧 `citizenapp` 标签；
- `citizen_sdk_secure_store_test.cc`：profile/secret CAS、generation retirement 与条件 Vault
  object 写线性化、openat VFS 和精确 schema/PRAGMA/COMMIT，以及 secure DB/全部 sidecar 的
  私有权限、符号链接/hardlink/非普通节点拒绝和损坏 revision/blob 失败关闭；
- `citizen_sdk_sensitive_buffer_test.cc`：不可复制、移动所有权和显式清零；
- `citizen_sdk_secret_vault_test.cc`：Vault availability、错误 wallet/generation 拒绝、retire 与
  迟到 provision 互斥、长认证提示后 retirement 重验、明文 DEK 输出失败清零与永久退休；
- `citizen_sdk_secret_boundary_test.cc`：Linux 新增的 Host/C++ 公共头闭集不另造助记词、口令、
  DEK 或私钥旁路；根产品 C ABI 的明确备份/恢复合同仍由根测试冻结；
- `citizen_sdk_tpm2_test.cc`：device-only TPM 对象策略、完整 child public template、DA lockout/
  真实层级 availability、固定 v1 KDF、认证会话、认证 UI 启动/输入超时及无硬件失败关闭；
- `citizen_sdk_wallet_flow_test.cc`：创建/导入/追加 canonical 门禁、Core/Vault/能力拒绝、result
  ownership、取消/close 互斥、GTK owner-thread 终态清理及 parent-destroy 立即退休。

所有需要磁盘状态的用例共用 `citizen_sdk_test_support.hpp`。配置测试时，调用方必须通过
`-DCITIZENSDK_TEST_WORK_DIR=<绝对路径>` 注入一个已经存在、本次任务独占、有效 UID 所有且
权限精确为 `0700` 的工作根；本机该路径必须位于
`/Users/rhett/TATA/tataconsole/target/citizensdk` 下。CMake 把同名环境变量注入每个 CTest，
helper 再逐级以 no-follow 方式验证该根，才用系统 CSPRNG 生成 128-bit 随机名称，并只通过
已验证目录 fd 的 `mkdirat` 创建 `0700` 子目录。清理始终持有目录 fd，并只通过
`openat`/`unlinkat` 处理已验证的精确 inode；不存在 `/tmp`、当前
目录或用户目录 fallback，也不会对可预测路径执行递归删除。

Linux 主流程会以 Release 配置编译合同测试。测试目标统一使用 `-UNDEBUG`，且每个测试翻译
单元都在发现 `NDEBUG` 时直接编译失败，确保标准 `assert` 不会被 Release 配置静默移除。

第 7.1 步仅提交这些测试源码，没有运行 CMake、CTest、Linux 编译、软件 TPM、实体 TPM、Git、
远程 CI 或 Release。软件 TPM 后续只作为确定性集成覆盖，不能替代 LinuxARM、LinuxAMD 实体
TPM 验收。
