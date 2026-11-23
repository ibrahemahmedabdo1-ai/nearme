import { handle, json, requirePermission, body, HttpError, audit, clientIp } from "@/lib/http";
import { q } from "@/lib/db";
import { DEFAULT_WEIGHTS } from "@/domain/matching";
export const GET = handle(async (r) => { await requirePermission(r, "config.edit"); return json({ weights: (await q<{ value: unknown }>("SELECT value FROM app_config WHERE key='matching.weights'"))[0]?.value ?? DEFAULT_WEIGHTS }); });
export const PUT = handle(async (r) => {
  const c = await requirePermission(r, "config.edit");
  const w = await body(r, x => { const o: Record<string, number> = {}; for (const k of Object.keys(DEFAULT_WEIGHTS)) { if (typeof x[k] !== "number" || x[k] < 0 || x[k] > 100) throw new Error("invalid_" + k); o[k] = x[k]; } if (Object.values(o).reduce((a, b) => a + b, 0) <= 0) throw new Error("weights_sum_zero"); return o; });
  await q("INSERT INTO app_config(key,value,updated_by) VALUES ('matching.weights',$1,$2) ON CONFLICT (key) DO UPDATE SET value=EXCLUDED.value,updated_by=EXCLUDED.updated_by,updated_at=now()", [JSON.stringify(w), c.sub]);
  await audit(c, "matching.weights", undefined, w, clientIp(r)); return json({ weights: w });
});
