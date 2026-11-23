#!/usr/bin/env bash
# Checks native libs in an AAB/APK are 16 KB page-size aligned (Play requirement). Uses Android SDK build-tools zipalign.
set -euo pipefail
f="${1:?path to .apk}"; "$ANDROID_HOME"/build-tools/*/zipalign -c -P 16 -v 4 "$f" | tail -3
