#!/usr/bin/env bash
# Builds signed APK + AAB for all three apps. Requires Flutter, Android SDK, API_BASE_URL,
# configured upload signing keys, and real production AdMob identifiers for Customer.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
API="${API_BASE_URL:?set API_BASE_URL=https://your-production-backend.example}"
DIST="$ROOT/dist"
mkdir -p "$DIST"

case "$API" in
  https://*) ;;
  *) echo "::error::API_BASE_URL must use HTTPS for production builds."; exit 1 ;;
esac

# Do not allow Google's test app/ad unit IDs into a production artifact.
bash "$ROOT/scripts/verify-release-admob.sh"

for app in customer admin support; do
  d="$ROOT/mobile/apps/$app"
  [ -d "$d/android" ] || { echo "run scripts/bootstrap-flutter.sh first"; exit 1; }
  (
    cd "$d"
    flutter analyze --no-fatal-infos --no-fatal-warnings
    flutter test
    if [ "$app" = "customer" ]; then
      flutter build apk --release \
        --dart-define=API_BASE_URL="$API" \
        --dart-define=ADMOB_BANNER_ID="$ADMOB_BANNER_ID" \
        --dart-define=ADMOB_INTERSTITIAL_ID="$ADMOB_INTERSTITIAL_ID" \
        --dart-define=ADMOB_REWARDED_ID="$ADMOB_REWARDED_ID" \
        --obfuscate --split-debug-info="$DIST/symbols-$app"
      flutter build appbundle --release \
        --dart-define=API_BASE_URL="$API" \
        --dart-define=ADMOB_BANNER_ID="$ADMOB_BANNER_ID" \
        --dart-define=ADMOB_INTERSTITIAL_ID="$ADMOB_INTERSTITIAL_ID" \
        --dart-define=ADMOB_REWARDED_ID="$ADMOB_REWARDED_ID" \
        --obfuscate --split-debug-info="$DIST/symbols-$app"
    else
      flutter build apk --release --dart-define=API_BASE_URL="$API" --obfuscate --split-debug-info="$DIST/symbols-$app"
      flutter build appbundle --release --dart-define=API_BASE_URL="$API" --obfuscate --split-debug-info="$DIST/symbols-$app"
    fi
  )
  cp "$d/build/app/outputs/flutter-apk/app-release.apk" "$DIST/nearme-$app.apk"
  cp "$d/build/app/outputs/bundle/release/app-release.aab" "$DIST/nearme-$app.aab"
  [ -f "$d/build/app/outputs/mapping/release/mapping.txt" ] && cp "$d/build/app/outputs/mapping/release/mapping.txt" "$DIST/mapping-$app.txt" || true
done

(cd "$DIST" && sha256sum *.apk *.aab > SHA256SUMS.txt)
echo "Artifacts in $DIST. Upload the .aab files to Play Console (Internal testing first)."
