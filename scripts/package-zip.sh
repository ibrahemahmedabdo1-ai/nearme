#!/usr/bin/env bash
# Creates a clean source ZIP (no secrets, no build output).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; OUT="${1:-$ROOT/../near-me-source.zip}"
cd "$ROOT/.." && rm -f "$OUT" && zip -qr "$OUT" "$(basename "$ROOT")" -x '*/node_modules/*' '*/.next/*' '*/build/*' '*/.dart_tool/*' '*/dist/*' '*.jks' '*.keystore' '*key.properties' '*/.env' '*/.env.local'
echo "$OUT"; unzip -l "$OUT" | tail -1
