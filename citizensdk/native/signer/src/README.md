# Source baseline note

`lib.rs` 是从 GMB 稳定 signer 导入的逐字节生产基线。文件中的历史共享调用关系属于来源
注释，不形成 CitizenSDK 对原目录的运行时依赖。

测试和 CitizenSDK 说明放在相邻独立文件，避免为改名而改写密码学基线。任何行为修改都必须
同时审查来源策略、向量、FFI 错误契约和零化路径。
