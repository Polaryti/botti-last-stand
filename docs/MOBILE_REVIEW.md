# Mobile code and visual review

Reviewed against `4acf43bf08bc2f5ee8038d8fa1a63b01d48d9a5c`, using Godot 4.7.2.
The changes preserve the existing art direction, gameplay data and network wire format.
This is a tested maintenance pass, not certification of every device or every gameplay combination.

## Code fixes

- All lobby broadcasts now include the map argument, including host choices and peer disconnection.
  Host choices also follow the same lobby publication path as client choices, keeping the online room
  metadata dirty flag and bot team balancing consistent.
- Invalid classes, maps, teams and rule/difficulty indices cannot enter through lobby choices;
  lobby choices cannot change a match after it starts.
- Pose packets are validated before avatar mutation: exact length, known weapon index and finite
  floats. An invalid weapon byte previously indexed outside the weapon table; NaN transforms
  could reach physics and rendering.
- Settings reject wrong types and non-finite float values, clamp slider values and nonnegative
  progress, and replace the old file only after writing a complete temporary file.
- Coarse pathfinding covers partial edge cells on maps whose dimensions are not multiples of four.
  Completely blocked grids return empty paths/reachability sets without asking AStar for solid endpoints.
- Changing weather retires pending strikes, hides their pooled warning rings and clears a sky flash.
  Reused warning rings restart at zero progress.
- Audio can be stopped explicitly before teardown. Test teardown releases the world and stops
  playback before quitting, avoiding audio playback resources left alive at engine shutdown.

## Visual fixes and measurements

Foliage already used a material with backface culling disabled, but each leaf also had duplicate
front and back triangles. A single triangle gives the same two-sided silhouette; Godot's
Compatibility renderer handles its backface lighting. Buildings retain their two-sided gables.

| Generated mesh | Vertices before | Vertices after | Reduction |
| --- | ---: | ---: | ---: |
| Wheat | 90 | 45 | 50.0% |
| Corn | 213 | 168 | 21.1% |
| Cabbage | 114 | 99 | 13.2% |
| Turnip | 84 | 72 | 14.3% |
| Beans | 96 | 75 | 21.9% |
| Pumpkin | 258 | 249 | 3.5% |
| Vine | 372 | 324 | 12.9% |
| Apple tree | 1,632 | 1,632 | unchanged |

These are mesh counts measured through Godot, not an FPS prediction. Instancing multiplies the
saved vertices by the number of plants drawn. Foliage and horses also receive bounds for shader
movement, so frustum culling no longer uses only their resting shapes.

Other changes:

- Procedural normals use the inverse transpose for nonuniform scale; mirrored transforms retain
  outward winding. Zero scale in the editor does not attempt to invert a singular basis.
- Waterfall edge fading uses increasing `smoothstep` edges. Shock-ring initialization avoids equal
  `smoothstep` edges at zero progress. Both cases previously had undefined shader results.
- Hidden Store/Armory previews stop their 3D animation processing, and rotated item previews stay
  centered around the transformed mesh bounds.
- A hidden or unfocused scrolling list releases its captured finger and inertia state.

The source asset inventory contains 22 glTF/GLB models and 176 PNG images under `assets/`.
The six character models contain 3,921–5,288 source triangles each and twelve animations each.
Existing character imports already generate LODs, disable unnecessary tangents/shadow meshes,
and limit their source 1,024-pixel textures to 512 pixels. UI assets are mostly 160 or 200 pixels.
No automatic decimation or atlas changes were made to animated characters.

The Compatibility renderer was used to inspect rain, indoor rain, lightning warning/impact,
closing fog, multiplayer screens, Store previews, settings, pause, map and Sandbox screens at
1280 × 720. Additional captures cover the Mists' terrain, bridges, waterfalls, combat effects,
animal models and class previews. The performance scene measured 157–255 draw calls and 73,912–109,806 triangles in
its five empty village viewpoints at high quality, and 351 draw calls / 138,358 triangles for its
23-enemy crowd. These are post-change measurements on Mesa llvmpipe, not Android/iOS timings
or a controlled before/after frame-time comparison.

## Build and test maintenance

`Validate game` runs on pull requests as well as `main`, with read-only repository permissions.
It imports resources, runs fast boundary/geometry regressions, the gameplay suite, paired LAN
scenarios, and software-rendered weather/UI captures. It needs no signing or Epic credentials.
Logs and captures are retained as workflow artifacts. Engine errors fail validation even when a
test script otherwise exits successfully.

The release workflows no longer discard import errors. They serialize same-platform release
runs, and Android signing-key cleanup runs even after a failed step. Android SDK license acceptance
also avoids a `yes`/SIGPIPE failure under the runner's `pipefail` shell. The initial Gradle-template
bootstrap still intentionally tolerates its first export failure, then checks that the template exists.

Test fixtures explicitly unlock the classes they exercise, navigate to the local tab before testing
a local host, allow time for slower headless startup, and clean up before shutdown. Run gameplay
and network checks sequentially on one machine: both can bind the same fixed LAN ports.
The paired runner waits for an explicit host-ready marker before starting its client. Otherwise the
host's temporary room-search socket can prevent the client from binding the discovery port on the
same machine. Binding failures now produce diagnostics instead of failing silently. An unparented
button in the scrolling test was also removed; it kept theme, text and texture resources alive at exit.

Local validation used Godot 4.7.2: the final full run passed 1,744 gameplay checks with
`--fixed-fps 240`, and 49 focused regressions passed. Both exited successfully without engine,
shader or script errors, including clean teardown. The affected scrolling/lifecycle scenario
also passed 24 checks separately. Check the added workflow after publishing the branch;
device exports, signing, installation and Epic relays require their own environments.

Paired LAN scenarios passed on host and client: Co-op (34 / 39 checks), All vs All (53 / 26),
Teams (31 / 17), Fort (18 / 18), Mists (16 / 14), bots (20 / 19), horse passenger (14 / 17),
and chariot passenger (21 / 21). These runs exercise two human processes, with two additional
bots in the bots scenario.

## Remaining work that needs a separate design or device measurement

| Priority | Area | Required next step |
| --- | --- | --- |
| High | Multiplayer trust | Combat remains client-reported. Pose/lobby validation is not anti-cheat. Move damage, item claims, cooldowns and rewards to host-owned validation before treating public rooms as trusted competition. |
| High | Android performance | Profile representative low/mid/high devices during a complete night with four players, rain, fire and summons. Measure CPU/GPU frame time, peak memory, thermal throttling and battery use. Set budgets from that evidence. |
| High | Mobile integration | Verify Android signing/update installation, hotspot routing, background/resume, and notch/touch behavior on real phones. Verify unsigned iOS export and installation on a Mac/iPhone. No signing or Epic credentials were used locally. |
| High | Online sessions | Test Epic initialization, room discovery and relay reconnect/disconnect on Android and iOS with the actual plugin and credentials. LAN tests cannot establish relay correctness. |
| Medium | Large scripts | `player.gd`, `world.gd`, `main.gd` and `net.gd` still mix responsibilities. Extract abilities/combat, presentation/effect pools and lobby/discovery incrementally behind the existing scene tests; avoid a simultaneous rewrite that changes balance and protocol behavior. |
| Medium | Asset merge contract | `Models.merged()` retains only the first material. Its current static prop/weapon inputs use one material. Add material-preserving surface groups before allowing multi-material inputs. Animated characters use their scene imports instead. |
| Medium | Visual budgets | Keep opaque water and batched foliage. Measure transparency overdraw from fog, rain and particles on tile-based mobile GPUs before changing particle counts or shader complexity. |
| Medium | Art direction | Character proportions and bright equipment remain stylized. A darker horror direction needs a separate art decision and calibrated phone brightness checks; globally darkening the image would harm enemy visibility. |

## Reproducing validation

See [Building and testing](BUILDING.md#tests) for commands. Use `tools/run_checks.py` for deterministic
save isolation and strict log checking on Linux. Use `tests/perf.tscn` for render counters and the
existing screenshot scenes for visual checks. A headless run alone does not compile or inspect
all displayed shader variants.
