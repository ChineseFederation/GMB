# Kotlin production source layout

Flutter validates an Android plugin's main class at the directory derived from
the package declared in `pubspec.yaml`. CitizenSDK therefore keeps production
Kotlin under `org/citizen/sdk/`; moving either source back to this directory
would make a consuming Flutter application reject the plugin before Gradle
compilation.

