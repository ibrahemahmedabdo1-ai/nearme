import { q } from "./db";
/** Behavioral badges are computed from real activity, never self-assigned. Idempotent. */
export async function awardBehavioralBadges(userId: string): Promise<string[]> {
  const s = (await q<any>(`SELECT
      (SELECT count(*)::int FROM users WHERE created_at <= (SELECT created_at FROM users WHERE id=$1) AND role='customer') AS member_rank,
      date_part('day', now()-(SELECT created_at FROM users WHERE id=$1))::int AS age_days,
      (SELECT count(*)::int FROM reports WHERE target_user=$1 AND status='actioned') AS upheld,
      (SELECT coalesce(avg(stars),0)::float FROM ratings WHERE ratee=$1) AS avg_rating, (SELECT count(*)::int FROM ratings WHERE ratee=$1) AS n_ratings,
      (SELECT count(*)::int FROM messages WHERE sender_id=$1) AS msgs,
      (SELECT count(DISTINCT conversation_id)::int FROM messages WHERE sender_id=$1) AS convs`, [userId]))[0];
  const earned: string[] = [];
  if (s.member_rank <= 1000) earned.push("badge_early");
  if (s.age_days >= 30 && s.upheld === 0 && s.n_ratings >= 1 && s.avg_rating >= 4) earned.push("badge_respectful");
  if (s.msgs >= 50 && s.convs >= 5) earned.push("badge_friendly");
  for (const b of earned) await q("INSERT INTO user_items(user_id,item_id,source) VALUES ($1,$2,'behavior') ON CONFLICT DO NOTHING", [userId, b]);
  return earned;
}
