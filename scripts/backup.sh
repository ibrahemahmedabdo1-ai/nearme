#!/usr/bin/env bash
# Manual database backup (custom-format dump + SHA-256). Usage: DATABASE_URL=... scripts/backup.sh [outdir]
set -euo pipefail
: "${DATABASE_URL:?DATABASE_URL required}"
out="${1:-./backups}"; mkdir -p "$out"
f="$out/nearme-$(date -u +%Y%m%dT%H%M%SZ).dump"
pg_dump --format=custom --no-owner --no-privileges "$DATABASE_URL" -f "$f"
sha256sum "$f" > "$f.sha256"
pg_restore --list "$f" >/dev/null   # sanity: archive is readable
echo "OK $f"; cat "$f.sha256"
