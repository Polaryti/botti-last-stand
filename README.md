# Botti's Last Stand

A first-person, low-poly medieval zombie survival game built with **Godot 4.7.2**, designed for landscape play on Android phones. Fight through a ten-minute night, defend a fort, or compete with friends while the undead hunt everyone. Touch controls support moving, looking and attacking at the same time; keyboard and mouse are available for desktop development.

Play solo, add bots, or make a room for **up to four players total**. LAN games work on the same Wi-Fi or a phone hotspot without internet. Online rooms use Epic Online Services and require internet, the optional plugin and build-time credentials. One player hosts the simulation; there is no dedicated game-server service in this repository.

## Play modes

| Mode | What you do |
| --- | --- |
| Survive the Night | Survive until dawn, ten minutes after the match starts. Enemies grow more dangerous as the clock advances; the final two minutes trigger the last stand. Choose the Village or the Mists. |
| Defend the Fort | Protect the Heart in the keep and repair damaged gates with wood. Stairs lead onto the walls and small exits let you venture outside. Losing the Heart or everyone falling ends the defence. |
| Co-op Night | Survive together on the Village or Mists map. Fallen players normally return after 20 seconds, provided someone is still standing. |
| All vs All | Fight players and zombies with three lives each. Respawns take six seconds while lives remain. A shrinking, damaging fog forces survivors together; the last player with lives remaining wins. |
| Teams | Team-based PvP with zombies, abilities that affect opponents, friendly support and respawns. |
| Sandbox | Try owned classes with skill points available immediately. Weapon/item stands, durable target dummies, enemy spawning and weather controls let you test builds without a normal night timer. |

Bots occupy player slots and support multiplayer rules, levelling, skill choices, weapons, abilities, familiars and fort repairs. Multiplayer also includes spectating fallen players and riding as a passenger on another player's horse or war chariot.

## Maps and combat

**The Village** has enterable buildings, farmland, hills, a castle and a river crossed by bridges and fords. Crops hide you, firelight makes you easier to see, and sound attracts enemies. The church bell marks elapsed minutes and draws attention.

**The Mists** is a separate survival map of floating islands, ruins, bridges, stepping stones and timed portals. Falling into the void is fatal. Its hazards include jumping enemies, Rift Stalkers and airborne Mist Harriers.

Fight with melee weapons, bows, crossbows, thrown weapons and class-specific attacks. Collect food, ammunition, potions, powers and familiars. Enemy types include ordinary zombies, beasts, spellcasters, ambushers, flying enemies, Dread Riders and Fallen Heroes. Most nights are clear; rain and thunderstorms alter visibility, and lightning warns with a glowing ground marker before it strikes.

Each match build progresses to **level 10**: three early choices, one of three specializations, four branch choices and a final ability. Builds combine damage, movement, defence, status effects, summons and active skills.

## Classes and permanent progression

The standard progression includes nine classes, plus two code-only classes. Unlocks and purchases are saved on the device; Botti Doubloons are earned in matches and spent in the in-game Store. They are not a real-money checkout implemented by this repository.

| Class | Normal availability | Specializations |
| --- | --- | --- |
| Infantry | Available from the start | Duelist, Berserker, Shadow Blade |
| Ranger | Available from the start | Sharpshooter, Trapper, Beastmaster |
| Heavy Infantry | Available from the start | Guardian, Warpriest, Warlord |
| Chivalry | Defeat a Dread Rider outside Sandbox | Lancer, Paladin, Horse Archer |
| Magician | Finish five games outside Sandbox | Necromancer, Elementalist, Illusionist |
| Revenant | Survive until dawn in the Mists five times | Mist Leaper, Rift Traveller, Summoner |
| Plague Doctor | Deal 3,000 cumulative poison damage outside Sandbox | Apothecary, Pestilence, Rat King |
| Monk | 800 Botti Doubloons in the Store | Bo Master, Spirit Walker, Iron Mountain |
| Artificer | 520 Botti Doubloons in the Store | Pyromaniac, Mechanic, Inventor |
| Adept | Redeem code | Blade Dancer, Mirror Step, Void Walker |
| Commander | Tournament prize code: “First prize in VRAIN tournaments” | Warlock, Gunner, Vanguard |

Redeem codes can also unlock supported classes. Codes are stored as hashes. Adept and Commander cannot be bought or earned through normal match progression.

**Adept** commits to Wind, Stone or Flame for six seconds, with a visible transition and a persistent stance card. Three connected melee attacks grant +15% damage until the next switch and empower that transition. Blade Dancer converts transitions into sweeps; Mirror Step combines timed damage recovery, protection and counters; Void Walker earns a temporary invisible stance through hits in different stances.

**Commander** is limited to one human per match; bots cannot choose it. Command becomes Last Command at level 10. Warlock keeps a War Staff whose fifth attack fires magic, summons a Magician, then commands an enemy-only storm. Gunner keeps a Musket with a melee bayonet, summons a torch-bearing Gunner, then selects an artillery circle on the map: everyone receives a warning, followed four seconds later by five seconds of shelling across an 18 m radius. Shells leave eight-second fire zones that damage enemies without stacking. Vanguard carries an off-hand banner, rallies nearby allies, then revives eligible allies, grants buffs and calls two Infantry. Exclusive weapons never appear as loot and cannot be dropped.



Multiplayer uses the original generated names, with the existing optional name field in Play Together. There is no first-launch or upgrade name prompt.

Store upgrades can add specialization abilities, and the Armory manages owned upgrades and selected familiars. The in-game Codex documents classes, enemies, weapons, items and familiars. The in-game Changelog reads [CHANGELOG.md](CHANGELOG.md).

## Android downloads: production and development

Download APKs from [GitHub Releases](https://github.com/Polaryti/botti-last-stand/releases). Check the release label before installing.

| Channel | Branch / release | Android app | Intended use |
| --- | --- | --- | --- |
| Production | `main`; stable `v…` releases | **Botti's Last Stand**, `com.botti.laststand` | Normal play; signed production updates are offered in the menu. |
| Development | `dev`; `dev-…` prereleases | **Botti's Last Stand Dev**, `com.botti.laststand.dev` | Test changes before promotion to production. Installs alongside production with separate saves. |

Every push to `dev` builds a uniquely versioned **Android-only** APK and publishes a prerelease with its checksum and source-commit metadata. It does not replace the latest stable release and does not build iOS. Development builds use a separate multiplayer compatibility namespace and do not offer production updates; everyone in a dev test session should install a compatible dev APK. Dev checks run automatically at launch. A newer dev APK shows the same update prompt as production; no manual check controls are added. Dev and production channels stay separate.

Both channels use the existing signing identity, but Android treats their different package IDs as different apps. The dev APK is an optimized release export, not a change to the production package. Online play is included when all Epic credentials are configured; otherwise its release notes identify it as solo/bots/LAN only.

The production iOS workflow exports an unsigned app for sideloading; it is not an App Store release. See [iPhone builds](docs/BUILDING.md#iphone). The primary supported build target remains Android.

## Development

Open the project in Godot 4.7.2 and press F5, or run `godot --path .`. Export templates, Android SDK configuration and signing keys are separate prerequisites for an APK build. The repository does not contain signing keys, Epic credentials or the compiled Epic plugin.

- [Building and testing](docs/BUILDING.md): Android/iOS setup, signing, online-play dependencies, checks and art tools.
- [Development Android releases](docs/BUILDING.md#development-android-releases): dev package identity, versioning and release workflow.
- [Editing maps](docs/EDITING_MAPS.md): edit map scenes in Godot and use F6 to walk around them.
- [Balance review](docs/BALANCE_REVIEW.md): all class/profession screening, simulation results and limitations.
- [Mobile review](docs/MOBILE_REVIEW.md): maintenance fixes, mesh measurements, validation and remaining architecture/device work.

`Validate game` checks pull requests and pushes to `main` and `dev`. It imports resources, runs gameplay and regression tests, exercises paired LAN scenarios, and captures weather/UI with the Compatibility renderer. The dev release workflow additionally verifies package identity and signing before publishing its APK. Engine tests and desktop captures do not substitute for real Android/iOS device profiling.

## Licence and credits

**All rights reserved**; see [LICENSE](LICENSE). A public repository is not an open-source licence. Third-party models, sprites, fonts and engine components retain their own licences, listed in [CREDITS.md](CREDITS.md).
