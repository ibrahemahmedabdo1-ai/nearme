// Test shim for src/lib/db.ts: executes parameterized SQL on local PostgreSQL through psql using PREPARE/EXECUTE
// (same parameter type inference as the real extended protocol). Production uses @neondatabase/serverless.
import { spawnSync } from "node:child_process";
const lit = (v: unknown): string => {
  if (v === null || v === undefined) return "NULL";
  if (typeof v === "number" || typeof v === "boolean") return String(v);
  if (Array.isArray(v)) return `'{${v.map(x => `"${String(x).replace(/(["\\])/g, "\\$1")}"`).join(",")}}'`;
  const s = typeof v === "object" ? JSON.stringify(v) : String(v);
  return `'${s.replace(/\0/g, "").replace(/'/g, "''")}'`;
};
export async function q<T = Record<string, unknown>>(text: string, params: unknown[] = []): Promise<T[]> {
  const url = process.env.DATABASE_URL!; const t = text.trim();
  const returns = /^(select|with)\b/i.test(t) || /\breturning\b/i.test(t);
  const wrapped = !returns ? t : /^(select|with)\b/i.test(t) ? `SELECT coalesce(json_agg(t),'[]'::json) FROM (${t}) t` : `WITH t AS (${t}) SELECT coalesce(json_agg(t),'[]'::json) FROM t`;
  const sql = params.length ? `PREPARE s AS ${wrapped};\nEXECUTE s(${params.map(lit).join(",")});` : `${wrapped};`;
  const r = spawnSync("psql", [url, "-X", "-qAt", "-v", "ON_ERROR_STOP=1"], { input: `\\set VERBOSITY verbose\n${sql}`, encoding: "utf8", maxBuffer: 64 * 1024 * 1024 });
  if (r.status !== 0) { const m = /ERROR:\s+([0-9A-Z]{5}):\s*(.*)/.exec(r.stderr); const e: any = new Error(m ? m[2] : r.stderr); e.code = m?.[1]; throw e; }
  if (!returns) return [];
  return JSON.parse(r.stdout.trim() || "[]") as T[];
}
