import { handle, json, auth, body, str, rateLimit, HttpError } from "@/lib/http";
import { q } from "@/lib/db";
const CATS = ["harassment","fake_profile","spam","nudity","minor_safety","csae","scam","hate","other"];
export const POST = handle(async (r) => {
  const c = await auth(r); rateLimit(r, "report", 20, 3_600_000, c.sub);
  const b = await body(r, x => ({ target: str(x.target_user, "target_user", 36, 36), category: CATS.includes(x.category) ? (x.category as string) : (() => { throw new Error("invalid_category"); })(), details: x.details ? str(x.details, "details", 1, 2000) : null, message_id: x.message_id ?? null }));
  if (b.target === c.sub) throw new HttpError(422, "invalid_target");
  const rows = await q<{ id: string }>("INSERT INTO reports(reporter,target_user,category,details,message_id) VALUES ($1,$2,$3,$4,$5) RETURNING id", [c.sub, b.target, b.category, b.details, b.message_id]);
  if (b.category === "csae" || b.category === "minor_safety") await q("INSERT INTO security_events(user_id,kind,detail) VALUES ($1,'child_safety_report',$2)", [b.target, JSON.stringify({ report_id: rows[0].id })]);
  return json({ report_id: rows[0].id }, 201);
});
