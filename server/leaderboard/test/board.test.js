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
import { matchPoints, weekOf, cleanName, nameKey, checkMatch, boardOf, WEEKLY_PRIZES } from "../src/index.js";
import { blockedName } from "../src/names.js";

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, "..");
const wrangler = join(root, "node_modules", ".bin", "wrangler");
const rules = JSON.parse(readFileSync(join(here, "rules.json"), "utf8"));
const PORT = 8790 + Math.floor(Math.random() * 100);
const BASE = `http://127.0.0.1:${PORT}`;
const MONDAY = Date.UTC(2026, 10, 9); // Monday 9 November 2026
let server;
let state;
const ADMIN = "test-admin-" + randomBytes(8).toString("hex");

function token() {
  return randomBytes(32).toString("hex");
}

function matchId() {
  return randomBytes(16).toString("hex");
}

async function call(method, path, { body, auth, now, admin } = {}) {
  const headers = { "content-type": "application/json" };
  if (auth) headers.authorization = `Bearer ${auth}`;
  if (admin) headers.authorization = `Admin ${admin}`;
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
  server = spawn(wrangler, ["dev", "--env", "dev", "--local", "--port", String(PORT), "--ip", "127.0.0.1", "--persist-to", state, "--var", "TEST_NOW:1", "--var", `ADMIN_KEY:${ADMIN}`, "--show-interactive-dev-session=false"], { cwd: root, stdio: ["ignore", "pipe", "pipe"] });
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

test("Fort matches count, each on its own board", async () => {
  assert.equal(checkMatch(match({ mode: "fort", map: "fort" })), null);
  assert.equal(boardOf({ mode: "fort", map: "fort" }), "fort");
  assert.equal(boardOf({ mode: "night", map: "mists" }), "mists");
  assert.equal(boardOf({ mode: "coop", map: "mists" }), "mists");
  assert.equal(boardOf({ mode: "coop", map: "village" }), "coop");
  assert.equal(boardOf({ mode: "ffa", map: "village" }), "versus");
  assert.equal(boardOf({ mode: "night", map: "village" }), "night");
  const now = MONDAY + 40 * 86400000;
  const a = token();
  await call("POST", "/v1/players", { body: { name: "Fort Keeper", token: a }, now });
  const fort = await call("POST", "/v1/matches", { body: match({ mode: "fort", map: "fort", class: "heavy", spec: "guardian" }), auth: a, now });
  assert.equal(fort.status, 200);
  assert.equal(fort.body.board, "fort");
  await call("POST", "/v1/matches", { body: match({ mode: "night", map: "mists", kills: 40 }), auth: a, now });
  const forts = await call("GET", "/v1/board?period=week&board=fort", { auth: a, now });
  assert.deepEqual(forts.body.entries.map((e) => [e.name, e.points, e.class]), [["Fort Keeper", 250, "heavy"]]);
  const mists = await call("GET", "/v1/board?period=week&board=mists", { auth: a, now });
  assert.deepEqual(mists.body.entries.map((e) => [e.name, e.points]), [["Fort Keeper", 140]]);
  const all = await call("GET", "/v1/board?period=week&board=all", { auth: a, now });
  assert.equal(all.body.entries.find((e) => e.name === "Fort Keeper").points, 390);
  assert.equal((await call("GET", "/v1/board?board=castle")).status, 400);
});

test("a match says where it moved you", async () => {
  const now = MONDAY + 50 * 86400000;
  const leader = token();
  const climber = token();
  await call("POST", "/v1/players", { body: { name: "Leader Lia", token: leader }, now });
  await call("POST", "/v1/players", { body: { name: "Climber Cid", token: climber }, now });
  await call("POST", "/v1/matches", { body: match({ kills: 100 }), auth: leader, now });
  const first = await call("POST", "/v1/matches", { body: match({ kills: 10, outcome: "lost" }), auth: climber, now });
  assert.equal(first.body.before.week.rank, null);
  assert.equal(first.body.week.rank, 2);
  const second = await call("POST", "/v1/matches", { body: match({ kills: 200 }), auth: climber, now });
  assert.equal(second.body.before.week.rank, 2);
  assert.equal(second.body.week.rank, 1);
});

test("your own last matches", async () => {
  const now = MONDAY + 60 * 86400000;
  const a = token();
  await call("POST", "/v1/players", { body: { name: "History Hal", token: a }, now });
  for (const kills of [10, 20, 30]) await call("POST", "/v1/matches", { body: match({ kills, outcome: "lost", class: "monk", spec: "" }), auth: a, now: now + kills * 1000 });
  const mine = await call("GET", "/v1/players/me/matches", { auth: a });
  assert.equal(mine.status, 200);
  assert.deepEqual(mine.body.matches.map((m) => m.kills), [30, 20, 10]);
  assert.equal(mine.body.matches[0].board, "night");
  assert.equal(mine.body.matches[0].points, 80);
  assert.ok(mine.body.matches[0].at > 0);
  assert.equal((await call("GET", "/v1/players/me/matches", { auth: token() })).status, 401);
});

test("rude names are refused, innocent ones are not", async () => {
  for (const name of ["Fuck", "F.u.u.c.k", "Sh1t Head", "PUTA madre", "maricón", "Gilipollas22", "n1gger", "Hijo de Puta", "asss"]) {
    assert.equal(blockedName(cleanName(name)), true, name);
  }
  for (const name of ["Mario", "As Botti", "Kike", "Zora", "therapist", "reputation", "Scunthorpe", "Mocholí_test", "Assassin", "Dickens", "Nazira"]) {
    assert.equal(blockedName(cleanName(name)), false, name);
  }
  const now = MONDAY + 70 * 86400000;
  const r = await call("POST", "/v1/players", { body: { name: "Fvck You", token: token() }, now });
  assert.equal(r.status, 400);
  assert.equal(r.body.error, "name_blocked");
  const a = token();
  await call("POST", "/v1/players", { body: { name: "Polite Pim", token: a }, now });
  const rn = await call("PUT", "/v1/players/me", { body: { name: "Puta Pim" }, auth: a, now: now + 3600000 });
  assert.equal(rn.body.error, "name_blocked");
});

test("the top three of a finished week win doubloons, once", async () => {
  const monday = MONDAY + 77 * 86400000; // a quiet week of its own
  const next = monday + 7 * 86400000 + 5000;
  const people = {};
  for (const [name, kills] of [["Gold Gus", 200], ["Silver Sal", 120], ["Also Silver", 120], ["Fourth Fay", 50], ["Hidden Hob", 400]]) {
    people[name] = token();
    await call("POST", "/v1/players", { body: { name, token: people[name] }, now: monday });
    await call("POST", "/v1/matches", { body: match({ kills, outcome: "lost" }), auth: people[name], now: monday + 3600000 });
  }
  // Hidden by the admin: no place, no prize.
  const found = await call("GET", "/v1/admin/players?q=hidden%20hob", { admin: ADMIN, now: monday + 4000000 });
  await call("POST", `/v1/admin/players/${found.body.players[0].id}`, { body: { action: "hide" }, admin: ADMIN, now: monday + 4000000 });
  // Nothing is handed out while the week is still running.
  assert.deepEqual((await call("GET", "/v1/players/me", { auth: people["Gold Gus"], now: monday + 5000000 })).body.rewards, []);
  const gold = await call("GET", "/v1/players/me", { auth: people["Gold Gus"], now: next });
  assert.deepEqual(gold.body.rewards.map((r) => [r.rank, r.doubloons]), [[1, WEEKLY_PRIZES[0]]]);
  // Equal points share second place, so both win second; nobody is third.
  for (const name of ["Silver Sal", "Also Silver"]) {
    const silver = await call("GET", "/v1/players/me", { auth: people[name], now: next });
    assert.deepEqual(silver.body.rewards.map((r) => [r.rank, r.doubloons]), [[2, WEEKLY_PRIZES[1]]], name);
  }
  assert.deepEqual((await call("GET", "/v1/players/me", { auth: people["Fourth Fay"], now: next })).body.rewards, []);
  assert.deepEqual((await call("GET", "/v1/players/me", { auth: people["Hidden Hob"], now: next })).body.rewards, []);
  // Collected once.
  const week = gold.body.rewards[0].week;
  const claimed = await call("POST", "/v1/rewards/claim", { body: { week }, auth: people["Gold Gus"], now: next });
  assert.equal(claimed.body.doubloons, WEEKLY_PRIZES[0]);
  assert.equal(claimed.body.already, false);
  assert.equal((await call("POST", "/v1/rewards/claim", { body: { week }, auth: people["Gold Gus"], now: next })).body.already, true);
  assert.deepEqual((await call("GET", "/v1/players/me", { auth: people["Gold Gus"], now: next })).body.rewards, []);
  assert.equal((await call("POST", "/v1/rewards/claim", { body: { week }, auth: people["Fourth Fay"], now: next })).status, 404);
});

test("the admin can rename, hide, take back and remove, and nobody else can", async () => {
  const now = MONDAY + 100 * 86400000;
  assert.equal((await call("GET", "/v1/admin/players", { now })).status, 401);
  assert.equal((await call("GET", "/v1/admin/players", { admin: "wrong", now })).status, 401);
  const page = await fetch(BASE + "/admin");
  assert.equal(page.status, 200);
  assert.match(page.headers.get("content-security-policy"), /default-src 'none'/);
  const a = token();
  await call("POST", "/v1/players", { body: { name: "Rude Rob", token: a }, now });
  await call("POST", "/v1/matches", { body: match({ kills: 100 }), auth: a, now });
  await call("POST", "/v1/matches", { body: match({ kills: 900 }), auth: a, now: now + 3600000 });
  const id = (await call("GET", "/v1/admin/players?q=rude", { admin: ADMIN, now })).body.players[0].id;
  // Rename, even to a name the filter would let through only from the admin.
  assert.equal((await call("POST", `/v1/admin/players/${id}`, { body: { action: "rename", name: "Player 7" }, admin: ADMIN, now })).status, 200);
  assert.equal((await call("GET", "/v1/players/me", { auth: a, now })).body.name, "Player 7");
  // Take back the impossible-looking match: totals and most played follow.
  const matches = (await call("GET", `/v1/admin/players/${id}/matches`, { admin: ADMIN, now })).body.matches;
  assert.equal(matches.length, 2);
  const big = matches.find((m) => m.kills === 900);
  await call("POST", `/v1/admin/players/${id}`, { body: { action: "take_back", match_id: big.match_id }, admin: ADMIN, now });
  const mine = await call("GET", "/v1/players/me", { auth: a, now: now + 3600000 });
  assert.equal(mine.body.all.points, 200);
  assert.equal(mine.body.all.matches, 1);
  // Hidden players are left off every board, and don't push anyone down.
  await call("POST", `/v1/admin/players/${id}`, { body: { action: "hide" }, admin: ADMIN, now });
  const board = await call("GET", "/v1/board?period=all", { now });
  assert.ok(!board.body.entries.some((e) => e.name === "Player 7"));
  await call("POST", `/v1/admin/players/${id}`, { body: { action: "unhide" }, admin: ADMIN, now });
  assert.ok((await call("GET", "/v1/board?period=all", { now })).body.entries.some((e) => e.name === "Player 7"));
  // Reset: nothing left. Remove: the phone is a stranger, and joins again as new.
  await call("POST", `/v1/admin/players/${id}`, { body: { action: "reset" }, admin: ADMIN, now });
  assert.equal((await call("GET", "/v1/players/me", { auth: a, now })).body.all.points, 0);
  await call("POST", `/v1/admin/players/${id}`, { body: { action: "remove" }, admin: ADMIN, now });
  assert.equal((await call("GET", "/v1/players/me", { auth: a, now })).status, 401);
  assert.equal((await call("POST", "/v1/players", { body: { name: "Rob Again", token: a }, now })).status, 201);
  const log = (await call("GET", "/v1/admin/log", { admin: ADMIN, now })).body.log.map((l) => l.action);
  assert.deepEqual(log.slice(0, 6), ["remove", "reset", "unhide", "hide", "take_back", "rename"]);
});

test("the second schema keeps every earlier score", () => {
  // Matches played before boards per kind existed are counted again, on the right boards.
  const dir = mkdtempSync(join(tmpdir(), "botti-migrate-"));
  const sql = (command) => execFileSync(wrangler, ["d1", "execute", "DB", "--env", "dev", "--local", "--persist-to", dir, "--json", "--command", command], { cwd: root, encoding: "utf8" });
  const migrations = join(root, "migrations");
  try {
    execFileSync(wrangler, ["d1", "execute", "DB", "--env", "dev", "--local", "--persist-to", dir, "--file", join(migrations, "0001_init.sql")], { cwd: root, stdio: "ignore" });
    sql("INSERT INTO players (id, name, name_key, token_hash, created_at, credit, credit_at) VALUES (1, 'Old Timer', 'oldtimer', 'x', 0, 0, 0)");
    sql("INSERT INTO matches VALUES (1, 'a', 'n', 2966, 250, 'ranger', 'trapper', 'night', 'village', 600, 150, 'won', 1, '0.21.1', 1), (1, 'b', 'n', 2967, 100, 'heavy', '', 'coop', 'mists', 300, 50, 'lost', 1, '0.21.1', 2)");
    execFileSync(wrangler, ["d1", "execute", "DB", "--env", "dev", "--local", "--persist-to", dir, "--file", join(migrations, "0002_boards_rewards_admin.sql")], { cwd: root, stdio: "ignore" });
    const rows = JSON.parse(sql("SELECT week, board, points, matches FROM totals_v2 ORDER BY week, board"))[0].results;
    assert.deepEqual(rows.map((r) => [r.week, r.board, r.points, r.matches]), [
      [-1, "all", 350, 2], [-1, "mists", 100, 1], [-1, "night", 250, 1],
      [2966, "all", 250, 1], [2966, "night", 250, 1], [2967, "all", 100, 1], [2967, "mists", 100, 1],
    ]);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});
