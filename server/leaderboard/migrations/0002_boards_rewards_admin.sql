-- Boards per kind of match, weekly rewards, hidden players and a record of what the admin did.

ALTER TABLE players ADD COLUMN hidden INTEGER NOT NULL DEFAULT 0;

-- Totals and plays now also say which board they count for: "all" for every match, and one board
-- per kind of match. Rebuilt from the matches themselves, which keep everything needed.
CREATE TABLE totals_v2 (
  player_id INTEGER NOT NULL REFERENCES players(id),
  week INTEGER NOT NULL,
  board TEXT NOT NULL,
  points INTEGER NOT NULL,
  matches INTEGER NOT NULL,
  PRIMARY KEY (player_id, week, board)
);
CREATE INDEX totals_v2_rank ON totals_v2 (week, board, points DESC);

CREATE TABLE plays_v2 (
  player_id INTEGER NOT NULL REFERENCES players(id),
  week INTEGER NOT NULL,
  board TEXT NOT NULL,
  class TEXT NOT NULL,
  spec TEXT NOT NULL,
  n INTEGER NOT NULL,
  last_at INTEGER NOT NULL,
  PRIMARY KEY (player_id, week, board, class, spec)
);

INSERT INTO totals_v2 (player_id, week, board, points, matches)
  SELECT player_id, -1, 'all', SUM(points), COUNT(*) FROM matches GROUP BY player_id;
INSERT INTO totals_v2 (player_id, week, board, points, matches)
  SELECT player_id, week, 'all', SUM(points), COUNT(*) FROM matches GROUP BY player_id, week;
INSERT INTO totals_v2 (player_id, week, board, points, matches)
  SELECT player_id, -1, b, SUM(points), COUNT(*) FROM (
    SELECT player_id, points, CASE WHEN mode IN ('ffa', 'teams') THEN 'versus' WHEN mode = 'fort' THEN 'fort' WHEN map = 'mists' THEN 'mists' WHEN mode = 'coop' THEN 'coop' ELSE 'night' END AS b FROM matches
  ) GROUP BY player_id, b;
INSERT INTO totals_v2 (player_id, week, board, points, matches)
  SELECT player_id, week, b, SUM(points), COUNT(*) FROM (
    SELECT player_id, week, points, CASE WHEN mode IN ('ffa', 'teams') THEN 'versus' WHEN mode = 'fort' THEN 'fort' WHEN map = 'mists' THEN 'mists' WHEN mode = 'coop' THEN 'coop' ELSE 'night' END AS b FROM matches
  ) GROUP BY player_id, week, b;

INSERT INTO plays_v2 (player_id, week, board, class, spec, n, last_at)
  SELECT player_id, -1, 'all', class, spec, COUNT(*), MAX(created_at) FROM matches GROUP BY player_id, class, spec;
INSERT INTO plays_v2 (player_id, week, board, class, spec, n, last_at)
  SELECT player_id, week, 'all', class, spec, COUNT(*), MAX(created_at) FROM matches GROUP BY player_id, week, class, spec;
INSERT INTO plays_v2 (player_id, week, board, class, spec, n, last_at)
  SELECT player_id, -1, b, class, spec, COUNT(*), MAX(created_at) FROM (
    SELECT player_id, class, spec, created_at, CASE WHEN mode IN ('ffa', 'teams') THEN 'versus' WHEN mode = 'fort' THEN 'fort' WHEN map = 'mists' THEN 'mists' WHEN mode = 'coop' THEN 'coop' ELSE 'night' END AS b FROM matches
  ) GROUP BY player_id, b, class, spec;
INSERT INTO plays_v2 (player_id, week, board, class, spec, n, last_at)
  SELECT player_id, week, b, class, spec, COUNT(*), MAX(created_at) FROM (
    SELECT player_id, week, class, spec, created_at, CASE WHEN mode IN ('ffa', 'teams') THEN 'versus' WHEN mode = 'fort' THEN 'fort' WHEN map = 'mists' THEN 'mists' WHEN mode = 'coop' THEN 'coop' ELSE 'night' END AS b FROM matches
  ) GROUP BY player_id, week, b, class, spec;

DROP TABLE totals;
DROP TABLE plays;

CREATE INDEX matches_recent ON matches (player_id, created_at DESC);

-- The top three of each finished week win doubloons, which their phones collect.
CREATE TABLE weeks_closed (
  week INTEGER PRIMARY KEY,
  closed_at INTEGER NOT NULL,
  nonce TEXT NOT NULL
);
CREATE TABLE rewards (
  player_id INTEGER NOT NULL REFERENCES players(id),
  week INTEGER NOT NULL,
  rank INTEGER NOT NULL,
  doubloons INTEGER NOT NULL,
  claimed INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (player_id, week)
);

CREATE TABLE admin_log (
  id INTEGER PRIMARY KEY,
  at INTEGER NOT NULL,
  action TEXT NOT NULL,
  player_id INTEGER,
  detail TEXT NOT NULL
);
