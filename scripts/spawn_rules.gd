class_name SpawnRules
extends RefCounted
## Empty map IDs are used by the Sandbox and tools that list every item.
static func allows(data: Dictionary, map_id: String) -> bool:
	return map_id == "" or not data.has("maps") or data["maps"].has(map_id)

static func names(data: Dictionary) -> String:
	var names := PackedStringArray()
	for id: String in data.get("maps", []):
		names.append({"village": "The Village", "fort": "The Fort", "mists": "The Mists"}.get(id, id.capitalize()))
	return " / ".join(names)
