class_name ClassPresentation
extends RefCounted

const COPY := {
	"infantry": [
		"The line holds while you stand.",
		"Heal from kills and fight with melee or ranged weapons."
	],
	"ranger": [
		"Every shot answers the dark.",
		"Recover arrows from kills and specialize in archery, traps or pets."
	],
	"heavy": [
		"Iron stands between the living and the horde.",
		"Block frontal attacks with a shield and wield melee weapons."
	],
	"chivalry": [
		"Ride where the line would break.",
		"Earn a summoned horse through kills and fight with your exclusive lance."
	],
	"magician": [
		"Old magic still burns in mortal hands.",
		"Wield only a mana-powered staff and master spells or summons."
	],
	"revenant": [
		"Death has left a debt unpaid.",
		"Spend Mist to attack with spectral claws instead of weapons."
	],
	"monk": [
		"Discipline survives where steel fails.",
		"Build Ki with hits to fuel abilities and carry one weapon."
	],
	"adept": [
		"Three paths meet at the edge of a blade.",
		"Commit to timed stances with distinct combat bonuses."
	],
	"artificer": [
		"Ingenuity arms the last survivors.",
		"Build devices and specialize in machines, explosives or constructs."
	],
	"plague_doctor": [
		"Carry the cure into the sickness.",
		"Fight with an exclusive blowgun and master poison, medicine or vermin."
	],
	"commander": [
		"A single voice can turn the battle.",
		"Use Command and unlock a profession-specific Last Command at level ten."
	]
}

static func description(id: String) -> String:
	return " ".join(COPY[id])

static func profession(spec: Dictionary) -> String:
	return spec["desc"].strip_edges().trim_suffix(".") + ". " + str(spec["entry"]["desc"]).split(". ")[0].trim_suffix(".") + "."
