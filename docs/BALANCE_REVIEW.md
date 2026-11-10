# Class and profession balance review

Combat screening revision: [`6666615`](https://github.com/Polaryti/botti-last-stand/commit/6666615c8e3883f707e35df7fcf3f237253f9334). Later visual replication and weapon attachment fixes are covered by the network and render checks.

This pass screened **all 11 classes and 33 professions**, including Commander, and tested both sides of every binary skill-tree choice: **4,224 level-10 builds**. The runtime probes use the real class definitions, ability application, attack intervals and damage modifiers.

The survival sample contains **66 valid post-change nights**, two per profession, using seeds 731 and 1907. Twelve baseline nights cover Adept and Plague Doctor before the rework. Every accepted run produced a result with no engine errors. Raw outcomes are in [survival.csv](balance/survival.csv); stat ranges are in [loadouts.json](balance/loadouts.json).

## Method and limits

The simulator starts at level 10 with the left option at each binary choice, Normal difficulty, Village, quality Low and the `good` reaction/aim profile. It uses ordinary player inputs, can pick up loot, and gets no invulnerability or damage cheats. Its deterministic RNG is reset per night. Commander simulation includes map targeting, musket bayonets and the War Staff's ranged fifth attack.

Two seeds per profession are a screening sample, not a statistical estimate of human win rates. Bot decisions underserve mechanics such as Iron Mountain's stationary defence, horse positioning, tactical artillery prediction and timed Mirror counters. Starting at level 10 also omits early-game progression. Do not tune these professions to the bot's shortcomings alone. Headless timings on a shared CPU do not establish Android GPU speed or thermal stability.

The static direct-DPS metric excludes critical hits, resource downtime, damage-over-time effects, summons, conditional passives, mounts and active abilities. Effective health includes base reductions and dodge, but excludes directional shields, temporary protection and Stone Skin. These ranges check structural outliers and invalid stats rather than predicting a fight's result.

## Changes and reasons

| Area | Change | Reason |
| --- | --- | --- |
| Plague Doctor baseline | 90 → 105 HP; 10% innate damage reduction; speed 1.00 → 1.05; darts 24 → 32; kill refill 1 → 2 | More room to survive while poison works; effective baseline health rises from 90 to 116.7. |
| Blowgun | Impact power 0.25 → 0.65; interval 0.80 → 0.65 seconds | Direct sustained DPS rises from 7.8 to 25 before talents, improving immediate feedback and finishing power. Poison remains non-stacking within its own channel. |
| Poison / bleed | Stronger poison survives weaker reapplication; poison and bleed have separate strengths and lifetimes | Blowgun poison previously overwrote Pestilence's stronger Virulence. One status also overwrote the other's damage. Timers now integrate the remaining duration without an extra expiry tick. |
| Adept | 6-second stance cooldown, 0.3-second wind-up, 3.5-second minimum after reductions; three connected blows grant 15% damage until switching | Transitions require commitment. Staying in a stance builds value, rather than rewarding repeated button presses. |
| Blade Dancer | Prepared transitions deal 60% stronger sweeps; cooldown picks reduce commitment moderately | Rewards landing attacks and choosing the transition moment. Its former 0.8-second base cooldown made sweep spam dominate. |
| Mirror Step | Timed hit recovery retained; every transition grants 70% protection for 1.2 seconds and a stronger next strike; mastery extends protection to 1.8 seconds | Provides proactive defence and counterplay when there is no recent hit to undo. |
| Void Walker | Earned stance sequence retained; kill extensions capped at six seconds per opening | Preserves its identity while preventing indefinitely extended invisibility in dense waves. |
| Revenant | Claw cost 6 → 5; passive Mist regeneration 4 → 6 per second; kill return 5 → 7 | Sustained attacks previously depleted resources too quickly. An empty-target full-bar drain changes from about 9.7 to 16.9 seconds, while still remaining finite. |
| Inventor | 15% more device damage on profession entry | Improves the less offensive device path without raising all Artificer weapon damage. |
| Commander | Warlock fragile, Gunner intermediate, Vanguard durable; 24-second Command and 60-second Last Command | Separates the three roles. Last Command replaces the base skill; exclusive weapons and the one-human-per-match limit constrain availability. |

Infantry, Ranger, Heavy Infantry, Chivalry, Magician and Monk retain their numeric trees after review. Their output depends strongly on role, positioning, resource use and conditional abilities. The sample does not justify broad changes to them. Low bot results for Horse Archer and Iron Mountain are flagged for human testing rather than compensated with automatic damage buffs.

## Survival screening

Each row averages two runs. A full night is 600 seconds; wins are out of two. Compare professions cautiously under the method above.

| Class | Profession | Mean survival (s) | Mean kills | Wins / 2 |
| --- | --- | ---: | ---: | ---: |
| adept | blade_dancer | 563.1 | 162.0 | 0 |
| adept | mirror_step | 541.5 | 118.5 | 1 |
| adept | void_walker | 436.1 | 104.0 | 0 |
| artificer | inventor | 572.9 | 180.0 | 1 |
| artificer | mechanic | 577.9 | 182.0 | 1 |
| artificer | pyromaniac | 550.1 | 175.5 | 0 |
| chivalry | horse_archer | 336.3 | 96.5 | 0 |
| chivalry | lancer | 471.8 | 136.0 | 0 |
| chivalry | paladin | 600.0 | 207.0 | 2 |
| commander | gunner | 572.5 | 198.5 | 0 |
| commander | vanguard | 600.0 | 177.5 | 2 |
| commander | warlock | 472.8 | 136.0 | 0 |
| heavy | guardian | 576.8 | 121.0 | 1 |
| heavy | warlord | 570.9 | 152.5 | 1 |
| heavy | warpriest | 580.2 | 156.5 | 1 |
| infantry | berserker | 540.4 | 172.0 | 1 |
| infantry | duelist | 600.0 | 175.5 | 2 |
| infantry | shadow | 561.6 | 147.0 | 1 |
| magician | elementalist | 530.8 | 201.0 | 0 |
| magician | illusionist | 586.2 | 202.0 | 1 |
| magician | necromancer | 600.0 | 213.0 | 2 |
| monk | bo_master | 600.0 | 169.5 | 2 |
| monk | iron_mountain | 365.8 | 74.5 | 0 |
| monk | spirit_walker | 529.4 | 103.0 | 1 |
| plague_doctor | apothecary | 505.2 | 128.0 | 0 |
| plague_doctor | pestilence | 519.9 | 151.5 | 0 |
| plague_doctor | rat_king | 570.4 | 183.5 | 1 |
| ranger | beastmaster | 542.1 | 184.5 | 0 |
| ranger | sharpshooter | 564.6 | 215.0 | 0 |
| ranger | trapper | 441.8 | 118.0 | 0 |
| revenant | leaper | 366.0 | 87.0 | 0 |
| revenant | rift | 405.0 | 93.5 | 0 |
| revenant | summoner | 395.0 | 110.0 | 0 |

The old Blade Dancer and Mirror Step won both baseline samples with over 200 kills each, illustrating how frequent free transitions dominated that bot strategy. Their post-rework results are lower; the intended tradeoff is deliberate stance play. Plague Doctor's Pestilence and Rat King improve mean kills from 124.0 to 151.5 and 159.5 to 183.5 respectively. Apothecary's sample is mixed, despite its substantially improved baseline health and impact damage. More human co-op and PvP sessions are needed before another numerical pass.

## Runtime and visual costs

- Commander storms query nearby enemies at 2 Hz and strike at 1 Hz. Artillery drops at 4 Hz for five seconds and reuses three shell meshes. Damage runs only on the host; other peers render the warning, field and shells.
- Summons reuse the existing ally pools and replication format. Added kinds are appended to preserve index stability; the multiplayer protocol is incremented for the new content.
- The banner, musket, crown and class gear use low-poly procedural meshes and existing materials. Commander crests and profession emblems use the existing icon vocabulary, stored as SVG sources.
- The stance card combines text, an icon and colour. A progress indicator shows the three connected attacks; the Vanguard banner is sized to preserve the central view.
- The ability-build smoke test reuses one map with a fresh pawn for each build. On this workspace the former roughly 87-second phase took about 18–26 seconds while other diagnostics ran. It retains both-choice coverage and checks engine errors as well as assertions.

## Remaining validation

Test the dev APK on low- and mid-tier Android devices in four-player sessions, with dense poison, summoned allies, a Warlock storm and artillery. Measure frame-time percentiles, memory, temperature and touch response. Include human trials for all three Adept paths, the three Commander roles, Plague Doctor survival and Revenant resource pressure. Verify online rooms against the existing Epic deployment.

## Subsequent dev artillery tuning

The artillery update changes Gunner Last Command to an 18 m radius, a 4 s warning and 20 shells over 5 s. Each impact leaves a 3.2 m radius fire zone for 8 s at 10 damage/s; overlaps do not stack and allies are excluded. The 60 s cooldown and 45 impact damage remain. The earlier simulation sample above predates these changes; it is not evidence of the new build’s win rates.

## November 2026: picks that did nothing, and a progression screening

### Picks replaced

Eight picks only made zombies see or hear you less. Zombies that are already chasing you, which is most of a
night, ignore both, so the picks did nothing in practice. Each is replaced by something that changes a fight:

| Class | Where | Was | Now |
| --- | --- | --- | --- |
| Monk | Spirit Walker, tier 1 | Quiet Mind: seen 35% less far | Still Mind: every 10 s, slow enemies within 5 m for 3 s |
| Adept | Void Walker, tier 2 | Silent Step: seen 30% less far | Void Appetite: kills give +15% melee damage for 5 s, up to 3 times |
| Plague Doctor | Core, tier 2 | Bird Mask: seen 25% less far | Bird Mask: heal 1 health per second |
| Revenant | Core, tier 2 | Thick Mist: +40 Mist and quieter steps | Thick Mist: +40 Mist, and Mist refills 15% faster |
| Revenant | Mist Leaper, tier 4 | After Image: seen 30% less far | Mist Landing: each landing heals 10 more and gives back 8 Mist |
| Revenant | Rift Traveller, tier 2 | Gone Again: seen 30% less far | Rift Feast: each hop heals 5 |
| Infantry | Shadow Blade, tier 1 | Soft Steps (50% less noise) / Cloak (seen 40% less far) | Cutthroat: each backstab heals 6 / Shadowstep: each backstab gives +35% speed for 2 s |
| Ranger | Trapper, tier 4 | Ghillie Suit: seen 40% less far | Fletcher: every kill gives an arrow back |

Shadow Blade's own "30% less noise" is replaced too (see below). Illusionist's Fade and Dazzle and the Trapper's
Lure stay: they act on enemies that are already hunting you.

### Method

The earlier screening started every night at level 10 with the left choice at every tier. This one plays each
night from level 1, the way a player does: the bot levels up during the night and takes a random side at each
tier, so a profession is judged across its builds and its early game. Village, Normal, the `good` bot, quality
Low, ten nights per profession (seeds 5000–5005 and 7000–7003). A full night is 600 seconds.

Ten nights is still a screening sample. A profession's result moves by about 50 seconds between samples of this
size, and the bot can't play some professions as a person would: it doesn't stand still for Iron Mountain's Stone
Skin, and it swaps a Horse Archer's bow for any melee weapon it finds. The swap of the eight picks above was made
while the first batch of nights was running, so most "before" nights already had the new picks; the "before"
column is "before the numbers below were tuned", not exactly 0.21.1. Raw nights are in
[progression.csv](balance/progression.csv).

### Changes and reasons

| Profession | Change | Reason |
| --- | --- | --- |
| Warpriest | Blessing heals 0.5 more per second (was 1); Shield of Faith every 50 s (was 35) | Won 8 of 10 nights and healed about twice what the other Heavy Infantry professions did. Now 5 of 10, still among the strongest. |
| Infantry (all three) | 110 health (was 100), and every kill heals 2 | The starting class. All three professions were the three weakest, dying around level 6 with about 55 kills: the Dagger hits one enemy at a time, and nothing healed it before a profession. At level 10 they were strong, so the help is early sustain rather than damage. |
| Shadow Blade | +20% melee damage, and 15% chance to avoid any hit, in place of 30% less noise | Backstabs rarely happen in a crowd that is already facing you; the profession had no other edge. |
| Paladin | Heals 0.5 per second always, twice that while riding (was 0.5 only while riding) | Weakest Chivalry path on foot, which is most of a night before the horse comes. |
| Horse Archer | +20% ranged damage at all times, and 2 arrows back per kill (was 1) | Weakest in both screenings. |
| Mechanic | The War Chariot mends 2 health a second | Died before or between chariots with almost no healing. |
| Blade Dancer | Each sweep heals 2 per enemy it hits, up to 10; Flowing Health now adds 6 to that | Sweeps only come with stance changes, and the path had no healing unless Flowing Health was picked. |
| Void Walker | Opening Void stance heals 15 | Low sustain outside the five seconds of Void. |
| Mist Leaper | Landing deals 20 damage around you and heals 5 | The leap was only movement until tier 3. |

Iron Mountain is unchanged: its weakness in the screening comes from the bot never standing still, and tuning it
to the bot would make it too strong for a player who does. Mechanic and Horse Archer stay below the middle; they
need human testing before another pass.

### Results

"After" is only shown for professions whose numbers changed.

| Class | Profession | Before: survival (s) | Before: wins / 10 | Before: kills | After: survival (s) | After: wins / 10 | After: kills |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| adept | blade_dancer | 327 | 0 | 69 | 368 | 0 | 82 |
| adept | mirror_step | 471 | 0 | 109 | — | — | — |
| adept | void_walker | 370 | 0 | 80 | 377 | 1 | 84 |
| artificer | inventor | 344 | 3 | 91 | — | — | — |
| artificer | mechanic | 286 | 0 | 51 | 300 | 3 | 71 |
| artificer | pyromaniac | 322 | 4 | 89 | — | — | — |
| chivalry | horse_archer | 276 | 0 | 65 | 326 | 0 | 86 |
| chivalry | lancer | 420 | 2 | 116 | — | — | — |
| chivalry | paladin | 318 | 1 | 83 | 364 | 0 | 90 |
| commander | gunner | 526 | 5 | 177 | — | — | — |
| commander | vanguard | 415 | 2 | 91 | — | — | — |
| commander | warlock | 441 | 0 | 112 | — | — | — |
| heavy | guardian | 506 | 3 | 116 | — | — | — |
| heavy | warlord | 471 | 2 | 111 | — | — | — |
| heavy | warpriest | 591 | 8 | 161 | 550 | 5 | 144 |
| infantry | berserker | 272 | 0 | 56 | 409 | 1 | 96 |
| infantry | duelist | 292 | 0 | 54 | 410 | 2 | 97 |
| infantry | shadow | 308 | 0 | 57 | 366 | 1 | 79 |
| magician | elementalist | 538 | 2 | 162 | — | — | — |
| magician | illusionist | 545 | 4 | 163 | — | — | — |
| magician | necromancer | 430 | 0 | 118 | — | — | — |
| monk | bo_master | 477 | 2 | 118 | — | — | — |
| monk | iron_mountain | 366 | 0 | 74 | — | — | — |
| monk | spirit_walker | 523 | 2 | 100 | — | — | — |
| plague_doctor | apothecary | 502 | 4 | 121 | — | — | — |
| plague_doctor | pestilence | 444 | 0 | 110 | — | — | — |
| plague_doctor | rat_king | 518 | 1 | 128 | — | — | — |
| ranger | beastmaster | 474 | 5 | 154 | — | — | — |
| ranger | sharpshooter | 453 | 1 | 128 | — | — | — |
| ranger | trapper | 424 | 2 | 126 | — | — | — |
| revenant | leaper | 338 | 0 | 77 | 482 | 3 | 123 |
| revenant | rift | 483 | 3 | 135 | — | — | — |
| revenant | summoner | 414 | 0 | 115 | — | — | — |
