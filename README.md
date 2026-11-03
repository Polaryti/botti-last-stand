# Undead Drop

Low-poly first-person medieval zombie survival for phones, made with Godot 4.7.2.

## What works now (version 0.7)

- **Survive the Night:** zombies roam the village and more arrive as the night goes on. In the last two minutes they sense the dawn and all come for you. Stay alive for 10 minutes to reach it, when a real sunrise burns the undead away.
- **Defend the Fort:** a second map with a walled fort in a clearing. Zombies break down one of four wooden gates, pour in and go for the Heart in the keep. Lose it, or lose everyone, and the night is over. Stairs climb the walls, you can jump off them, and small doors let you out but keep the zombies out. Wood lies mostly outside, and standing near a damaged gate with wood mends it.
- **Roam:** walk the map freely with no zombies.
- **Store and Botti Doubloons:** every match pays 1 doubloon a minute, 1 per 5 kills and 20 for reaching dawn, with 1.5 times as much in multiplayer. The Store button is on the main menu but is not open yet.
- **Classes:** Infantry, Ranger, Heavy Infantry, Chivalry, Magician. Each has its own start, rules and ability tree. A sixth, the Revenant, is hidden until a code is redeemed in Settings.
- **Revenant:** no weapons. Spectral claws use Mist, which refills over time and from kills. Mist Burst damages and freezes everything around for 2 seconds. Gifts unlock by themselves with each level, apart from one chosen path: Mist Leaper (bound forward in a burst of fog), Rift Traveller (hop between enemies, untouchable) or Summoner (call one more Revenant for a while).
- **Firelight:** bonfires and torches light the map. Zombies see you 50% further when you stand in firelight or carry a torch, and a bonfire slowly heals you if you stand close.
- **Map screen:** in the pause menu, with your position and place names.
- **Ability tree:** kills give XP, each level gives one choice. Four shared steps, then one of three specializations per class, then 12 more steps and a final ability. 18 levels in all, and the final ability comes around minute 8 of a good night. The game keeps running while the tree is open.
- **Specializations:** Duelist, Berserker, Shadow Blade. Sharpshooter, Trapper, Beastmaster. Guardian (raises a dome and takes hits for teammates), Warpriest, Warlord. Lancer, Paladin, Horse Archer. A Chivalry horse can carry one teammate behind the rider, who can fight but not steer. Necromancer, Elementalist, Illusionist.
- **Enemies:** Zombie, Clever, Magic, Beast, Leaper, Carrion Crow, Gargoyle, Mimic, Scarecrow, Wraith, Banshee, Dread Rider (mounted, from minute 5), and five Fallen Heroes who get stronger each minute. The Codex in the game menu describes them all.
- **Play Together:** on the same Wi-Fi or through one phone's hotspot, up to 4 phones, with no server and no internet. One phone starts the game and the others find it in a list, or join by its address. Summons are shared too. The host picks the difficulty on the same screen. Four ways to play: Co-op Night, Defend the Fort, All vs All and Teams. Fallen players come back after 20 seconds and watch through another player's eyes while they wait. If all of a co-op team are down at once, the match ends.
- **Map:** a large map at night with real hills, light fog and a river that can only be crossed on two bridges and at a ford. The village at the centre has 7 houses, a shed, a barn, a cowshed and a church with a bell. Around it: a walled castle ruin on a hill, with one road up and holes in its walls; a graveyard with a crypt; a windmill on a hilltop; a water mill; a farm; an orchard with vines; two hamlets; a lumber camp; a watch post. Buildings can be entered, and roofs stop flying enemies.
- **Crops:** wheat and barley sway in the wind and hide you. Corn stands taller than you do. Vegetable gardens have cabbages, turnips, beans and pumpkins.
- **Bell:** rings each minute and pulls roaming zombies toward the church.
- **Stealth:** zombies notice by sight and sound, call others, try to surround you, and search where you were heading. Tall crops hide you. Pushing the stick halfway walks quietly.
- **Weapons:** Dagger, Sword, Spear, Mace, Lance, Scythe, Flail, Bell Hammer, Pitchfork, Torch, Short Bow, Crossbow, Long Bow, Throwing Axes, and the Magician's Staff.
- **Items:** food heals, and arrows are one shared stock. Weapons vanish after 60 s and other drops after 45 s.
- **Potions (20 s):** Speed, Sensor, Fire Arrows, Bouncing Arrows.
- **Familiars (40 s, one about every 30 s, announced by a chime):** Angel, Daemon, Archer, Thunder, Raven, Ghost Knight, Thief Imp, Bell Spirit, Plague Rat.
- **Sound:** synthesized creature voices, and dark music in three layers that follow the night: calm, hunted, dawn. Music and sound have separate volume sliders.
- **Difficulty:** Easy, Normal or Hard in Settings. On any of them, whatever rises late in the night is tougher than what came before.
- **Help in the game:** the Codex describes every enemy, familiar, item and weapon, and the loading screen gives tips. An item within reach shows its name, enemies you hit show a health bar, and a red arc shows where a hit came from.
- **Controls:** touch, with auto-jump and vibration that can be turned off in Settings. Keyboard and mouse work for desktop testing.

## Ideas for later

More maps, internet multiplayer with free room codes, an open Store, iOS build.

## Looking at the maps in the Godot editor

The game builds its maps from code when it starts, so `scenes/main.tscn` looks empty in the editor. To see them, open `map_previews/village.scn` or `map_previews/fort.scn`. These are copies to look at: the game does not read them, and changes made there do not reach the game. Maps are changed in `scripts/village.gd`, `scripts/fort_map.gd` and `scripts/landmarks.gd`. After a change, make new copies with:

    godot --path . res://tools/make_previews.tscn

## Run and test

Open the folder in Godot 4.7.2, or run it from a terminal:

    godot --path .
    godot --headless --path . res://tests/test_game.tscn
    godot --headless --path . res://tests/test_game.tscn -- soak

Multiplayer has its own test, which runs two copies of the game talking to each other. The rules can be coop, ffa or teams:

    godot --headless --path . res://tests/net_test.tscn -- host coop
    godot --headless --path . res://tests/net_test.tscn -- client coop

`tests/sim.tscn` is a balance simulator: a bot with human-like limits plays whole nights at 12 times normal speed and prints one line of results per night:

    godot --headless --path . res://tests/sim.tscn -- class=ranger spec=2 nights=3 skill=good quality=2

`tests/shots.tscn` renders reference screenshots, and `tests/perf.tscn` prints what each part of the scene costs to draw. Both need a display:

    godot --path . --rendering-driver opengl3 res://tests/shots.tscn -- /some/folder 2
    godot --path . --rendering-driver opengl3 res://tests/perf.tscn -- 2

## Build the Android APK on Ubuntu

1. Install Godot 4.7.2, its export templates and the Android SDK command-line tools.
2. In Godot, set the SDK path under Editor Settings > Export > Android.
3. Run:

       mkdir -p build
       godot --headless --path . --export-release Android build/undead-drop.apk

`keys/undead-drop.keystore` is a test key, and its password is stored in `export_presets.cfg`.
Keep it so phone updates install over the old version. Make a new private key before publishing on a store.

## Tools

- `tools/make_audio.py`: every sound effect and all the music.
- `tools/make_icons.py`, `tools/make_ui.py`, `tools/make_launcher.py`: icons, iron and parchment textures, launcher icon and splash.
- `tools/make_assets.py`: the ground texture.
- `tools/slim_characters.mjs`: strips the KayKit characters down and joins them into one mesh per material.

See `CREDITS.md` for asset licences.
