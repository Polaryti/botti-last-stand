class_name SpawnRules
extends RefCounted
## Empty map IDs are used by the Sandbox and tools that list every item.
static func allows(data: Dictionary, map_id: String) -> bool:
	return map_id == "" or not data.has("maps") or data["maps"].has(map_id)

## The two maps beyond the Mists share one name on badges.
const MESENLLA := ["mesenlla", "bastion"]

static func is_mesenlla(data: Dictionary) -> bool:
	var maps: Array = data.get("maps", [])
	return not maps.is_empty() and maps.all(func(m: String) -> bool: return m in MESENLLA)

static func names(data: Dictionary) -> String:
	if is_mesenlla(data):
		return "Mesenlla"
	var names := PackedStringArray()
	for id: String in data.get("maps", []):
		names.append({"village": "The Village", "fort": "The Fort", "mists": "The Mists"}.get(id, id.capitalize()))
	return " / ".join(names)
