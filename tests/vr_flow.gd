extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run_test")

func check(ok: bool, what: String) -> void:
	if not ok:
		push_error("FAILED: " + what)
		failures += 1

func run_test() -> void:
	var game = load("res://main.tscn").instantiate()
	game.vr_active = true
	game.save_path = "user://test_vr_%s.json" % Time.get_ticks_usec()
	root.add_child(game)
	await process_frame
	check(game.camera is XRCamera3D, "tracked stereo camera")
	check(game.left_controller.tracker == "left_hand" and game.right_controller.tracker == "right_hand", "controller trackers")
	check(game.rod.get_parent() == game.right_controller, "rod follows controller")
	check(game.vr_ui_viewport != null and game.pixel_renderer == null, "stereo UI without mono pixel viewport")
	game._on_vr_left_button("by_button")
	check(game.map_open, "Y opens map")
	game._on_vr_left_button("by_button")
	game._on_vr_right_button("ax_button")
	check(game.book_open, "A opens book")
	game._on_vr_right_button("ax_button")
	game.player.position = Vector3(0, 0, 10)
	game._on_vr_left_button("ax_button")
	check(game.riding, "X boards boat")
	game.boat.position = Vector3(0, 0, -10)
	game._on_vr_right_button("trigger_click")
	check(game.state == "casting", "right trigger casts")
	game.state = "bite"
	game._on_vr_right_button("trigger_click")
	check(game.state == "reeling", "right trigger hooks")
	game.state = "dialogue"
	game.current_type = "other"
	game.current_fish = "Test"
	game._on_vr_right_button("by_button")
	check(game.state == "idle" and game.pending_fish.size() == 1, "B keeps fish")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.save_path))
	game.queue_free()
	print("PASS: VR rig, menus, boat, casting, hooking and fish choice" if failures == 0 else "VR failures: %d" % failures)
	quit(1 if failures else 0)
