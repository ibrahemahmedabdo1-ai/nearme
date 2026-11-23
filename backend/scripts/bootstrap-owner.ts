// One-time Owner creation. Run LOCALLY against the production DATABASE_URL, then delete OWNER_BOOTSTRAP_TOKEN from the environment.
// Usage: OWNER_BOOTSTRAP_TOKEN=... DATABASE_URL=... DATA_ENCRYPTION_KEY=... OWNER_EMAIL=you@x.com OWNER_PASSWORD='...' node --experimental-strip-types scripts/bootstrap-owner.ts
import { spawnSync } from "node:child_process";
import { hashPassword, validatePasswordStrength } from "../src/domain/password.ts";
import { newTotpSecret } from "../src/lib/totp.ts";
import { encrypt } from "../src/lib/crypto.ts";
const need = (k: string) => process.env[k] || (console.error(`missing ${k}`), process.exit(1)) as never;
need("OWNER_BOOTSTRAP_TOKEN"); const url = need("DATABASE_URL"); const key = need("DATA_ENCRYPTION_KEY");
const email = need("OWNER_EMAIL"), pw = need("OWNER_PASSWORD");
const weak = validatePasswordStrength(pw); if (weak || pw.length < 14) { console.error("Owner password must be >= 14 chars with upper, lower, digit"); process.exit(1); }
const secret = newTotpSecret();
const sql = "INSERT INTO users(email,email_verified_at,password_hash,role,display_name,birthdate,totp_secret_enc) VALUES (:'e', now(), :'h', 'owner', 'Owner', '1980-01-01', :'t')";
const r = spawnSync("psql", [url, "-v", "ON_ERROR_STOP=1", "-q", "-v", `e=${email}`, "-v", `h=${await hashPassword(pw)}`, "-v", `t=${encrypt(secret, key)}`], { input: sql, encoding: "utf8" });
if (r.status) { console.error("Owner already exists or DB error:\n" + r.stderr); process.exit(1); }
console.log(`Owner created. Add this TOTP secret to your authenticator app NOW (shown once):\n${secret}\notpauth://totp/NEARME:${encodeURIComponent(email)}?secret=${secret}&issuer=NEARME`);
