import { handle, json, auth } from "@/lib/http";
import { q } from "@/lib/db";
export const GET = handle(async (r) => { await auth(r); return json({ stickers: await q("SELECT id,name_en,name_ar,payload,animated FROM cosmetic_items WHERE kind='sticker' AND active ORDER BY id") }); });
