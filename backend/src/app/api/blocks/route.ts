import { handle, json, auth, body, str, HttpError } from "@/lib/http";
import { q } from "@/lib/db";
export const POST = handle(async (r) => {
  const c = await auth(r); const { target } = await body(r, x => ({ target: str(x.target_user, "target_user", 36, 36) }));
  if (target === c.sub) throw new HttpError(422, "invalid_target");
  await q("INSERT INTO blocks(blocker,blocked) VALUES ($1,$2) ON CONFLICT DO NOTHING", [c.sub, target]);
  return json({ ok: true }, 201);
});
export const DELETE = handle(async (r) => {
  const c = await auth(r); const { target } = await body(r, x => ({ target: str(x.target_user, "target_user", 36, 36) }));
  await q("DELETE FROM blocks WHERE blocker=$1 AND blocked=$2", [c.sub, target]); return json({ ok: true });
});
