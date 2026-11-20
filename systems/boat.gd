extends RefCounted

var game

func _init(owner):
	game = owner

func _move_player(delta: float) -> void:
	var v = game._movement_input()
	if v.length() > 1: v = v.normalized()
	var direction = game._movement_direction(v)
	var speed = 5.0 if Input.is_key_pressed(KEY_SHIFT) else 3.0
	game.player_velocity = game.player_velocity.move_toward(direction * speed, 12.0 * delta)
	game.player.velocity = game.player_velocity
	game.player.move_and_slide()
	game.player_velocity = game.player.velocity
	if not game.vr_active:
		var walking_bob = sin(game.water_time * 8.0) * 0.025 * clampf(game.player_velocity.length() / 3.0, 0.0, 1.0)
		game.camera.position.y = lerpf(game.camera.position.y, 1.65 + walking_bob, 1.0 - exp(-8.0 * delta))
	game.player.position.x = clampf(game.player.position.x, -15.5, 15.5)
	game.player.position.z = clampf(game.player.position.z, 4.5, 23.5)

func _move_boat(delta: float) -> void:
	if game.vr_active:
		_advance_rowing_boat(delta, game.vr_oar_force[0], game.vr_oar_force[1])
	else:
		_advance_boat(delta, game._movement_input())

func _advance_rowing_boat(delta: float, left_force: float, right_force: float) -> void:
	# Oars act independently in the horizontal plane; equal strokes propel
	# forward, while unequal strokes create yaw around the hull's centre.
	var left = clampf(left_force, -1.0, 1.0)
	var right = clampf(right_force, -1.0, 1.0)
	var forward = game.boat_hull.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	game.boat_velocity += forward * ((left + right) * 3.5 * delta)
	game.boat_velocity *= exp(-0.55 * delta)
	game.boat_velocity = game.boat_velocity.limit_length(4.2)
	game.boat_yaw_velocity += (left - right) * 1.8 * delta
	game.boat_yaw_velocity *= exp(-1.4 * delta)
	game.boat_hull.rotate_y(game.boat_yaw_velocity * delta)
	_move_boat_position(delta)

func _advance_boat(delta: float, v: Vector2) -> void:
	if v.length() > 1: v = v.normalized()
	var direction = game._movement_direction(v)
	direction.y = 0.0
	# A boat carries momentum and eases to a stop after the player releases WASD.
	var acceleration = (4.0 if game.vr_active else 1.8) if v.length_squared() > 0.0 else (0.55 if game.vr_active else 1.0)
	game.boat_velocity = game.boat_velocity.move_toward(direction * (4.2 if game.vr_active else 3.0), acceleration * delta)
	_move_boat_position(delta)
	if game.boat_velocity.length_squared() > 0.04:
		var heading = atan2(game.boat_velocity.x, game.boat_velocity.z)
		game.boat_hull.rotation.y = lerp_angle(game.boat_hull.rotation.y, heading, 1.0 - exp(-2.0 * delta))

func _move_boat_position(delta: float) -> void:
	var next_x = clampf(game.boat.position.x + game.boat_velocity.x * delta, -45.0, 45.0)
	if _boat_blocked(Vector2(next_x, game.boat.position.z)):
		game.boat_velocity.x = 0.0
	else:
		game.boat.position.x = next_x
	var next_z = clampf(game.boat.position.z + game.boat_velocity.z * delta, -45.0, 8.0)
	if _boat_blocked(Vector2(game.boat.position.x, next_z)):
		game.boat_velocity.z = 0.0
	else:
		game.boat.position.z = next_z
	if absf(game.boat.position.x) >= 45.0: game.boat_velocity.x = 0.0
	if game.boat.position.z <= -45.0 or game.boat.position.z >= 8.0: game.boat_velocity.z = 0.0

func _boat_blocked(pos: Vector2) -> bool:
	# Keep the hull out of the three shores while allowing routes around them.
	# The pier starts at z=4; leave room for the rotating hull in front of it.
	if absf(pos.x) < 3.5 and pos.y > 1.9:
		return true
	if pos.x >= -18.0 and pos.x <= 18.0 and pos.y >= -24.0 and pos.y <= -14.7:
		return true
	if absf(pos.x) >= 26.5 and absf(pos.x) <= 47.5 and pos.y >= -24.5 and pos.y <= -11.5:
		return true
	return false

func _update_boat_pose(delta: float) -> void:
	# Sample both ends and sides of the hull; the shader uses the same waves.
	var yaw_basis = Basis(Vector3.UP, game.boat_hull.rotation.y)
	var front = game.boat.position + yaw_basis * Vector3(0, 0, 1.5)
	var rear = game.boat.position + yaw_basis * Vector3(0, 0, -1.5)
	var right = game.boat.position + yaw_basis * Vector3(0.55, 0, 0)
	var left = game.boat.position + yaw_basis * Vector3(-0.55, 0, 0)
	var front_height = game._water_height(front.x, front.z)
	var rear_height = game._water_height(rear.x, rear.z)
	var right_height = game._water_height(right.x, right.z)
	var left_height = game._water_height(left.x, left.z)
	# Keel is approximately -0.176 m in hull space; 0.076 m sits in water.
	var height = (front_height + rear_height + right_height + left_height) * 0.25 + 0.10
	var smoothing = 1.0 - exp(-4.0 * delta)
	game.boat_hull.position.y = lerpf(game.boat_hull.position.y, height, smoothing)
	game.boat_hull.rotation.x = lerp_angle(game.boat_hull.rotation.x, -atan2(front_height - rear_height, 3.0), smoothing)
	game.boat_hull.rotation.z = lerp_angle(game.boat_hull.rotation.z, atan2(right_height - left_height, 1.1), smoothing)
	var stroke_strength = clampf(game.boat_velocity.length() / 2.5, 0.0, 1.0)
	for oar_name in ["LeftOar", "RightOar"]:
		var oar = game.boat_hull.get_node(oar_name) as Node3D
		if not game.vr_active:
			oar.rotation.y = sin(game.water_time * 2.5) * 0.24 * stroke_strength
	game.boat_wake.visible = game.boat_velocity.length() > 0.25
	game.boat_wake.position = game.boat.position
	game.boat_wake.position.y = game._water_height(game.boat.position.x, game.boat.position.z) + 0.08
	game.boat_wake.scale = Vector3(1.0, 1.0, 1.0 + game.boat_velocity.length() * 0.3)
	if not game.riding:
		return
	if game.vr_active:
		var yaw_delta = angle_difference(game.vr_boat_last_yaw, game.boat_hull.rotation.y)
		game.player.rotate_y(yaw_delta)
		game.vr_boat_last_yaw = game.boat_hull.rotation.y
		var head_offset = game.player.global_basis * game.vr_boat_head_offset
		game.player.position = game.boat.position - Vector3(head_offset.x, 0, head_offset.z)
	else:
		game.player.position = game.boat.position
	# Keep the camera level for comfort; only a small vertical bob follows the hull.
	game.player.position.y = 0.5 if game.vr_active else 0.5 + game.boat_hull.position.y

func _interact() -> void:
	if game.riding:
		if game.boat.position.distance_to(game.BOAT_MOORING) < 4.0:
			game.riding = false
			game.boat_blocker.collision_layer = 1
			game.boat_velocity = Vector3.ZERO
			game.player_velocity = Vector3.ZERO
			game.boat.position = game.BOAT_MOORING
			game.player.position = Vector3(0, 0, 4.8)
			if game.vr_active:
				var head_offset = game.camera.global_position - game.player.global_position
				game.player.position -= Vector3(head_offset.x, 0, head_offset.z)
			for entry in game.pending_fish:
				game.stored_fish.append(entry)
				if entry.get("type", "") == "boss":
					game.caught_bosses[str(entry.get("zone", 0))] = true
			game.caught_boss = game.caught_bosses.has("0")
			game.boss_in_box = false
			var delivered = game.pending_fish.size()
			game.pending_fish.clear()
			game._refresh_collection()
			game._show_message("Дома! Рыб в колбах: %d. Привезено за выход: %d." % [game.stored_fish.size(), delivered], 7)
			game.caught_other = 0
			game._save_game()
		else:
			game._show_message("Чтобы выйти, вернись к причалу у дома.", 4)
	elif game.player.position.z < 12.0 and absf(game.player.position.x - game.boat.position.x) < 3.0 and game.player.position.distance_to(game.boat.position) < 5.0:
		game.riding = true
		game.boat_blocker.collision_layer = 0
		game.boat_velocity = Vector3.ZERO
		game.player_velocity = Vector3.ZERO
		game.boat_yaw_velocity = 0.0
		if game.vr_active:
			var look_forward = -game.camera.global_basis.z
			if Vector2(look_forward.x, look_forward.z).length_squared() > 0.01:
				game.boat_hull.rotation.y = atan2(look_forward.x, look_forward.z)
		if game.vr_active:
			var head_offset = game.camera.global_position - game.player.global_position
			game.vr_boat_head_offset = game.player.global_basis.inverse() * Vector3(head_offset.x, 0, head_offset.z)
			game.vr_boat_last_yaw = game.boat_hull.rotation.y
			game.player.position = game.boat.position - Vector3(head_offset.x, 0, head_offset.z) + Vector3(0, 0.5, 0)
		else:
			game.player.position = game.boat.position + Vector3(0, 0.5, 0)
		game._show_message("Поднеси руки к вёслам, зажми хват и греби назад. Y — карта." if game.vr_active else "Плыви к одному из трёх участков. Открой карту клавишей M.", 6)
	elif game.player.position.distance_to(Vector3(-2.5, 0, 21)) < 2.5:
		game.book_open = true
	elif game.player.position.distance_to(Vector3(2.8, 0, 21)) < 2.5:
		game.clock_minutes += 8 * 60
		game.energy = minf(100, game.energy + 8 * 15)
		game._save_game()
		game._show_message("Вы поспали 8 часов. Энергия восстановлена.", 5)
	else:
		game._show_message("E: книга на столе, кровать или лодка у причала.", 4)
