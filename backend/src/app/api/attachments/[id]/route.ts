import { handle, json, auth, HttpError } from "@/lib/http";
import { q } from "@/lib/db";
import { getProviders } from "@/providers";
/** Short-lived signed download link. Only the owner or a participant of a conversation where it was sent (and not deleted for everyone). */
export const GET = handle(async (r, { params }) => {
  const c = await auth(r); const { id } = await params;
  const ok = await q(`SELECT 1 FROM attachments a WHERE a.id=$1 AND a.scan_status='clean' AND (a.owner_id=$2 OR EXISTS (SELECT 1 FROM messages m JOIN conversations cv ON cv.id=m.conversation_id WHERE m.attachment_id=a.id AND m.deleted_for_all_at IS NULL AND $2 IN (cv.user_a,cv.user_b) AND cv.intro_status<>'rejected'))`, [id, c.sub]);
  if (!ok.length) throw new HttpError(404, "not_found");
  const key = (await q<{ storage_key: string }>("SELECT storage_key FROM attachments WHERE id=$1", [id]))[0].storage_key;
  const s = await getProviders().storage.presignDownload(key, 120);
  if (!s.ok) throw new HttpError(501, "storage_not_configured"); return json({ url: s.data.url, expires_in: 120 });
});
