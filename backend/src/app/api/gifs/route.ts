import { handle, json, auth, HttpError, rateLimit } from "@/lib/http";
/** GIF search through a provider (GIPHY). 501 until GIPHY_API_KEY is configured. The client sends the chosen https GIF URL as a 'gif' message. */
export const GET = handle(async (r) => {
  const c = await auth(r); rateLimit(r, "gif", 60, 60_000, c.sub);
  const key = process.env.GIPHY_API_KEY; if (!key || key === "none") throw new HttpError(501, "gif_provider_not_configured");
  const term = (new URL(r.url).searchParams.get("q") ?? "").slice(0, 60);
  const res = await fetch(`https://api.giphy.com/v1/gifs/${term ? "search" : "trending"}?api_key=${encodeURIComponent(key)}&limit=24&rating=pg&q=${encodeURIComponent(term)}`);
  if (!res.ok) throw new HttpError(502, "gif_provider_error");
  const d: any = await res.json(); return json({ gifs: (d.data ?? []).map((g: any) => ({ id: g.id, url: g.images?.fixed_height?.url, preview: g.images?.fixed_height_small?.url })).filter((g: any) => typeof g.url === "string") });
});
