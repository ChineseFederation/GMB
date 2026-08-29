# Kademlia k-bucket 说明

`kbuckets.rs` 实现轻节点的 Kademlia 邻居分桶，与父模块 `src/network/kademlia.rs` 配套。
它处理公开 PeerId、连接状态和节点发现，不保存钱包、公民账户或管理员私钥。

源码保持与 CitizenApp 已验证来源逐字节一致；本 README 仅补充目录职责。
