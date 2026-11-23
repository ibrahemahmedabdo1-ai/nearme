import { str } from "./http";
/** Validates an occasion payload (shared by create and update routes). */
export function occasionInput(x: any) {
  const iso = (v: unknown, n: string, optional = false) => { if (v == null && optional) return null; const d = new Date(String(v)); if (isNaN(+d)) throw new Error("invalid_" + n); return d.toISOString(); };
  const list = (v: unknown, n: string, re: RegExp) => { if (v == null) return null; if (!Array.isArray(v) || v.length > 100 || v.some(e => typeof e !== "string" || !re.test(e))) throw new Error("invalid_" + n); return v as string[]; };
  const msg = x.message; if (!msg || typeof msg !== "object" || typeof msg.en !== "string" || typeof msg.ar !== "string" || msg.en.length > 300 || msg.ar.length > 300) throw new Error("invalid_message");
  return { name: str(x.name, "name", 2, 80), starts: iso(x.starts_at, "starts_at"), ends: iso(x.ends_at, "ends_at", true), recurrence: ["none", "yearly"].includes(x.recurrence ?? "none") ? (x.recurrence ?? "none") : (() => { throw new Error("invalid_recurrence"); })(),
    countries: list(x.countries, "countries", /^[A-Za-z]{2}$/)?.map(s => s.toUpperCase()) ?? null, languages: list(x.languages, "languages", /^(ar|en)$/), message: msg, push: x.send_push === true, inApp: x.send_in_app !== false, theme: x.theme_id ?? null, audience: x.audience && typeof x.audience === "object" ? x.audience : {}, image: x.image_key ?? null };
}
