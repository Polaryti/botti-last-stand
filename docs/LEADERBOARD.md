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

7. Optional, for the admin page: add a third secret, `LEADERBOARD_ADMIN_KEY`, a random string of at
   least 24 characters (for example the output of `openssl rand -hex 24`). The next run of the workflow
   gives both boards that key (see [Admin page](#admin-page)). Without it the page answers 404.

Without the two secrets, everything still builds. The server is tested but not deployed, and
the game's Leaderboard screen says this version has no leaderboard.

## What it counts

- **Names.** On first launch, or the next launch for players who never chose one, the game asks for a
  display name. It is shown to others in games together and on the leaderboard. A name is 3 to 16
  letters, numbers, spaces and `_ . ' -`. Names are unique, ignoring capitals, spaces and those
  marks: "Sir Botti" and "sirbotti" are the same name. A few names are reserved, such as "admin" and "botti".
  Rude names are refused with "That name isn't allowed": the board compares the name with lists of
  slurs and insults after folding accents, number-for-letter swaps (`4`→a, `3`→e, `0`→o…) and repeated
  letters, and some words only match as a whole word so names like "Scunthorpe", "Dickens" or
  "Assassin" stay allowed. The lists are in `server/leaderboard/src/names.js`.
  Offline, the name is kept and sent when the board can be reached. If someone took it in the
  meantime, the game asks for another. Tapping your name at the top of the menu, or in Play
  Together, changes it, at most once every 10 minutes.
- **Points per match.** 1 per kill, 5 per full minute played, 50 for winning (dawn in Survive the Night,
  Co-op or Defend the Fort, or winning All vs All or Teams), times 0.75 on Easy, 1 on Normal and
  1.25 on Hard. The Sandbox never counts. The end screen shows the points.
- **All time and this week.** All-time counts every match since the board began. The week runs from
  Monday 00:00 UTC (01:00 in Madrid in winter, 02:00 in summer). The top 50 are listed, and so is your own place.
- **One board per kind of match.** Besides **All** (every match), each kind has its own board, with
  all-time and weekly tabs: **Night** (Survive the Night on the Village, alone), **Mists** (any match on
  the Mists), **Fort** (Defend the Fort), **Co-op** (Co-op on the Village) and **Versus** (All vs All and Teams).
  A match counts on All and on its own kind.
- **Your matches.** The Leaderboard's third tab lists your last 30 counted matches, newest first: the
  result, how long it lasted, the kind and map, the class and profession, and the points.
- **Movement.** When a match is counted, the end screen adds where it left you, for example
  "+60 leaderboard points: #2 this week and #3 of all time (up 2)".
- **Weekly prizes.** When a week ends, the top three of that week's All board win Doubloons: 120 for first,
  80 for second, 50 for third. Players with equal points share the place and each gets its prize. Hidden
  players get nothing, and the place goes to the next player. The week is closed by the first request
  the board gets after Monday 00:00 UTC, and its prizes are fixed from then on. The game collects them
  the next time it opens the menu online, shows "A leaderboard prize", adds the Doubloons, and only then
  tells the board they were paid; a prize is paid once even if that last step fails and is retried.
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

## Admin page

With `LEADERBOARD_ADMIN_KEY` set, each board has a page at `/admin`:

- Development: https://botti-board-dev.mario-camposmocholi.workers.dev/admin
- Production: https://botti-board.mario-camposmocholi.workers.dev/admin

Enter the key to open it. The key stays in that browser tab only and is forgotten when the tab
closes. The page lists players (search by name) with their all-time points, matches and this week's
points, and can:

- **Rename** a player. The rude-name check doesn't apply here. The phone takes the new name the next
  time it opens the menu online (at most every five minutes).
- **Hide** a player: they leave every board and cannot win weekly prizes; their matches are kept. **Show** undoes it.
- **Reset scores**: delete every match of the player; their points start from nothing.
- **Remove** a player completely; the phone joins again as a new player on its next match.
- **Matches**: the player's last 200 matches, each with **Take back**, which deletes that match and
  recounts their totals.

Everything done there is listed under "What was done". A wrong key is refused; after 20 wrong keys
from one address within the same clock hour (UTC), that address is refused until the next hour starts. To change the key, change the secret
and run the Leaderboard workflow on `dev` and on `main`.

## Maintenance

- Tests: `npm ci && npm test` in `server/leaderboard` runs the real Worker locally against a local
  database. `python3 tools/run_checks.py board` runs the game against local dev and production boards.
  Both run in CI.
- Schema changes go in a new file in `server/leaderboard/migrations/`. The workflow applies new
  migrations before deploying.
- To start a board over, delete its database in the Cloudflare dashboard (D1) and run the workflow
  again. Players keep their names on their phones and join again on their next match. If a name was
  taken in the meantime, the game asks for another.
- `GET /v1/board?period=all|week&board=all|night|mists|fort|coop|versus` is the public board,
  for anyone who wants to read it outside the game.
- Free plan limits (100,000 Worker requests a day, 5 GB of D1 storage) are far above what this game
  needs. A match is two requests; opening the board is one.
