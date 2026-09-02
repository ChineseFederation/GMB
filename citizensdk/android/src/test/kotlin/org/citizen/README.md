# CitizenSDK package tests

The `sdk/` child contains unit tests for the Flutter codec, session registry,
and secure-wallet-flow bridge. Keeping them in the production package allows
testing package-visible helpers without widening the public Android API.
