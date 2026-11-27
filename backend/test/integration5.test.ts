// Discovery regression tests: gender preferences and persisted pass actions.
import { test } from "node:test";
import assert from "node:assert/strict";
import { call, newUser, sql } from "./harness/helpers.ts";

test("discovery applies selected genders and excludes profiles already swiped", async () => {
  const seeker = await newUser("genderSeeker");
  const woman = await newUser("genderWoman");
  const man = await newUser("genderMan");
  sql(`UPDATE users SET gender='female' WHERE id='${woman.id}'`);
  sql(`UPDATE users SET gender='male' WHERE id='${man.id}'`);
  sql(`UPDATE preferences SET genders=ARRAY['female']::text[] WHERE user_id='${seeker.id}'`);
  const first = await call("discover", "GET", { token: seeker.token, query: "?radius=all" });
  assert.equal(first.status, 200, JSON.stringify(first.body));
  const ids = first.body.results.map((p: any) => p.id);
  assert.ok(ids.includes(woman.id));
  assert.ok(!ids.includes(man.id));
  const pass = await call("swipes", "POST", { token: seeker.token, body: { to_user: woman.id, kind: "pass" } });
  assert.equal(pass.status, 201);
  const second = await call("discover", "GET", { token: seeker.token, query: "?radius=all" });
  assert.equal(second.status, 200);
  assert.ok(!second.body.results.some((p: any) => p.id === woman.id), "passed profiles must not be recommended again");
});

test("empty gender preferences preserve all-gender discovery", async () => {
  const seeker = await newUser("allGenderSeeker");
  const woman = await newUser("allGenderWoman");
  const man = await newUser("allGenderMan");
  sql(`UPDATE users SET gender='female' WHERE id='${woman.id}'`);
  sql(`UPDATE users SET gender='male' WHERE id='${man.id}'`);
  sql(`UPDATE preferences SET genders='{}'::text[] WHERE user_id='${seeker.id}'`);
  const result = await call("discover", "GET", { token: seeker.token, query: "?radius=all" });
  assert.equal(result.status, 200);
  const ids = result.body.results.map((p: any) => p.id);
  assert.ok(ids.includes(woman.id) && ids.includes(man.id));
});
