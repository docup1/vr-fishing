extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("run_test")
func check(value: bool, message: String) -> void:
	if not value:
		push_error("FAILED: " + message)
		failures += 1
func run_test() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	check(game.vr_simulator and game.vr_active and not root.use_xr, "simulator starts without XR hardware")
	check(game.save_path == "user://simulator_save.json", "simulator has separate save")
	game.player.position = Vector3(0, 0, 5)
	game._on_vr_left_button("ax_button")
	check(game.riding, "simulator boards boat")
	game.boat.position = Vector3(0, 0, -5)
	game._update_boat_pose(0.016)
	game._update_simulated_hands(0.016)
	game.sim_grips[0] = true
	game._update_simulated_hands(0.016)
	game._update_vr_rowing(0.016)
	check(game.vr_holding_oar[0], "simulated hand grips mounted oar")
	var event := InputEventKey.new()
	event.keycode = KEY_K
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	game._update_simulated_hands(0.05)
	game._update_vr_rowing(0.05)
	check(game.vr_row_strength > 0, "simulated backward stroke produces force")
	game._move_boat(0.05)
	check(game.boat_velocity.length() > 0, "simulated stroke moves boat")
	var release := InputEventKey.new()
	release.keycode = KEY_K
	release.pressed = false
	Input.parse_input_event(release)
	game.sim_grips[0] = false
	game._update_vr_rowing(0.016)
	check(not game.vr_holding_oar[0], "releasing simulated grip releases oar")
	game.queue_free()
	print("PASS: simulator, oar grip, stroke and boat movement" if failures == 0 else "Simulator failures: %d" % failures)
	quit(1 if failures else 0)
