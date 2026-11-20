extends RefCounted

var game

func _init(owner):
	game = owner

func _advance_reeling(delta: float, reel_pressed: bool) -> void:
	game.fish_time += delta
	# A damped pull gives both the rod and the fish momentum instead of teleporting.
	game.fishing_aim = game.fishing_aim.lerp(game.aim_destination, 1.0 - exp(-9.0 * delta))
	var struggle_speed = 1.25 if game.current_type == "boss" else 1.0
	var swim_time = game.fish_time * struggle_speed
	var fish_destination = Vector2(1.5 * sin(swim_time * 0.85) + 0.35 * sin(swim_time * 2.1), 0.85 * sin(swim_time * 1.2)) * (1.0 - game.progress * 0.35)
	var step = minf(delta, 0.05)
	game.fish_velocity += (fish_destination - game.fish_offset) * 8.0 * step
	game.fish_velocity *= exp(-4.0 * step)
	game.fish_offset += game.fish_velocity * step
	var desired_tension = clampf(game.fishing_aim.distance_to(game.fish_offset) / 2.5 + (0.3 if reel_pressed else 0.0), 0.0, 1.0)
	game.line_tension = lerpf(game.line_tension, desired_tension, 1.0 - exp(-3.0 * delta))
	if reel_pressed:
		if game.fishing_aim.distance_to(game.fish_offset) <= game.ZONE_RADIUS:
			game.progress += delta * 0.19
		else:
			game.progress -= delta * 0.10
	game.progress = clampf(game.progress, 0.0, 1.0)

func _water_position(offset: Vector2) -> Vector3:
	var point = game.fishing_center + game.fishing_right * offset.x + game.fishing_forward * offset.y
	point.y = game._water_height(point.x, point.z) + 0.065
	return point

func _update_fishing_visuals() -> void:
	if game.state not in ["casting", "waiting", "bite", "reeling"]:
		game.rod.rotation = game.rod.rotation.lerp(Vector3.ZERO, 0.08)
		return
	if game.state == "reeling":
		game.holding_zone.position = _water_position(game.fishing_aim)
		game.fish_wake.position = _water_position(game.fish_offset)
		game.fish_wake.scale = Vector3.ONE * (1.0 + 0.12 * sin(game.fish_time * 4.0))
		var swim_direction = game.fishing_right * game.fish_velocity.x + game.fishing_forward * game.fish_velocity.y
		if swim_direction.length_squared() > 0.01:
			game.swimming_fish.rotation.y = atan2(-swim_direction.z, swim_direction.x)
		game.swimming_fish.get_node("Tail").rotation.y = 0.45 * sin(game.fish_time * 8.0)
		var in_zone = game.fishing_aim.distance_to(game.fish_offset) <= game.ZONE_RADIUS
		game.zone_material.albedo_color = Color(0.25, 0.95, 0.55, 0.38) if in_zone else Color(0.25, 0.7, 1.0, 0.24)
		game.zone_ring_material.albedo_color = Color(0.55, 1.0, 0.68) if in_zone else Color(0.54, 0.83, 1.0)
		game.bobber.position = game.fish_wake.position + Vector3(0, 0.14, 0)
	elif game.state == "bite":
		game.bobber.position.y = game._water_height(game.bobber.position.x, game.bobber.position.z) + 0.13 + 0.08 * sin(game.bite_seconds * 18.0)
		game.bobber.rotation.z = 0.3 * sin(game.bite_seconds * 13.0)
	elif game.state == "waiting":
		game.bobber.position.y = game._water_height(game.bobber.position.x, game.bobber.position.z) + 0.16
		game.bobber.rotation.z = 0.07 * sin(game.water_time * 2.0)
	var rod_target = Vector3(-game.fishing_aim.y * 0.06, -game.fishing_aim.x * 0.09, -game.fishing_aim.x * 0.05) if game.state == "reeling" else Vector3.ZERO
	if game.state == "reeling":
		rod_target.x += game.line_tension * 0.1 + sin(game.fish_time * 7.0) * game.line_tension * 0.015
	if game.state == "casting":
		rod_target.x = sin(game.cast_elapsed / game.CAST_DURATION * PI) * 0.45
	elif game.state == "bite":
		rod_target.x = 0.035 * sin(game.bite_seconds * 18.0)
	game.rod.rotation = game.rod.rotation.lerp(rod_target, 0.12)
	var line_start = game.rod_tip.global_position
	var line_end = game.bobber.global_position
	var previous = line_start
	var sag = lerpf(0.40, 0.06, game.line_tension) if game.state == "reeling" else 0.42
	for i in range(game.line_segments.size()):
		var t = float(i + 1) / float(game.line_segments.size())
		var point = line_start.lerp(line_end, t) - Vector3(0, sag * 4.0 * t * (1.0 - t), 0)
		var vector = point - previous
		var segment = game.line_segments[i]
		segment.global_position = (previous + point) * 0.5
		if vector.length_squared() > 0.0001:
			segment.look_at(point, Vector3.UP)
			segment.rotate_object_local(Vector3.RIGHT, PI / 2.0)
			segment.scale = Vector3(1, vector.length(), 1)
		previous = point

func _fishing_action() -> void:
	if game.state == "bite":
		game.state = "reeling"
		if not game.vr_active:
			game.camera.look_at(_water_position(Vector2.ZERO), Vector3.UP)
		game.progress = 0.0
		game.fish_time = 0.0
		game.fishing_aim = Vector2.ZERO
		game.aim_destination = Vector2.ZERO
		game.fish_offset = Vector2.ZERO
		game.fish_velocity = Vector2.ZERO
		game.line_tension = 0.0
		game.holding_zone.visible = true
		game.fish_wake.visible = true
		game._show_message("", 0)
		return
	if game.state != "idle": return
	if not game.riding:
		game._show_message("Для рыбалки сначала сядь в лодку у причала.", 4)
		return
	game.current_zone = _nearest_fishing_zone()
	if game.current_zone < 0:
		game._show_message("Выбери место ловли на карте и подплыви ближе к берегу.", 4)
		return
	if game.energy < 8:
		game._show_message("Мало энергии. Вернись домой и поспи.", 4)
		return
	# Fishing starts at anchor, so the boat cannot drift through the markers.
	game.boat_velocity = Vector3.ZERO
	game.energy -= 8
	game.attempts += 1
	var zone: Dictionary = game.ZONES[game.current_zone]
	if game.attempts % 2 == 1:
		game.current_fish = zone.friend
		game.current_type = "friend"
	else:
		var unavailable = game.caught_bosses.has(str(game.current_zone))
		for entry in game.pending_fish:
			if entry.get("type", "") == "boss" and int(entry.get("zone", -1)) == game.current_zone:
				unavailable = true
		game.current_fish = "Прудовая рыбка" if unavailable else zone.boss
		game.current_type = "other" if unavailable else "boss"
	game.state = "casting"
	game.wait_seconds = randf_range(3.0, 6.0)
	game.fishing_forward = -game.camera.global_basis.z if game.vr_active else -game.player.global_basis.z
	game.fishing_forward.y = 0
	game.fishing_forward = game.fishing_forward.normalized()
	game.fishing_right = Vector3(-game.fishing_forward.z, 0, game.fishing_forward.x)
	var cast_distance = clampf(5.0 + game.camera.rotation.x * 2.0, 3.5, 7.0)
	game.fishing_center = game.boat.position + game.fishing_forward * cast_distance
	# Keep the entire minigame on water even close to a shoreline.
	game.fishing_center.x = clampf(game.fishing_center.x, -47.0, 47.0)
	game.fishing_center.z = clampf(game.fishing_center.z, -12.6, 7.0)
	game.fishing_center.y = -0.06
	if not game.vr_active:
		game.camera.look_at(game.fishing_center, Vector3.UP)
	game.cast_elapsed = 0.0
	game.cast_start = game.rod_tip.global_position
	game.bobber.global_position = game.cast_start
	game.bobber.rotation = Vector3.ZERO
	game.bobber.visible = true
	game._set_line_visible(true)
	game._show_message("Заброс...", 1)

func _nearest_fishing_zone() -> int:
	var location = Vector2(game.boat.position.x, game.boat.position.z)
	for i in range(game.ZONES.size()):
		if location.distance_to(game.ZONES[i].center) <= 9.0:
			return i
	return -1

func _end_attempt(text: String) -> void:
	game.state = "idle"
	game.bobber.visible = false
	game.holding_zone.visible = false
	game.fish_wake.visible = false
	game._set_line_visible(false)
	game._show_message(text, 5)

func _choose_fish(release: bool) -> void:
	if game.current_type == "friend" and release:
		game.story_zones[str(game.current_zone)] = true
		game.known_story = game.story_zones.has("0")
		game._show_message("Рыба рассказала часть истории Кузовка. Запись в книге.", 6)
	elif not release:
		game.pending_fish.append({"name": game.current_fish, "type": game.current_type, "zone": game.current_zone})
		if game.current_type == "boss": game.boss_in_box = true
		else: game.caught_other += 1
		game._show_message("%s в ящике. Дома рыба попадёт в колбу." % game.current_fish, 6)
	else:
		game._show_message("Рыба уплыла. Её можно будет встретить снова.", 5)
	game.state = "idle"
	game._save_game()
