# Android Flutter projection tests

These unit tests lock the v1 Flutter method/event field closure, public-only
codec, request sequencing, configuration-change rebinding, supervised detach,
and SDK-owned wallet-flow routing. CI and Release execute them through the
generated Flutter Android host's `:citizen_sdk:testDebugUnitTest` task.

The Kotlin tests live at `kotlin/org/citizen/sdk/`, exactly mirroring the
`org.citizen.sdk` production package required by Flutter plugin discovery.
