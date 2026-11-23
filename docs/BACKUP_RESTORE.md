# Backup & restore (manual, Owner-authorized only)
Backup (database): `pg_dump --format=custom --no-owner "$DATABASE_URL" -f nearme-$(date +%F).dump && sha256sum nearme-*.dump`
Restore into a NEW Neon branch/database first: `createdb`/new branch → `pg_restore --no-owner -d "$NEW_URL" nearme.dump` → run `npm run test:db` style checks (row counts, `SELECT count(*) FROM users`) → only then repoint `DATABASE_URL`.
Files: sync the object-storage bucket with `rclone`/`aws s3 sync` to a second bucket. Settings: `COPY app_config/themes/ad_config TO ...`.
Never run backups/restores from automation without the Owner; record each in `backups` and `audit_log`.
