#!/usr/bin/env bash
# Builds APK (local testing) and AAB (Play) + obfuscation symbols + checksums into ./dist. Requires: Flutter, Android SDK, key.properties for release.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; API="${API_BASE_URL:?set API_BASE_URL=https://your-app.vercel.app}"; DIST="$ROOT/dist"; mkdir -p "$DIST"
for app in customer admin support; do
  d="$ROOT/mobile/apps/$app"; [ -d "$d/android" ] || { echo "run scripts/bootstrap-flutter.sh first"; exit 1; }
  (cd "$d" && flutter test && flutter build apk --release --dart-define=API_BASE_URL="$API" --obfuscate --split-debug-info="$DIST/symbols-$app" \
     && flutter build appbundle --release --dart-define=API_BASE_URL="$API" --obfuscate --split-debug-info="$DIST/symbols-$app")
  cp "$d/build/app/outputs/flutter-apk/app-release.apk" "$DIST/nearme-$app.apk"
  cp "$d/build/app/outputs/bundle/release/app-release.aab" "$DIST/nearme-$app.aab"
  [ -f "$d/build/app/outputs/mapping/release/mapping.txt" ] && cp "$d/build/app/outputs/mapping/release/mapping.txt" "$DIST/mapping-$app.txt" || true
done
(cd "$DIST" && sha256sum *.apk *.aab > SHA256SUMS.txt)
echo "Artifacts in $DIST. Upload the .aab files to Play Console (Internal testing first)."
