import { json } from "@/lib/http";
import { q } from "@/lib/db";
export const dynamic = "force-dynamic";
export async function GET() {
  try { await q("SELECT 1"); return json({ status: "ok", db: "up", time: new Date().toISOString() }); }
  catch { return json({ status: "degraded", db: "down" }, 503); }
}
