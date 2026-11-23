import { handle, json, auth, HttpError } from "@/lib/http";
import { q } from "@/lib/db";
export const DELETE = handle(async (r, { params }) => { const c = await auth(r); const { id } = await params; const x = await q("UPDATE sessions SET revoked_at=now() WHERE id=$1 AND user_id=$2 AND revoked_at IS NULL RETURNING id", [id, c.sub]); if (!x.length) throw new HttpError(404, "not_found"); return json({ ok: true }); });
