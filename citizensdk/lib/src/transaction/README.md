# 公民链交易

本目录保留旧 Dart 交易实现作为归档差分测试基线。它只通过本机 smoldot 轻节点读取
finalized 状态、获取 runtime nonce、构造并提交公民链 extrinsic。SDK 不提供远程 RPC 代理，
也不包含 CitizenApp 的服务端签名交易中继。

Android、iOS 与 macOS 正式公共 API 均不再导出或调用本目录。`CitizenTransactions` 通过高层 Core ABI 完成
构造、Rust 内 sr25519 签名、pending-before-broadcast、提交、watch 和 finalized Runtime
执行核验；Dart 永远收不到 signed extrinsic 或 Core result handle。

在线交易固定使用 immortal era；nonce 每次签名前从 runtime 实时读取，不缓存、不自增。
金额真源为整数分 `BigInt`，宿主界面的元/小数转换不得进入交易编码层。

runtime version 与 metadata 必须固定在同一 finalized/目标块，并以 `specVersion` 作为缓存
身份；前一代 in-flight 迟到不得覆盖新 registry。手续费只解码 metadata 的
`OnchainFeeRate` 与 `OnchainMinFee`，按 runtime 的 Perbill、u128 饱和与 half-up 规则计算。

余额读取解码 finalized `System.Account` 的 free/reserved/total。批量入口规范化并去重
AccountId/公民 SS58 对应的 storage key，只发起一次轻节点 batch storage 请求，再按原始输入
顺序和重复项重建结果；传输错误不能伪装成零余额。

交易池状态只提供包含线索，最终成功仍由同块 `System.Events` 的
`ExtrinsicSuccess/Failed` 决定。状态回调与订阅取消是 best-effort 观察边界；同步或异步异常
不能阻塞清理、泄漏未处理错误或制造第二个终态。

标准移动装配在广播前把本机签名交易持久化为 pending，再交给轻节点广播；写入失败且回读
没有完整事实时禁止广播，避免链上已有交易而本地没有记录。交易池 `invalid/usurped` 保存为
无块锚的 `poolRejected`，链上 `ExtrinsicFailed` 则必须携带 finalized 块、extrinsic index
和结构化 DispatchError；后续明确链上证据优先于交易池拒绝线索。

`FinalizedTransactionScanner` 只扫描 finalized 块。首次纳入的账户从当时 finalized 高度开始，
不读取加入前历史；已有持久游标重启后每批最多补 120 块并继续调度。每个块的转账、pending
终态和逐账户游标通过一次 CAS 提交，任何 metadata、事件、块体或仓储错误都不推进游标。
本机 txHash 被同 index 的明确 System outcome 认领后不重复生成转出流水，接收方流水仍保留。
并发启动共享同一初始化 Future；停止通过代际信号脱离不可取消 RPC，并在所有 listener、连接
和已进入的仓储任务真实收口后返回。
