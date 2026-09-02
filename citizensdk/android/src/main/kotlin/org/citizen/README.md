# Citizen namespace

The `citizen/` level owns Android code shipped by the independent CitizenSDK
product. The child `sdk/` package contains the Flutter-only projection. Wallet,
vault, JNI, and lifecycle behavior come from the shared `android/native`
facade compiled by the root source set.
