# 公民链交易

本目录只通过本机 smoldot 轻节点读取 finalized 状态、获取 runtime nonce、构造并提交
公民链 extrinsic。SDK 不提供远程 RPC 代理，也不包含 CitizenApp 的服务端签名交易中继。

在线交易固定使用 immortal era；nonce 每次签名前从 runtime 实时读取，不缓存、不自增。
金额真源为整数分 `BigInt`，宿主界面的元/小数转换不得进入交易编码层。
