import { handle, json, auth, body, HttpError } from "@/lib/http";
import { q } from "@/lib/db";
export const PUT = handle(async (r) => {
  const c = await auth(r);
  const { slugs } = await body(r, x => { if (!Array.isArray(x.slugs) || x.slugs.length > 10 || x.slugs.some((s: unknown) => typeof s !== "string" || s.length > 40)) throw new Error("invalid_slugs"); return { slugs: x.slugs as string[] }; });
  const found = await q<{ id: number }>("SELECT id FROM interests WHERE slug = ANY($1::text[])", [slugs]);
  if (found.length !== new Set(slugs).size) throw new HttpError(422, "unknown_interest");
  await q("DELETE FROM user_interests WHERE user_id=$1", [c.sub]);
  for (const f of found) await q("INSERT INTO user_interests(user_id,interest_id) VALUES ($1,$2)", [c.sub, f.id]);
  return json({ ok: true });
});
