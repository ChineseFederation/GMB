# Android device contracts

Instrumentation validates JNI ABI loading, exact SQLite CAS, lifecycle cleanup
and fail-closed hardware vault behavior. A signed test on a physical device
with StrongBox or TEE and enrolled strong biometrics is required for a positive
vault result; emulator results may only prove failure closure.

