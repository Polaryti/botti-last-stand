# Leaderboard

The public leaderboard runs on Cloudflare's free plan: one small Worker and one D1 database per
channel. The code is in `server/leaderboard`, and `.github/workflows/leaderboard.yml` tests and
deploys it.

| Channel | Branch | Worker and database | Used by |
| --- | --- | --- | --- |
| Development | `dev` | `botti-board-dev` | Botti's Last Stand Dev (`com.botti.laststand.dev`) |
| Production | `main` | `botti-board` | Botti's Last Stand (`com.botti.laststand`) |

The two never share anything. Each has its own Worker and its own database. Every answer names
its channel, and the game ignores answers from the other channel's board. `tools/check_production_build.py`
also stops a production build that points at the dev board.

## Setting it up (once)

1. Make a free account at [dash.cloudflare.com](https://dash.cloudflare.com). Open **Workers & Pages** once
   and choose a `workers.dev` subdomain when asked; the boards' addresses are made from it.
2. Copy your **Account ID** (on the Workers & Pages overview, or in the address bar after `dash.cloudflare.com/`).
3. Under **My Profile → API Tokens → Create Token**, start from **Edit Cloudflare Workers**, add the
   permission **Account → D1 → Edit**, and create it.
4. In the GitHub repository, under **Settings → Secrets and variables → Actions**, add
   `CLOUDFLARE_API_TOKEN` (the token) and `CLOUDFLARE_ACCOUNT_ID`.
5. Under **Actions → Leaderboard → Run workflow**, run it on `dev`. It creates the dev database, its
   tables and the Worker, then checks the deployed board answers as the dev board. Its summary shows
   the address.
6. The next dev APK (any push to `dev`, or **Android dev release → Run workflow**) has the board.

Production gets its board the same way when `main` is next pushed: the workflow runs on `main`
and deploys `botti-board`, and the production Android and iOS builds point at it.

Without the two secrets, everything still builds. The server is tested but not deployed, and
the game's Leaderboard screen says this version has no leaderboard.

## What it counts

- **Names.** On first launch, or the next launch for players who never chose one, the game asks for a
  display name. It is shown to others in games together and on the leaderboard. A name is 3 to 16
  letters, numbers, spaces and `_ . ' -`. Names are unique, ignoring capitals, spaces and those
  marks: "Sir Botti" and "sirbotti" are the same name. A few names are reserved, such as "admin" and "botti".
  Offline, the name is kept and sent when the board can be reached. If someone took it in the
  meantime, the game asks for another. Tapping your name at the top of the menu, or in Play
  Together, changes it, at most once every 10 minutes.
- **Points per match.** 1 per kill, 5 per full minute played, 50 for winning (dawn in Survive the Night,
  Co-op or Defend the Fort, or winning All vs All or Teams), times 0.75 on Easy, 1 on Normal and
  1.25 on Hard. The Sandbox never counts. The end screen shows the points.
- **All time and this week.** All-time counts every match since the board began. The week runs from
  Monday 00:00 UTC (01:00 in Madrid in winter, 02:00 in summer). The top 50 are listed, and so is your own place.
- **Most played.** The class and profession you finished the most matches as: all time on the all-time
  board, this week's on the weekly one. A match that ended before choosing a profession counts as the class alone.

## How it keeps scores honest

The game never sends points. It sends what happened: time, kills, the result, difficulty, mode, map,
class and profession. The board checks that the match is possible and works out the points itself.
It refuses more kills than 1.5 a second plus 30, and a night "won" in under ten minutes.
A player can't report more match time than real time has passed: there is a six-hour allowance
that refills as time passes, up to a day. Each match has an id made on the phone, so a retry is
never counted twice. A phone is known by a random secret it keeps, and the board stores only its
SHA-256. Sign-ups are limited to 10 an hour per address.

This stops casual cheating, not a determined one: someone who rewrites the game can still report
matches that never happened, within those limits. Scores stay as believable as the game's own
host-run matches, and the board can be wiped and restarted if needed (see below).

## Maintenance

- Tests: `npm ci && npm test` in `server/leaderboard` runs the real Worker locally against a local
  database. `python3 tools/run_checks.py board` runs the game against local dev and production boards.
  Both run in CI.
- Schema changes go in a new file in `server/leaderboard/migrations/`. The workflow applies new
  migrations before deploying.
- To start a board over, delete its database in the Cloudflare dashboard (D1) and run the workflow
  again. Players keep their names on their phones and join again on their next match. If a name was
  taken in the meantime, the game asks for another.
- Free plan limits (100,000 Worker requests a day, 5 GB of D1 storage) are far above what this game
  needs. A match is two requests; opening the board is one.
