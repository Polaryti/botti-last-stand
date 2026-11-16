class_name Places
## The five places of the world, said the same way everywhere they are shown: the Codex, the loading
## screen and the world atlas. Each has a name, an icon, a colour, its lore, what is played there and
## a few hints about it for the loading screen.

const ORDER := ["village", "fort", "mists", "mesenlla", "bastion"]

const ALL := {
	"village": {"name": "The Village", "icon": "map_village", "color": Color("efe8d8"), "plays": "Survive the Night, Co-op, All vs All and Teams",
		"lore": "The first village to be overrun and razed by the zombie hordes.",
		"tips": ["The river can only be crossed on the bridges and at the ford, and it pulls you downstream.",
			"The bell strikes once for each minute gone, and draws zombies to the church.",
			"Corn hides you better than anything. It also hides them."]},
	"fort": {"name": "The Fort", "icon": "map_fort", "color": Color("efe8d8"), "plays": "Defend the Fort",
		"lore": "The last bastion protecting the portal to The Mists.",
		"tips": ["Carry wood close to a damaged gate and it mends as you stand there.",
			"Only you fit through the fort's small doors. Enemies have to break a gate.",
			"Drop off the walls when you need to get out fast. It does not hurt."]},
	"mists": {"name": "The Mists", "icon": "map_mists", "color": Color("6fb6d6"), "plays": "Survive the Night and Co-op",
		"lore": "The heart of mysterious worlds lying beyond our own.",
		"tips": ["Leave an island when its Mist Storm warning sounds.",
			"The Veil Regent's crown attack has a safe eye in the middle. Stand in it.",
			"Portals open and close in turn. Watch the map for the open ones."]},
	"mesenlla": {"name": "Valleys of Mesenlla", "icon": "map_mesenlla", "color": UiTheme.TWILIGHT, "plays": "Survive the Night, Co-op, All vs All and Teams",
		"lore": "Fleeing a collapsed world and having conquered the heart of the Mists, new paths open to distant lands through its portals. The first leads to a mountain outpost under an endless twilight.",
		"tips": ["A bear rears up before it mauls. Step back, or stun it.",
			"Leave a coloured circle before it fills: each one is a blow on its way.",
			"The Great Revenant Elemental rises at the Ring of Stones at about 8:30. Dawn waits for it."]},
	"bastion": {"name": "Mist Bastion", "icon": "map_bastion", "color": Color(0.45, 0.85, 0.82), "plays": "Defend the Fort",
		"lore": "Beyond the Mists, a Great Portal turns on a mountaintop, walled in by a citadel. Three lanes climb to its gates.",
		"tips": ["Mist Soldiers step out of each lane's waystone to hold it. Fight beside them.",
			"The War Wyvern makes burning passes at the Great Portal. Bring it down before the portal falls.",
			"Each gate has a small door beside it that only you fit through."]},
}


## Where a match is played: the map of the night or fort being started, or "" for the Sandbox.
static func of_match(mode: int) -> String:
	if mode == Game.Mode.SANDBOX or mode == Game.Mode.MENU:
		return ""
	var id := Game.current_map()
	return id if ALL.has(id) else ""
