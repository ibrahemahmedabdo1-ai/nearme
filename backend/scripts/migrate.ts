// Usage: DATABASE_URL=... npm run migrate   (uses psql so no extra deps; ships with Neon tooling)
import { readdirSync, readFileSync } from "node:fs";
import { createHash } from "node:crypto";
import { spawnSync } from "node:child_process";
const url = process.env.DATABASE_URL; if (!url) { console.error("DATABASE_URL required"); process.exit(1); }
const psql = (sql: string, extra: string[] = []) => spawnSync("psql", [url, "-v", "ON_ERROR_STOP=1", "-qAt", ...extra, "-c", sql], { encoding: "utf8" });
const q = psql("CREATE TABLE IF NOT EXISTS schema_migrations(name text PRIMARY KEY, checksum text NOT NULL, applied_at timestamptz NOT NULL DEFAULT now())");
if (q.status) { console.error(q.stderr); process.exit(1); }
const dir = new URL("../migrations/", import.meta.url);
for (const f of readdirSync(dir).filter(f => f.endsWith(".sql")).sort()) {
  const body = readFileSync(new URL(f, dir), "utf8"); const sum = createHash("sha256").update(body).digest("hex");
  const prev = psql(`SELECT checksum FROM schema_migrations WHERE name='${f}'`).stdout.trim();
  if (prev) { if (prev !== sum) { console.error(`CHECKSUM MISMATCH for applied migration ${f}`); process.exit(2); } continue; }
  const tx = `BEGIN;\n${body}\nINSERT INTO schema_migrations(name,checksum) VALUES ('${f}','${sum}');\nCOMMIT;`;
  const r = spawnSync("psql", [url, "-v", "ON_ERROR_STOP=1", "-q"], { input: tx, encoding: "utf8" });
  if (r.status) { console.error(`FAILED ${f}\n${r.stderr}`); process.exit(1); }
  console.log(`applied ${f}`);
}
console.log("migrations up to date");
