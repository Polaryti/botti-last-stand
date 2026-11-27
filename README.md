# Botti's Last Stand

**0.23.0 — Archipelagos of the Forgotten Gods** sails on from Port Vael to Fontanova, the first island of an archipelago of forgotten gods, with its own rites, creatures, cult and the fallen god Al'quimelea, the Ascendant, new weapons, a sea chart of the Archipelago and a random place to play. Read the [release notes](CHANGELOG.md).

A first-person, low-poly medieval zombie survival game built with **Godot 4.7.2**, designed for landscape play on Android phones. Fight through a ten-minute night, defend a fort, or compete with friends while the undead hunt everyone. Touch controls support moving, looking and attacking at the same time; keyboard and mouse are available for desktop development.

Play solo, add bots, or make a room for **up to four players total**. LAN games work on the same Wi-Fi or a phone hotspot without internet. Online rooms use Epic Online Services and require internet, the optional plugin and build-time credentials. One player hosts the simulation; there is no dedicated game-server service in this repository.

## Play modes

| Mode | What you do |
| --- | --- |
| Survive the Night | Survive until dawn, ten minutes after the match starts. The Mists also requires defeating the Veil Regent, and the Valleys of Mesenlla the Great Revenant Elemental. Enemies grow more dangerous as the clock advances; the final two minutes trigger the last stand. In Port Vael the night lasts fifteen minutes, and dawn waits for the Hollow Sovereign, the Leviathan and the Kraken. On Fontanova it lasts twelve, and dawn waits for Al'quimelea. Choose the Village, the Mists, the Valleys of Mesenlla, Port Vael or Fontanova, or a random place. |
| Defend the Fort | Protect the portal in the keep and repair damaged gates with wood. Stairs lead onto the walls and small exits let you venture outside. Losing the portal or everyone falling ends the defence. Choose the Fort or Mist Bastion. |
| Co-op Night | Survive together on the Village, the Mists, the Valleys of Mesenlla, Port Vael or Fontanova, or a random place. Fallen players normally return after 20 seconds, provided someone is still standing. |
| All vs All | Fight players and zombies with three lives each. Respawns take six seconds while lives remain. A shrinking, damaging fog forces survivors together; the last player with lives remaining wins. Played on the Village, the Valleys of Mesenlla, Port Vael or Fontanova. |
| Teams | Team-based PvP with zombies, abilities that affect opponents, friendly support and respawns, on the Village, the Valleys of Mesenlla, Port Vael or Fontanova. |
| Sandbox | Try owned classes with skill points available immediately. Weapon/item stands, durable target dummies, enemy spawning and weather controls let you test builds without a normal night timer. |

Bots occupy player slots and support multiplayer rules, levelling, skill choices, weapons, abilities, familiars and fort repairs. Multiplayer also includes spectating fallen players and riding as a passenger on another player's horse or war chariot. **Spectator Mode** lets up to four more people watch a match under way, like a broadcast: Same Wi-Fi and public online matches are listed under Matches to watch, and a private match can be watched with its code.

## Maps and combat

**The Village** has enterable buildings, farmland, hills, a castle and a river crossed by bridges and fords. Crops hide you, firelight makes you easier to see, and sound attracts enemies. The church bell marks elapsed minutes and draws attention. Local ground haze and warm fireflies give the night its atmosphere; Defend the Fort uses smoke-toned wisps and ember motes.

**The Mists** is a separate survival map of floating islands, ruins, bridges, stepping stones and timed portals. Falling into the void is fatal. Its hazards include jumping enemies, Rift Stalkers and airborne Mist Harriers. Night lighting, drifting wisps and glowing route inlays accompany its own Lantern Wisps, Mist Weavers and Fallen Revenants. Once around 8:30, the Veil Regent awakens in the arena: dodge its marked seals, use the safe eye of its crown attack, and defeat it. Its second phase calls reinforcements; its health scales for multiplayer. Island Mist Storms gather from 0:45, each 12 seconds after the last one ends, and from 5:00 two can rage at once: an 8-second evacuation warning, then 20 seconds at 6 HP/s. Smooth amphitheatre ramps, terrain-following shrine floors, rippling pools and animated portals keep routes readable. Supplies and small supply shrines favour the outer islands, while encounters replenish near explorers and on quieter islands. Bots explore and flee storms. Winning requires both surviving ten minutes and defeating the Regent. When it awakens, all outer islands and shelves gather permanent Mist Storms: a 20-second warning gives the party time to return through open gates to the safe central arena. The match continues beyond ten minutes if the boss is still alive.

**The Valleys of Mesenlla** lie beyond a Great Portal of the Mists, under a luminous twilight: a deep, heavily forested valley ringed by mountains. Players start in a makeshift outpost on a raised shoulder, with a plank hall, palisades, watchtowers and tents; the Great Falls feed a river crossed by a log bridge and fords, under mossy rock arches, with the Ring of Stones, the Woodcutters' Camp, a crag and an overlook around it. In the south, the Fallen Hall, the Hunters' Lodge and the Old Mine keep caches of rarer weapons or a potion (refilled 100 seconds after they are taken), and the Stag, Bear and Mossy Spring shrines bless whoever touches them. From 2:00 the outpost is shelled; at 5:15 a barrage brings it down and a Mist Storm covers it for the rest of the night. Only the Creatures of Mesenlla roam here: Children of the Woods, Bears, Eagles, Shapeshifters, Elementals, the Woodland Cavalry (from 5:00) and Wyverns of fire, ice or storm (from 5:00). At about 8:30 the Great Revenant Elemental rises at the Ring of Stones; dawn waits until it falls. Its music is played on harps, strings, recorders, flutes and bells. The map is also available in All vs All and Teams, and its nights count on the Survive the Night leaderboard.

**Mist Bastion** is a Defend the Fort map beyond the Mists: a citadel on a mountaintop guards a Great Portal, a ring of runestones turning in the air. Its west, middle and east gates each have a postern beside them, and the creatures of Mesenlla climb three lanes to them, kept apart by spines of rock. From 0:20, and every 40 seconds while a lane has fewer than two, a Mist Soldier steps out of each lane's waystone and holds a post on that lane: Mist Infantry (117 health), Mist Rangers (72 health, shooting from the post) and, from 3:00, Mist Heavies (221 health, heavy battleaxe blows and a shield that takes 30% off every blow). Their kills give no one XP. Repair the gates with wood as in the Fort. The Mist Reinforcements Map Upgrade strengthens them and posts Mist Rangers on top of the gates, with a Long Bow for the lanes and a Crossbow for the foot of the gate. At about 8:30 the War Wyvern comes for the portal with two riders, making burning passes along the lanes every 22 seconds; any circle that lands on the portal damages it. Dawn waits until the War Wyvern falls. Mist Bastion counts on the Fort leaderboard.

**Port Vael** lies at the end of the road down from the Valleys: a harbour kingdom drowned when the Mists rose like a sea. The upper town, Market Square, the quay with its cranes and warehouses, two breakwaters, a lighthouse, wrecks and a drowned bell tower look over the tide flats. The **Mist Tide** turns every 90 seconds: at low tide the seabed is bare and each wreck keeps a sea chest you can open once; at high tide the flats flood, wading slows you, the sea-mist half blinds you in the water and the Drowned are a quarter quicker. Drowned Sailors, Barnacle Brutes, Brine Hounds, Lantern Jellies, Anglers, Sirens, Press Gangs and Tide Witches come up from the sea, and Wreck Gulls, Storm Rays and Bell Wraiths hunt from above. The drowned court follows: the Harbourmaster (around 3:00), the Kraken's Arms (the high tide after 4:30) and the Mad Lighthouse Keeper (around 6:00). The Hollow Sovereign rises around 8:30 and drops the Sunken Crown (25% harder blows and 2 health a second for whoever wears it, seen by all); the Leviathan of the Mists follows around 11:30. When both have fallen, the Kraken rises in front of the quay, and dawn waits until it sinks. The night here lasts fifteen minutes. In All vs All the Sunken Crown washes up at the Drowned Bell at 2:00.

**Fontanova** is the first island of the Archipelago of the Forgotten Gods, reached by sea after Port Vael: you land in a cove beside the merchant ship that brought you. Olive terraces climb from the shore, the Sacred Way climbs to the temple of Al'quimelea on the Acropolis crag, and the worshippers' village stands on the rim of the Ravine, crossed by two rope bridges; a fall into it kills, and out of your depth the sea drowns you. Its rites move the night around: light the Oracle's Grotto's three braziers for a rare weapon and the Oracle's Eye (marks enemies within 36 m, 20% harder blows, lost when you fall); from 2:00 a god's altar wakes every 2 minutes and blesses all who hold it; the sea floods the beaches at 3:20, 6:40 and 10:00; and from 2:40 transmutation blooms poison whoever stands among them. Mutant Bees and their Beehives, Wasps, Snails, Spiders, Battle Ostriches, Ember Moths and Thornbacks roam it, and the cult of Al'quimelea comes down in processions: Worshippers (some with bows), Priests of Change, Temple Guardians and, from 6:00, Ostrich Guardians, with the Hierophant around 3:00 and the Polemarch around 5:30. At 9:00 Al'quimelea, the fallen god of change, comes down from its temple; dawn waits until it falls. The night lasts twelve minutes.

**Choosing where to play.** Survive the Night and Defend the Fort open a world atlas with two charts: the Known World, its six places joined by the road from the Village to the Fort, the portal paths through the Mists and the road down to the coast, and the Archipelago of the Forgotten Gods, a sea chart off Port Vael's coast with Fontanova its first island. The places that mode can be played in are lit, and each shows its story before you play. A Random place, alone or in a room, picks somewhere you have not just played each match. The loading screen paints the place you are going to, with its story, your class and a hint for it. The title screen tours Fontanova to its own theme. In a match, the Map shows the land in its own colours (the twilight for the lands beyond the Mists), floating islands overhead, rifts, standing stones, portals and waystones, and on a stronghold each gate by its state and the portal's remaining health.

Fight with melee weapons, bows, crossbows, thrown weapons and class-specific attacks. Collect food, ammunition, potions, powers and familiars. Familiars last 20 seconds before duration upgrades. Chivalry’s Lance is class-exclusive and cannot be dropped or found as loot. Weapons fall into Melee, Two-Handed, Ranged and Exclusive groups; only Infantry, Chivalry, Monk, Adept, Artificer, Ascendant and Commander wield Two-Handed weapons (Bell Hammer, Pitchfork, Scythe, Greatsword, Battleaxe, Ship's Anchor, Ferryman's Oar, Ruin-Breaker Greataxe). Port Vael adds the coast weapons: Cutlass, Boarding Hook, Whaler's Harpoon, Flare Pistol, Ship's Anchor and Ferryman's Oar. Fontanova adds the Censer Flail, the Resin Repeater, the Ruin-Breaker Greataxe, the Honeycomb familiar and the Mysterious Flask. Invisibility cannot be regained for 3 seconds after it ends. Enemy types include ordinary zombies, beasts, spellcasters, ambushers, flying enemies, Dread Riders and Fallen Heroes. Most nights are clear; rain and thunderstorms alter visibility, and lightning warns with a glowing ground marker before it strikes.

Each match build progresses to **level 10**: three early choices, one of three specializations, four branch choices and a final ability. Builds combine damage, movement, defence, status effects, summons and active skills.

## Classes and permanent progression

The standard progression includes fourteen classes, available from the start, earned through play or bought in the Store, plus the code-only Commander. Unlocks and purchases are saved on the device; Botti Doubloons are earned in matches and spent in the in-game Store. They are not a real-money checkout implemented by this repository.

| Class | Normal availability | Specializations |
| --- | --- | --- |
| Infantry | Available from the start | Duelist, Berserker, Shadow Blade |
| Ranger | Available from the start | Sharpshooter, Trapper, Beastmaster |
| Heavy Infantry | Available from the start | Guardian, Warpriest, Warlord |
| Chivalry | Defeat a Dread Rider outside Sandbox | Lancer, Paladin, Horse Archer |
| Magician | Finish five games outside Sandbox | Necromancer, Elementalist, Illusionist |
| Revenant | Survive until dawn in the Mists five times | Mist Leaper, Rift Traveller, Summoner |
| Plague Doctor | Deal 3,000 cumulative poison damage outside Sandbox | Apothecary, Pestilence, Rat King |
| Monk | 920 Botti Doubloons in the Store | Bo Master, Spirit Walker, Iron Mountain |
| Artificer | 598 Botti Doubloons in the Store | Pyromaniac, Mechanic, Inventor |
| Adept | 1,150 Botti Doubloons in the Store, or redeem code | Blade Dancer, Mirror Step, Void Walker |
| Bandit | 860 Botti Doubloons in the Store, or redeem code | Thief, Mercenary, Highwayman |
| Cartographer | Win 3 matches in the Valleys of Mesenlla and 3 at Mist Bastion, or redeem code | Star Reader, Worlds Traveler, Pathfinder |
| Tidecaller | Win a match in Port Vael: reach the dawn there or win a versus match there | Tidewarden, Stormcaller, Deepcaller |
| Ascendant | Play a match on Fontanova to its end, won or lost, or redeem code | Godslayer; Adorer of Al'quimelea (win on Fontanova as the Ascendant) |
| Commander | Tournament prize code: “First prize in VRAIN tournaments” | Warlock, Gunner, Vanguard |

Redeem codes can also unlock supported classes. Codes are stored as hashes. Commander remains a tournament-prize code unlock.

**Adept** commits to Wind, Stone or Flame for six seconds, with a visible transition and a persistent stance card. Three connected melee attacks grant +15% damage until the next switch and empower that transition. Blade Dancer converts transitions into sweeps; Mirror Step combines timed damage recovery, protection and counters; Void Walker earns a temporary invisible stance through hits in different stances.

**Bandit** starts with a Dagger, a Long Bow and 20 arrows, and turns invisible with Into the Shadows (4 s, every 12 s). Each path adds a second ability beside it. Thief has Steal: appear in front of the nearest foe within 14 m (players, then bots, then creatures), turn invisible, strike, and knock a droppable weapon out of their hand. Mercenary has Nightfall, a 6 m dome for 8 s that hides the Mercenary and friends inside (for 1.5 s after leaving too) and half-blinds enemies inside. Highwayman has a five-knife Dagger Fan and plunders food, arrows or potions from 12% of kills. Bandits cannot wield Two-Handed weapons.

**Cartographer** starts with a Spear and plants up to three beacons (one every 5 s, each standing 60 s). Beacons within 24 m are linked: friends within 4 m of a beacon run 10% faster, friends on a line heal 2 health a second, and enemies within 10 m are marked through walls. Star Reader turns three linked stones into a constellation (+20% damage for friends, starlight on enemies every 2 s). Worlds Traveler turns them into Waygates that carry friends from one to the next. Pathfinder unearths finds only a Pathfinder can use: the Machete, the Bolas and the Wayfinder's Lantern. Cartographers cannot wield Two-Handed weapons.

**Tidecaller** fights with its own Trident and spends tide, which the Trident draws with every blow that lands (110 health). Call the Tide rolls a wave 14 m ahead. The core of its tree is the Trident: Long Haft, Skewer and Brine. Tidewarden holds the front line in a Tide Shell that refills with every Trident blow and bursts outward; Stormcaller soaks enemies with the Trident and chains Stormspear's lightning between them; Deepcaller raises a sea serpent that fights beside it.

**Ascendant** starts with the Ruin-Breaker Greataxe (110 health) and strikes bosses, minibosses and mutants 15% harder. Ascend leaps up to 8 m and comes down on everything within 3 m for 35, stunning it. Godslayer's Deicide leaps on the enemy you face, ends lesser foes when they are low, and breaks an attack being readied, even a god's; an Adorer of Al'quimelea drinks the Elixir of Change, quickening, poisoning its blows and opening a field of change.

**Commander** is limited to one human per match; bots cannot choose it. Command becomes Last Command at level 10. Warlock keeps a War Staff whose fifth attack fires empowered, piercing magic that staggers enemies, summons a Magician, then commands an enemy-only storm with a Magician beside it. Gunner keeps a Musket with a melee bayonet, summons a torch-bearing Artificer, then selects an artillery circle (with another Artificer) on the map: everyone receives a warning, followed four seconds later by five seconds of shelling across an 18 m radius. Shells leave eight-second fire zones that damage enemies without stacking. Vanguard carries an off-hand banner, rallies nearby allies and calls an Infantry, then revives eligible allies, grants buffs and calls two Infantry and a Ranger. Exclusive weapons never appear as loot and cannot be dropped.



Players choose a display name the first time they start the game (and players from earlier versions on their next start). Names are unique and appear in games together and on the **Leaderboard**, which lists the top 50 players of all time and of the current week by match points, with each player's most-played class and profession. Each kind of match (Night, Mists, Fort, Co-op, Versus) also has its own board, the **Your matches** tab lists your last 30 counted matches, and the top three of each week win Doubloons. Points come from finished matches outside the Sandbox: 1 per kill, 5 per full minute, 50 for winning, scaled by difficulty. The board is a small Cloudflare Worker in `server/leaderboard`, with separate dev and production boards; see [Leaderboard](docs/LEADERBOARD.md).

Every specialization of the thirteen Store-era classes has a Class Upgrade in the Store, shown at work on the Store's stage. Map Upgrades (Mist Reinforcements for Mist Bastion, the Trappers' Guild for the Valleys) change a place for everyone in the match and stack, one level for each player who brings one; cosmetics such as Chivalry's White Stag can be tried on in the Armory, which also manages owned upgrades, Map Upgrades and selected familiars. The in-game Codex documents classes, enemies, weapons, items and familiars. The in-game Changelog reads [CHANGELOG.md](CHANGELOG.md).

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
- [Leaderboard](docs/LEADERBOARD.md): setting up the free Cloudflare boards, how points are counted and checked, and maintenance.
- [Mobile review](docs/MOBILE_REVIEW.md): maintenance fixes, mesh measurements, validation and remaining architecture/device work.

`Validate game` checks pull requests and pushes to `main` and `dev`. It imports resources, runs gameplay and regression tests, exercises paired LAN scenarios, runs the game against local copies of both leaderboards, and captures weather/UI with the Compatibility renderer. The dev release workflow additionally verifies package identity and signing before publishing its APK, and keeps only the newest five dev builds. `Leaderboard` tests the board server and deploys it: `dev` to the dev board, `main` to the production board. Engine tests and desktop captures do not substitute for real Android/iOS device profiling.

## Licence and credits

**All rights reserved**; see [LICENSE](LICENSE). A public repository is not an open-source licence. Third-party models, sprites, fonts and engine components retain their own licences, listed in [CREDITS.md](CREDITS.md).
