export type Role = "customer" | "support" | "admin" | "owner";
export const PERMISSIONS = ["tickets.read","tickets.reply","users.read","users.moderate","verification.review","verification.approve","reports.review","punish.warn","punish.suspend","punish.ban","analytics.read","config.edit","themes.edit","occasions.edit","ads.config","marketing.manage","release.manage","backup.run","accounts.manage_staff","security.view","emergency.control","identity.view_secrets","ownership.transfer","owner.credentials"] as const;
export type Permission = typeof PERMISSIONS[number];
/** Owner-only forever: cannot be granted to any staff account, regardless of DB rows. */
export const OWNER_ONLY: ReadonlySet<Permission> = new Set(["accounts.manage_staff","emergency.control","identity.view_secrets","ownership.transfer","owner.credentials","backup.run","release.manage"]);
export const ROLE_DEFAULTS: Record<Role, Permission[]> = {
  customer: [],
  support: ["tickets.read","tickets.reply","users.read","reports.review","punish.warn","verification.review"],
  admin: ["tickets.read","tickets.reply","users.read","users.moderate","verification.review","verification.approve","reports.review","punish.warn","punish.suspend","analytics.read","config.edit","themes.edit","occasions.edit","security.view"],
  owner: [...PERMISSIONS],
};
export function can(role: Role, granted: readonly Permission[], p: Permission): boolean {
  if (role === "owner") return true;
  if (role === "customer") return false;
  if (OWNER_ONLY.has(p)) return false;
  return ROLE_DEFAULTS[role].includes(p) || granted.includes(p);
}
