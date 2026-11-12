class_name StatusCatalog
extends RefCounted
## Timed player states shared by the status bar and Codex.
const TIMED := [
	{
		"field": "dome_left",
		"name": "Guardian Dome",
		"icon": "shield_rect+up",
		"desc": "Reduces incoming damage while the dome protects you. It does not grant invincibility."
	},
	{
		"field": "_cast_left",
		"name": "Channeling",
		"icon": "staff+clock",
		"desc": "Preparing an ability. Keep clear of danger until the cast finishes."
	},
	{
		"field": "invis_left",
		"name": "Invisible",
		"icon": "eye_closed",
		"desc": "Hides you from ordinary enemies until the timer ends or you attack. Some foes can see through it. Afterwards you cannot turn invisible again for 3 seconds."
	},
	{
		"field": "invis_lockout",
		"name": "Revealed",
		"icon": "eye+clock",
		"desc": "You have just been invisible. Nothing can hide you again until this runs out."
	},
	{
		"field": "void_left",
		"name": "Void Walker",
		"icon": "eye_closed+star",
		"desc": "An empowered hidden stance."
	},
	{
		"field": "guard_left",
		"name": "Protected",
		"icon": "shield",
		"desc": "Temporary protection from damage."
	},
	{
		"field": "flurry_left",
		"name": "Blade Flurry",
		"icon": "sword+wind",
		"desc": "Faster attacks and critical strikes."
	},
	{
		"field": "rage_left",
		"name": "Undying Rage",
		"icon": "flame",
		"desc": "A revived Berserker fights faster and ignites enemies."
	},
	{
		"field": "spirit_left",
		"name": "Spirit Walk",
		"icon": "ghost",
		"desc": "Walk unseen while your body remains behind."
	},
	{
		"field": "mirror_guard_left",
		"name": "Mirror Guard",
		"icon": "shield+star",
		"desc": "Temporary protection after a counter."
	},
	{
		"field": "riding_left",
		"name": "Mounted",
		"icon": "horse",
		"desc": "Your summoned mount remains available."
	},
	{
		"field": "burn_time",
		"name": "Burning",
		"icon": "status_burning",
		"desc": "Fire deals damage over time."
	},
	{
		"field": "poison_left",
		"name": "Poisoned",
		"icon": "status_poisoned",
		"desc": "Poison deals damage over time."
	},
	{
		"field": "bleed_left",
		"name": "Bleeding",
		"icon": "status_bleeding",
		"desc": "Bleeding deals damage over time."
	},
	{
		"field": "frozen_left",
		"name": "Disabled",
		"icon": "star",
		"desc": "Frozen or stunned: movement is interrupted."
	},
	{
		"field": "slowed_left",
		"name": "Slowed",
		"icon": "status_slowed",
		"desc": "Movement speed is reduced."
	}
]
