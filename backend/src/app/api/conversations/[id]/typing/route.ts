import { handle, json, auth, HttpError, rateLimit } from "@/lib/http";
import { q } from "@/lib/db";
export const POST = handle(async (r, { params }) => {
  const c = await auth(r); rateLimit(r, "typing", 120, 60_000, c.sub); const { id } = await params;
  if (!(await q("SELECT 1 FROM conversations WHERE id=$1 AND $2 IN (user_a,user_b) AND intro_status<>'rejected'", [id, c.sub])).length) throw new HttpError(404, "not_found");
  await q("INSERT INTO typing_state(conversation_id,user_id,until) VALUES ($1,$2, now()+interval '6 seconds') ON CONFLICT (conversation_id,user_id) DO UPDATE SET until=EXCLUDED.until", [id, c.sub]);
  return json({ ok: true });
});
