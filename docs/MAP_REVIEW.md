# Expedition map review

All three combat maps now have optional supply destinations. Sandbox retains its training layout.

| Map | Stop | Site centre (X, Z) | Layout |
| --- | --- | --- | --- |
| Village | Foresters’ Rest | -76, -28 | Canopy below the castle, linked by a woodland loop to the western road |
| Village | Millers’ Store | 96, 32 | Supply awning east of the river, between the east crossing and windmill |
| Village | Ferry Camp | -59, 92 | Farm-side stopping place, with a circuit around the cornfield |
| Mists | Watch Refuge | 110, -16 | Broken stone shelter in the battlements |
| Mists | Root Sanctuary | -105, 24 | Forest refuge with two marked approaches |
| Mists | Pilgrims’ Rest | 20, -110 | Supply ruin east of the rotunda |
| Fort | East / West Timber Depot | 56, -18 / -56, 18 | Outer supply shelters and log stacks, with detours from the gate roads |
| Fort | South / North Supply Post | 32, 54 / -18, -56 | Outer staging posts, with routes back to the radial roads |

Each player receives 15 doubloons, 60 XP, 30 healing and a temporary Speed or Sensor effect, once per chest per match. A living allied player within 8 m adds 15 XP and 10 healing. Multiple companions do not stack the bonus; enemies and fallen allies cannot trigger it. The existing six Mists jumping challenges keep their original rewards.

`MapExpedition` shares the editor/runtime builder. Canopies and broken shelters have open approaches; poles, benches and walls receive matching collision. Buildings and roads are not replaced. Village pads are levelled before terrain baking; individual props sample ground height. Trees and movable clutter leave authored walking lanes clear. Trails appear on the map screen and terrain. Decorative details use the existing cell batching and model scattering. Lanterns use the existing distance/quality light budget.

The artillery warning and scorch sample ground around their perimeter. Twenty shells use a fixed schedule and deterministic spread on every peer. Fire is suppressed on water, island pools and the void; ground markings omit void segments. Only the host applies impact/fire damage; fire checks run at 2 Hz and overlapping zones are deduplicated. Flames are batched instances of the existing shader mesh. Seven-puff smoke bursts replace solid persistent smoke columns; there are no new dynamic lights or shadow casters.

Validation covers dry/walkable cache positions, two approaches, single-claim rewards, companion bonuses, artillery timing/cleanup/damage authority, paired-peer fire visibility and friendly-fire exclusion. `tests/world_review_shots.tscn` captures every stop by day/night, all three map overviews and artillery phases; CI checks renderer errors and uploads the images. Captured desktop draw counts are diagnostics, not Android performance measurements. Real phone frame times, thermal behaviour and audio mixing still require device testing.
