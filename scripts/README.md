# Release Build Scripts

Always use these scripts for App Store / Play Store submissions.
They enable Dart obfuscation and tree shaking automatically.

## iOS (App Store / TestFlight)

```bash
cd foundry-app/flutter
./scripts/build_ios_release.sh
```

Output:
- IPA: `build/ios/ipa/`
- Debug symbols: `build/debug-info/ios/`

## Android (Play Store)

```bash
cd foundry-app/flutter
./scripts/build_android_release.sh
```

Output:
- AAB: `build/app/outputs/bundle/release/`
- Debug symbols: `build/debug-info/android/`

## Why obfuscation matters

- Dart code is compiled to native ARM — obfuscation renames internal symbols
- Makes reverse engineering harder
- Reduces binary size slightly via `--tree-shake-icons`
- Required for production releases

## Debug symbols

Keep `build/debug-info/` on your machine after each release build.
These are needed to decode stack traces from crash reports.
They are excluded from git via `.gitignore`.

If using Firebase Crashlytics, upload them after each release:
```bash
firebase crashlytics:symbols:upload --app=<APP_ID> build/debug-info/ios/
```
