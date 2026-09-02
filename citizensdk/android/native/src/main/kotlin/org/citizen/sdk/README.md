# CitizenSDK Kotlin facade

The classes in this directory are public, Java-callable projections of the
stable Core ABI. Public values contain chain facts, wallet public profiles,
signatures and verified transaction outcomes only. All numeric chain values
whose width exceeds a signed JVM integer retain exact unsigned decimal or
`CitizenU128` representation.

