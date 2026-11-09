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
