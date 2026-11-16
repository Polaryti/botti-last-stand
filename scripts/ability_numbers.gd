class_name AbilityNumbers
extends RefCounted
## The numbers behind abilities whose effect is written in code rather than in their data (a "flag" in
## AbilityData). The code reads them from here, and the words of each ability are checked against them
## (tests/text_audit.gd), so what a screen says is always what the game does.

# Infantry
const EXECUTE_BELOW := 0.3 # Coup de Grace: melee kills enemies under this share of their health
const RIPOSTE_EVERY := 8.0
const RIPOSTE_STUN := 1.5
const RIPOSTE_REACH := 6.0
const RAGE_MAX := 0.6 # Berserker: damage at no health left
const FRENZY_BELOW := 0.5 # Blood Frenzy
const FRENZY_RATE := 1.5
const FRENZY_HEAL := 3.0
const ASSASSIN_HIDE := 3.0
# Ranger
const STILL_AIM := 1.5
const OVERDRAW_EVERY := 3
const OVERDRAW_POWER := 2.0
const KILLING_SHOT_EVERY := 6.0
const KILLING_SHOT_DAMAGE := 300.0
const TRAP_BLEED := 16.0 # a second
const TRAP_BLEED_TIME := 4.0
const SAVAGE_BITE_STUN := 0.7
const SCENT_REACH := 15.0
const PACK_TACTICS := 1.3
const PACK_REACH := 5.0
const BOND_HEAL := 5.0
# Heavy Infantry
const AEGIS_HEAL := 30.0
# Chivalry
const RUN_DOWN_TIME := 1.0
const SACRED_STEED_REST := 60.0
# Magician
const METEOR_EVERY := 4
const FADE_TIME := 2.5
const DAZZLE_REACH := 10.0
const LEGION_IMAGES := 3
const LEGION_TIME := 8.0
const BURST_STUN := 1.5
# Revenant
const LEAP_HEAL := 5.0
const LEAP_MEND_HEAL := 15.0 # Mist Landing: 10 more than a plain landing
const LEAP_MEND_MIST := 8.0
const RIFT_FEAST_HEAL := 5.0
const RIFT_MIST := 6.0
# Monk
const WIDE_SWEEP := 1.5
const STUN_SWEEP := 0.8
const HIGH_VAULT := 1.5
const CRUSHING_POWER := 2.0
const CRUSHING_STUN := 1.5
const LONGER_JOURNEY := 2.0
const MENDED_HEAL := 20.0
const HAUNTING_SLOW := 3.0
const ENLIGHTENED_DAMAGE := 80.0
const ENLIGHTENED_STUN := 1.5
const ENLIGHTENED_REACH := 6.0
const RECOIL_DAMAGE := 15.0
const AFTERSHOCK_SLOW := 3.0
const ROOTED := 1.35
# Adept
const STANCE_MASTERY := 0.15 # melee damage after three blows in one stance
const DANCE_HEAL_EACH := 2.0
const DANCE_HEAL_MAX := 10.0
const DANCE_POWER := 1.6 # a sweep after three blows
const DANCE_ON := 0.15
const DANCE_ON_TIME := 4.0
const DANCE_ON_STACKS := 3
const FLOWING_HEAL := 6.0
const WHIRL := 1.5
const UNDO_HEAL := 10.0
const MIRROR_GUARD := 0.7 # protection after a transition
const MIRROR_GUARD_TIME := 1.2
const MIRROR_GUARD_LONG := 1.8 # after three blows
const MIRROR_NEXT_BLOW := 1.5
const LONG_MIRROR := 1.5
const STILL_REFLECTION := 10.0
const BLINDING_STEP_REACH := 4.0
const BLINDING_STEP_STUN := 1.0
const PATIENT_BLADE := 0.25
const PATIENT_BLADE_TIME := 4.0
const PERFECT_REFLECTION_REACH := 5.0
const VOID_HEAL := 15.0
const DEEPER_VOID := 2.0
const HUNGRY_VOID := 12.0
const AFTERMATH_REACH := 6.0
const AFTERMATH_STUN := 1.5
const WALKER_BETWEEN := 1.0
const WALKER_BETWEEN_MAX := 6
# Plague Doctor
const TONIC_HEAL := 30.0
const TONIC_FRIEND_HEAL := 25.0
const STRONG_TONIC := 15.0
const MIRACLE_CURE := 2.0
const BLACK_DEATH_REACH := 6.0
# Artificer
const BOMB_STUN := 1.5
const BOMBLETS := 6
# Bandit
const STEAL_STUN := 1.5
const SLIP_AWAY := 0.35
const SLIP_AWAY_TIME := 3.0
const NIGHT_DAMAGE := 0.25
const NIGHT_GUARD := 0.2
const NIGHT_HEAL := 2.0
const FAN_SLOW := 2.0
const FAN_CLOSE := 1.5
const FAN_CLOSE_REACH := 6.0
# Commander
const BANNER_REACH := 16.0
const RALLY_HEAL := 20.0
const BAYONET_STAGGER := 0.6
