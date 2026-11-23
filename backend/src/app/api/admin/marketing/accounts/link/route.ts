import { handle, json, requirePermission, body, HttpError } from "@/lib/http";
import { env } from "@/lib/env";
import { OAUTH, configured, signState, type Platform } from "@/lib/oauth";
/** Starts the OFFICIAL OAuth flow for a platform. 501 until that platform's app credentials are configured. No passwords are ever handled. */
export const POST = handle(async (r) => {
  const c = await requirePermission(r, "marketing.manage");
  const { platform } = await body(r, x => { if (!(x.platform in OAUTH)) throw new Error("invalid_platform"); return { platform: x.platform as Platform }; });
  if (!configured(platform)) throw new HttpError(501, "platform_api_not_configured");
  const o = OAUTH[platform]; const redirect = `${env("APP_PUBLIC_URL")}/api/admin/marketing/accounts/callback`;
  const url = `${o.auth}?client_id=${encodeURIComponent(process.env[o.idVar]!)}&redirect_uri=${encodeURIComponent(redirect)}&response_type=code&scope=${encodeURIComponent(o.scope)}&state=${encodeURIComponent(signState(c.sub, platform))}`;
  return json({ authorize_url: url });
});
