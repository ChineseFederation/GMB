# trie_root_calculator 测试说明

`tests.rs` 是上游 trie root 计算器的单元测试模块，与父模块
`src/executor/trie_root_calculator.rs` 配套。它验证 runtime storage overlay 生成的 trie
变化，不处理钱包密钥或产品业务。

测试源码保持与 CitizenApp 已验证来源逐字节一致；本 README 仅补充目录职责。
