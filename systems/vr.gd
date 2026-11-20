extends RefCounted

var game

func _init(owner):
	game = owner

func _init_vr() -> void:
	# Headless tests and servers do not have an XR display.
	if DisplayServer.get_name() == "headless":
		return
	var interface = XRServer.find_interface("OpenXR")
	if interface and (interface.is_initialized() or interface.initialize()):
		game.vr_active = true
		game.get_viewport().use_xr = true
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.physics_ticks_per_second = 90
		print("OpenXR подключён: VR-режим включён.")
	else:
		print("OpenXR недоступен. Запуск в обычном режиме; проверьте подключение шлема и OpenXR runtime.")

func _make_controller(tracker_path: String) -> XRController3D:
	var controller = XRController3D.new()
	controller.tracker = tracker_path
	controller.pose = "grip"
	game.xr_origin.add_child(controller)
	var handle = MeshInstance3D.new()
	var mesh = CapsuleMesh.new()
	mesh.radius = 0.035
	mesh.height = 0.18
	handle.mesh = mesh
	controller.add_child(handle)
	var anchor = CharacterBody3D.new()
	anchor.name = "PhysicalHandAnchor"
	anchor.set_script(load("res://addons/vr_physics_adapter/hand_anchor.gd"))
	anchor.controller = controller
	anchor.collision_layer = 0
	anchor.collision_mask = 1
	var collision = CollisionShape3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = 0.08
	collision.shape = sphere
	anchor.add_child(collision)
	game.add_child(anchor)
	anchor.global_position = controller.global_position
	game.vr_hand_anchors.append(anchor)
	return controller

func _on_vr_left_button(action: String) -> void:
	if action == "ax_button" and game.state == "idle" and not game.book_open and not game.map_open:
		game._interact()
	elif action == "by_button" and game.state == "idle":
		game.map_open = not game.map_open
		game.book_open = false

func _on_vr_right_button(action: String) -> void:
	if action == "ax_button":
		if game.state == "dialogue":
			game._choose_fish(true)
		elif game.state == "idle":
			game.book_open = not game.book_open
			game.map_open = false
	elif action == "by_button" and game.state == "dialogue":
		game._choose_fish(false)

func _update_vr_input(delta: float) -> void:
	if game.vr_simulator:
		_update_sim_gamepad(delta)
		_update_simulated_hands(delta)
	_update_vr_rowing(delta)
	_update_vr_trigger(float(Input.is_key_pressed(KEY_SPACE) or (game.sim_joy_id >= 0 and Input.is_joy_button_pressed(game.sim_joy_id, JOY_BUTTON_RIGHT_SHOULDER))) if game.vr_simulator else game.right_controller.get_float("trigger"))
	var stick = Vector2(float(Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_LEFT)), float(Input.is_key_pressed(KEY_UP)) - float(Input.is_key_pressed(KEY_DOWN))) if game.vr_simulator and game.state == "reeling" else (Vector2.ZERO if game.vr_simulator else game.right_controller.get_vector2("primary"))
	if game.vr_simulator and game.state == "reeling" and game.sim_joy_id >= 0:
		stick += Vector2(Input.get_joy_axis(game.sim_joy_id, JOY_AXIS_RIGHT_X), -Input.get_joy_axis(game.sim_joy_id, JOY_AXIS_RIGHT_Y))
		stick = stick.limit_length(1.0)
	if game.state == "reeling":
		game.aim_destination.x = clampf(game.aim_destination.x + stick.x * delta * 2.8, -game.FISHING_RANGE, game.FISHING_RANGE)
		game.aim_destination.y = clampf(game.aim_destination.y + stick.y * delta * 2.8, -game.FISHING_RANGE, game.FISHING_RANGE)
	else:
		_turn_vr(stick.x, delta)

func _update_vr_trigger(value: float) -> void:
	if game.vr_trigger_pressed:
		if value <= game.VR_TRIGGER_RELEASE:
			game.vr_trigger_pressed = false
	elif value >= game.VR_TRIGGER_PRESS:
		game.vr_trigger_pressed = true
		if not game.book_open and not game.map_open and not game.vr_holding_oar[1]:
			game._fishing_action()

func _row_hand_strength(index: int, local_position: Vector3, gripping: bool, delta: float) -> float:
	if not gripping:
		game.vr_row_tracking[index] = false
		return 0.0
	if not game.vr_row_tracking[index] or delta <= 0.0 or delta > 0.1:
		game.vr_row_previous[index] = local_position
		game.vr_row_tracking[index] = true
		return 0.0
	var displacement: Vector3 = local_position - game.vr_row_previous[index]
	game.vr_row_previous[index] = local_position
	# Compare tracked hand movement in the play space, excluding boat motion.
	var hand_velocity = game.xr_origin.global_basis * displacement / delta
	var forward = game.boat_hull.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	return clampf(-hand_velocity.dot(forward) / 1.2, -1.0, 1.0)

func _update_vr_rowing(delta: float) -> void:
	var can_row = game.riding and game.state == "idle" and not game.book_open and not game.map_open
	var controllers = [game.left_controller, game.right_controller]
	game.vr_row_strength = 0.0
	for index in range(2):
		var controller: XRController3D = controllers[index]
		game.vr_haptic_cooldown[index] = maxf(0.0, game.vr_haptic_cooldown[index] - delta)
		var pressed: bool = (game.sim_grips[index] or (game.sim_joy_id >= 0 and Input.get_joy_axis(game.sim_joy_id, JOY_AXIS_TRIGGER_LEFT if index == 0 else JOY_AXIS_TRIGGER_RIGHT) > 0.4)) if game.vr_simulator else controller.get_is_active() and controller.get_float("grip") > 0.55
		var hand_position: Vector3 = controller.global_position if game.vr_simulator else game.vr_hand_anchors[index].global_position
		var was_gripping: bool = game.vr_holding_oar[index]
		var gripping = _update_oar_grab(index, hand_position, pressed, can_row)
		if gripping and not was_gripping:
			_oar_haptic(index, 0.35, 0.07)
		var local_hand = game.xr_origin.to_local(hand_position)
		var hand_force = _row_hand_strength(index, local_hand, gripping, delta)
		var oar = game.boat_hull.get_node("RightOar" if index == 0 else "LeftOar") as Node3D
		var paddle = oar.get_child(0) as Node3D
		# Broad end of the GLB is at +Z in the imported model.
		var blade = paddle.to_global(Vector3(0, 0, 1.8989))
		var depth = game._water_height(blade.x, blade.z) - blade.y
		var submerged = depth > 0.0
		game.vr_oar_force[index] = _oar_water_force(hand_force, depth, gripping)
		if gripping and absf(game.vr_oar_force[index]) > 0.15 and game.vr_haptic_cooldown[index] <= 0.0:
			_oar_haptic(index, 0.1 + absf(game.vr_oar_force[index]) * 0.22, 0.08)
			game.vr_haptic_cooldown[index] = 0.12
		var fx = game.oar_water_fx[index]
		# Show a waterline ring even when the oar is still or not held.
		fx.visible = submerged
		fx.global_position = Vector3(blade.x, game._water_height(blade.x, blade.z) + 0.04, blade.z)
		fx.scale = Vector3.ONE * (0.9 + absf(hand_force) * 0.45)
		game.vr_row_strength += game.vr_oar_force[index] * 0.6
	game.vr_row_strength = clampf(game.vr_row_strength, 0.0, 1.0)
	game.rod.visible = not game.vr_holding_oar[1]

func _oar_haptic(index: int, intensity: float, duration: float) -> void:
	if game.vr_simulator:
		if game.sim_joy_id >= 0:
			Input.start_joy_vibration(game.sim_joy_id, intensity if index == 0 else 0.0, intensity if index == 1 else 0.0, duration)
	elif XRServer.primary_interface:
		var controller = game.left_controller if index == 0 else game.right_controller
		XRServer.primary_interface.trigger_haptic_pulse("haptic", controller.tracker, 0.0, clampf(intensity * XRToolsUserSettings.haptics_scale, 0.0, 1.0), duration, 0.0)

func _oar_water_force(hand_force: float, depth: float, gripping: bool) -> float:
	return hand_force * clampf(depth / 0.15, 0.0, 1.0) if gripping and depth > 0.0 else 0.0

func _update_oar_grab(index: int, hand_position: Vector3, pressed: bool, can_row: bool) -> bool:
	# The boat's +Z bow faces the player, so its model sides are reversed in view.
	var oar = game.boat_hull.get_node("RightOar" if index == 0 else "LeftOar") as Node3D
	var grip_point = oar.get_node("GripPoint") as Marker3D
	if not can_row or not pressed:
		game.vr_holding_oar[index] = false
	elif not game.vr_holding_oar[index]:
		var grip_start = oar.global_position
		var grip_end = grip_point.global_position
		var closest = Geometry3D.get_closest_point_to_segment(hand_position, grip_start, grip_end)
		if hand_position.distance_to(closest) <= game.VR_OAR_GRAB_RADIUS:
			game.vr_holding_oar[index] = true
	if game.vr_holding_oar[index]:
		# The handle follows the hand around the fixed oarlock.
		var direction = game.boat_hull.global_basis.inverse() * (hand_position - oar.global_position)
		if direction.length_squared() > 0.01:
			oar.quaternion = Quaternion(Vector3.UP, direction.normalized())
	return game.vr_holding_oar[index]

func _update_sim_gamepad(delta: float) -> void:
	var devices = Input.get_connected_joypads()
	if devices.is_empty():
		game.sim_joy_id = -1
		return
	if not devices.has(game.sim_joy_id):
		game.sim_joy_id = devices[0]
		if Input.has_joy_motion_sensors(game.sim_joy_id):
			Input.set_joy_motion_sensors_enabled(game.sim_joy_id, true)
	if Input.has_joy_motion_sensors(game.sim_joy_id):
		var gyro = Input.get_joy_gyroscope(game.sim_joy_id)
		if absf(gyro.y) > 0.025:
			_turn_vr(-signf(gyro.y), minf(absf(gyro.y) * delta / game.VR_TURN_SPEED, 0.05))
		if absf(gyro.x) > 0.025:
			game.camera.rotation.x = clampf(game.camera.rotation.x + gyro.x * delta, -1.25, 1.1)

func _update_simulated_hands(delta: float) -> void:
	var controllers = [game.left_controller, game.right_controller]
	for index in range(2):
		var controller: XRController3D = controllers[index]
		var oar = game.boat_hull.get_node("RightOar" if index == 0 else "LeftOar") as Node3D
		var handle = oar.get_node("GripPoint") as Node3D
		if game.riding:
			var holding: bool = game.sim_grips[index] or (game.sim_joy_id >= 0 and Input.get_joy_axis(game.sim_joy_id, JOY_AXIS_TRIGGER_LEFT if index == 0 else JOY_AXIS_TRIGGER_RIGHT) > 0.4)
			if not holding:
				if game.sim_hand_grabbed[index]:
					game.sim_hand_offsets[index] = Vector3.ZERO
				game.sim_hand_grabbed[index] = false
				if game.sim_joy_id >= 0:
					var free_x = Input.get_joy_axis(game.sim_joy_id, JOY_AXIS_LEFT_X if index == 0 else JOY_AXIS_RIGHT_X)
					var free_y = Input.get_joy_axis(game.sim_joy_id, JOY_AXIS_LEFT_Y if index == 0 else JOY_AXIS_RIGHT_Y)
					if absf(free_x) > 0.15: game.sim_hand_offsets[index].x = clampf(game.sim_hand_offsets[index].x + free_x * delta, -0.4, 0.4)
					if absf(free_y) > 0.15: game.sim_hand_offsets[index].z = clampf(game.sim_hand_offsets[index].z + free_y * delta, -0.45, 0.45)
				controller.global_position = handle.global_position + game.camera.global_basis.x * game.sim_hand_offsets[index].x + game.camera.global_basis.z * game.sim_hand_offsets[index].z
			else:
				if not game.sim_hand_grabbed[index]:
					game.sim_hand_base[index] = controller.position
					game.sim_hand_offsets[index] = Vector3.ZERO
					game.sim_hand_grabbed[index] = true
				var back = Input.is_key_pressed(KEY_K if index == 0 else KEY_DOWN)
				var forward = Input.is_key_pressed(KEY_I if index == 0 else KEY_UP)
				var movement = float(back) - float(forward)
				var sideways = 0.0
				if game.sim_joy_id >= 0:
					var axis_x = JOY_AXIS_LEFT_X if index == 0 else JOY_AXIS_RIGHT_X
					var axis_y = JOY_AXIS_LEFT_Y if index == 0 else JOY_AXIS_RIGHT_Y
					var stick_x = Input.get_joy_axis(game.sim_joy_id, axis_x)
					var stick_y = Input.get_joy_axis(game.sim_joy_id, axis_y)
					if absf(stick_x) > 0.15: sideways = stick_x
					if absf(stick_y) > 0.15: movement += stick_y
				game.sim_hand_offsets[index].x = clampf(game.sim_hand_offsets[index].x + sideways * delta, -0.4, 0.4)
				game.sim_hand_offsets[index].z = clampf(game.sim_hand_offsets[index].z + movement * delta * 1.5, -0.45, 0.45)
				controller.position = game.sim_hand_base[index] + (game.xr_origin.global_basis.inverse() * (game.camera.global_basis.z * game.sim_hand_offsets[index].z + game.camera.global_basis.x * game.sim_hand_offsets[index].x))
		else:
			if game.sim_joy_id >= 0:
				var free_x = Input.get_joy_axis(game.sim_joy_id, JOY_AXIS_LEFT_X if index == 0 else JOY_AXIS_RIGHT_X)
				var free_y = Input.get_joy_axis(game.sim_joy_id, JOY_AXIS_LEFT_Y if index == 0 else JOY_AXIS_RIGHT_Y)
				if absf(free_x) > 0.15: game.sim_hand_offsets[index].x = clampf(game.sim_hand_offsets[index].x + free_x * delta, -0.4, 0.4)
				if absf(free_y) > 0.15: game.sim_hand_offsets[index].z = clampf(game.sim_hand_offsets[index].z + free_y * delta, -0.45, 0.45)
			controller.position = game.camera.position + Vector3(-0.3 if index == 0 else 0.3, -0.4, -0.4) + game.sim_hand_offsets[index]

func _turn_vr(axis: float, delta: float) -> void:
	const DEADZONE = 0.2
	if absf(axis) <= DEADZONE:
		return
	var strength = (minf(absf(axis), 1.0) - DEADZONE) / (1.0 - DEADZONE)
	# Rotate the rig around the tracked head without shifting it relative to the boat.
	var head_position = game.camera.global_position
	game.xr_origin.rotate_y(-signf(axis) * strength * game.VR_TURN_SPEED * delta)
	var head_delta = head_position - game.camera.global_position
	game.xr_origin.global_position += Vector3(head_delta.x, 0, head_delta.z)

func _movement_input() -> Vector2:
	if game.vr_simulator:
		var keyboard = Vector2(float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)), float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W)))
		if game.sim_joy_id >= 0:
			keyboard += Vector2(float(Input.is_joy_button_pressed(game.sim_joy_id, JOY_BUTTON_DPAD_RIGHT)) - float(Input.is_joy_button_pressed(game.sim_joy_id, JOY_BUTTON_DPAD_LEFT)), float(Input.is_joy_button_pressed(game.sim_joy_id, JOY_BUTTON_DPAD_DOWN)) - float(Input.is_joy_button_pressed(game.sim_joy_id, JOY_BUTTON_DPAD_UP)))
		return keyboard.limit_length(1.0)
	if game.vr_active:
		var stick = game.left_controller.get_vector2("primary")
		if stick.length() < 0.2:
			return Vector2.ZERO
		return Vector2(stick.x, -stick.y)
	return Vector2(float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)), float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W)))

func _movement_direction(v: Vector2) -> Vector3:
	if not game.vr_active:
		return game.player.global_basis * Vector3(v.x, 0, v.y)
	var forward = -game.camera.global_basis.z
	forward.y = 0
	forward = forward.normalized()
	var right = Vector3(-forward.z, 0, forward.x)
	return right * v.x - forward * v.y

func _unhandled_input(event: InputEvent) -> void:
	if game.vr_simulator:
		if event is InputEventJoypadButton and event.pressed:
			match event.button_index:
				JOY_BUTTON_A: _on_vr_left_button("ax_button")
				JOY_BUTTON_Y: _on_vr_left_button("by_button")
				JOY_BUTTON_X: _on_vr_right_button("ax_button")
				JOY_BUTTON_B: _on_vr_right_button("by_button")
		elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_turn_vr(signf(event.relative.x), absf(event.relative.x) * 0.001)
			game.camera.rotation.x = clampf(game.camera.rotation.x - event.relative.y * 0.0025, -1.25, 1.1)
		elif event is InputEventKey and not event.echo:
			match event.keycode:
				KEY_Q: game.sim_grips[0] = event.pressed
				KEY_E: game.sim_grips[1] = event.pressed
				KEY_X:
					if event.pressed: _on_vr_left_button("ax_button")
				KEY_Y:
					if event.pressed: _on_vr_left_button("by_button")
				KEY_1:
					if event.pressed: _on_vr_right_button("ax_button")
				KEY_2:
					if event.pressed: _on_vr_right_button("by_button")
				KEY_ESCAPE:
					if event.pressed: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
		return
	if game.vr_active:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion = event as InputEventMouseMotion
		if game.state == "reeling":
			game.aim_destination.x = clampf(game.aim_destination.x + motion.relative.x * 0.008, -game.FISHING_RANGE, game.FISHING_RANGE)
			game.aim_destination.y = clampf(game.aim_destination.y - motion.relative.y * 0.008, -game.FISHING_RANGE, game.FISHING_RANGE)
		else:
			game.player.rotate_y(-motion.relative.x * 0.0025)
			game.camera.rotation.x = clampf(game.camera.rotation.x - motion.relative.y * 0.0025, -1.25, 1.1)
	if event is InputEventKey and event.pressed and not event.echo:
		var key = (event as InputEventKey).keycode
		if key == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
		elif key == KEY_TAB and game.state == "idle":
			game.book_open = not game.book_open
			game.map_open = false
		elif key == KEY_M and game.state == "idle":
			game.map_open = not game.map_open
			game.book_open = false
		elif key == KEY_E and game.state == "idle" and not game.book_open and not game.map_open:
			game._interact()
		elif key == KEY_F and not game.book_open and not game.map_open:
			game._fishing_action()
		elif key == KEY_1 and game.state == "dialogue":
			game._choose_fish(true)
		elif key == KEY_2 and game.state == "dialogue":
			game._choose_fish(false)
