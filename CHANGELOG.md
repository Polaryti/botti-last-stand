# Changelog

Newest first. The game shows this file on its Changelog screen, so keep the same layout: `## ` for a version, `### ` for a part of it, and `- ` for a line. Write for the player: what is new to do, see or earn, in a sentence or two.

## Development — The Mists awaken
### Changed
- Removed the old bell inside the War Bell Hammer, retaining its armoured frame and rear pick.
- The Mists now has a blue moonlit night, stars, a darker flowing mist sea, drifting ground wisps and spectral motes. The Village keeps its lighting.
- Bridge deck inlays, illuminated entry posts and stepping-stone runes make existing routes easier to read at night.
### New
- Lantern Wisps mark your position with a delayed mist seal. Mist Weavers place three seals across your route. Escape the marked area before it bursts and slows you.
- The Veil Regent awakens once in the arena between 8:45 and 9:00. Its crown attack leaves a safe central eye. Below half health it alternates crown waves with three targeted seals and summons two Lantern Wisps.
- The Regent scales with party size, sees through concealment and resists long disables. Defeating it releases an Angel familiar; surviving to dawn still wins the night.
- All three mist-born enemies have original low-poly models, animated veils, Codex icons and distinct magical warning and impact sounds. Their warnings and damage work in multiplayer.
### Performance
- Mist particles, enemy bodies and active seals have fixed mobile budgets. New enemy and seal shaders warm behind the loading screen. Multiplayer requires matching updated builds.

## Development — Weapon presentation and Commander training
### Changed
- The Lance belongs to Chivalry: no map spawns or drops, including Fallen Knights. Other players, bots and knights carry it forward and thrust with it.
- Scythes reap in one direction. Flails hang from a moving chain and swing forward. Bell Hammers have a reinforced warhammer frame, resonant bell and rear pick.
- Bows and crossbows lose their nocked arrow when fired and load the next one during recovery. The Sling has been removed.
- Gunner Musket reloads in 1.25 seconds instead of 1.5; Command summons a torch-wielding Artificer who burns enemies in melee.
- Every fifth War Staff attack fires an empowered, piercing bolt that staggers enemies. Spellbreaker and Storm Conductor improve piercing or add chain lightning.
- Commander training now includes spell damage, faster early Command, bayonet stagger, piercing musket shots, longer-lived summons and healing rallies. Vanguard banners have folded cloth, raised heraldry, wind movement and improved grips in both views.
- Familiars last 20 seconds. Codex class entries explain earned and code unlocks without zero-price Store text; food and ammunition are no longer listed as Codex items.
### Multiplayer
- Updated the network protocol for the weapon and summon changes. Players must use the same dev build to play together.

## Development — Projectile and animation fixes
### Fixed
- Projectiles stop safely when their owner leaves instead of crediting the host.
- Remote players’ animation speed adjusts while staying in the same animation, preserving its phase.
### Changed
- Shockwave and lightning-warning rims have smoother edges at distance.
- Projectile reuse resets transform and spin in one place; visual-only shots cannot trigger local weapon-return callbacks.

## Development — Artillery update
### Fixed
- Removed the mandatory name-selection prompt and its migration data; original multiplayer naming is restored.
### New
- Dev APKs offer newer dev builds in the menu, with verified downloads and Android installation. Install this dev APK manually once if your older dev build has no updater.
### Changed
- Gunner Last Command gives a four-second warning over an 18 m radius, then fires twenty shells over five seconds. Each impact leaves an eight-second fire zone. Overlapping fire does not multiply damage, and allies remain safe.
- Artillery has a ground-following warning, countdown, falling-shell whistles, deeper explosions, shockwaves, brief smoke, animated flames and distance-based camera shake.
### Fixed
- Artillery lasts until the final shell and fire have finished. Impact sounds are no longer doubled on remote players.
- Multiplayer fog and bot checks isolate their combat scenarios instead of depending on random waves or bot injuries.

## Development — Commander and stance rework
### New
- Commander: First prize in VRAIN tournaments, unlocked by code. Only one per match, and never a bot. Choose Warlock, Gunner or Vanguard; Command becomes Last Command at level 10.
- Warlocks wield a War Staff, firing magic on every fifth attack. Gunners wield a Musket with a melee bayonet. Vanguards carry a banner. Summons, storm lightning, warned artillery and rallying revives complete their command skills.
### Changed
- Adept stances require commitment and a short visible transition. Three landed attacks build mastery; each stance has a persistent HUD card. Blade Dancer rewards prepared sweeps, Mirror Step gains a defensive counter window, and Void kill extensions have a limit.
- Plague Doctor gains health, protection, movement, darts and stronger direct hits. Strong profession poison can no longer be overwritten by a weaker dart; bleeding and poison have independent damage timers.
- Revenant spends less Mist on claws, refills more quickly and recovers more on kills. Inventor devices gain a modest damage increase.
### Fixed
- Maps of different sizes keep independent terrain dimensions, avoiding invalid height samples when changing maps.
- Fort gate changes reach every phone reliably, including a repaired doorway closing after enemies leave it.
- Lingering traps and sentries safely handle an owner leaving. Exclusive weapons reject pickups by other classes.
- Tests use deterministic seeds, isolated scenarios, named groups and strict process results. Skill-tree build coverage reuses the map and runs substantially faster.

## 0.20.2 (8 November 2026)
- No changes to the game. This version is here to try the in-game update: on Android, the main menu offers it and Update installs it. It plays together with 0.20.1.

## 0.20.1 (7 November 2026)
### New
- Bots now play like people. Each one levels up, picks its path in the skill tree and uses its abilities, familiars and Store items, picks up weapons and power-ups, and repairs the Fort.
- Everything you do reaches bots too: skills, fire, poison, bleeding, stuns, traps, familiars and the thundercloud. A bot you hit flashes and shows its health, and you can see when it burns, is poisoned or is stunned. Bots on your side can heal you and guard you, and their blows never hurt you.
- Online games are Public or Private. A public game is listed for everyone under Play Together, with its room code too; a private one can only be joined with its code. The list shows games still waiting for players, and you join with one tap.
- After an online match, the host can take everyone back to the room for another round, and a public game shows in the list again.
- When a new version is out, the main menu tells you. On Android, tap Update and the game downloads it and opens the installer (the first time, Android asks you to allow installs from the game). On iPhone it tells you where to get it.
### Fixed
- Dropping a weapon no longer picks it straight back up.
- Class weapons, like the Monk's Bo, no longer lie around on the map.
- In the Armory, Back from the Store now returns to the Armory.
- Long skill descriptions in the skill tree now fit their cards.
### Changed
- The skill tree button is larger and golden, and glows with a count when you have points to spend.
- Lists in the Store, the Armory and the rest follow your finger exactly, glide on when you flick them, and can be dragged with a mouse. A bar on the right shows where you are, and you can drag it too.
- Ranger: Spare Parts also adds 3 traps to the Trap Satchel. Field of Snares holds 8 traps on the ground and 8 in the Satchel.
- Beastmaster: The Pack now gives you one more beast, and every 20 seconds the pack acts by kind: wolves stun all around you, ravens mark every enemy near you, snakes poison them and foxes bring food or arrows.
- The snake moves faster. The fox takes longer to find something, and now finds arrows as well as food.
- The Monk gains Ki more slowly.
- Defend the Fort: less wood, and most of it lies outside the walls.
- The Mechanic's crest is now a war chariot instead of a turret.
- The main menu no longer shows your best night and dawns reached.

## 0.20.0 (6 November 2026)
### The Mists
- Nothing is safe up on the stones any more. Every zombie that walks now jumps gaps and follows you along the stone lines, and comes back down when you do.
- Rift Stalker: a teal hunter found only in the Mists. It bounds over gaps a zombie could never clear, up to twenty metres.
- Mist Harrier: a pale ray that glides over the void and dives at you. Its blow throws you back, so keep away from the edge when you hear it.

## 0.19.1 (6 November 2026)
### New
- You can now drop the weapon in your hands, to leave it for a friend or make room. You always keep something to fight with, and a class's own weapon stays with it.
- New ways to earn classes. The Revenant comes to those who survive until dawn five times in The Mists. The Plague Doctor comes to those who have dealt 3000 poison damage. The Monk is now in the Store.
### Changed
- The Monk carries one weapon at a time, and goes back to punching if it drops it.
- Lists in the Store, the Armory and the rest now scroll by dragging anywhere on them, like any list on your phone.
- Defend the Fort: wood now turns up right at the gates, starting with the one in the worst shape.
- Things to find are spread out, instead of piling up in one spot.
### The Mists
- The water now flows, like the village river, from pools on several islands to the waterfalls.
- Bridges meet the land properly at both ends, so you can walk across them in either direction and reach every island.
- Monuments, the great sword and their steps are solid now.

## 0.19.0 (6 November 2026)
### New
- The Mists are reborn. Tall rock islands rise from a sea of teal mist: a sunken arena around a giant sword, white rotundas under glass domes, ruined battlements, an old forest and waterfalls off the highest rock.
- Rope bridges with no railings. Mind the edge, because a good hit can throw you off.
- Follow the floating stones for a real test of your jumping. Most lead to a chest of doubloons, with a familiar or a fine weapon inside, and two are short cuts between islands.

## 0.18.0 (6 November 2026)
### New
- Every class now looks like itself, from a straw-hatted Monk to a beaked Plague Doctor, so you can tell who is who from any side.
- Fighters move better. Spears thrust, maces come down from overhead, swords sweep and javelins are thrown, and armed enemies do the same.
### Changed
- The Monk has become a master of Ki. Land hits to fill the bar, then spend it on what your path can do. Bo Master spins and vaults over enemies. Spirit Walker leaves its body behind as bait and walks unseen. Iron Mountain stands still until its skin is stone, then spends it all in one great stomp.
- Only a Monk can wield the Bo.

## 0.17.0 (5 November 2026)
### Changed
- New icons in full colour. Every class has its own crest and every specialization its own emblem.
- Pets now sit with the Beastmaster's upgrades in the Store, and every upgrade shows which class and specialization it is for.

## 0.16.0 (5 November 2026)
### New
- Two new classes. The Monk fights with spirit and bare hands. The Plague Doctor starts with a Blowgun, and can cure friends, spread sickness or command an army of rats.
- The Bo Staff, a long weapon that sweeps wide.

## 0.15.0 (5 November 2026)
### New
- A second map for Survive the Night: The Mists, with islands joined by gates that open and close. Falling off the edge is the end of you.
- Survive the Night now asks where you want to spend it. In a game together, the host chooses for co-op.

## 0.14.0 (5 November 2026)
### New
- The Armory, on the main menu: equip the upgrades you own for each class, and choose your pet.
- New upgrades to buy. Rain of Arrows for the Sharpshooter, a Trap Satchel for the Trapper, Blade Flurry for the Duelist, Undying Rage for the Berserker and Shadow Shroud for the Shadow Blade.
- Beastmaster pets: a Raven that attacks from the air, a Snake that poisons and a Fox that finds food.
- The Store has sections, and what you pick turns slowly beside its description.
- The Revenant now chooses its abilities at each level, like everyone else.

## 0.13.0 (5 November 2026)
### New
- Three new ranged weapons: Javelins that pierce, a Sling that never needs arrows and a silent, poisonous Blowgun.
- Earn Chivalry by killing a Dread Rider, and the Magician by finishing 5 games.
- Bots grow with the night. They level up, go after supplies and back off when hurt, and they get sharper on higher difficulties.
- Defend the Fort: a compass points to each gate, and you can see how much wood you carry and how much each gate needs.
### Changed
- Weapons now feel different. The Long Bow drops a zombie with one arrow, the Dagger strikes twice as hard from behind, and more.
- Fire on the ground has real flames, poison bubbles, and stunned enemies see stars.
- Being poisoned makes every hit hurt more, and bleeding slows you down.

## 0.12.4 (5 November 2026)
### Changed
- Cross the river anywhere: it slows everyone, you and mobs alike, but nothing stops you.
- Stairs are smooth to walk, and the village paths blend into the grass.
- The Revenant spends more Mist on each swing and gets less back, and the Sacred Steed takes longer to return.

## 0.12.2 (4 November 2026)
### Changed
- Moving between Wi-Fi and mobile data no longer stops you from starting a game.
- When you fall in Teams, you only watch your own team.
- Mobs now walk around fences and carts instead of staring at you, and the castle hill has gentler slopes.

## 0.12.0 (4 November 2026)
### New
- Play online from almost anywhere, mobile data included, with no account. Start a game and share the room code.

## 0.11.0 (4 November 2026)
### New
- The game comes to iPhone.

## 0.10.0 (4 November 2026)
### New
- Bots can fill up to three empty places in any multiplayer mode, so you can play All vs All or Teams on your own.
- The game is now called Botti's Last Stand.
### Changed
- All vs All: levels come twice as fast, and taking someone down is worth more.

## 0.9.0 (4 November 2026)
### New
- All vs All: three lives each and a deadly fog closing in. The last one standing wins.
- Abilities now work on other players in All vs All and Teams.
- Weather: some nights bring rain, and a few a storm, with lightning that hurts anyone under it.
- The Illusionist now jumps ahead and leaves a copy behind that draws enemies, then bursts.
- Training dummies in the Sandbox show how much damage you do.
- New music, played by an orchestra, that builds when you are hunted and brightens at dawn.
### Changed
- New skill trees for every class, with one big choice at each level up to level 10.
- Levels come faster later in the game, and enemies are easier to hit.

## 0.8.0 (3 November 2026)
### New
- New class, the Artificer, with three paths: incendiary bombs, a war chariot, or a bag of inventions.
- The Store opens, so your Botti Doubloons have something to buy.
- Sandbox: try any class you own against any enemy, with every weapon on show.
### Changed
- Three seconds of invincibility when you gain a level.
- The bell strikes once for each minute gone, and the river carries you along if you wade in.
- A new look, with firelit colours in place of parchment and iron.

## 0.7.0 (3 November 2026)
### New
- Defend the Fort: hold four wooden gates and protect the Heart, mending the gates with wood.
- The Dread Rider, a mounted enemy that appears from minute 5.
- A Chivalry horse can carry a teammate.
- Botti Doubloons, earned in every match.
- In multiplayer, the fallen come back after 20 seconds, and watch through a friend's eyes until then.

## 0.6.0 (3 November 2026)
### New
- The Revenant: no weapons, only claws of Mist.
- Play through one phone's hotspot.
- Bonfires and torches light the map. Zombies see you further in their light, but a bonfire heals you.
- A map screen in the pause menu.

## 0.5.0 (3 November 2026)
### New
- Play Together: up to 4 phones, with Co-op Night, All vs All and Teams.
- A much larger map with hills, a river, a castle, a graveyard, mills, farms and crops that hide you.
- Every weapon has its own attack.

## 0.4.0 (3 November 2026)
### New
- An ability tree for each class.
- New enemies: Mimic, Scarecrow, Wraith and Banshee.
- Zombie voices, dark music that follows the night, and a better sunrise.

## 0.3.0 (2 November 2026)
### New
- Five classes with their own abilities, chosen before each game.
- A church bell that rings each minute, and a horse to ride.
- More weapons and familiars, and zombies that hunt more cleverly.

## 0.2.0 (2 November 2026)
### New
- The game moves to a medieval village at night, with fog, buildings to enter and stealth.
- New weapons, items, potions and types of zombie.

## 0.1.0 (2 November 2026)
### New
- First version: first-person survival against zombies, with weapons and items to find.
