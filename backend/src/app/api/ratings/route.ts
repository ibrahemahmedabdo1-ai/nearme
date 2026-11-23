import { handle, json, auth, body, str, HttpError, rateLimit } from "@/lib/http";
import { q } from "@/lib/db";
import { trustScore } from "@/domain/policy";
export const POST = handle(async (r) => {
  const c = await auth(r); rateLimit(r, "rating", 20, 3_600_000, c.sub);
  const b = await body(r, x => { if (!Number.isInteger(x.stars) || x.stars < 1 || x.stars > 5) throw new Error("invalid_stars"); return { ratee: str(x.ratee, "ratee", 36, 36), conv: str(x.conversation_id, "conversation_id", 36, 36), stars: x.stars as number, comment: x.comment ? str(x.comment, "comment", 1, 500) : null }; });
  if (b.ratee === c.sub) throw new HttpError(422, "invalid_target");
  // Genuine interaction only: both members have written in the conversation and it has >= 6 messages.
  const g = (await q<{ senders: number; total: number }>("SELECT count(DISTINCT sender_id)::int AS senders, count(*)::int AS total FROM messages m JOIN conversations cv ON cv.id=m.conversation_id WHERE cv.id=$1 AND $2 IN (cv.user_a,cv.user_b) AND $3 IN (cv.user_a,cv.user_b)", [b.conv, c.sub, b.ratee]))[0];
  if (!g || g.senders < 2 || g.total < 6) throw new HttpError(403, "interaction_required");
  try { await q("INSERT INTO ratings(rater,ratee,conversation_id,stars,comment) VALUES ($1,$2,$3,$4,$5)", [c.sub, b.ratee, b.conv, b.stars, b.comment]); }
  catch (e: any) { if (e?.code === "23505") throw new HttpError(409, "already_rated"); throw e; }
  const s = (await q<any>("SELECT avg(stars)::float AS avg, count(*)::int AS n, (SELECT count(*)::int FROM reports WHERE target_user=$1 AND status='actioned') AS upheld, (SELECT EXISTS(SELECT 1 FROM verifications WHERE user_id=$1 AND status='approved')) AS verified, (SELECT date_part('day', now()-created_at)::int FROM users WHERE id=$1) AS age_days FROM ratings WHERE ratee=$1", [b.ratee]))[0];
  await q("UPDATE users SET trust_score=$2 WHERE id=$1", [b.ratee, trustScore({ verified: s.verified, ratingAvg: s.avg, ratingCount: s.n, reportsUpheld: s.upheld, accountAgeDays: s.age_days })]);
  return json({ ok: true }, 201);
});
