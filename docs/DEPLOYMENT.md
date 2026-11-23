# Deployment: Neon + Vercel

## 1. Neon
1. Create a project at neon.com; copy the **pooled** connection string (`?sslmode=require`).
2. Locally: `export DATABASE_URL='postgresql://...'; cd backend; npm run migrate` (requires `psql`). The runner applies `migrations/*.sql` in order inside transactions and records checksums; editing an applied migration aborts with an error.
3. Optional dev data only: `psql "$DATABASE_URL" -f scripts/seed-dev.sql` (interests + disabled ad placements). Do not use dev seeds for anything else in production.
4. Create the Owner: set `OWNER_BOOTSTRAP_TOKEN`, `DATA_ENCRYPTION_KEY`, `OWNER_EMAIL`, `OWNER_PASSWORD` (>=14 chars) and run `node --experimental-strip-types scripts/bootstrap-owner.ts`. Save the printed TOTP secret in an authenticator immediately. Then unset the token.

## 2. Vercel
1. Push the repo to GitHub. In Vercel: New Project → import → **Root Directory: `backend`**.
2. Environment variables: copy every key from `backend/.env.example` (Production + Preview). Generate secrets with `openssl rand -base64 48` / `openssl rand -base64 32`.
3. Deploy. Verify `https://<project>.vercel.app/api/health` returns `{"status":"ok","db":"up"}`.
4. Public pages for Play Console: `/privacy`, `/terms`, `/child-safety`, `/delete-account`.
5. Build apps with `API_BASE_URL=https://<project>.vercel.app scripts/build-all.sh`.

## Limits & costs (verify current pricing before launch — they change)
- Vercel Hobby is for non-commercial use; a commercial/ads-supported app needs Pro. Serverless functions have execution time limits; long-lived WebSockets are not supported → use a managed realtime provider (Ably/Pusher).
- Neon free tier has storage/compute caps and scale-to-zero cold starts; paid plans for production.
- Object storage (Cloudflare R2 / S3), FCM (free), email provider, AI provider, malware scanning: usage-based; estimate per active user before launch.
- Social APIs (Meta, TikTok, X) require app review; X API access is paid.

## Production migration rule
Forward-only. Add a new numbered file; never edit an applied one. Test on a Neon branch first (`neon branches` are cheap copy-on-write).

## GitHub
```
cd near-me && git init && git add -A && git commit -m "Initial import"
git branch -M main && git remote add origin git@github.com:<you>/near-me.git && git push -u origin main
```
`.gitignore` already excludes keystores, `key.properties`, `.env*`, build output. Add repository secrets only for CI signing (optional).

## Local verification before deploying
`cd backend && npm install && TEST_PG_URL=postgresql:///postgres npm run test:all` (needs PostgreSQL + psql locally).
Set `CRON_SECRET` in Vercel; `vercel.json` already schedules `/api/cron/occasions` every 15 minutes.
