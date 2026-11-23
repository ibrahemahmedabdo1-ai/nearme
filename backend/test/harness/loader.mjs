// Test-only ESM loader: resolves "@/..." aliases and extensionless imports, and swaps `next/server` and the Neon driver
// for local equivalents so the REAL route handlers run against a REAL local PostgreSQL.
import { existsSync } from "node:fs";
import { fileURLToPath, pathToFileURL } from "node:url";
import { dirname, resolve as pres } from "node:path";
const root = pathToFileURL(pres(dirname(fileURLToPath(import.meta.url)), "../../")).href + "/"; // backend/
const here = (f) => new URL(f, import.meta.url).href;
export async function resolve(spec, ctx, next) {
  if (spec === "next/server") return { url: here("./next-server.ts"), shortCircuit: true };
  if (spec === "@/lib/db") return { url: here("./db.ts"), shortCircuit: true };
  let target = null;
  if (spec.startsWith("@/")) target = new URL("src/" + spec.slice(2), root);
  else if ((spec.startsWith("./") || spec.startsWith("../")) && ctx.parentURL) target = new URL(spec, ctx.parentURL);
  if (target && /\/src\/lib\/db(\.ts)?$/.test(target.pathname)) return { url: here("./db.ts"), shortCircuit: true };
  if (target && !/\.(ts|mjs|js|json)$/.test(target.pathname)) {
    for (const cand of [target.href + ".ts", target.href + "/index.ts"]) if (existsSync(fileURLToPath(cand))) return { url: cand, shortCircuit: true };
  }
  if (target) return next(target.href, ctx);
  return next(spec, ctx);
}
