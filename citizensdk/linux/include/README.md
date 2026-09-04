# Linux public headers

`citizensdk_host.h` is the Linux Host C ABI. The remaining headers form a
header-only C++17 convenience layer over that ABI and the canonical root
`citizensdk.h`. No C++ symbol is part of CitizenSDK's compatibility promise.

`citizen_sdk_plugin.h` is the one Flutter generated-registrant declaration for
the Linux adapter registered as `CitizenSdkPlugin`. Native C/C++ installation excludes this header;
it adds no product ABI, Core symbol, wallet API or secret-bearing type.

第 7.4 步候选将根 `citizensdk.h`、`citizensdk_types.h` 原字节投影到本目录，并合并两种平台
共用的 7 个原生 Host/C++ 头；任何重叠文件必须字节一致。Hosted 另保留上述 Flutter 注册头，
合计 10 个头，不携带 Host 私有头。源码目录不保存生成的根头副本或运行库；实际 Linux
平台验证仍由后续统一 GitHub CI/Release 执行。

Every pointer returned by CitizenSDK remains governed by its declaring C ABI.
Raw C observers must release each Rust result exactly once. The official C++
`EventObserver` instead borrows the result only during the callback: it may
inspect or copy synchronously, but the C++ trampoline performs the one release
on every return path, so the observer must neither retain nor release it.
