# Botti's Last Stand

A low-poly, first-person medieval zombie survival game for phones, made with Godot 4.7.2. Free, with no servers and no internet needed: friends play together over the same Wi-Fi or one phone's hotspot.

The game's own Changelog screen, in `CHANGELOG.md`, lists what changed in each version.

## The game

**Ways to play**

- **Survive the Night:** zombies roam the village, and more arrive as the night goes on. In the last two minutes they sense the dawn and all come for you. Last 10 minutes and a real sunrise burns them away.
- **Defend the Fort:** zombies break down the fort's gates and go for the Heart in the keep. Lose it, or lose everyone, and the night is over. Wood mends the gates, stairs climb the walls and small doors let you out.
- **Play Together:** up to 4 players, on phones or as bots: on the same Wi-Fi, through one phone's hotspot, or online with a room code. Co-op Night, Defend the Fort, All vs All or Teams. Fallen players come back after 20 seconds.
- **All vs All:** three lives each, and a deadly fog closes in on the village. The last one standing wins, in about six minutes. Zombies are still out there, and abilities work on other players.
- **Sandbox:** a small map with every weapon, item and familiar on stands, and any class you own. All your skill points from the start, dummies to hit that never die, any enemy on call, and the weather of your choice.

Most nights are clear. Some bring rain, and a few a storm whose lightning hurts anyone under it, players and enemies alike. The ground glows first.

**Classes**

Each class has its own start and rules, and an ability tree with one big choice per level, up to level 10: three shared choices, one of three specializations, four either/or choices, and a final ability.

| Class | Specializations |
|---|---|
| Infantry | Duelist, Berserker, Shadow Blade |
| Ranger | Sharpshooter, Trapper, Beastmaster |
| Heavy Infantry | Guardian, Warpriest, Warlord |
| Chivalry | Lancer, Paladin, Horse Archer |
| Magician | Necromancer, Elementalist, Illusionist |
| Revenant (Store or code) | Mist Leaper, Rift Traveller, Summoner |
| Artificer (Store or code) | Pyromaniac, Mechanic, Inventor |

The Artificer carries one weapon at a time and starts with a Torch. The Pyromaniac throws incendiary bombs, ending with Chaotic bomblets. The Mechanic builds a slow war chariot that absorbs damage, takes a friend along, and gains a turret and spikes. The Inventor gets a different device with every use, and the button shows which comes next.

**The world**

- A large map at night with hills, fog, firelight, crops to hide in, and a river that carries you along and can only be crossed on bridges and fords.
- The church bell strikes once for each minute gone, half a second apart, across the whole map, and draws zombies towards it.
- Many kinds of enemy, from the plain Zombie to the Dread Rider and Fallen Heroes who grow stronger each minute. Zombies notice by sight and sound, call each other, surround you and search where you were heading.
- Melee and ranged weapons, food, potions and familiars appear around the map and vanish if nobody takes them.
- Botti Doubloons come from every match and buy the two extra classes in the Store.

The Codex in the game describes every class, enemy, familiar, item and weapon.

## Changing the game

- [Editing the maps](docs/EDITING_MAPS.md): every map is a Godot scene you can open and change. Move, turn, copy or delete any building, tree or fire, and drag hills, roads and the river. Press F6 to walk around it.
- [Building and testing](docs/BUILDING.md): building the Android app, the signing key, the tests and the art tools.

iOS is not built yet.

## Licence

All rights reserved: see `LICENSE`. Free assets and fonts stay under their own licences, listed in `CREDITS.md`.
