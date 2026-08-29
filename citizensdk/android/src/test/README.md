# Android native tests

These unit tests lock the deterministic CitizenSDK alias namespace and the
stable hardware-vault envelope parser. CI and Release execute them through the
generated Flutter Android host's `:citizen_sdk:testDebugUnitTest` task. They
intentionally avoid AndroidKeyStore; hardware properties still require signed
physical-device release validation.

The Kotlin tests live at `kotlin/org/citizen/sdk/`, exactly mirroring the
`org.citizen.sdk` production package required by Flutter plugin discovery.
