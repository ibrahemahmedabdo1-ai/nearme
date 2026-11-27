#!/usr/bin/env bash
# Fail closed before any production Android build if AdMob identifiers are missing or are Google's test IDs.
set -euo pipefail

required=(ADMOB_APP_ID ADMOB_BANNER_ID ADMOB_INTERSTITIAL_ID ADMOB_REWARDED_ID)
for name in "${required[@]}"; do
  value="${!name:-}"
  if [[ -z "$value" ]]; then
    echo "::error::$name is required for a production build."
    exit 1
  fi
  if [[ "$value" == *"3940256099942544"* || "$value" == *"YOUR_"* || "$value" == *"PLACEHOLDER"* ]]; then
    echo "::error::$name contains a Google test ID or placeholder; production builds are blocked."
    exit 1
  fi
done

[[ "$ADMOB_APP_ID" =~ ^ca-app-pub-[0-9]{16}~[0-9]{10}$ ]] || {
  echo "::error::ADMOB_APP_ID has an invalid AdMob app ID format."
  exit 1
}
for name in ADMOB_BANNER_ID ADMOB_INTERSTITIAL_ID ADMOB_REWARDED_ID; do
  value="${!name}"
  [[ "$value" =~ ^ca-app-pub-[0-9]{16}/[0-9]{10}$ ]] || {
    echo "::error::$name has an invalid AdMob ad unit ID format."
    exit 1
  }
done

echo "Production AdMob identifiers are present and do not match Google's test IDs."
