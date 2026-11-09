# Building and testing

## Running the game

Open the folder in Godot 4.7.2 and press F5, or from a terminal:

    godot --path .

Keyboard and mouse work for testing on a computer.

## Building the Android app

You need Godot 4.7.2, its export templates and the Android SDK command-line tools on Linux, with the SDK path set in Godot under Editor Settings > Export > Android.

The signing key is not in this repository, and it must stay out of it. Whoever holds the key is the only one who can publish updates that install over the existing game. Keep two private files in a `keys/` folder, which Git ignores:

- `keys/botti-last-stand.keystore`, the key itself.
- `keys/signing.env`, which tells Godot how to use it:

      export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$PWD/keys/botti-last-stand.keystore"
      export GODOT_ANDROID_KEYSTORE_RELEASE_USER="bottilaststand"
      export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="the password"
      export GODOT_ANDROID_KEYSTORE_DEBUG_PATH="$GODOT_ANDROID_KEYSTORE_RELEASE_PATH"
      export GODOT_ANDROID_KEYSTORE_DEBUG_USER="$GODOT_ANDROID_KEYSTORE_RELEASE_USER"
      export GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD="$GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD"

Then build:

    tools/build_android.sh

The app ends up in `build/botti-last-stand.apk`. Without the key, make your own for testing:

    keytool -genkeypair -keystore keys/botti-last-stand.keystore -alias bottilaststand -keyalg RSA -keysize 2048 -validity 10000 -storetype PKCS12

An app signed with a different key will not install over one already on a phone until that one is uninstalled.

## Development Android releases

Every push to `dev` runs **Android dev release** and creates a GitHub prerelease tagged
`dev-<workflow-run-number>-<short-commit>`. The APK is named after that tag. Its release also
contains a SHA-256 checksum and `build-info.json` with the exact source commit and online-play status.
No iOS build runs for dev. The production Android and iOS jobs also refuse manual dispatch on
branches other than `main`.

The workflow prepares a disposable checkout with `tools/prepare_dev_build.py`. Production
`project.godot` and the existing Android/iOS export presets stay unchanged in Git. The generated
**Android Dev** preset uses `com.botti.laststand.dev`, the launcher name **Botti's Last Stand Dev**,
a `dev` feature tag, and version `<base>-dev.<run>+<commit>` with Android code `100000 + run`.
The existing signing secrets are reused so later dev APKs can update earlier dev installs.
Different package IDs allow dev and production to coexist with separate Android app data.

Dev multiplayer has a separate compatibility namespace for LAN handshakes and online room lists.
Dev builds query the prerelease feed and select the newest complete `dev-<run>-<sha>` APK by
run number, independently of production’s stable `/latest` feed. Both Android presets include
`REQUEST_INSTALL_PACKAGES`; Android asks the player before installation. The downloaded file’s
size and GitHub SHA-256 digest (when supplied) are verified. Prereleases remain `latest=false`.
Install dev build 7 or later manually once when upgrading from earlier builds, whose updater was
disabled. Future dev updates appear in the menu. **Check again** repeats the check after startup; connection, timeout and rate-limit failures show **Retry check** and **Open Releases**. Downloads request a fresh GitHub asset redirect to avoid expired cached links. Production never offers a dev APK.

The workflow uses Godot 4.7.2 and Epic plugin release 2.3.1. If all Epic secrets are available it
includes online play; if any are missing it builds solo/bots/LAN and says so in the release notes.
It runs packaging unit tests and GDScript regressions, verifies the certificate and APK package /
version metadata, and publishes only after those steps pass. The separate **Validate game** run
provides the complete gameplay, paired-network and render checks for the pushed commit.

To inspect preparation locally, use a disposable project copy:

    python3 tools/prepare_dev_build.py --build-number 1 --commit <git-commit-sha>

This command rewrites configuration in that copy. Do not run it in a production working tree
whose configuration edits you want to retain. The normal `Android` and `iOS` preset definitions
are preserved, and the generated preset is idempotent for the same build number and commit.

## Making a new version

1. Raise `config/version` in `project.godot`, and `version/code` and `version/name` in `export_presets.cfg`. The code has to go up by one each time, or phones refuse the update.
2. Add the notes to the top of `CHANGELOG.md`. The game shows this file on its Changelog screen, so write for players. It reads `## ` as a version, `### ` as a heading and `- ` as a line.
3. Run the tests below, build the app, commit as `Version X.Y.Z` and push.

## Releases and the in-game update

Every push to `main` runs the "Android release" workflow. It builds the signed Android app and publishes it as a GitHub Release named after `config/version` (`v0.20.1`, say), with the newest `CHANGELOG.md` entry as its notes. The "iOS build" workflow adds the iPhone app to the same release. A version is published once: pushing again with the same version leaves its release alone.

When the game opens its menu it asks GitHub for the latest release. If it is newer, the menu says so. On Android, Update downloads the app and opens Android's installer, which asks before it installs (the first time, Android also asks to allow this game to install apps). On an iPhone it only points to the release, because an iPhone app cannot install another.

The workflow needs the signing key in the repository's Actions secrets (Settings > Secrets and variables > Actions > New repository secret). Without them it skips the release and leaves a warning:

- `ANDROID_KEYSTORE_BASE64`: the key file in base64 (`base64 -w0 keys/botti-last-stand.keystore`).
- `ANDROID_KEYSTORE_USER`: the key's alias, `bottilaststand`.
- `ANDROID_KEYSTORE_PASSWORD`: its password.

The workflow refuses to publish an app whose certificate is not the game's (SHA-256 `53c7a9b0...8fa79`), since phones would refuse it as an update.

## Online play

The Epic plugin's compiled files (hundreds of MB) and the keys are not in the repository, so a fresh copy builds without online play until you add them. Android also needs a Gradle build with the Android SDK's android-36 platform and build-tools 36.1.0:

    godot --headless --path . --install-android-build-template --export-release Android build/first.apk
    python3 tools/setup_epic.py path/to/addons/epic-online-services-godot

Download the plugin from its [Releases](https://github.com/3ddelano/epic-online-services-godot/releases), the file with `-all-` in its name. The keys go in `keys/epic.env`. For iPhone builds they go in the repository's GitHub secrets: `EPIC_PRODUCT_ID`, `EPIC_SANDBOX_ID`, `EPIC_DEPLOYMENT_ID`, `EPIC_CLIENT_ID` and `EPIC_CLIENT_SECRET`. `tests/epic_check.tscn` signs in and tries a room with them.

## iPhone

Every push to `main` builds an unsigned iPhone app on one of GitHub's Macs. Nothing needs a paid Apple account:

1. On GitHub, open Actions, then the latest "iOS build" run, and download `botti-last-stand-ios`. Unzip it to get the `.ipa`.
2. On a Mac or Windows PC, open Sideloadly, plug in the iPhone, drop in the `.ipa` and sign in with an Apple ID.
3. On the iPhone, trust the profile in Settings > General > VPN & Device Management, and turn on Developer Mode if asked.

With a free Apple ID the app stops opening after 7 days. Install it again to renew it.

## Tests

Pull requests and pushes to `main` and `dev` run `Validate game` without signing keys or Epic credentials.
It imports resources, runs gameplay and regression checks, exercises paired LAN sessions, and
captures weather and UI with the Compatibility renderer. Logs and images are attached to the run.
Production releases run on `main`; Android development prereleases run on `dev`.

For strict checks on Linux, with separate temporary saves for each process:

    python3 tools/run_checks.py regressions
    python3 tools/run_checks.py gameplay
    python3 tools/run_checks.py network --mode coop
    python3 tools/run_checks.py network --mode mists

Set `GODOT` or pass `--godot /path/to/godot`. The runner rejects engine errors, failed assertions,
missing result summaries and timeouts. Logs go in `build/checks/`. Run network modes sequentially:
they share the game's fixed LAN ports. These checks do not test Epic relays, phone GPU speed,
Android signing or iOS device installation. Run gameplay and network suites sequentially on
one machine because the gameplay suite also exercises hosting and discovery on the fixed ports.

    python3 tools/run_checks.py gameplay                           # full ordered suite
    python3 tools/run_checks.py gameplay --group classes           # one isolated group
    python3 tools/run_checks.py gameplay --case test_version_18     # one named scenario
    python3 tools/run_checks.py rework                             # Commander, Adept and Epic score contracts
    python3 -m unittest discover -s tests -p 'test_*.py'             # runner and packaging checks
    godot --headless --path . res://tests/test_game.tscn -- soakonly # optional long soak

Gameplay uses fixed 1/60 game-second physics steps and uncapped headless rendering, with a stable
seed per scenario. Groups are `core`, `recent`, `legacy`, `classes` and `world`. Each scenario prints
its check count and elapsed time; add `verbose` to the direct Godot invocation for individual successes.
The former overlapping `new`, `quick` and `v201` plans have been replaced by named groups/cases.

Multiplayer has its own test, which runs two copies of the game talking to each other. Start the host and the client in two terminals. The third word can be `bots`, `botsffa`, `coop`, `ffa`, `teams`, `fort`, `ride`, `chariot`, `commander`, `room` or `soak`:

    godot --headless --path . res://tests/net_test.tscn -- host coop
    godot --headless --path . res://tests/net_test.tscn -- client coop

`tests/bot_watch.tscn` watches the multiplayer bots play a match at high speed, with the player safely aside: `-- coop 3 300` is the rules, how many bots and how many seconds. After those can come a class for all of them and a clock to start from.

`tests/sim.tscn` is a balance simulator. A bot with human limits plays whole nights at high speed and prints one line of results per night:

    godot --headless --path . --fixed-fps 240 res://tests/sim.tscn -- class=ranger spec=2 nights=2 seed=731 skill=good quality=0
    godot --headless --path . --fixed-fps 240 res://tests/sim.tscn -- class=adept spec=0 seed=731 loadout=full quality=0
    godot --headless --path . res://tests/balance_probe.tscn

`loadout=full` starts with a level-10 left-choice build. Omit it to test normal progression.
The exhaustive probe evaluates all 128 binary choice combinations per profession. These tools
are balance diagnostics; headless timing is not phone GPU performance. See [the balance review](BALANCE_REVIEW.md).

The leaderboard reuses Epic but needs [portal definitions and policy setup](EPIC_LEADERBOARD.md).

Screenshots and performance need a display:

    godot --path . --rendering-driver opengl3 res://tests/shots.tscn -- /some/folder 2
    godot --path . --rendering-driver opengl3 res://tests/art_shots.tscn -- /some/folder
    godot --path . --rendering-driver opengl3 res://tests/top_shots.tscn -- /some/folder village fort sandbox
    godot --path . --rendering-driver opengl3 res://tests/tree_shots.tscn -- /some/folder
    godot --path . --rendering-driver opengl3 res://tests/weather_shots.tscn -- /some/folder
    godot --path . --rendering-driver opengl3 res://tests/animal_shots.tscn -- /some/folder
    godot --path . --rendering-driver opengl3 res://tests/perf.tscn -- 2

## Art and sound tools

Everything generated is made by the scripts in `tools/`. They need Python 3 with NumPy, SciPy and Pillow, ffmpeg for the sound, and Node.js for the last one. Run them from the project root, then reopen Godot or run `godot --headless --path . --import`.

| Script | Makes |
|---|---|
| `tools/make_audio.py` | All sound effects |
| `tools/make_music.py` | All the music. The score is written in this file, and it plays it with the VSCO 2 Community Edition samples. They are 3 GB and not kept here, so clone https://github.com/sgossner/VSCO-2-CE and pass its folder: `python3 tools/make_music.py path/to/VSCO-2-CE` |
| `tools/make_icons.py` | Every icon |
| `tools/make_ui.py` | Discs, slider knob, menu shade, the Botti Doubloon and the wordmark |
| `tools/make_launcher.py` | Launcher icon and splash |
| `tools/make_assets.py` | The ground texture |
| `tools/slim_characters.mjs` | Strips the KayKit characters down and joins them into one mesh per material |

## Redeem codes

Codes are kept in `scripts/game.gd` as SHA-256 hashes, so reading the source does not reveal them. To add one:

    printf 'NEWCODE' | sha256sum

Put that hash in `CODES` with the class it opens. Each code works once per phone: there is no server to count them across phones.
