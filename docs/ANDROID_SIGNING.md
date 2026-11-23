# Android signing & Play App Signing
1. On YOUR computer run `scripts/generate-upload-keystore.sh` (creates one **upload** key per app in `~/.nearme-keys`, outside the repo; exports the public certificate PEM).
2. Back up `~/.nearme-keys` (password manager + offline copy). Never commit/upload `.jks`, `key.properties`, or passwords. `.gitignore` already excludes them.
3. In Play Console, create each app and **opt in to Play App Signing**; Google holds the app signing key. Upload only the `.aab` signed with your upload key.
4. `scripts/build-all.sh` builds with `--obfuscate --split-debug-info` and copies `mapping.txt`; upload mapping and native debug symbols (Play Console → App bundle explorer / Deobfuscation files).
5. Versioning: bump `version: x.y.z+N` in each `pubspec.yaml`; `N` (versionCode) must increase on every upload.
6. CI signing (optional): store keystore as base64 secret, decode to `$RUNNER_TEMP`, write `key.properties`, build, delete. Never expose it as an artifact.
7. If `patch_android.py` printed WARN lines, set manually in `android/app/build.gradle(.kts)`: `compileSdk=36`, `targetSdk=36`, `minSdk=26`, release `signingConfig` from `key.properties`, `ndk.debugSymbolLevel="FULL"`.
