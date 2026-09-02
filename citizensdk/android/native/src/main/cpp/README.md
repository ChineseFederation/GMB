# Private JNI bridge

`citizensdk_host_bridge.*` owns the versioned C host vtables and their Kotlin
contexts. `citizensdk_jni.cpp` is the only JNI export unit. The bridge calls the
single `libcitizensdk.so`; it never includes smoldot or signer entry points.

The DEK wrap input and unwrap output are exposed to the private Kotlin vault as
direct `ByteBuffer` views over Rust-owned memory. Completion is exactly once,
and the Kotlin side must stop accessing each view before invoking the native
completion method.

