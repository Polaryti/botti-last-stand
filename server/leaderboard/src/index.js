// Public leaderboard for Botti's Last Stand.
//
// One Worker per channel, each with its own database: "botti-board-dev" for the dev app and
// "botti-board" for the production app. Every answer names its channel, and the game refuses an
// answer from the other one, so dev and production can never mix.
//
// The phone never sends points. It sends what happened in a match, and the server works out the
// points with the same rule the game shows, after checking that the match is possible.

import CLASSES from "./classes.json" with { type: "json" };

const API = 1;
const NAME_MIN = 3;
const NAME_MAX = 16;
const RESERVED = new Set(["admin", "administrator", "moderator", "mod", "botti", "system", "server", "host", "bot", "you"]);
const MODES = new Set(["night", "fort", "coop", "ffa", "teams"]);
const MAPS = new Set(["village", "mists"]);
const NIGHT_LENGTH = 600;
const MAX_SECONDS = 3600;
const DIFFICULTY = [0.75, 1.0, 1.25];
// A player can only report as much match time as real time has passed, with this much saved up.
const CREDIT_START = 6 * 3600;
const CREDIT_MAX = 24 * 3600;
const RENAME_GAP = 10 * 60 * 1000;
const BOARD_SIZE = 50;
const ALL_TIME = -1;
const MAX_BODY = 4096;

// ---------------------------------------------------------------------------------------------
// Rules shared with the game. tests/leaderboard_rules.json holds examples both sides check.

export function matchPoints(m) {
  const minutes = Math.floor(Math.min(m.seconds, MAX_SECONDS) / 60);
  const base = m.kills + 5 * minutes + (m.outcome === "won" ? 50 : 0);
  return Math.round(base * DIFFICULTY[m.difficulty]);
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

async function standing(env, playerId, week) {
  const mine = await env.DB.prepare("SELECT points, matches FROM totals WHERE player_id = ? AND week = ?").bind(playerId, week).first();
  if (!mine) return { points: 0, matches: 0, rank: null };
  const above = await env.DB.prepare("SELECT COUNT(*) AS n FROM totals WHERE week = ? AND points > ?").bind(week, mine.points).first();
  return { points: mine.points, matches: mine.matches, rank: above.n + 1 };
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
  const key = nameKey(name);
  if (RESERVED.has(key)) return fail(env, 409, "name_taken");
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
  if (RESERVED.has(key)) return fail(env, 409, "name_taken");
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
  return reply(env, 200, {
    id: mine.id,
    name: mine.name,
    all: await standing(env, mine.id, ALL_TIME),
    week: await standing(env, mine.id, weekOf(now)),
  });
}

async function submit(env, request, now) {
  const mine = await player(env, request);
  if (!mine) return fail(env, 401, "unknown_player");
  const m = await readJson(request);
  const problem = checkMatch(m);
  if (problem) return fail(env, 400, problem);
  const known = await env.DB.prepare("SELECT points FROM matches WHERE player_id = ? AND match_id = ?").bind(mine.id, m.match_id).first();
  if (known) return reply(env, 200, { points: known.points, duplicate: true });
  // Time played can't run ahead of time passed.
  const credit = Math.min(CREDIT_MAX, mine.credit + (now - mine.credit_at) / 1000);
  if (m.seconds > credit) return fail(env, 429, "too_fast", { retry_after: Math.ceil(m.seconds - credit) });
  const points = matchPoints(m);
  const week = weekOf(now);
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
    statements.push(
      env.DB.prepare(
        `INSERT INTO totals (player_id, week, points, matches) SELECT ?, ?, ?, 1 WHERE ${ours} ON CONFLICT(player_id, week) DO UPDATE SET points = points + excluded.points, matches = matches + 1`
      ).bind(mine.id, w, points, ...guard),
      env.DB.prepare(
        `INSERT INTO plays (player_id, week, class, spec, n, last_at) SELECT ?, ?, ?, ?, 1, ? WHERE ${ours} ON CONFLICT(player_id, week, class, spec) DO UPDATE SET n = n + 1, last_at = excluded.last_at`
      ).bind(mine.id, w, m.class, m.spec, now, ...guard)
    );
  }
  await env.DB.batch(statements);
  const stored = await env.DB.prepare("SELECT points, nonce FROM matches WHERE player_id = ? AND match_id = ?").bind(mine.id, m.match_id).first();
  return reply(env, 200, {
    points: stored.points,
    duplicate: stored.nonce !== nonce,
    all: await standing(env, mine.id, ALL_TIME),
    week: await standing(env, mine.id, week),
  });
}

async function board(env, request, url, now) {
  const period = url.searchParams.get("period") || "all";
  if (period !== "all" && period !== "week") return fail(env, 400, "bad_period");
  const week = period === "all" ? ALL_TIME : weekOf(now);
  const rows = await env.DB.prepare(
    `SELECT p.id, p.name, t.points, t.matches,
       (SELECT q.class || '|' || q.spec FROM plays q WHERE q.player_id = t.player_id AND q.week = t.week ORDER BY q.n DESC, q.last_at DESC LIMIT 1) AS favourite
     FROM totals t JOIN players p ON p.id = t.player_id
     WHERE t.week = ? AND t.points > 0
     ORDER BY t.points DESC, t.matches ASC, p.id ASC
     LIMIT ?`
  ).bind(week, BOARD_SIZE).all();
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
  const body = { period, entries: entries.map(({ id, ...rest }) => rest) };
  if (period === "week") {
    body.week_start = Math.floor(weekStart(week) / 1000);
    body.week_end = Math.floor(weekStart(week + 1) / 1000);
  }
  const mine = await player(env, request);
  if (mine) {
    body.me = { name: mine.name, ...(await standing(env, mine.id, week)) };
    body.me.listed = entries.some((e) => e.id === mine.id);
  }
  return reply(env, 200, body);
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const now = env.TEST_NOW ? Number(request.headers.get("x-test-now") || Date.now()) : Date.now();
    try {
      const route = request.method + " " + url.pathname;
      switch (route) {
        case "GET /v1/health":
          return reply(env, 200, { ok: true });
        case "POST /v1/players":
          return await register(env, request, now);
        case "PUT /v1/players/me":
          return await rename(env, request, now);
        case "GET /v1/players/me":
          return await me(env, request, now);
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
