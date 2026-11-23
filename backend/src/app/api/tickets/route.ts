import { handle, json, auth, body, str, rateLimit } from "@/lib/http";
import { q } from "@/lib/db";
export const POST = handle(async (r) => {
  const c = await auth(r); rateLimit(r, "ticket", 10, 86_400_000, c.sub);
  const b = await body(r, x => ({ subject: str(x.subject, "subject", 3, 150), text: str(x.text, "text", 3, 4000) }));
  const t = (await q<{ id: string }>("INSERT INTO tickets(user_id,subject) VALUES ($1,$2) RETURNING id", [c.sub, b.subject]))[0];
  await q("INSERT INTO ticket_messages(ticket_id,author,identity,body) VALUES ($1,$2,'customer',$3)", [t.id, c.sub, b.text]);
  return json({ ticket_id: t.id }, 201);
});
