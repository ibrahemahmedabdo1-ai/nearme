#!/usr/bin/env bash
# Restore a dump into the target DB. DESTRUCTIVE: drops existing objects. Requires typing the database name to confirm.
# Usage: DATABASE_URL=... scripts/restore.sh backup.dump
set -euo pipefail
: "${DATABASE_URL:?DATABASE_URL required}"; f="${1:?dump file required}"
sha256sum -c "$f.sha256" || { echo "checksum mismatch -- refusing"; exit 1; }
db="$(psql "$DATABASE_URL" -qAt -c 'select current_database()')"
if [ "${RESTORE_CONFIRM:-}" != "$db" ]; then read -r -p "Type the database name ($db) to confirm: " a; [ "$a" = "$db" ] || { echo aborted; exit 1; }; fi
pg_restore --clean --if-exists --no-owner --no-privileges -d "$DATABASE_URL" "$f"
echo "restored into $db"
