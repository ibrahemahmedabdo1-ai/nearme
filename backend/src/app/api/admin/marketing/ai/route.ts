import { handle, json, requirePermission, body, str, HttpError } from "@/lib/http";
import { getProviders } from "@/providers";
/** AI Content Studio / Marketing Analyst. Advisory: output is a suggestion a human edits and approves. 501 until an AI provider is configured. */
export const POST = handle(async (r) => {
  await requirePermission(r, "marketing.manage");
  const b = await body(r, x => { if (!["draft_post", "analyze_campaign"].includes(x.task)) throw new Error("invalid_task"); return { task: x.task as string, text: str(x.input, "input", 1, 4000) }; });
  const a = await getProviders().ai.analyze("marketing_" + b.task, { text: b.text });
  if (!a.ok) throw new HttpError(501, "ai_not_configured"); return json({ advisory: true, result: a.data });
});
