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
	var rod_model := game.rod.get_child(0) as Node3D
	check(rod_model.basis.z.normalized().dot(Vector3.DOWN) > 0.99 and game.rod_tip.position.y < -1.5, "rod matches oar orientation and line starts at its tip")
	for oar_name in ["LeftOar", "RightOar"]:
		var paddle := game.boat_hull.get_node(oar_name).get_child(0) as Node3D
		var imported_mesh := paddle.get_child(0) as Node3D
		var blade_axis: Vector3 = (paddle.basis * imported_mesh.basis * Vector3.UP).normalized()
		check(blade_axis.dot(Vector3.DOWN) > 0.99, "%s imported blade points vertically down" % oar_name)
	check(game.vr_ui_viewport != null and game.pixel_renderer == null, "stereo UI without mono pixel viewport")
	check(game.camera.get_node_or_null("VRPixelEffect") == null, "VR view is not covered by a screen-reading effect")
	var test_mesh := MeshInstance3D.new()
	test_mesh.mesh = BoxMesh.new()
	var test_material := StandardMaterial3D.new()
	test_material.albedo_texture = GradientTexture2D.new()
	test_mesh.material_override = test_material
	game._apply_vr_texture_filter(test_mesh)
	check(test_material.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS, "VR textures use nearest filtering")
	test_mesh.free()
	game.camera.position = Vector3(0.3, 1.65, 0.2)
	var head_before: Vector3 = game.camera.global_position
	game._turn_vr(1.0, 0.25)
	check(absf(game.xr_origin.rotation.y + game.VR_TURN_SPEED * 0.25) < 0.001, "held stick turns smoothly at configured speed")
	check(game.camera.global_position.distance_to(head_before) < 0.001, "turn keeps head position fixed")
	game._on_vr_left_button("by_button")
	check(game.map_open, "Y opens map")
	game._on_vr_left_button("by_button")
	game._on_vr_right_button("ax_button")
	check(game.book_open, "A opens book")
	game._on_vr_right_button("ax_button")
	game.player.position = Vector3(0, 0, 5)
	game._on_vr_left_button("ax_button")
	check(game.riding, "X boards boat")
	check(Vector2(game.camera.global_position.x - game.boat.global_position.x, game.camera.global_position.z - game.boat.global_position.z).length() < 0.001, "boarding centers the tracked head over the boat")
	var oar := game.boat_hull.get_node("RightOar") as Node3D
	var pivot_before: Vector3 = oar.position
	var grip_point := oar.get_node("GripPoint") as Node3D
	check(not game._update_oar_grab(0, grip_point.global_position + Vector3(3, 0, 0), true, true), "cannot grab an oar from far away")
	check(game._update_oar_grab(0, grip_point.global_position, true, true), "hand can grab an oar near its handle")
	check(game._update_oar_grab(0, grip_point.global_position + Vector3(0, 0, 0.4), true, true), "moving hand keeps hold of the oar")
	check(oar.get_parent() == game.boat_hull and oar.position.is_equal_approx(pivot_before), "oar pivot remains attached to the boat")
	check(not game._update_oar_grab(0, grip_point.global_position, false, true), "releasing grip releases the oar")
	check(oar.get_parent() == game.boat_hull and oar.position.is_equal_approx(pivot_before), "released oar stays attached to the boat")
	var backward_local: Vector3 = game.xr_origin.global_basis.inverse() * game.camera.global_basis.z.normalized()
	check(game._row_hand_strength(0, Vector3.ZERO, true, 0.05) == 0.0, "grabbing an oar does not create a stroke")
	var stroke: float = game._row_hand_strength(0, backward_local * 0.08, true, 0.05)
	check(stroke > 0.5, "pulling the tracked hand backward creates a stroke")
	check(game._row_hand_strength(0, Vector3.ZERO, true, 0.05) == 0.0, "moving the hand forward does not propel the boat")
	check(game._row_hand_strength(0, Vector3.ZERO, false, 0.05) == 0.0, "released hand does not propel the boat")
	game.boat.position = Vector3(0, 0, -5)
	game.vr_row_strength = stroke
	game._move_boat(0.1)
	check(game.boat_velocity.length() > 0.0, "rowing propels the boat")
	game.boat_velocity = Vector3.ZERO
	game._advance_boat(1.0, Vector2(0, -1))
	game._update_boat_pose(1.0)
	check(Vector2(game.camera.global_position.x - game.boat.global_position.x, game.camera.global_position.z - game.boat.global_position.z).length() < 0.001, "tracked head stays with the moving boat")
	var bow_direction: Vector3 = game.boat_hull.global_basis.z
	bow_direction.y = 0
	check(bow_direction.normalized().dot(game.boat_velocity.normalized()) > 0.8, "boat bow faces its direction of travel")
	game.boat.position = Vector3(0, 0, -10)
	game._update_vr_trigger(0.8)
	check(game.state == "casting", "right trigger casts")
	game.state = "bite"
	game._update_vr_trigger(0.8)
	check(game.state == "bite", "held trigger does not hook repeatedly")
	game._update_vr_trigger(0.2)
	game._update_vr_trigger(0.8)
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
