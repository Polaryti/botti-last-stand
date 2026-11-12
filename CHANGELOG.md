# Changelog

## Development — Beyond the Mists, part 1: Weapons

### Two-Handed weapons
- A new weapon group, Two-Handed. The Bell Hammer, Pitchfork and Scythe are Two-Handed, joined by the new Greatsword.
- Only Infantry, Chivalry, Monk, Adept, Artificer and Commander can wield Two-Handed weapons. Melee and ranged rules for every class are unchanged.
- Greatsword: wide, heavy sweeps that cut through up to five. Found on every map.

### Found beyond the Mists ("Map Exclusive · Mesenlla")
- Battleaxe (Two-Handed): every third blow in a row is a cleaving chop that does double damage and throws enemies back.
- Rift Chakram (ranged): a ring of mist-glass that ricochets on to three more enemies and needs no arrows.
- Both will lie on the new maps when they arrive later in this update.

### Codex, Armory and class screen
- Each class shows the weapon groups it can wield as tags: Melee, Two-Handed, Ranged and Exclusive Weapon. Weapons in the Codex show their group.
- Class stats and descriptions read the same on the Codex, the Armory and the class screen.

### Stealth
- After invisibility ends, for any reason, you cannot turn invisible again for 3 seconds. A "Revealed" icon on the effects row counts it down.

### Playing together
- Phones on this build only play with phones on the same build.

## Development — Smoother Crowds
- Store class descriptions and profession summaries scroll within the detail panel, while the preview and purchase controls stay visible.
- Terrain and bridge checks do less repeated work in busy areas, with the same walking surfaces and approach margins.
- Stationary enemies reuse their ground-shadow placement; moving or airborne enemies still update correctly. Terrain rebuilds refresh cached shadow results.
- Animation distance checks retain the same detail and update rates with simpler calculations.
- Mists portals gain finer moving filaments and smoother edges, while fully transparent corners skip unnecessary shading.

## Previous development — Steadier Light
- Firelight follows the burning enemies nearest your view, using the same number of lights.
- River highlights receive pixel-width filtering to soften distant shimmer.
- Ground and pool shaders use simpler lighting calculations while retaining their falloff and highlights.
- Pickup scanning and icon loading do less repeated work, without changing reach or artwork.

## 0.21.4 — A Portal Worth Defending (11 November 2026)

### The Fort
- The last bastion now protects a glowing portal to The Mists instead of the Heart. Defend the portal and keep the gates standing until dawn.
- Gate repair signs now say Wood. The Fort objective and Adept stance display no longer overlap.

### Your class and equipment
- The Armory introduces each class and its base stats, explains its three professions, and shows its Class Upgrades and equipment controls. Toggling an upgrade keeps your place in the list and your model preview.
- Class and profession introductions are more consistent. Beastmaster skill descriptions now refer to your pet and its ability.
- Commander has a new officer helmet and redesigned class and profession emblems, with matching frames.
- Monk's hands are visible again, with working punch animations. Magician can wield only the Staff. Attacking breaks invisibility.
- Plague Doctor now has 100 base health and 100% movement speed. Commander moves at 105% speed, and Artificer has 100 base health. Heavy Infantry starts with a Flail.

### Finds worth travelling for
- Scythes, Pitchforks, Throwing Axes and Torches are found in The Village and The Fort. Artificer still starts with a Torch on every map.
- Bell Hammers are found in The Mists. Their Codex badge uses the same blue as the Mists creatures.
- Plague Rat and Bell Spirit familiars, Carrion Crows and Dread Riders appear only in The Village and The Fort.
- Idle Clever enemies search farther for weapons they can reach.

### Clearer battles and field notes
- Fire and poison arrows have distinct effects that preserve their arrow shape, separate from fireballs.
- Invisibility adds a screen tint. Timed status icons and more distinctive combat messages make effects, backstabs and dodges easier to read.
- The Codex groups enemies into families, highlights map-exclusive entries, explains general status conditions, and introduces the three maps with their own emblems and lore.
- Removed duplicate descriptions and class prices from the Codex. The Armory explains professions and Class Upgrades without listing the entire skill tree.
- Menus respect mobile screen cutouts and safe edges. Touch lists no longer display scrollbars. Inspecting another skill clears the previous inspection ring.

### Fixes and playing together
- Fixed phantom fire, poison, blood and attack effects when starting a match.
- Temporary hit and freeze appearances now restore correctly when effects end or a player falls and respawns.
- Online matches require everyone to update to 0.21.4 so class balance and map rules agree.

## 0.21.3 — Steadier Online Games and a Fairer Fort (10 November 2026)

### Online games
- A player whose connection was slower than the others no longer falls further and further behind. Through the online relay, positions, poses and the clock used to queue up for a slow phone; now a late update is skipped and the newest one is used, so that phone stays in step and its timer agrees with the host's.
- Inventor sentries and burning or poisoned ground placed by another player now always appear on every phone; they could go missing before.
- Phones on 0.21.3 only play with other phones on 0.21.3: update every phone before playing together.

### Playing together
- The list of players shows everyone's health. A player who is down is greyed out with "Down, back in 14 s", and "Out" when they have no lives left.
- Buffs from another player, like a Commander's rally, appear in the row of effects with their time left, as do your own skills' buffs, a Shield Dome over you and a Guardian's cover while you stand near one.

### Controls
- The drop-weapon button has moved to the top row, beside the skill tree, and needs to be held for half a second ("Hold to drop"), so a passing thumb no longer throws a weapon away.

### Defend the Fort
- Enemies are sent evenly against all four gates and come from that gate's side. When a gate breaks, only its own attackers and about a quarter of the others go for it, so the other gates stay under pressure.
- Much more wood: 5 pieces for one player and 2 more per extra player, a new piece every 4 seconds while short. Almost half lies 6 to 15 m outside the walls, the rest out in the field or in the woods, never in a gateway.
- The wood a gate needs is painted on the wall above the gateway, inside and out, so it can be read from any angle. Gate names stand clear of the battlements.

### Classes
- The Adept is switched off for now. It can't be picked, bought or used by bots. Phones that own it keep it for when it returns, and its code is not used up.
- Commander: Warlock's Last Command also calls a Magician, and Gunner's Last Command an Artificer. Vanguard's Command calls an Infantry, and Last Command two Infantry and a Ranger, a new ally that shoots arrows.

## 0.21.2 — Leaderboard Prizes and Fairer Trees (10 November 2026)

### Leaderboard
- Each kind of match has its own board as well as the overall one: Night, Mists, Fort, Co-op and Versus (All vs All and Teams), each with all-time and weekly tabs.
- A new **Your matches** tab lists your last 30 counted matches: result, length, mode and map, class and profession, and points.
- The end screen says where a match left you, for example "+60 leaderboard points: #2 this week and #3 of all time (up 2)".
- Weekly prizes: when a week ends, the top three of that week's board win 120, 80 and 50 Doubloons (equal points share a place). The game hands them out the next time you open the menu online, once.
- Rude names are refused with "That name isn't allowed". Accents, numbers standing in for letters and stretched letters don't get round it; ordinary names that happen to contain a rude word stay allowed.
- Defend the Fort matches now reach the leaderboard. The 0.21.1 board turned them away.
- An admin page for the board (behind a private key) can rename or hide a player, reset their scores, remove them, or take back a single match. A renamed player's phone takes the new name.

### Skill trees
- Eight picks that only made zombies see or hear you less are gone; zombies already chasing you ignored them. In their place: Still Mind (Spirit Walker) slows enemies around you every 10 s; Void Appetite (Void Walker) stacks melee damage on kills; Bird Mask (Plague Doctor) heals 1 per second; Thick Mist (Revenant) also refills Mist 15% faster; Mist Landing (Mist Leaper) heals and returns Mist on landing; Rift Feast (Rift Traveller) heals on each hop; Cutthroat and Shadowstep (Shadow Blade) heal or speed you up on backstabs; Fletcher (Trapper) returns an arrow per kill.

### Balance
- Infantry has 110 health and heals 2 from every kill. Shadow Blade gains +20% melee damage and a 15% chance to avoid hits instead of quieter steps.
- Warpriest: Blessing heals 0.5 more per second instead of 1, and Shield of Faith comes every 50 s instead of 35.
- Paladin heals 0.5 per second on foot as well as while riding (1 per second riding). Horse Archer gets +20% ranged damage at all times and 2 arrows back per kill. The Mechanic's War Chariot mends 2 health a second.
- Blade Dancer sweeps heal 2 per enemy hit, up to 10. Opening Void stance heals 15. Mist Leap landings deal 20 damage around you and heal 5.

### Playing together
- Phones on 0.21.2 only play with other phones on 0.21.2: update every phone before playing together.

## 0.21.1 — Names and the Leaderboard (10 November 2026)

### Your name
- Choose a display name when you start the game. Other players see it in games together and on the leaderboard, and each name belongs to one player. Tap your name at the top of the menu, or in Play Together, to change it.
- Choose a name offline and it waits for the next connection. If someone takes it in the meantime, the game asks you for another.

### Leaderboard
- A new Leaderboard on the menu lists the top 50 players of all time and of this week (from Monday 00:00 UTC), with their points and their most-played class and profession. Your own place shows even when you're not in the top 50.
- Every finished match outside the Sandbox earns points: 1 per kill, 5 per full minute, 50 for winning. Easy scores 0.75 times as much and Hard 1.25 times. The end screen shows what the match was worth.
- Matches played offline are kept and sent later, and each counts once. The dev app and the released game have separate leaderboards.

### Classes and skills
- Monk now costs 920 Doubloons and Artificer costs 598. Adept is available in the Store for 1,150; existing owners keep their unlocks, and its class code still works.
- Guardian gains Oathkeeper: blocks store up to 20 healing, spent when raising Shield Dome to mend nearby allies and summons.
- Warpriest gains Last Rites: every third kill sends out a funeral flame, healing allies near the fallen and igniting surrounding enemies.
- Warlord gains Faultline: every third connecting swing splits a narrow line through the crowd, damaging, pushing and slowing enemies. Walls stop the fissure. Earthbreaker now counts connecting swings rather than each enemy struck.

### Store and Armory
- Heavy Infantry upgrades are now permanent Store purchases: Oathkeeper (240 Doubloons), Last Rites (260) and Faultline (280). Equip or disable them in the Armory; they work on their matching professions. The original free skill-tree choices return.
- Upgrade displays demonstrate their effects: a shower of arrows, a Berserker rising through flames, moving pets, flurries, shrouds, funeral flames, healing motes and ground fissures.

### Music
- The menu has a theme of its own. The Mists and Defend the Fort each have new music: one for the quiet, one for when you're hunted, and one for dawn.

### The Village
- Dry hillside navigation restrictions no longer form invisible walls for players. Deep-water and map-boundary barriers remain.
- The Windmill has collision matching its tapered tower. Bonfires have level ground beneath their full footprints, and the fires near Windmill Hill and Castle Road have clearer positions.
- Ground continues behind the boundary forest, covering the visible seam. A small memorial resting place fills the clearing north of the Church.

### The Mists
- The map names every island and shelf, and highlights the islands affected by Mist Storms, including the final retreat.
- Shelf stairs have matching continuous walking surfaces and solid ramp connections across island rims. Shrines have wider, clearly open approaches.
- The northern parkour shortcut reaches its shelf. Floating stones have matching upper and lower facets; the southern monument has a smaller, centred base and a clearer staircase landing.
- The forest parkour spiral leaves headroom above the western shelf ramp, keeping the route open for mobs and bots.

### The world
- Homes have rugs, shelves of crockery and herbs drying from the beams. Barns, sheds and halls get shelves.
- Gaining a level sends a golden ring and rising sparks around you, and every ability flares in its class's colour at your feet. Other players see both.
- Mist Storms gather every 70 seconds. Their warning, damage duration and final-boss retreat rules remain the same.
- Snakes slither, breathe and lunge when biting, including other players' snakes. Their Store preview moves too.
- Fort firewood replenishes in reachable woodland locations, well away from the gates. Each damaged gate shows the wood needed on both faces; the HUD only lists what you carry.
- Bots use the Fort’s side doors when fetching woodland supplies instead of walking into the walls.
- Repaired gates wait for players and summons as well as enemies to leave the doorway before closing. Summons appear on their correct ground height immediately.
- Fences and fallen logs follow uneven terrain. Rocks settle onto slopes, and trees and boulders leave house footprints clear.

### Playing together
- Everyone in a multiplayer room needs this version.

## 0.21.0 — The Mists Update (9 November 2026)
### Enter The Mists
- The Mists takes over the title screen. Explore its floating islands beneath a blue moon, with drifting mist, glowing portals, rippling pools and waterfalls disappearing into the dark.
- Bridges, stepping stones and portals lead to scattered supplies and small island shrines. Food and arrows favour the outer islands: leave the arena, explore and prepare for the final stand.
- Mist Storms gather every 90 seconds. You have eight seconds to evacuate before the island becomes dangerous for 20 seconds. Watch the violet mist and warning rings, and use the open gates to escape.
### The Veil Regent awaits
- Face new mist-born enemies: Lantern Wisps mark you with delayed magical strikes, Mist Weavers cover your escape routes, and Fallen Revenants hunt with spectral claws and mist leaps. Their attacks warn you with distinct sights and sounds.
- Around 8:30, the Veil Regent awakens in the central arena. Dodge its seals, find the safe eye of its crown attack, and brace for reinforcements when the fight turns against it. Defeat it to claim an Angel familiar.
- The Regent's arrival brings permanent storms to every outer island. You have 20 seconds to return to the centre; portals stay open for the retreat.
- To win The Mists, survive ten minutes AND defeat the Regent. If the boss still stands at dawn, your fight continues. Bring allies: the Regent grows stronger with your party.
### Commander joins the battle
- A new tournament-prize class, obtained as the “First prize in VRAIN tournaments” and unlocked by code. Only one human Commander can join a match; bots cannot take the role.
- Warlock wields a War Staff whose fifth attack unleashes piercing magic. Command calls a Magician; at level 10, Last Command replaces the summon with a storm of slowing winds and enemy-only lightning.
- Gunner fights with a Musket and bayonet, and calls a torch-bearing Artificer. Last Command lets you choose an artillery zone: a four-second warning, five seconds of shelling, and lingering fires that spare allies.
- Vanguard carries a battle banner and rallies nearby allies with a voiced battle cry and a burst of speed. Last Command revives eligible fallen allies, strengthens the group and calls two Infantry into the fight.
### Refined classes and combat
- Adept stances now demand commitment. A clear stance display and a short transition make each change easier to follow; landing three attacks empowers your next transition. Blade Dancer gains prepared sweeps, Mirror Step gains defensive counters, and Void Walker keeps its hit-driven invisible stance.
- Plague Doctor gains stronger darts, better survivability and improved poison reliability. Poison wears enemies down without repeatedly stunning them. Revenant recovers Mist more readily, and Inventor's devices hit harder.
- Guardian's Shield Dome now reduces incoming damage by 60% instead of granting invulnerability. Familiars stay for 20 seconds.
- Chivalry's Lance and the Plague Doctor's Blowgun belong to their classes: they cannot be dropped or found as loot. The Sling has been removed.
### A clearer, livelier world
- Revised lance thrusts, scythe sweeps and flail swings give weapons more natural movement. The War Bell Hammer has a new armoured model; bows and crossbows visibly loose and reload their arrows.
- Vanguard's banner has animated cloth and clearer placement in both first-person and other players' views. Mist-born enemies dissolve when defeated, and their attacks have stronger warning and impact effects.
- The Village gains drifting haze and fireflies; Defend the Fort gains smoke and embers. Village house floors stay clear of terrain, crops leave bonfires open, and the mill wheel turns in the river.
- Mists portals and monuments have clearer approaches. Mobs can enter shrines, arena ramps are walkable slopes, and torches, paving and runes sit on their proper surfaces.
### Better together
- Bots explore the islands and escape Mist Storms. Their Ghost Knight familiars follow the correct owner, and players can ride bot-summoned horses and war chariots.
- Improved shared combat, fort gate repairs, projectile behaviour and player animations make multiplayer more consistent. Everyone in a room needs this version to play together.
- The Codex explains how earned and prize classes are obtained, with a cleaner item list. Your existing saves and unlocks carry forward.

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
