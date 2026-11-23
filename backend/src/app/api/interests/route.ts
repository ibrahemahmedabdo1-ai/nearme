import { handle, json } from "@/lib/http";
import { q } from "@/lib/db";
export const GET = handle(async () => json({ interests: await q("SELECT slug,name_en,name_ar FROM interests ORDER BY slug") }));
