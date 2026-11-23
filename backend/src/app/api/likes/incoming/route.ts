import { handle, json, auth } from "@/lib/http";
import { q } from "@/lib/db";
// Members who liked me and whom I have not answered yet (excludes blocked/inactive). Exact location never included.
export const GET = handle(async (r) => {
  const c = await auth(r);
  return json({ likes: await q(`SELECT u.id,u.member_code,u.display_name AS name,date_part('year',age(u.birthdate))::int AS age,s.kind,s.created_at
    FROM swipes s JOIN users u ON u.id=s.from_user
    WHERE s.to_user=$1 AND s.kind IN ('like','super_like') AND u.status='active'
      AND NOT EXISTS (SELECT 1 FROM swipes me WHERE me.from_user=$1 AND me.to_user=s.from_user)
      AND NOT EXISTS (SELECT 1 FROM blocks b WHERE (b.blocker=$1 AND b.blocked=u.id) OR (b.blocker=u.id AND b.blocked=$1))
    ORDER BY s.created_at DESC LIMIT 50`, [c.sub]) });
});
