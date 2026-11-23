import { handle, json, auth, body, HttpError } from "@/lib/http";
import { q } from "@/lib/db";
export const POST = handle(async (r, { params }) => {
  const c = await auth(r); const { id } = await params;
  const { accept } = await body(r, x => { if (typeof x.accept !== "boolean") throw new Error("invalid_accept"); return { accept: x.accept as boolean }; });
  // Only the RECIPIENT (not the initiator) can answer, only while pending.
  const row = await q("UPDATE conversations SET intro_status=$3 WHERE id=$1 AND intro_status='pending' AND initiator<>$2 AND $2 IN (user_a,user_b) RETURNING id", [id, c.sub, accept ? "accepted" : "rejected"]);
  if (!row.length) throw new HttpError(404, "not_found");
  return json({ intro_status: accept ? "accepted" : "rejected" });
});
