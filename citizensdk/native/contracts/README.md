# CitizenSDK Core Contracts

本 crate 是 CitizenSDK Rust Core 的唯一依赖合同层。它只定义稳定的数据语义和对象安全
接口，不实现轻节点、sr25519、平台金库、Flutter 或任何产品业务。

依赖方向固定为：

```text
Engine -> Contracts <- smoldot / sr25519 / OS vault / typed stores
```

## 安全边界

- `VerifiedChainClient` 只提供带块身份的类型化链能力，不提供任意
  `rpc(method, params)` 逃逸接口。
- `RuntimeContext` 始终把 runtime version、transaction version、metadata 与同一个
  `VerifiedBlockRef` 绑定。
- `SecretVault` 只负责系统金库保护、解锁与密文信封；`ChainSigner` 才负责 sr25519。
- `SecretBuffer` 不实现 `Clone` 或序列化，`Debug` 永远脱敏，底层字节由 `Zeroizing`
  在生命周期结束时擦除。API 只直接借给同步 Rust 闭包；闭包 provider 仍属于受信任
  进程边界，必须审查其不复制秘密，不能把这一接口夸大成同进程硬隔离。
- 五个数据存储合同分别保存轻节点数据库、runtime cache、钱包公开资料、交易历史和
  已加密秘密；加上 `SecretVault` 共六个隔离边界。没有通用 `put(key, bytes)`。
- `EncryptedSecretBlobStore` 的类型系统只接受 `EncryptedSecretEnvelope`，不能接收明文
  助记词、mini-secret 或私钥。

## 异步与对象安全

所有 provider/store trait 返回 `ContractFuture` 或 `ContractStream`，因此可以作为
`dyn Trait` 由 Engine 组合，不依赖 Tokio、Flutter isolate 或某个平台线程模型。错误先使用
Rust 合同类别；稳定 C ABI 数字错误码在后续 `native/ffi` 中单独冻结，不能提前混为一层。

`import_state` 的“仅启动前、身份一致、格式一致、finalized 且不倒退”属于 Engine 必须再次
执行的安全门禁；provider 即使也检查，Engine 也不能信任它替自己完成验证。
