import { handle, json, auth, HttpError } from "@/lib/http";
import { q } from "@/lib/db";
export const POST = handle(async (r, { params }) => {
  const c = await auth(r); const { id } = await params;
  const d = (await q<any>(`SELECT d.reward_item,d.target,CASE d.metric
        WHEN 'likes_sent' THEN (SELECT count(*)::int FROM swipes WHERE from_user=$1 AND kind IN ('like','super_like') AND created_at::date=CURRENT_DATE)
        WHEN 'messages_sent' THEN (SELECT count(*)::int FROM messages WHERE sender_id=$1 AND sent_at::date=CURRENT_DATE)
        WHEN 'profile_bio_set' THEN (SELECT (bio IS NOT NULL)::int FROM users WHERE id=$1) ELSE 1 END AS progress
      FROM daily_challenges d WHERE d.id=$2 AND d.active`, [c.sub, id]))[0];
  if (!d) throw new HttpError(404, "not_found");
  if (d.progress < d.target) throw new HttpError(409, "not_completed");
  const ins = await q("INSERT INTO challenge_claims(user_id,challenge_id,day) VALUES ($1,$2,CURRENT_DATE) ON CONFLICT DO NOTHING RETURNING 1", [c.sub, id]);   // PK = one claim per day, race-safe
  if (!ins.length) throw new HttpError(409, "already_claimed");
  if (d.reward_item) await q("INSERT INTO user_items(user_id,item_id,source) VALUES ($1,$2,'challenge') ON CONFLICT DO NOTHING", [c.sub, d.reward_item]);
  return json({ reward_item: d.reward_item });
});
