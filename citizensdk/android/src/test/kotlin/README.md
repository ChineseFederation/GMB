# Kotlin test source layout

Android unit tests mirror the production package at `org/citizen/sdk/` so the
generated Flutter host can compile package-visible Flutter projection
contracts. These files are source tests and never contain Gradle outputs.
