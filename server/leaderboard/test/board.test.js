// Runs the real Worker locally (wrangler dev, with a local copy of the database) and talks to it
// over HTTP, the way the game does.
import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import { spawn, execFileSync } from "node:child_process";
import { mkdtempSync, rmSync, readFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { randomBytes } from "node:crypto";
import { matchPoints, weekOf, cleanName, nameKey, checkMatch } from "../src/index.js";

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, "..");
const wrangler = join(root, "node_modules", ".bin", "wrangler");
const rules = JSON.parse(readFileSync(join(here, "rules.json"), "utf8"));
const PORT = 8790 + Math.floor(Math.random() * 100);
const BASE = `http://127.0.0.1:${PORT}`;
const MONDAY = Date.UTC(2026, 10, 9); // Monday 9 November 2026
let server;
let state;

function token() {
  return randomBytes(32).toString("hex");
}

function matchId() {
  return randomBytes(16).toString("hex");
}

async function call(method, path, { body, auth, now } = {}) {
  const headers = { "content-type": "application/json" };
  if (auth) headers.authorization = `Bearer ${auth}`;
  if (now !== undefined) headers["x-test-now"] = String(now);
  const response = await fetch(BASE + path, { method, headers, body: body === undefined ? undefined : JSON.stringify(body) });
  return { status: response.status, body: await response.json() };
}

function match(extra = {}) {
  return { match_id: matchId(), seconds: 600, kills: 150, outcome: "won", difficulty: 1, mode: "night", map: "village", class: "ranger", spec: "trapper", version: "0.21.0", ...extra };
}

before(async () => {
  state = mkdtempSync(join(tmpdir(), "botti-board-"));
  execFileSync(wrangler, ["d1", "migrations", "apply", "DB", "--env", "dev", "--local", "--persist-to", state], { cwd: root, stdio: "ignore" });
  server = spawn(wrangler, ["dev", "--env", "dev", "--local", "--port", String(PORT), "--ip", "127.0.0.1", "--persist-to", state, "--var", "TEST_NOW:1", "--show-interactive-dev-session=false"], { cwd: root, stdio: ["ignore", "pipe", "pipe"] });
  let log = "";
  server.stdout.on("data", (d) => (log += d));
  server.stderr.on("data", (d) => (log += d));
  const deadline = Date.now() + 60000;
  while (Date.now() < deadline) {
    try {
      const r = await fetch(BASE + "/v1/health");
      if (r.ok) return;
    } catch {}
    await new Promise((r) => setTimeout(r, 300));
  }
  throw new Error("The local Worker did not start:\n" + log);
});

after(() => {
  server?.kill();
  rmSync(state, { recursive: true, force: true });
});

test("the scoring rule matches the shared examples", () => {
  for (const e of rules.points) assert.equal(matchPoints(e), e.points, JSON.stringify(e));
  for (const e of rules.weeks) assert.equal(weekOf(e.unix * 1000), e.week, String(e.unix));
});

test("names are cleaned and compared without case or spacing", () => {
  assert.equal(cleanName("  Sir   Botti  "), "Sir Botti");
  assert.equal(cleanName("ab"), null);
  assert.equal(cleanName("a".repeat(17)), null);
  assert.equal(cleanName("<script>"), null);
  assert.equal(cleanName("---"), null);
  assert.equal(cleanName("Ｍａｒｉｏ"), "Mario");
  assert.equal(cleanName("Íñigo_2"), "Íñigo_2");
  assert.equal(nameKey("Sir Botti"), nameKey("sirbotti"));
  assert.equal(nameKey("Mario-1"), nameKey("mario 1"));
});

test("impossible matches are refused", () => {
  assert.equal(checkMatch(match()), null);
  assert.equal(checkMatch(match({ kills: 1000 })), "bad_kills");
  assert.equal(checkMatch(match({ seconds: 300 })), "bad_outcome");
  assert.equal(checkMatch(match({ seconds: 300, mode: "ffa" })), null);
  assert.equal(checkMatch(match({ spec: "warlock" })), "bad_spec");
  assert.equal(checkMatch(match({ spec: "" })), null);
  assert.equal(checkMatch(match({ class: "wizard" })), "bad_class");
  assert.equal(checkMatch(match({ seconds: 600.5 })), "bad_seconds");
  assert.equal(checkMatch(match({ match_id: "x" })), "bad_match_id");
  assert.equal(checkMatch(match({ mode: "sandbox" })), "bad_mode");
});

test("every answer says which board it came from", async () => {
  const r = await call("GET", "/v1/health");
  assert.equal(r.status, 200);
  assert.equal(r.body.env, "dev");
});

test("names are unique, and a lost answer can be asked for again", async () => {
  const a = token();
  const first = await call("POST", "/v1/players", { body: { name: "Unique One", token: a }, now: MONDAY });
  assert.equal(first.status, 201);
  assert.equal(first.body.name, "Unique One");
  const again = await call("POST", "/v1/players", { body: { name: "Unique One", token: a }, now: MONDAY });
  assert.equal(again.status, 200);
  assert.equal(again.body.id, first.body.id);
  const other = await call("POST", "/v1/players", { body: { name: "unique-one", token: token() }, now: MONDAY });
  assert.equal(other.status, 409);
  assert.equal(other.body.error, "name_taken");
  const reserved = await call("POST", "/v1/players", { body: { name: "Admin", token: token() }, now: MONDAY });
  assert.equal(reserved.status, 409);
  const bad = await call("POST", "/v1/players", { body: { name: "x", token: token() }, now: MONDAY });
  assert.equal(bad.body.error, "bad_name");
});

test("renaming keeps names unique and is not too frequent", async () => {
  const a = token();
  const b = token();
  await call("POST", "/v1/players", { body: { name: "Renamer", token: a }, now: MONDAY });
  await call("POST", "/v1/players", { body: { name: "Holder", token: b }, now: MONDAY });
  assert.equal((await call("PUT", "/v1/players/me", { body: { name: "holder" }, auth: a, now: MONDAY })).status, 409);
  const ok = await call("PUT", "/v1/players/me", { body: { name: "Renamed" }, auth: a, now: MONDAY });
  assert.equal(ok.status, 200);
  assert.equal(ok.body.name, "Renamed");
  const soon = await call("PUT", "/v1/players/me", { body: { name: "Renamed Again" }, auth: a, now: MONDAY + 60000 });
  assert.equal(soon.status, 429);
  // Changing only the capitals is always allowed.
  assert.equal((await call("PUT", "/v1/players/me", { body: { name: "RENAMED" }, auth: a, now: MONDAY + 60000 })).status, 200);
  const later = await call("PUT", "/v1/players/me", { body: { name: "Renamed Again" }, auth: a, now: MONDAY + 11 * 60000 });
  assert.equal(later.status, 200);
  // The old name is free for someone else.
  assert.equal((await call("POST", "/v1/players", { body: { name: "Renamer", token: token() }, now: MONDAY })).status, 201);
  assert.equal((await call("PUT", "/v1/players/me", { body: { name: "Who" }, auth: token() })).status, 401);
});

test("the server works out the points and counts each match once", async () => {
  const a = token();
  await call("POST", "/v1/players", { body: { name: "Scorer", token: a }, now: MONDAY });
  const m = match({ points: 99999 });
  const first = await call("POST", "/v1/matches", { body: m, auth: a, now: MONDAY + 3600000 });
  assert.equal(first.status, 200);
  assert.equal(first.body.points, 250);
  assert.equal(first.body.all.points, 250);
  const retry = await call("POST", "/v1/matches", { body: m, auth: a, now: MONDAY + 3600000 });
  assert.equal(retry.body.duplicate, true);
  // Sent twice at once: still counted once.
  const twice = match();
  const both = await Promise.all([1, 2].map(() => call("POST", "/v1/matches", { body: twice, auth: a, now: MONDAY + 3600000 })));
  assert.ok(both.every((r) => r.status === 200));
  const mine = await call("GET", "/v1/players/me", { auth: a, now: MONDAY + 3600000 });
  assert.equal(mine.body.all.points, 500);
  assert.equal(mine.body.all.matches, 2);
  assert.equal(mine.body.week.points, 500);
  assert.equal((await call("POST", "/v1/matches", { body: match({ kills: 5000 }), auth: a })).body.error, "bad_kills");
  assert.equal((await call("POST", "/v1/matches", { body: match(), auth: token() })).status, 401);
});

test("match time cannot run ahead of real time", async () => {
  const a = token();
  await call("POST", "/v1/players", { body: { name: "Speedy", token: a }, now: MONDAY });
  // A new player has six hours in hand: 36 ten-minute matches, then the 37th must wait.
  let refused = null;
  for (let i = 0; i < 37 && !refused; i++) {
    const r = await call("POST", "/v1/matches", { body: match({ outcome: "lost", kills: 1 }), auth: a, now: MONDAY });
    if (r.status !== 200) refused = { i, r };
  }
  assert.ok(refused, "a 37th match at once is refused");
  assert.equal(refused.i, 36);
  assert.equal(refused.r.status, 429);
  assert.equal(refused.r.body.error, "too_fast");
  const later = await call("POST", "/v1/matches", { body: match({ outcome: "lost", kills: 1 }), auth: a, now: MONDAY + 600000 });
  assert.equal(later.status, 200);
});

test("all-time and weekly boards rank by points and show the favourite", async () => {
  const lastWeek = MONDAY - 3 * 86400000;
  const nextWeek = MONDAY + 7 * 86400000 + 1000;
  const people = {};
  for (const name of ["Alpha", "Bravo", "Charlie"]) {
    people[name] = token();
    await call("POST", "/v1/players", { body: { name, token: people[name] }, now: lastWeek - 86400000 });
  }
  // Last week: Alpha plays a lot. This week: Bravo and Charlie.
  for (let i = 0; i < 3; i++) await call("POST", "/v1/matches", { body: match({ class: "monk", spec: "bo_master" }), auth: people.Alpha, now: lastWeek });
  await call("POST", "/v1/matches", { body: match({ class: "monk", spec: "" }), auth: people.Alpha, now: lastWeek });
  await call("POST", "/v1/matches", { body: match({ class: "heavy", spec: "warlord", kills: 200 }), auth: people.Bravo, now: nextWeek });
  await call("POST", "/v1/matches", { body: match({ class: "ranger", spec: "", kills: 200 }), auth: people.Charlie, now: nextWeek });
  const all = await call("GET", "/v1/board?period=all", { auth: people.Bravo, now: nextWeek });
  assert.equal(all.status, 200);
  const names = all.body.entries.map((e) => e.name);
  assert.ok(names.indexOf("Alpha") < names.indexOf("Bravo"), "Alpha leads all time");
  const alpha = all.body.entries.find((e) => e.name === "Alpha");
  assert.equal(alpha.points, 1000);
  assert.equal(alpha.class, "monk");
  assert.equal(alpha.spec, "bo_master");
  assert.equal(all.body.me.name, "Bravo");
  assert.equal(all.body.me.listed, true);
  const week = await call("GET", "/v1/board?period=week", { auth: people.Alpha, now: nextWeek });
  const weekNames = week.body.entries.map((e) => e.name);
  assert.deepEqual(weekNames.slice(0, 2).sort(), ["Bravo", "Charlie"]);
  assert.ok(!weekNames.includes("Alpha"), "last week's points do not count this week");
  // Equal points share a place.
  assert.equal(week.body.entries[0].rank, 1);
  assert.equal(week.body.entries[1].rank, 1);
  const charlie = week.body.entries.find((e) => e.name === "Charlie");
  assert.equal(charlie.spec, "");
  assert.equal(week.body.me.points, 0);
  assert.equal(week.body.me.rank, null);
  assert.equal(week.body.me.listed, false);
  assert.equal(week.body.week_start, (MONDAY + 7 * 86400000) / 1000);
  assert.equal(week.body.week_end, (MONDAY + 14 * 86400000) / 1000);
  assert.equal((await call("GET", "/v1/board?period=year")).status, 400);
  const anyone = await call("GET", "/v1/board?period=all");
  assert.equal(anyone.body.me, undefined);
});

test("signing up is limited per address", async () => {
  let refused = 0;
  const now = MONDAY + 30 * 86400000;
  for (let i = 0; i < 12; i++) {
    const r = await call("POST", "/v1/players", { body: { name: `Flood ${i}`, token: token() }, now });
    if (r.status === 429) refused++;
  }
  assert.equal(refused, 2);
});
