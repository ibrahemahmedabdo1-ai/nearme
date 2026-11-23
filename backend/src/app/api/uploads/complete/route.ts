import { handle, json, auth, body, str, HttpError } from "@/lib/http";
import { q } from "@/lib/db";
import { getProviders } from "@/providers";
/** Step 3 of an upload: run the malware scan. Without a configured scanner the file stays 'pending' and can never be sent (fail closed). */
export const POST = handle(async (r) => {
  const c = await auth(r); const { id } = await body(r, x => ({ id: str(x.attachment_id, "attachment_id", 36, 36) }));
  const a = (await q<any>("SELECT storage_key,scan_status FROM attachments WHERE id=$1 AND owner_id=$2", [id, c.sub]))[0]; if (!a) throw new HttpError(404, "not_found");
  if (a.scan_status !== "pending") return json({ scan_status: a.scan_status });
  const s = await getProviders().malware.scan(a.storage_key);
  if (!s.ok) { if (s.reason === "not_configured") throw new HttpError(501, "malware_scanner_not_configured"); await q("UPDATE attachments SET scan_status='error' WHERE id=$1", [id]); return json({ scan_status: "error" }, 502); }
  await q("UPDATE attachments SET scan_status=$2 WHERE id=$1", [id, s.data.verdict]);
  if (s.data.verdict === "infected") await q("INSERT INTO security_events(user_id,kind,detail) VALUES ($1,'infected_upload',$2)", [c.sub, JSON.stringify({ attachment: id })]);
  return json({ scan_status: s.data.verdict });
});
