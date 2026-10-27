# Code signing policy

Duck's Windows builds are **not signed**. Windows SmartScreen may warn when you run them; build from source if you prefer.

Android release builds are signed with the maintainer's own key (see [CONTRIBUTING.md](CONTRIBUTING.md#compile-a-release-apk)). Debug builds use the Android debug key and the package `app.duck.share.debug`, so they install next to a release build.

The original LocalSend binaries are signed through SignPath by the LocalSend project; that signing does not cover Duck.

## Privacy

Duck has no servers, accounts or analytics. Files and messages go directly between devices on your local network. Tap to share exchanges only the device alias, port, local IP addresses and certificate fingerprint over NFC.
