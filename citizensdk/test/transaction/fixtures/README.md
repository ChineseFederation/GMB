# System events metadata fixture

`substrate-v14-system-events-metadata.hex` 是只用于交易执行确认测试的
Substrate v14 runtime metadata 快照，SHA-256 为
`95b368e7907511b28ba283a6741f4be551b56fb917c2f0183b4143dbe0ebf95b`。

它逐字节复制自 CitizenApp 已验证源码中的
`smoldot/pow/full-node/tests/substrate-node-template-metadata.hex`，只提供
`System.Event`、`Phase`、`DispatchInfo` 等 SCALE 类型结构。CitizenSDK 不复制、
编译或开放全节点出块实现；该测试数据也不进入运行时信任锚或链 RPC 配置。

`citizenchain-runtime-v14-metadata.hex` 与
`citizenchain-runtime-system-events.hex` 是同一次生产 CitizenChain `Runtime` 编码得到的
成对夹具，SHA-256 分别为：

- `da62207dfa342ce5285bb214a116761fd0a38c7c329ab8953506ad52471ed681`
- `2c4d04a69ff994622877786d481dc4780b7a32795e5f7cfa070ae4acb72679ef`

生成时把 `/Users/rhett/GMB/citizenchain` 只读复制到
`/Users/rhett/Only/tataconsole/target/citizensdk/.work`，临时 example 直接调用生产
`Runtime::metadata_at_version(14)`，并以生产 `RuntimeEvent` 编码
`Vec<EventRecord<RuntimeEvent, H256>>`。事件固定为：同一 extrinsic index 0 的
`Balances.Transfer`、`OnchainTransaction.TransferWithRemark` 与
`System.ExtrinsicSuccess`，以及 index 1 的 `System.ExtrinsicFailed(BadOrigin)`。发送方为
`0x11` 重复 32 字节，接收方为 `0x22` 重复 32 字节，金额为 `123456`，备注为
`CitizenSDK production Runtime fixture`。

复现时必须继续在上述 TataConsole 隔离目录中使用 CitizenChain 固定 `Cargo.lock` 和
`rust-toolchain.toml`，把 `CARGO_TARGET_DIR` 指向
`/Users/rhett/Only/tataconsole/target/citizensdk/.work/runtime-fixture/cargo-target`，连续生成两次并逐字节比较 metadata、events 后
再更新两份 SHA。不得为生成夹具修改真实 CitizenChain runtime，也不得把 Cargo 产物写入
CitizenSDK 源码树。这两份文件只证明生产 metadata/event 的 SCALE 解码合同，不是随包链资产。
