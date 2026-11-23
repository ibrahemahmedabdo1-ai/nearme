#!/usr/bin/env bash
# Run on YOUR computer. Creates the upload keystore OUTSIDE the repo. Never commit or share the .jks or passwords.
set -euo pipefail
OUT="${1:-$HOME/.nearme-keys}"; mkdir -p "$OUT"; chmod 700 "$OUT"
for app in customer admin support; do
  KS="$OUT/nearme-$app-upload.jks"
  if [ -f "$KS" ]; then echo "exists: $KS (skipping)"; continue; fi
  echo "== $app upload key =="; read -r -s -p "Choose a strong keystore password for $app: " PW; echo
  keytool -genkeypair -v -keystore "$KS" -alias upload -keyalg RSA -keysize 4096 -validity 9125 -storepass "$PW" -keypass "$PW" -dname "CN=NEAR ME $app, O=YOUR COMPANY, C=EG"
  keytool -export -rfc -keystore "$KS" -alias upload -storepass "$PW" -file "$OUT/nearme-$app-upload-cert.pem"   # certificate only: safe to share with Google Play Console if asked
  printf 'storeFile=%s\nstorePassword=%s\nkeyAlias=upload\nkeyPassword=%s\n' "$KS" "$PW" "$PW" > "$OUT/$app.key.properties"; chmod 600 "$OUT/$app.key.properties"
  cp "$OUT/$app.key.properties" "$(dirname "$0")/../mobile/apps/$app/android/key.properties" 2>/dev/null || echo "run bootstrap-flutter.sh first, then copy $OUT/$app.key.properties to mobile/apps/$app/android/key.properties"
done
echo "BACK UP $OUT in two safe places (password manager + offline). Losing the upload key requires a Play Console reset request."
