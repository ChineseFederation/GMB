# 公民链 smoldot PoW 快照

本目录收编 CitizenApp 当前使用的 smoldot PoW + GRANDPA 轻节点源码。内部 workspace 只含
`lib` 与 `light-base`。`Cargo.lock` 从 CitizenApp 已验证 workspace 锁机械裁掉全节点与 WASM
成员不可达闭包，并固定所有保留 registry 包的来源 name/version/checksum。

生产源码、公开夹具与上游内联测试按来源复制；只对 workspace、crate 入口和 identity 模块
进行轻客户端最小适配。SDK 新增来源 manifest 与能力边界测试，钉死复制集合和排除项。

不收编全节点 `author` 出块、identity keystore 或 seed phrase 解析。保留的
`identity::ss58` 只处理公钥地址；用户密钥只由 CitizenSDK signer 与设备安全金库管理。
libp2p Noise 密钥只用于单连接传输握手，不持久化。

上游提交、本地 PoW 改动和同步规则见相邻 `UPSTREAM.md`。CI/Release 不得回指 CitizenApp。
