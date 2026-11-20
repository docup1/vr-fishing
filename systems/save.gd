extends RefCounted

var game

func _init(owner):
	game = owner

func _save_game() -> void:
	if not game.persistence_enabled:
		return
	var file = FileAccess.open(game.save_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"clock": game.clock_minutes, "energy": game.energy, "story": game.known_story, "boss": game.caught_boss, "boss_in_box": game.boss_in_box, "other": game.caught_other, "attempts": game.attempts, "story_zones": game.story_zones, "caught_bosses": game.caught_bosses, "stored_fish": game.stored_fish, "pending_fish": game.pending_fish}))

func _load_game() -> void:
	if not game.persistence_enabled:
		return
	if not FileAccess.file_exists(game.save_path): return
	var file = FileAccess.open(game.save_path, FileAccess.READ)
	if file == null: return
	var data: Variant = JSON.parse_string(file.get_as_text())
	if not data is Dictionary: return
	game.clock_minutes = float(data.get("clock", game.clock_minutes))
	game.energy = float(data.get("energy", game.energy))
	game.known_story = bool(data.get("story", false))
	game.caught_boss = bool(data.get("boss", false))
	game.boss_in_box = bool(data.get("boss_in_box", false))
	game.caught_other = int(data.get("other", 0))
	game.attempts = int(data.get("attempts", 0))
	game.story_zones = data.get("story_zones", {}) if data.get("story_zones", {}) is Dictionary else {}
	game.caught_bosses = data.get("caught_bosses", {}) if data.get("caught_bosses", {}) is Dictionary else {}
	game.stored_fish = data.get("stored_fish", []) if data.get("stored_fish", []) is Array else []
	game.pending_fish = data.get("pending_fish", []) if data.get("pending_fish", []) is Array else []
	# Older saves recorded the first boss and the crate as flags, without fish entries.
	if not data.has("story_zones") and game.known_story: game.story_zones["0"] = true
	if not data.has("caught_bosses") and game.caught_boss:
		game.caught_bosses["0"] = true
		game.stored_fish.append({"name": "Ёрш Игла", "type": "boss", "zone": 0})
	if not data.has("pending_fish"):
		if game.boss_in_box: game.pending_fish.append({"name": "Ёрш Игла", "type": "boss", "zone": 0})
		for i in range(game.caught_other): game.pending_fish.append({"name": "Прудовая рыбка", "type": "other", "zone": 0})
