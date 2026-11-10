// Public leaderboard for Botti's Last Stand.
//
// One Worker per channel, each with its own database: "botti-board-dev" for the dev app and
// "botti-board" for the production app. Every answer names its channel, and the game refuses an
// answer from the other one, so dev and production can never mix.
//
// The phone never sends points. It sends what happened in a match, and the server works out the
// points with the same rule the game shows, after checking that the match is possible.
//
// Boards: "all" counts every match; "night", "mists", "fort", "coop" and "versus" count one kind
// each. Every board has an all-time and a weekly view. The top three of each finished week (on the
// "all" board) win doubloons, which their phones collect. A small admin page at /admin, behind the
// ADMIN_KEY secret, can rename, hide, reset or remove a player and take back single matches.

import CLASSES from "./classes.json" with { type: "json" };
import { blockedName } from "./names.js";
import { ADMIN_PAGE } from "./admin_page.js";

const API = 1;
const NAME_MIN = 3;
const NAME_MAX = 16;
const RESERVED = new Set(["admin", "administrator", "moderator", "mod", "botti", "system", "server", "host", "bot", "you"]);
const MODES = new Set(["night", "fort", "coop", "ffa", "teams"]);
const MAPS = new Set(["village", "mists", "fort"]);
export const BOARDS = ["all", "night", "mists", "fort", "coop", "versus"];
const NIGHT_LENGTH = 600;
const MAX_SECONDS = 3600;
const DIFFICULTY = [0.75, 1.0, 1.25];
// A player can only report as much match time as real time has passed, with this much saved up.
const CREDIT_START = 6 * 3600;
const CREDIT_MAX = 24 * 3600;
const RENAME_GAP = 10 * 60 * 1000;
const BOARD_SIZE = 50;
const HISTORY_SIZE = 30;
const ALL_TIME = -1;
const MAX_BODY = 4096;
// Doubloons for the first, second and third place of a finished week. Equal points share a place.
export const WEEKLY_PRIZES = [120, 80, 50];

// ---------------------------------------------------------------------------------------------
// Rules shared with the game. test/rules.json holds examples both sides check.

export function matchPoints(m) {
  const minutes = Math.floor(Math.min(m.seconds, MAX_SECONDS) / 60);
  const base = m.kills + 5 * minutes + (m.outcome === "won" ? 50 : 0);
  return Math.round(base * DIFFICULTY[m.difficulty]);
}

// Which board a match counts for, besides "all".
export function boardOf(m) {
  if (m.mode === "ffa" || m.mode === "teams") return "versus";
  if (m.mode === "fort") return "fort";
  if (m.map === "mists") return "mists";
  if (m.mode === "coop") return "coop";
  return "night";
}

// Weeks start on Monday 00:00 UTC. 1970-01-05 was the first Monday after the epoch.
export function weekOf(ms) {
  return Math.floor((Math.floor(ms / 86400000) - 4) / 7);
}

export function weekStart(week) {
  return (week * 7 + 4) * 86400000;
}

export function cleanName(raw) {
  if (typeof raw !== "string") return null;
  const name = raw.normalize("NFKC").replace(/\s+/gu, " ").trim();
  const length = [...name].length;
  if (length < NAME_MIN || length > NAME_MAX) return null;
  if (!/^[\p{L}\p{N} _.'-]+$/u.test(name)) return null;
  if (!/[\p{L}\p{N}]/u.test(name)) return null;
  return name;
}

export function nameKey(name) {
  return name.toLowerCase().replace(/[\s_.'-]/gu, "");
}

// Why a cleaned name can't be had, or null: reserved names count as taken, rude ones as blocked.
function nameRefusal(name) {
  if (RESERVED.has(nameKey(name))) return "name_taken";
  if (blockedName(name)) return "name_blocked";
  return null;
}

export function checkMatch(m) {
  if (!m || typeof m !== "object") return "bad_match";
  if (typeof m.match_id !== "string" || !/^[0-9a-f]{32}$/.test(m.match_id)) return "bad_match_id";
  if (!Number.isInteger(m.seconds) || m.seconds < 1 || m.seconds > MAX_SECONDS) return "bad_seconds";
  if (!Number.isInteger(m.kills) || m.kills < 0 || m.kills > Math.floor(m.seconds * 1.5) + 30) return "bad_kills";
  if (m.outcome !== "won" && m.outcome !== "lost") return "bad_outcome";
  if (!Number.isInteger(m.difficulty) || m.difficulty < 0 || m.difficulty > 2) return "bad_difficulty";
  if (!MODES.has(m.mode)) return "bad_mode";
  if (!MAPS.has(m.map)) return "bad_map";
  if (typeof m.class !== "string" || !Object.hasOwn(CLASSES, m.class)) return "bad_class";
  if (typeof m.spec !== "string" || (m.spec !== "" && !CLASSES[m.class].includes(m.spec))) return "bad_spec";
  if (typeof m.version !== "string" || m.version.length > 40) return "bad_version";
  // Surviving the night takes the whole night. All vs All and Teams can be won sooner.
  if (m.outcome === "won" && ["night", "fort", "coop"].includes(m.mode) && m.seconds < NIGHT_LENGTH - 5) return "bad_outcome";
  return null;
}

// ---------------------------------------------------------------------------------------------

function reply(env, status, body) {
  return new Response(JSON.stringify({ api: API, env: env.BOARD_ENV, ...body }), {
    status,
    headers: { "content-type": "application/json; charset=utf-8", "cache-control": "no-store" },
  });
}

function fail(env, status, error, extra = {}) {
  return reply(env, status, { error, ...extra });
}

async function sha256(text) {
  const bytes = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text));
  return [...new Uint8Array(bytes)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

function randomHex(bytes) {
  const data = crypto.getRandomValues(new Uint8Array(bytes));
  return [...data].map((b) => b.toString(16).padStart(2, "0")).join("");
}

async function readJson(request) {
  const length = Number(request.headers.get("content-length") || 0);
  if (length > MAX_BODY) return null;
  const text = await request.text();
  if (text.length > MAX_BODY) return null;
  try {
    return JSON.parse(text);
  } catch {
    return null;
  }
}

function bearer(request) {
  const header = request.headers.get("authorization") || "";
  const match = /^Bearer ([0-9a-f]{64})$/.exec(header);
  return match ? match[1] : null;
}

async function player(env, request) {
  const token = bearer(request);
  if (!token) return null;
  return env.DB.prepare("SELECT * FROM players WHERE token_hash = ?").bind(await sha256(token)).first();
}

// At most `limit` requests of this kind per address per window.
async function limited(env, request, kind, limit, windowMs, now) {
  const address = request.headers.get("cf-connecting-ip") || "local";
  const key = await sha256(kind + "|" + address);
  const window = Math.floor(now / windowMs);
  const row = await env.DB.prepare(
    "INSERT INTO hits (key, window, n) VALUES (?, ?, 1) ON CONFLICT(key) DO UPDATE SET n = CASE WHEN window = excluded.window THEN n + 1 ELSE 1 END, window = excluded.window RETURNING n"
  ).bind(key, window).first();
  return row.n > limit;
}

async function nameTaken(env, key, exceptId) {
  const row = await env.DB.prepare("SELECT id FROM players WHERE name_key = ?").bind(key).first();
  return row !== null && row.id !== exceptId;
}

// Where a player stands on one board in one period. Hidden players are not counted above anyone.
async function standing(env, playerId, week, board = "all") {
  const mine = await env.DB.prepare("SELECT points, matches FROM totals_v2 WHERE player_id = ? AND week = ? AND board = ?").bind(playerId, week, board).first();
  if (!mine || mine.points <= 0) return { points: mine ? mine.points : 0, matches: mine ? mine.matches : 0, rank: null };
  const above = await env.DB.prepare(
    "SELECT COUNT(*) AS n FROM totals_v2 t JOIN players p ON p.id = t.player_id WHERE t.week = ? AND t.board = ? AND t.points > ? AND p.hidden = 0"
  ).bind(week, board, mine.points).first();
  return { points: mine.points, matches: mine.matches, rank: above.n + 1 };
}

// Every total and "most played" count of one player, rebuilt from their matches. Used after the
// admin takes back a match or resets a player, so nothing can drift from what was really played.
function rebuildStatements(env, playerId) {
  const b = "CASE WHEN mode IN ('ffa', 'teams') THEN 'versus' WHEN mode = 'fort' THEN 'fort' WHEN map = 'mists' THEN 'mists' WHEN mode = 'coop' THEN 'coop' ELSE 'night' END";
  const s = [
    env.DB.prepare("DELETE FROM totals_v2 WHERE player_id = ?").bind(playerId),
    env.DB.prepare("DELETE FROM plays_v2 WHERE player_id = ?").bind(playerId),
  ];
  for (const [weekExpr, group] of [["-1", ""], ["week", ", week"]]) {
    s.push(
      env.DB.prepare(`INSERT INTO totals_v2 (player_id, week, board, points, matches) SELECT player_id, ${weekExpr}, 'all', SUM(points), COUNT(*) FROM matches WHERE player_id = ? GROUP BY player_id${group}`).bind(playerId),
      env.DB.prepare(`INSERT INTO totals_v2 (player_id, week, board, points, matches) SELECT player_id, ${weekExpr}, ${b}, SUM(points), COUNT(*) FROM matches WHERE player_id = ? GROUP BY player_id${group}, ${b}`).bind(playerId),
      env.DB.prepare(`INSERT INTO plays_v2 (player_id, week, board, class, spec, n, last_at) SELECT player_id, ${weekExpr}, 'all', class, spec, COUNT(*), MAX(created_at) FROM matches WHERE player_id = ? GROUP BY player_id${group}, class, spec`).bind(playerId),
      env.DB.prepare(`INSERT INTO plays_v2 (player_id, week, board, class, spec, n, last_at) SELECT player_id, ${weekExpr}, ${b}, class, spec, COUNT(*), MAX(created_at) FROM matches WHERE player_id = ? GROUP BY player_id${group}, ${b}, class, spec`).bind(playerId)
    );
  }
  return s;
}

// The top three of every finished week get their prize, once. Called on each visit, it usually
// finds nothing to do; the first visit of a new week closes the one before.
async function closeWeeks(env, now) {
  const current = weekOf(now);
  const open = await env.DB.prepare(
    "SELECT DISTINCT week FROM totals_v2 WHERE board = 'all' AND week >= 0 AND week < ? AND week NOT IN (SELECT week FROM weeks_closed) ORDER BY week"
  ).bind(current).all();
  for (const { week } of open.results) {
    const nonce = randomHex(16);
    // Whoever writes the week's row first hands out its prizes; anyone else at the same moment
    // finds the row written and does nothing.
    await env.DB.batch([
      env.DB.prepare("INSERT OR IGNORE INTO weeks_closed (week, closed_at, nonce) VALUES (?, ?, ?)").bind(week, now, nonce),
      env.DB.prepare(
        `INSERT OR IGNORE INTO rewards (player_id, week, rank, doubloons)
         SELECT player_id, week, place, CASE place WHEN 1 THEN ? WHEN 2 THEN ? ELSE ? END FROM (
           SELECT t.player_id, t.week, RANK() OVER (ORDER BY t.points DESC) AS place
           FROM totals_v2 t JOIN players p ON p.id = t.player_id
           WHERE t.week = ? AND t.board = 'all' AND t.points > 0 AND p.hidden = 0
         ) WHERE place <= 3 AND EXISTS (SELECT 1 FROM weeks_closed WHERE week = ? AND nonce = ?)`
      ).bind(...WEEKLY_PRIZES, week, week, nonce),
    ]);
  }
}

async function unclaimed(env, playerId) {
  const rows = await env.DB.prepare("SELECT week, rank, doubloons FROM rewards WHERE player_id = ? AND claimed = 0 ORDER BY week").bind(playerId).all();
  return rows.results;
}

// ---------------------------------------------------------------------------------------------

async function register(env, request, now) {
  const body = await readJson(request);
  if (!body || typeof body.token !== "string" || !/^[0-9a-f]{64}$/.test(body.token)) return fail(env, 400, "bad_request");
  const tokenHash = await sha256(body.token);
  const existing = await env.DB.prepare("SELECT id, name FROM players WHERE token_hash = ?").bind(tokenHash).first();
  // A retry after a lost answer: the phone is already registered.
  if (existing) return reply(env, 200, { id: existing.id, name: existing.name });
  const name = cleanName(body.name);
  if (!name) return fail(env, 400, "bad_name");
  const refused = nameRefusal(name);
  if (refused) return fail(env, refused === "name_taken" ? 409 : 400, refused);
  const key = nameKey(name);
  if (await limited(env, request, "register", 10, 3600 * 1000, now)) return fail(env, 429, "slow_down");
  if (await nameTaken(env, key, -1)) return fail(env, 409, "name_taken");
  try {
    const row = await env.DB.prepare(
      "INSERT INTO players (name, name_key, token_hash, created_at, credit, credit_at) VALUES (?, ?, ?, ?, ?, ?) RETURNING id"
    ).bind(name, key, tokenHash, now, CREDIT_START, now).first();
    return reply(env, 201, { id: row.id, name });
  } catch (error) {
    // Two phones asked for the same name at the same moment.
    if (String(error).includes("UNIQUE")) return fail(env, 409, "name_taken");
    throw error;
  }
}

async function rename(env, request, now) {
  const me = await player(env, request);
  if (!me) return fail(env, 401, "unknown_player");
  const body = await readJson(request);
  const name = body && cleanName(body.name);
  if (!name) return fail(env, 400, "bad_name");
  const key = nameKey(name);
  if (name === me.name) return reply(env, 200, { id: me.id, name });
  const refused = nameRefusal(name);
  if (refused) return fail(env, refused === "name_taken" ? 409 : 400, refused);
  // Saying a name is taken comes first: it is the more useful answer.
  if (await nameTaken(env, key, me.id)) return fail(env, 409, "name_taken");
  if (key !== me.name_key && now - me.renamed_at < RENAME_GAP) {
    return fail(env, 429, "slow_down", { retry_after: Math.ceil((me.renamed_at + RENAME_GAP - now) / 1000) });
  }
  try {
    await env.DB.prepare("UPDATE players SET name = ?, name_key = ?, renamed_at = ? WHERE id = ?").bind(name, key, now, me.id).run();
  } catch (error) {
    if (String(error).includes("UNIQUE")) return fail(env, 409, "name_taken");
    throw error;
  }
  return reply(env, 200, { id: me.id, name });
}

async function me(env, request, now) {
  const mine = await player(env, request);
  if (!mine) return fail(env, 401, "unknown_player");
  await closeWeeks(env, now);
  return reply(env, 200, {
    id: mine.id,
    name: mine.name,
    all: await standing(env, mine.id, ALL_TIME),
    week: await standing(env, mine.id, weekOf(now)),
    rewards: await unclaimed(env, mine.id),
    prizes: WEEKLY_PRIZES,
  });
}

// The phone has added a week's prize to its doubloons: it won't be offered again.
async function claim(env, request) {
  const mine = await player(env, request);
  if (!mine) return fail(env, 401, "unknown_player");
  const body = await readJson(request);
  if (!body || !Number.isInteger(body.week)) return fail(env, 400, "bad_request");
  const row = await env.DB.prepare("SELECT doubloons, claimed FROM rewards WHERE player_id = ? AND week = ?").bind(mine.id, body.week).first();
  if (!row) return fail(env, 404, "no_reward");
  await env.DB.prepare("UPDATE rewards SET claimed = 1 WHERE player_id = ? AND week = ?").bind(mine.id, body.week).run();
  return reply(env, 200, { week: body.week, doubloons: row.doubloons, already: row.claimed === 1 });
}

async function history(env, request, url) {
  const mine = await player(env, request);
  if (!mine) return fail(env, 401, "unknown_player");
  const limit = Math.min(HISTORY_SIZE, Math.max(1, Number(url.searchParams.get("limit")) || HISTORY_SIZE));
  const rows = await env.DB.prepare(
    "SELECT points, class, spec, mode, map, seconds, kills, outcome, difficulty, created_at FROM matches WHERE player_id = ? ORDER BY created_at DESC LIMIT ?"
  ).bind(mine.id, limit).all();
  return reply(env, 200, {
    matches: rows.results.map((r) => ({ ...r, board: boardOf(r), at: Math.floor(r.created_at / 1000), created_at: undefined })),
  });
}

async function submit(env, request, now) {
  const mine = await player(env, request);
  if (!mine) return fail(env, 401, "unknown_player");
  const m = await readJson(request);
  const problem = checkMatch(m);
  if (problem) return fail(env, 400, problem);
  const week = weekOf(now);
  const kind = boardOf(m);
  const known = await env.DB.prepare("SELECT points FROM matches WHERE player_id = ? AND match_id = ?").bind(mine.id, m.match_id).first();
  if (known) {
    return reply(env, 200, { points: known.points, duplicate: true, all: await standing(env, mine.id, ALL_TIME), week: await standing(env, mine.id, week) });
  }
  // Time played can't run ahead of time passed.
  const credit = Math.min(CREDIT_MAX, mine.credit + (now - mine.credit_at) / 1000);
  if (m.seconds > credit) return fail(env, 429, "too_fast", { retry_after: Math.ceil(m.seconds - credit) });
  const points = matchPoints(m);
  // Where the player stood before, so the game can say how far this match moved them.
  const before = { all: await standing(env, mine.id, ALL_TIME), week: await standing(env, mine.id, week) };
  const nonce = randomHex(16);
  const ours = "EXISTS (SELECT 1 FROM matches WHERE player_id = ? AND match_id = ? AND nonce = ?)";
  const guard = [mine.id, m.match_id, nonce];
  const statements = [
    env.DB.prepare(
      "INSERT OR IGNORE INTO matches (player_id, match_id, nonce, week, points, class, spec, mode, map, seconds, kills, outcome, difficulty, version, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
    ).bind(mine.id, m.match_id, nonce, week, points, m.class, m.spec, m.mode, m.map, m.seconds, m.kills, m.outcome, m.difficulty, m.version, now),
    // Everything below only happens when the line above added the match, all in one transaction.
    // Worked out from the stored value, so two matches sent at once both spend their time.
    env.DB.prepare(
      `UPDATE players SET credit = MIN(?, credit + MAX(0, ? - credit_at) / 1000.0) - ?, credit_at = MAX(credit_at, ?) WHERE id = ? AND ${ours}`
    ).bind(CREDIT_MAX, now, m.seconds, now, mine.id, ...guard),
  ];
  for (const w of [ALL_TIME, week]) {
    for (const b of ["all", kind]) {
      statements.push(
        env.DB.prepare(
          `INSERT INTO totals_v2 (player_id, week, board, points, matches) SELECT ?, ?, ?, ?, 1 WHERE ${ours} ON CONFLICT(player_id, week, board) DO UPDATE SET points = points + excluded.points, matches = matches + 1`
        ).bind(mine.id, w, b, points, ...guard),
        env.DB.prepare(
          `INSERT INTO plays_v2 (player_id, week, board, class, spec, n, last_at) SELECT ?, ?, ?, ?, ?, 1, ? WHERE ${ours} ON CONFLICT(player_id, week, board, class, spec) DO UPDATE SET n = n + 1, last_at = excluded.last_at`
        ).bind(mine.id, w, b, m.class, m.spec, now, ...guard)
      );
    }
  }
  await env.DB.batch(statements);
  const stored = await env.DB.prepare("SELECT points, nonce FROM matches WHERE player_id = ? AND match_id = ?").bind(mine.id, m.match_id).first();
  return reply(env, 200, {
    points: stored.points,
    board: kind,
    duplicate: stored.nonce !== nonce,
    before,
    all: await standing(env, mine.id, ALL_TIME),
    week: await standing(env, mine.id, week),
  });
}

async function board(env, request, url, now) {
  const period = url.searchParams.get("period") || "all";
  if (period !== "all" && period !== "week") return fail(env, 400, "bad_period");
  const kind = url.searchParams.get("board") || "all";
  if (!BOARDS.includes(kind)) return fail(env, 400, "bad_board");
  const week = period === "all" ? ALL_TIME : weekOf(now);
  await closeWeeks(env, now);
  const rows = await env.DB.prepare(
    `SELECT p.id, p.name, t.points, t.matches,
       (SELECT q.class || '|' || q.spec FROM plays_v2 q WHERE q.player_id = t.player_id AND q.week = t.week AND q.board = t.board ORDER BY q.n DESC, q.last_at DESC LIMIT 1) AS favourite
     FROM totals_v2 t JOIN players p ON p.id = t.player_id
     WHERE t.week = ? AND t.board = ? AND t.points > 0 AND p.hidden = 0
     ORDER BY t.points DESC, t.matches ASC, p.id ASC
     LIMIT ?`
  ).bind(week, kind, BOARD_SIZE).all();
  const entries = [];
  let rank = 0;
  let last = null;
  rows.results.forEach((row, i) => {
    // Equal points share a place: 1, 2, 2, 4.
    if (row.points !== last) {
      rank = i + 1;
      last = row.points;
    }
    const [cls, spec] = (row.favourite || "|").split("|");
    entries.push({ rank, name: row.name, points: row.points, matches: row.matches, class: cls, spec, id: row.id });
  });
  const body = { period, board: kind, entries: entries.map(({ id, ...rest }) => rest), prizes: WEEKLY_PRIZES };
  if (period === "week") {
    body.week_start = Math.floor(weekStart(week) / 1000);
    body.week_end = Math.floor(weekStart(week + 1) / 1000);
  }
  const mine = await player(env, request);
  if (mine) {
    body.me = { name: mine.name, ...(await standing(env, mine.id, week, kind)) };
    body.me.listed = entries.some((e) => e.id === mine.id);
  }
  return reply(env, 200, body);
}

// ---------------------------------------------------------------------------------------------
// The admin's tools. Without an ADMIN_KEY secret, none of this exists.

async function sameSecret(a, b) {
  // Compare digests, so the time taken says nothing about how much of the key was right.
  const [x, y] = await Promise.all([sha256("botti|" + a), sha256("botti|" + b)]);
  let diff = 0;
  for (let i = 0; i < x.length; i++) diff |= x.charCodeAt(i) ^ y.charCodeAt(i);
  return diff === 0;
}

async function adminAllowed(env, request, now) {
  const header = request.headers.get("authorization") || "";
  const given = header.startsWith("Admin ") ? header.slice(6).trim() : "";
  if (given && (await sameSecret(given, env.ADMIN_KEY))) return true;
  await limited(env, request, "admin-fail", 1000, 3600 * 1000, now);
  return false;
}

async function adminTooManyFailures(env, request, now) {
  const address = request.headers.get("cf-connecting-ip") || "local";
  const key = await sha256("admin-fail|" + address);
  const row = await env.DB.prepare("SELECT window, n FROM hits WHERE key = ?").bind(key).first();
  return row !== null && row.window === Math.floor(now / (3600 * 1000)) && row.n >= 20;
}

function logAction(env, now, action, playerId, detail) {
  return env.DB.prepare("INSERT INTO admin_log (at, action, player_id, detail) VALUES (?, ?, ?, ?)").bind(now, action, playerId, JSON.stringify(detail));
}

async function adminPlayers(env, url, now) {
  const q = (url.searchParams.get("q") || "").trim().toLowerCase();
  const week = weekOf(now);
  const rows = await env.DB.prepare(
    `SELECT p.id, p.name, p.hidden, p.created_at,
       COALESCE((SELECT points FROM totals_v2 WHERE player_id = p.id AND week = -1 AND board = 'all'), 0) AS all_points,
       COALESCE((SELECT matches FROM totals_v2 WHERE player_id = p.id AND week = -1 AND board = 'all'), 0) AS all_matches,
       COALESCE((SELECT points FROM totals_v2 WHERE player_id = p.id AND week = ? AND board = 'all'), 0) AS week_points
     FROM players p
     WHERE ? = '' OR instr(lower(p.name), ?) > 0
     ORDER BY all_points DESC, p.id ASC LIMIT 100`
  ).bind(week, q, q).all();
  return reply(env, 200, { players: rows.results });
}

async function adminMatches(env, playerId) {
  const rows = await env.DB.prepare(
    "SELECT match_id, points, class, spec, mode, map, seconds, kills, outcome, difficulty, version, created_at FROM matches WHERE player_id = ? ORDER BY created_at DESC LIMIT 200"
  ).bind(playerId).all();
  return reply(env, 200, { matches: rows.results });
}

async function adminAct(env, request, playerId, now) {
  const target = await env.DB.prepare("SELECT * FROM players WHERE id = ?").bind(playerId).first();
  if (!target) return fail(env, 404, "unknown_player");
  const body = await readJson(request);
  const action = body && body.action;
  if (action === "rename") {
    const name = cleanName(body.name);
    if (!name) return fail(env, 400, "bad_name");
    if (await nameTaken(env, nameKey(name), target.id)) return fail(env, 409, "name_taken");
    await env.DB.batch([
      env.DB.prepare("UPDATE players SET name = ?, name_key = ? WHERE id = ?").bind(name, nameKey(name), target.id),
      logAction(env, now, "rename", target.id, { from: target.name, to: name }),
    ]);
  } else if (action === "hide" || action === "unhide") {
    await env.DB.batch([
      env.DB.prepare("UPDATE players SET hidden = ? WHERE id = ?").bind(action === "hide" ? 1 : 0, target.id),
      logAction(env, now, action, target.id, { name: target.name }),
    ]);
  } else if (action === "reset") {
    await env.DB.batch([
      logAction(env, now, "reset", target.id, { name: target.name }),
      env.DB.prepare("DELETE FROM matches WHERE player_id = ?").bind(target.id),
      ...rebuildStatements(env, target.id),
    ]);
  } else if (action === "remove") {
    // The phone keeps its name and joins again on its next match, as a new player.
    await env.DB.batch([
      logAction(env, now, "remove", target.id, { name: target.name }),
      env.DB.prepare("DELETE FROM matches WHERE player_id = ?").bind(target.id),
      env.DB.prepare("DELETE FROM totals_v2 WHERE player_id = ?").bind(target.id),
      env.DB.prepare("DELETE FROM plays_v2 WHERE player_id = ?").bind(target.id),
      env.DB.prepare("DELETE FROM rewards WHERE player_id = ?").bind(target.id),
      env.DB.prepare("DELETE FROM players WHERE id = ?").bind(target.id),
    ]);
  } else if (action === "take_back") {
    if (typeof body.match_id !== "string") return fail(env, 400, "bad_request");
    const match = await env.DB.prepare("SELECT points, created_at FROM matches WHERE player_id = ? AND match_id = ?").bind(target.id, body.match_id).first();
    if (!match) return fail(env, 404, "unknown_match");
    await env.DB.batch([
      logAction(env, now, "take_back", target.id, { name: target.name, match_id: body.match_id, points: match.points }),
      env.DB.prepare("DELETE FROM matches WHERE player_id = ? AND match_id = ?").bind(target.id, body.match_id),
      ...rebuildStatements(env, target.id),
    ]);
  } else {
    return fail(env, 400, "bad_action");
  }
  return reply(env, 200, { ok: true });
}

async function admin(env, request, url, now) {
  if (!env.ADMIN_KEY) return fail(env, 404, "not_found");
  if (await adminTooManyFailures(env, request, now)) return fail(env, 429, "slow_down");
  if (!(await adminAllowed(env, request, now))) return fail(env, 401, "not_admin");
  const parts = url.pathname.split("/").filter(Boolean); // v1 admin ...
  if (request.method === "GET" && parts.length === 3 && parts[2] === "players") return adminPlayers(env, url, now);
  if (request.method === "GET" && parts.length === 3 && parts[2] === "log") {
    const rows = await env.DB.prepare("SELECT at, action, player_id, detail FROM admin_log ORDER BY id DESC LIMIT 100").all();
    return reply(env, 200, { log: rows.results });
  }
  if (parts.length >= 4 && parts[2] === "players" && /^\d+$/.test(parts[3])) {
    const id = Number(parts[3]);
    if (request.method === "GET" && parts.length === 5 && parts[4] === "matches") return adminMatches(env, id);
    if (request.method === "POST" && parts.length === 4) return adminAct(env, request, id, now);
  }
  return fail(env, 404, "not_found");
}

// ---------------------------------------------------------------------------------------------

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const now = env.TEST_NOW ? Number(request.headers.get("x-test-now") || Date.now()) : Date.now();
    try {
      if (url.pathname.startsWith("/v1/admin/")) return await admin(env, request, url, now);
      const route = request.method + " " + url.pathname;
      switch (route) {
        case "GET /admin":
          if (!env.ADMIN_KEY) return fail(env, 404, "not_found");
          return new Response(ADMIN_PAGE, {
            headers: {
              "content-type": "text/html; charset=utf-8",
              "cache-control": "no-store",
              "content-security-policy": "default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; connect-src 'self'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'",
              "x-robots-tag": "noindex",
            },
          });
        case "GET /v1/health":
          return reply(env, 200, { ok: true });
        case "POST /v1/players":
          return await register(env, request, now);
        case "PUT /v1/players/me":
          return await rename(env, request, now);
        case "GET /v1/players/me":
          return await me(env, request, now);
        case "GET /v1/players/me/matches":
          return await history(env, request, url);
        case "POST /v1/rewards/claim":
          return await claim(env, request);
        case "POST /v1/matches":
          return await submit(env, request, now);
        case "GET /v1/board":
          return await board(env, request, url, now);
        default:
          return fail(env, 404, "not_found");
      }
    } catch (error) {
      console.error(error);
      return fail(env, 500, "server_error");
    }
  },
};
