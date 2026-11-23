import { handle, json, auth } from "@/lib/http";
import { q } from "@/lib/db";
/** Daily challenges. Progress is computed from REAL activity in the database (never trusted from the client). Rewards are free, non-cash cosmetics. */
export const GET = handle(async (r) => {
  const c = await auth(r);
  const rows = await q<any>(`SELECT d.id,d.metric,d.target,d.title_en,d.title_ar,d.reward_item,
      CASE d.metric
        WHEN 'likes_sent' THEN (SELECT count(*)::int FROM swipes WHERE from_user=$1 AND kind IN ('like','super_like') AND created_at::date=CURRENT_DATE)
        WHEN 'messages_sent' THEN (SELECT count(*)::int FROM messages WHERE sender_id=$1 AND sent_at::date=CURRENT_DATE)
        WHEN 'profile_bio_set' THEN (SELECT (bio IS NOT NULL)::int FROM users WHERE id=$1)
        WHEN 'daily_login' THEN 1 END AS progress,
      EXISTS(SELECT 1 FROM challenge_claims cc WHERE cc.user_id=$1 AND cc.challenge_id=d.id AND cc.day=CURRENT_DATE) AS claimed
    FROM daily_challenges d WHERE d.active ORDER BY d.id`, [c.sub]);
  return json({ challenges: rows.map((x: any) => ({ ...x, progress: Math.min(x.progress, x.target), completed: x.progress >= x.target })) });
});
