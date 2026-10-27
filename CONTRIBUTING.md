# Contributing to Duck

Duck is a fork of [LocalSend](https://github.com/localsend/localsend). This guide covers working on it; [AGENTS.md](AGENTS.md) describes the architecture.

## Run

Install [Flutter](https://flutter.dev) via [fvm](https://fvm.app) (version in [.fvmrc](.fvmrc)) and [Rust](https://www.rust-lang.org/tools/install), then:

```shell
cd app
fvm flutter pub get
fvm dart run build_runner build -d
fvm dart run slang
fvm flutter run
```

## Checks

The same as CI ([.github/workflows/ci.yml](.github/workflows/ci.yml)):

```shell
cd app
fvm dart format --set-exit-if-changed lib test
fvm flutter analyze
fvm flutter test

cd ../packages/core
cargo test --features full
cargo clippy --features full
```

Formatting is 150 columns. Generated Dart (`lib/gen`) is not format-checked.

## Testing tap to share

Tap to share needs two real Android phones with NFC; the emulator has none.

1. Pair both phones over wireless debugging (*Developer options → Wireless debugging → Pair device with QR code*).
2. Install on both: `adb -s <device> install -r app/build/app/outputs/flutter-apk/app-debug.apk`. Debug builds use the package `app.duck.share.debug`.
3. Watch the exchange: `adb -s <device> logcat -s TapShare flutter`.
4. To test with the app closed: `adb shell input keyevent KEYCODE_HOME && adb shell am kill app.duck.share.debug`.

On Pixel phones, turn off Google's *Tap to Share* first; it competes for NFC.

## Translations

Add new strings to `app/assets/i18n/en.json` only, then run `fvm dart run slang`. The other locale files come from LocalSend and may lag behind; missing keys fall back to English.

Fields starting with `@` are notes for translators and are not used by the app.

## Branding

The logo and every platform icon are generated from one script, see [support/branding](support/branding/README.md). Edit `duck.py`, then run `python support/branding/export.py app`. Brand colors: Pond blue `#1E6FD9`, ink `#1C1B1F`.

## Guidelines

- Keep code formatted and covered by tests where it has logic worth testing.
- Write descriptive commit messages (Conventional Commits: `feat:`, `fix:`, …).
- Pull requests target `main`.

## Bug reports and security issues

Report bugs in the [issue tracker](https://github.com/n1th1n-19/duck/issues). Report security issues privately via [GitHub security advisories](https://github.com/n1th1n-19/duck/security/advisories/new), not in a public issue.

## Pulling changes from LocalSend

The original project is the `upstream` remote:

```shell
git fetch upstream
git merge upstream/main
```

Expect conflicts in the rebranded files (app name, icons, `applicationId`, i18n). Duck keeps LocalSend's internal identifiers (method channel names, settings keys, the Kotlin package `org.localsend.localsend_app`) so that merges stay small.

## Notes

### Compile a release APK

Release builds need a signing key. Create `app/android/key.properties` with your keystore, or sign with the debug key:

```groovy
// File: app/android/app/build.gradle
buildTypes {
  release {
    signingConfig signingConfigs.debug // using debug signing
  }
}
```

### Bump Flutter

Suppose we want to update Flutter to `3.41.9`:

1. Update Flutter from fvm: `fvm use 3.41.9`
2. Update Flutter from the submodule:
   1. `git submodule update --init`
   2. `cd support/submodules/flutter`
   3. `git fetch`
   4. `git checkout 3.41.9`
   5. `cd ../../..`
   6. `git add support/submodules/flutter`
3. Update the Flutter constraints:
   1. In CI: `.github/workflows/ci.yml`
   2. In pubspec: `pubspec.yaml`

### Release

`app/pubspec.yaml`'s version must match `#define MyAppVersion` in `support/scripts/compile_windows_exe-inno.iss` and the `version` in `cli/Cargo.toml`; CI fails on a mismatch. The "Release Draft" workflow ([release.yml](.github/workflows/release.yml)) builds the binaries; arm64 Linux binaries need a self-hosted runner.
