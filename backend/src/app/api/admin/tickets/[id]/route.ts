import { handle, json, requirePermission, body, str, HttpError, audit, clientIp } from "@/lib/http";
import { q } from "@/lib/db";
const IDENTITIES = ["support", "admin", "anonymous"];
export const GET = handle(async (r, { params }) => {
  await requirePermission(r, "tickets.read"); const { id } = await params;
  return json({ messages: await q("SELECT id,identity,internal_note,body,created_at FROM ticket_messages WHERE ticket_id=$1 ORDER BY created_at", [id]) });
});
export const POST = handle(async (r, { params }) => {
  const c = await requirePermission(r, "tickets.reply"); const { id } = await params;
  const b = await body(r, x => ({ body: str(x.body, "body", 1, 4000), internal_note: x.internal_note === true, identity: IDENTITIES.includes(x.identity) ? (x.identity as string) : "support" }));
  // Which identities a staff member may speak as is Owner-controlled; "anonymous" requires explicit setting.
  if (b.identity === "anonymous") { const a = await q("SELECT value FROM app_config WHERE key='support.allow_anonymous_identity'"); if (a[0]?.value !== true && c.role !== "owner") throw new HttpError(403, "identity_not_allowed"); }
  if (b.identity === "admin" && c.role === "support") throw new HttpError(403, "identity_not_allowed");
  await q("INSERT INTO ticket_messages(ticket_id,author,identity,internal_note,body) VALUES ($1,$2,$3,$4,$5)", [id, c.sub, b.identity, b.internal_note, b.body]);
  await audit(c, "ticket.reply", { type: "ticket", id }, { identity: b.identity, internal: b.internal_note }, clientIp(r));
  return json({ ok: true }, 201);
});

export const PATCH = handle(async (r, { params }) => {
  const c = await requirePermission(r, "tickets.reply"); const { id } = await params;
  const b = await body(r, x => { if (!["open", "pending", "escalated", "closed"].includes(x.status)) throw new Error("invalid_status"); return { status: x.status as string }; });
  const u = await q("UPDATE tickets SET status=$2 WHERE id=$1 RETURNING id", [id, b.status]); if (!u.length) throw new HttpError(404, "not_found");
  await audit(c, "ticket.status", { type: "ticket", id }, { status: b.status }, clientIp(r)); return json({ ok: true });
});
