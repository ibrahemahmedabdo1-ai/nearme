import { neon } from "@neondatabase/serverless";
import { env } from "./env";
let _sql: ReturnType<typeof neon> | null = null;
/** Parameterized queries only: q("SELECT ... WHERE id=$1", [id]). Never concatenate user input into SQL. */
export async function q<T = Record<string, unknown>>(text: string, params: unknown[] = []): Promise<T[]> {
  _sql ??= neon(env("DATABASE_URL"));
  return (await _sql.query(text, params)) as T[];
}
