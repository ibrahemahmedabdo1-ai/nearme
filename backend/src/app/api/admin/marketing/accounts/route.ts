import { handle, json, requirePermission, body, str, HttpError, audit, clientIp } from "@/lib/http";
import { q } from "@/lib/db";
export const GET = handle(async (r) => { await requirePermission(r, "marketing.manage"); return json({ accounts: await q("SELECT id,platform,external_id,display_name,status,linked_at,expires_at FROM social_accounts ORDER BY linked_at DESC") }); });   // tokens are never returned
export const DELETE = handle(async (r) => {
  const c = await requirePermission(r, "marketing.manage"); const { id } = await body(r, x => ({ id: str(x.id, "id", 36, 36) }));
  const u = await q("UPDATE social_accounts SET status='unlinked',token_enc='',refresh_token_enc=NULL WHERE id=$1 RETURNING id", [id]); if (!u.length) throw new HttpError(404, "not_found");
  await audit(c, "marketing.account_unlink", { type: "social_account", id }, {}, clientIp(r)); return json({ ok: true });
});
