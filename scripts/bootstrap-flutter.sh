#!/usr/bin/env bash
# Generates Android platform folders for the three apps and patches them (targetSdk 36, minSdk 26, release signing,
# FLAG_SECURE for the customer app). Requires Flutter >= 3.27 stable on YOUR machine. Run once after cloning.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
command -v flutter >/dev/null || { echo "Flutter not found. Install from https://docs.flutter.dev/get-started/install"; exit 1; }
declare -A IDS=( [customer]=app.nearme.customer [admin]=app.nearme.admin [support]=app.nearme.support )
declare -A NAMES=( [customer]="NEAR ME" [admin]="NEAR ME Admin" [support]="NEAR ME Support" )
(cd "$ROOT/mobile/packages/near_me_core" && flutter pub get)
(cd "$ROOT/mobile/packages/near_me_support" && flutter pub get)
for app in customer admin support; do
  dir="$ROOT/mobile/apps/$app"; pushd "$dir" >/dev/null
  had_test=0; [ -d test ] && had_test=1
  [ -d android ] || flutter create --platforms=android --org "${IDS[$app]%.*}" --project-name "near_me_${app}$([ $app = support ] && echo _app)" .
  [ $had_test = 1 ] || rm -rf test   # flutter create adds a default test that references MyApp and would fail analyze
  flutter pub get
  GRADLE="android/app/build.gradle.kts"; [ -f "$GRADLE" ] || GRADLE="android/app/build.gradle"
  python3 "$ROOT/scripts/patch_android.py" "$GRADLE" "${IDS[$app]}" "${NAMES[$app]}" "$app"
  popd >/dev/null
done
echo "Done. Next: scripts/generate-upload-keystore.sh, then scripts/build-all.sh"
