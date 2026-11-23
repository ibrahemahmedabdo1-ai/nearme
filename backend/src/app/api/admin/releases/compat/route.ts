import { handle, json, requirePermission } from "@/lib/http";
import { q } from "@/lib/db";
/** Database-compatibility check before a release: which migrations are applied, and the oldest app version still supported. */
export const GET = handle(async (r) => {
  await requirePermission(r, "release.manage");
  return json({ migrations: (await q<{ name: string }>("SELECT name FROM schema_migrations ORDER BY name")).map(x => x.name),
    min_required_version_code: (await q<{ v: number | null }>("SELECT max(version_code) AS v FROM app_releases WHERE min_required"))[0].v });
});
