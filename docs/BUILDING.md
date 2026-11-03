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

## Making a new version

1. Raise `config/version` in `project.godot`, and `version/code` and `version/name` in `export_presets.cfg`. The code has to go up by one each time, or phones refuse the update.
2. Add the notes to the top of `CHANGELOG.md`. The game shows this file on its Changelog screen, so write for players. It reads `## ` as a version, `### ` as a heading and `- ` as a line.
3. Run the tests below, build the app, commit as `Version X.Y.Z` and push.

## Tests

    godot --headless --path . res://tests/test_game.tscn              # everything, about 15 minutes
    godot --headless --path . res://tests/test_game.tscn -- new       # the newest features and map checks
    godot --headless --path . res://tests/test_game.tscn -- quick     # the later half of the checks, without the first play-through
    godot --headless --path . res://tests/test_game.tscn -- soak      # a long night with everything going on

Multiplayer has its own test, which runs two copies of the game talking to each other. Start the host and the client in two terminals. The third word can be `coop`, `ffa`, `teams`, `fort`, `ride`, `chariot` or `soak`:

    godot --headless --path . res://tests/net_test.tscn -- host coop
    godot --headless --path . res://tests/net_test.tscn -- client coop

`tests/sim.tscn` is a balance simulator. A bot with human limits plays whole nights at high speed and prints one line of results per night:

    godot --headless --path . res://tests/sim.tscn -- class=ranger spec=2 nights=3 skill=good quality=2

Screenshots and performance need a display:

    godot --path . --rendering-driver opengl3 res://tests/shots.tscn -- /some/folder 2
    godot --path . --rendering-driver opengl3 res://tests/art_shots.tscn -- /some/folder
    godot --path . --rendering-driver opengl3 res://tests/top_shots.tscn -- /some/folder village fort sandbox
    godot --path . --rendering-driver opengl3 res://tests/perf.tscn -- 2

## Art and sound tools

Everything generated is made by the scripts in `tools/`. They need Python 3 with NumPy, SciPy and Pillow, ffmpeg for the sound, and Node.js for the last one. Run them from the project root, then reopen Godot or run `godot --headless --path . --import`.

| Script | Makes |
|---|---|
| `tools/make_audio.py` | All sound effects |
| `tools/make_music.py` | All the music |
| `tools/make_icons.py` | Every icon |
| `tools/make_ui.py` | Discs, slider knob, menu shade, the Botti Doubloon and the wordmark |
| `tools/make_launcher.py` | Launcher icon and splash |
| `tools/make_assets.py` | The ground texture |
| `tools/slim_characters.mjs` | Strips the KayKit characters down and joins them into one mesh per material |

## Redeem codes

Codes are kept in `scripts/game.gd` as SHA-256 hashes, so reading the source does not reveal them. To add one:

    printf 'NEWCODE' | sha256sum

Put that hash in `CODES` with the class it opens. Each code works once per phone: there is no server to count them across phones.
