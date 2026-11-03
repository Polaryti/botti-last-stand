# Editing the maps

Every map is an ordinary Godot scene made of pieces: a house, a tree, a hill, a stretch of road. Open it, move things, save, and that is what the game plays. There is nothing to export or convert, and the scene is the only copy, so nothing can overwrite your changes.

## Getting started

1. Install [Godot 4.7.2](https://godotengine.org/download/archive/4.7.2-stable/), the standard version.
2. In Godot's Project Manager choose Import and pick this folder's `project.godot`.
3. In the FileSystem panel, open the `maps` folder and double-click a map:

| File | Used by |
|---|---|
| `maps/village.tscn` | Survive the Night, All vs All and Teams |
| `maps/fort.tscn` | Defend the Fort |
| `maps/sandbox.tscn` | Sandbox |

The map draws itself in the 3D view. The village takes a second or two. Hold the right mouse button and use W, A, S and D to fly around.

**To play the map you have open, press F6.** You land straight in it. Close the window to come back.

## Everyday changes

| To do this | Do this |
|---|---|
| Move something | Click it, press W and drag the arrows. It stays on the ground by itself, wherever you put it. |
| Turn it | Press E and drag the green ring. Any angle works, and walls and doors turn with the building. |
| Copy it | Ctrl+D, then move the copy. |
| Delete it | Delete key. |
| Change it | Click it and use the Inspector on the right: size, roof, crop, kind of tree and so on. The view updates as you type. |
| Add something new | Right-click a group in the Scene panel, choose Add Child Node and type the name of a piece from the list below. Copying a similar piece is usually quicker. |
| Raise it off the ground | Change Lift in the Inspector. Turn On Ground off to place it by hand. |

Change sizes in the Inspector, not with the scale tool. Pieces work out their walls and collisions from their own sizes, so scaling a node makes it look right and collide wrongly. Props have a Grow value for this.

When a hill, road or building moves, the ground redraws a moment later. If it gets in the way, select the top node of the map and turn off Auto Redraw. The same node has a "Redraw the whole map" button.

Pieces inside another piece move with it. Furniture is placed inside its house with On Ground off, so moving the house brings the beds along.

## The pieces

**Buildings**

| Piece | What it is |
|---|---|
| `MapHouse` | A building you can walk into. Set its size, roof, walls and openings. It levels the ground under itself. |
| `MapWall` | A straight wall, for castles and ruins. Runs along its own X axis. |
| `MapTower` | A round tower that shows above the fog. |
| `MapRamp` | Stairs that climb towards its own -Z. |
| `MapSetPiece` | A big landmark as one piece: church, cowshed, windmill, mill wheel, and the fort's walls and keep. |

**Things on the ground**

| Piece | What it is |
|---|---|
| `MapField` | A fenced plot: wheat, barley, corn, garden, orchard, vines or graveyard. Tall crops hide players. |
| `MapTree` | A fir, a broad tree or a dead one. Size and height are up to you. |
| `MapProp` | Barrel, crate, lumber, sack, bucket, wheelbarrow, target, weapon rack, rock. |
| `MapThing` | Bed, table, hay, bonfire, torch, lantern, well, stall, scarecrow, cow, cart, graves, tomb, log pile, stump, rubble and more. Bonfires and torches give real light, which changes how far zombies see. |

**The land**

| Piece | What it is |
|---|---|
| `MapHill` | A rise. Height is how tall, Radius how far the slopes spread. |
| `MapLevel` | A flat area at the piece's own height, blended into the land around it. Good for a village square or a terrace. |
| `MapRoad` | A road. With the piece selected, the curve tools in the toolbar above the 3D view drag, add and delete its points. Turn Cut on to shape the land to the road at each point's own height, which is how a road climbs a hill. Turn Draw off to shape the land without showing a road. |
| `MapRiver` | The river, shaped the same way as a road. It flows from its first point to its last, and carries anyone in it that way. A map has one. |
| `MapBridge` | A bridge along its own Z axis, centred over the water. The land at each end sets its height. |
| `MapFord` | A shallow crossing, with stones to mark it. |

**Things nobody sees in the game** (`MapSpot`)

These show in the editor as small markers. Set Kind in the Inspector.

| Kind | What the game does with it |
|---|---|
| `loot` | Items and weapons can appear here. |
| `poi` | Roaming zombies wander here. |
| `crop` | Scarecrows rise here, so put these in fields. |
| `start` | Where players begin, one spot each, in order. Four phones can play, so keep four. |
| `rival` | The same, for All vs All and Teams. |
| `place` | A name on the map screen. Type it in Text. |
| `wood`, `yard_wood` | Where wood appears in the fort: outside it, and in its yard. |
| `weapon`, `item`, `familiar` | The stands in the Sandbox. Each row fills itself with everything of that type. |

## Doors and windows

A `MapHouse` has one text box per side: North, South, East and West. List the openings on that side, separated by commas. The number is how many metres from the middle of that wall.

| Text | Meaning |
|---|---|
| `door:1` | A door 1 m from the middle |
| `door:1:1.6:2.4` | A door 1.6 m wide and 2.4 m tall |
| `window:-2` | A window 2 m the other way |
| `slit:0` | A narrow arrow slit |
| `hole:0:3:0.5:2` | A hole 3 m wide, from 0.5 m to 2 m above the floor |

For example, `door:1, window:-2` is a door and a window on the same wall. Fence gaps work the same way on `MapField`: `-2..2, 6..9` leaves two gaps in that side of the fence.

## What the game works out by itself

- **Zombies find their way** around whatever you place. Their paths are worked out from the solid things on the map each time it loads.
- **The ground** under buildings and fields is levelled for you. Turn Level Ground off if you want a building to sit on a slope.
- **Fog, light and night** come from the game, not from the map.

## What to keep in mind

- **Fort:** the fort's walls and keep hold its rules: where the gates, doors and Heart are. Leave those two pieces in the middle of `fort.tscn`. Stairs, wood and everything outside are yours to change.
- **Church:** a map should have one, because the bell hangs in it and zombies walk to its door. You can move it.
- **The river divides the map.** Players can only cross on bridges and fords, so check that every part can still be reached.
- **Size of the map:** the top node's Play Half is how far players can go from the centre, and Forest Wall puts trees along that edge.
- **Roads:** nothing stops you placing a house on a road. Press F6 and walk it, or run the check below.

## Checking your changes

Press F6 and walk around first. To look for problems such as a road that has become blocked, run the map checks from a terminal:

    godot --headless --path . res://tests/test_game.tscn -- new

It lists anything that fails and ends with `RESULT`. A line saying `road blocked` tells you where.

## Sharing your changes

Maps are text files, so Git shows exactly what changed. Save in Godot, then commit and push to GitHub. Each new version is built from what is on GitHub, so your edits stay when other changes are made on top. If two people move things in the same map at the same time, Git may ask you to choose between the two versions, so agree who is working on which map.

To try a new map, make a copy of a scene in `maps/` and open it with F6. To put it in the game, add it to `_map_file()` in `scripts/world.gd`.
