# Flutter Kotlin projection

Flutter validates an Android plugin's main class at the directory derived from
the package declared in `pubspec.yaml`. CitizenSDK therefore keeps production
Flutter projection code under `org/citizen/sdk/`.

The product implementation is not copied here. Gradle compiles the exact public
facade from `android/native/src/main/kotlin` into this library through one
source set. This directory owns only channel codecs, session coordination,
secure-wallet-flow projection, and Flutter lifecycle registration.

`CitizenSdkFlutterCodec`, `CitizenSdkFlutterSessions`, and
`CitizenSdkFlutterWalletFlow` are deliberately separate: tuple validation has
no Android UI side effect, session ownership never sees recovery material, and
only the wallet-flow bridge may launch the SDK-owned secure Activity.
