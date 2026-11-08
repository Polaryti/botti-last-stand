# Epic leaderboard setup

The leaderboard reuses the existing Epic Online Services deployment, credentials, device-ID login and EOSG plugin. Configure it in the **same product, sandbox and deployment** used by the game's `EPIC_*` build secrets. This setup is performed in the Epic Developer Portal.

## Definitions

[config/epic-leaderboards.json](../config/epic-leaderboards.json) lists the exact settings to enter. Regenerate it with `python3 tools/leaderboard_config.py` when adding professions.

| Channel | Points stat | Leaderboard name | Profession stat prefix |
| --- | --- | --- | --- |
| Development | `BLS_DEV_POINTS` | `BLS_DEV_LIFETIME` | `BLS_DEV_PLAY_` |
| Production | `BLS_POINTS` | `BLS_LIFETIME` | `BLS_PLAY_` |

1. Under Game Services → Stats, create the **45 stats per channel** in the manifest, all with **MAX** aggregation. The 44 play counters include one unspecialised entry and three professions for each of the 11 classes. Preserve their exact spelling, including the trailing underscore for unspecialised classes.
2. Enable Stats and Leaderboards in the existing client's policy. Permit the signed-in user to ingest **their own** stats, query stats, query leaderboard ranks and query user scores for the displayed players. No server credentials belong in the APK.
3. Under Game Services → Leaderboards, create the two leaderboards above, each ranking its channel's points stat with MAX aggregation and higher scores first. Start tracking before the first test submission and enable **Never expire**.
4. Confirm these definitions and the policy are active in the deployment selected by the existing build secrets.

Epic creates leaderboard definitions through the portal. The repository provides their configuration and the runtime integration; it does not create portal definitions during an APK build. Portal controls can change: see [Epic's setup guide](https://dev.epicgames.com/docs/epic-online-services/player-and-game-data/leaderboards-interface/leaderboards-guide/set-up-leaderboards).

## Data and behavior

- The first launch after this update requires a name confirmation. Names have 1–16 characters after trimming control characters. Duplicate names are allowed; Epic's anonymous product-user ID identifies the player.
- Lifetime points start with this update. Previous spending prevents reconstructing a historical total from the old currency balance. New match rewards add equally to currency and lifetime points; spending currency leaves points intact. Sandbox earns neither points nor play counters.
- A finished match increments its class–profession pair once. An early finish without a profession counts as unspecialised. The highest play count selects the favourite; ties use the stable order in `Scores.PAIRS`.
- Offline rewards remain pending in the atomic local save. Before uploading, the game reads the online floor and writes an exact outbox snapshot locally. MAX snapshots make an acknowledged-late or retried request idempotent. Matches earned during a request remain pending for the next sync.
- Completed matches trigger a sync when the Epic plugin is present. The leaderboard button also syncs, then shows the top 50 players with points and favourite profession. A one-minute cache limits repeated reads. Closing the screen safely discards its UI callback while the sync continues.
- Development uses its own stat names and leaderboard even when the same Epic deployment is shared with production. The two Android packages also have separate device identities and saves.

This follows the game's existing client-authoritative progression model. A modified client can falsify its local counters. Tournament-grade score verification would require trusted match validation on a server; the current board should be treated as a community leaderboard. Device-ID accounts also do not provide account recovery or automatic cross-device progress transfer.

## Verification after configuring Epic

Install the dev APK on two devices. Confirm the same name on both, finish a normal match, and open Leaderboard. Both identities should appear after Epic updates its ranks, with independent totals. Spend some currency and confirm points remain unchanged. Finish an offline match, reconnect and open the board twice: its reward must appear once. Check the production leaderboard separately to confirm the dev result did not enter it.

Automated checks in `tests/rework.gd` use a fake implementation of the exact EOSG 2.3.1 stats and leaderboard calls. They exercise duplicate names, sorting, favourite counters, failed-ingest retries and local persistence. Live portal permissions and Epic's aggregation delay still need the device check above.
