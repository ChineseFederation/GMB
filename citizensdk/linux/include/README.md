# Linux public headers

`citizensdk_host.h` is the Linux Host C ABI. The remaining headers form a
header-only C++17 convenience layer over that ABI and the canonical root
`citizensdk.h`. No C++ symbol is part of CitizenSDK's compatibility promise.

Every pointer returned by CitizenSDK remains governed by its declaring C ABI.
Raw C observers must release each Rust result exactly once. The official C++
`EventObserver` instead borrows the result only during the callback: it may
inspect or copy synchronously, but the C++ trampoline performs the one release
on every return path, so the observer must neither retain nor release it.
