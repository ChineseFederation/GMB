# CitizenSDK 公共模型

本目录只定义应用可以安全持有的公民链公开事实：账户、能力、链状态、钱包公开资料、签名和
交易结果。模型不包含助记词、password、mini-secret、私钥、DEK、原生句柄、结果句柄或已签名
extrinsic。

跨 Flutter channel 的整数合同不依赖 Kotlin `Long` 或 JavaScript 安全整数范围。所有 u64、
u128、时间戳和块高先以十进制字符串传输，再在 Dart 中恢复为 `BigInt`。AccountId 与哈希固定为
`0x` 加 64 位小写十六进制；公开字节使用 `Uint8List`。
