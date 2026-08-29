# Android native tests

These source-only unit tests lock the deterministic alias namespaces and the
stable CitizenApp envelope parser. They intentionally avoid AndroidKeyStore;
hardware properties require signed physical-device release validation.

No Gradle task was run when these tests were added.
