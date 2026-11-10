-- Players are known by a secret token kept on their phone; only its SHA-256 is stored here.
CREATE TABLE players (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL,
  name_key TEXT NOT NULL UNIQUE,
  token_hash TEXT NOT NULL UNIQUE,
  created_at INTEGER NOT NULL,
  renamed_at INTEGER NOT NULL DEFAULT 0,
  credit REAL NOT NULL,
  credit_at INTEGER NOT NULL
);

-- One row per finished match. The phone names each match, so a retry never counts twice.
CREATE TABLE matches (
  player_id INTEGER NOT NULL REFERENCES players(id),
  match_id TEXT NOT NULL,
  nonce TEXT NOT NULL,
  week INTEGER NOT NULL,
  points INTEGER NOT NULL,
  class TEXT NOT NULL,
  spec TEXT NOT NULL,
  mode TEXT NOT NULL,
  map TEXT NOT NULL,
  seconds INTEGER NOT NULL,
  kills INTEGER NOT NULL,
  outcome TEXT NOT NULL,
  difficulty INTEGER NOT NULL,
  version TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  PRIMARY KEY (player_id, match_id)
);

-- Running totals per player: week -1 is all time, otherwise the week number (Mondays, UTC).
CREATE TABLE totals (
  player_id INTEGER NOT NULL REFERENCES players(id),
  week INTEGER NOT NULL,
  points INTEGER NOT NULL,
  matches INTEGER NOT NULL,
  PRIMARY KEY (player_id, week)
);
CREATE INDEX totals_rank ON totals (week, points DESC);

-- How often each class and profession was played, for "most played".
CREATE TABLE plays (
  player_id INTEGER NOT NULL REFERENCES players(id),
  week INTEGER NOT NULL,
  class TEXT NOT NULL,
  spec TEXT NOT NULL,
  n INTEGER NOT NULL,
  last_at INTEGER NOT NULL,
  PRIMARY KEY (player_id, week, class, spec)
);

-- Simple request counters for rate limits, keyed by a hash of the address.
CREATE TABLE hits (
  key TEXT PRIMARY KEY,
  window INTEGER NOT NULL,
  n INTEGER NOT NULL
);
