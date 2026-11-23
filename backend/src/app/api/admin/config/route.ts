import { handle, json, requirePermission, body, str, HttpError, audit, clientIp } from "@/lib/http";
import { q } from "@/lib/db";
// App Builder backend: DATA-ONLY remote config with draft -> publish -> rollback. It can never ship executable code.
const FORBIDDEN_KEYS = /^(script|code|eval|function|dex|js|html)$/i;
function assertDataOnly(v: unknown, depth = 0) {
  if (depth > 8) throw new Error("too_deep");
  if (v && typeof v === "object") for (const [k, x] of Object.entries(v)) { if (FORBIDDEN_KEYS.test(k)) throw new Error("executable_content_not_allowed"); assertDataOnly(x, depth + 1); }
  if (typeof v === "string" && /<script|javascript:/i.test(v)) throw new Error("executable_content_not_allowed");
}
export const GET = handle(async (r) => {
  await requirePermission(r, "config.edit");
  const scope = new URL(r.url).searchParams.get("scope") ?? "app";
  return json({ versions: await q("SELECT id,scope,state,payload,created_by,created_at,published_at FROM config_versions WHERE scope=$1 ORDER BY id DESC LIMIT 50", [scope]) });
});
export const POST = handle(async (r) => {
  const c = await requirePermission(r, "config.edit");
  const b = await body(r, x => {
    if (!["draft", "publish", "rollback"].includes(x.action)) throw new Error("invalid_action");
    if (x.action === "draft") { const s = JSON.stringify(x.payload ?? null); if (s.length > 65_536) throw new Error("payload_too_large"); assertDataOnly(x.payload); }
    return { action: x.action as string, scope: x.scope ? str(x.scope, "scope", 1, 40) : "app", payload: x.payload, id: Number.isInteger(x.id) ? (x.id as number) : null };
  });
  if (b.action === "draft") {
    const row = (await q<{ id: number }>("INSERT INTO config_versions(scope,state,payload,created_by) VALUES ($1,'draft',$2,$3) RETURNING id", [b.scope, JSON.stringify(b.payload), c.sub]))[0];
    await audit(c, "config.draft", { type: "config", id: String(row.id) }, {}, clientIp(r)); return json({ id: row.id }, 201);
  }
  const v = (await q<any>("SELECT * FROM config_versions WHERE id=$1 AND scope=$2", [b.id, b.scope]))[0];
  if (!v) throw new HttpError(404, "not_found");
  if (b.action === "publish" && v.state !== "draft") throw new HttpError(409, "not_a_draft");
  // publish = make this draft live; rollback = re-publish an older version's payload as a NEW published version
  const payload = JSON.stringify(v.payload);
  const newId = b.action === "publish" ? v.id : (await q<{ id: number }>("INSERT INTO config_versions(scope,state,payload,created_by) VALUES ($1,'draft',$2,$3) RETURNING id", [b.scope, payload, c.sub]))[0].id;
  await q("UPDATE config_versions SET state='rolled_back' WHERE scope=$1 AND state='published'", [b.scope]);
  await q("UPDATE config_versions SET state='published',published_at=now() WHERE id=$1", [newId]);
  await q("INSERT INTO app_config(key,value,updated_by) VALUES ($1,$2,$3) ON CONFLICT (key) DO UPDATE SET value=EXCLUDED.value,updated_by=EXCLUDED.updated_by,updated_at=now()", [`builder.${b.scope}`, payload, c.sub]);
  await audit(c, `config.${b.action}`, { type: "config", id: String(newId) }, { from: b.id }, clientIp(r));
  return json({ published_id: newId });
});
