import { handle, json, requirePermission, body, HttpError, audit, clientIp } from "@/lib/http";
import { q } from "@/lib/db";
import { occasionInput } from "../route";
export const PATCH = handle(async (r, { params }) => {
  const c = await requirePermission(r, "occasions.edit"); const { id } = await params; const o = await body(r, occasionInput);
  const u = await q("UPDATE occasions SET name=$2,starts_at=$3,ends_at=$4,recurrence=$5,countries=$6,languages=$7,image_key=$8,message=$9,send_push=$10,send_in_app=$11,theme_id=$12,audience=$13 WHERE id=$1 RETURNING id", [id, o.name, o.starts, o.ends, o.recurrence, o.countries, o.languages, o.image, JSON.stringify(o.message), o.push, o.inApp, o.theme, JSON.stringify(o.audience)]);
  if (!u.length) throw new HttpError(404, "not_found"); await audit(c, "occasion.update", { type: "occasion", id }, {}, clientIp(r)); return json({ ok: true });
});
export const DELETE = handle(async (r, { params }) => { const c = await requirePermission(r, "occasions.edit"); const { id } = await params; await q("DELETE FROM occasions WHERE id=$1", [id]); await audit(c, "occasion.delete", { type: "occasion", id }, {}, clientIp(r)); return json({ ok: true }); });
