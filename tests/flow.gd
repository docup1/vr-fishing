extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run_flow")

func check(condition: bool, description: String) -> void:
	if not condition:
		push_error("FAILED: " + description)
		failures += 1

func run_flow() -> void:
	var game = load("res://main.tscn").instantiate()
	game.save_path = "user://test_fishing_%s.json" % str(Time.get_ticks_usec())
	root.add_child(game)
	await process_frame
	await physics_frame
	check(get_nodes_in_group("nature_assets").size() >= 50, "downloaded nature scenes are instantiated")
	var first_nature = get_nodes_in_group("nature_assets")[0]
	check(first_nature.scene_file_path.begins_with("res://Prefabs/"), "the new nature prefab set is used")
	game.map_open = true
	game._update_ui()
	check(game.map_image.visible and game.map_marker.visible, "map view and player marker appear")
	check(game.map_viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS, "top-down camera renders while map is open")
	var marker_before: Vector2 = game.map_marker.marker_position()
	game.player.position.x += 5.0
	var marker_after: Vector2 = game.map_marker.marker_position()
	check(marker_after.x > marker_before.x and absf(marker_after.y - marker_before.y) < 0.01, "map marker follows player position")
	game.player.position.x = 0
	game.map_open = false
	game._update_ui()
	check(not game.map_image.visible and game.map_viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "map closes and stops rendering")
	var press := InputEventKey.new()
	press.keycode = KEY_W
	press.pressed = true
	Input.parse_input_event(press)
	for i in range(15):
		await physics_frame
	var release := InputEventKey.new()
	release.keycode = KEY_W
	release.pressed = false
	Input.parse_input_event(release)
	check(game.player.position.z < 19.95, "keyboard moves the character through physics")
	game.player_velocity = Vector3.ZERO
	game.player.position = Vector3(0, 0, 19)
	var wall_hit = game.player.move_and_collide(Vector3(8, 0, 0))
	check(wall_hit != null and game.player.position.x < 4.3, "house wall blocks the player")
	game.player.position = Vector3(0, 0, 21)
	var table_hit = game.player.move_and_collide(Vector3(-4, 0, 0))
	check(table_hit != null and game.player.position.x > -1.5, "table blocks the player")
	game.player.position = Vector3(0, 0, 21)
	var bed_hit = game.player.move_and_collide(Vector3(4, 0, 0))
	check(bed_hit != null and game.player.position.x < 1.8, "bed blocks the player")
	game.player.position = Vector3(0, 0, 19)
	var doorway_hit = game.player.move_and_collide(Vector3(0, 0, -4))
	check(doorway_hit == null and game.player.position.z < 16.0, "doorway remains passable")
	game.player.position = Vector3(0, 0, 12)
	var boat_hit = game.player.move_and_collide(Vector3(0, 0, -5))
	check(boat_hit != null and game.player.position.z > 8.8, "moored boat blocks walking")
	game._interact()
	check(game.riding, "board the boat at the dock")
	check(game.boat_blocker.collision_layer == 0, "boat collision is disabled while riding")
	game._advance_boat(0.1, Vector2(0, -1))
	check(game.boat_velocity.length() > 0.0 and game.boat_velocity.length() < 3.0, "boat accelerates gradually")
	var moving_speed: float = game.boat_velocity.length()
	game._advance_boat(0.1, Vector2.ZERO)
	check(game.boat_velocity.length() > 0.0 and game.boat_velocity.length() < moving_speed, "boat coasts and slows without input")
	game.boat.position = Vector3(0, 0, -10)
	game._fishing_action()
	check(game.state == "casting" and game.energy == 92.0, "cast starts flight and costs energy")
	check(game.boat_velocity.is_zero_approx(), "boat anchors while fishing")
	game._process(0.45)
	check(game.state == "casting" and game.bobber.global_position.y > 0.8, "bobber follows visible casting arc")
	game._process(0.5)
	check(game.state == "waiting", "bobber lands after casting")
	game._process(7.0)
	check(game.state == "bite", "bite follows the cast")
	game._fishing_action()
	check(game.state == "reeling", "hook the fish")
	check(game.holding_zone.visible and game.fish_wake.visible, "water markers appear on hook")
	game.fish_time = 0.0
	game.fishing_aim = Vector2.ZERO
	game.aim_destination = Vector2.ZERO
	game._advance_reeling(0.1, true)
	check(game.progress > 0.0, "reeling within the zone increases progress")
	var previous_progress: float = game.progress
	game.fishing_aim = Vector2(2.2, 2.2)
	game.aim_destination = game.fishing_aim
	game._advance_reeling(0.1, false)
	check(is_equal_approx(game.progress, previous_progress), "pausing holds progress outside the zone")
	game._advance_reeling(0.1, true)
	check(game.progress < previous_progress, "reeling outside the zone decreases progress")
	game.progress = 1.0
	game._process(0.01)
	check(game.state == "dialogue", "finish reeling and start dialogue")
	check(not game.holding_zone.visible and not game.fish_wake.visible and not game.fishing_line.visible, "water markers disappear after catching")
	check(game.overlay_background.position.x >= 0 and game.overlay_background.position.x + game.overlay_background.size.x <= root.get_visible_rect().size.x, "dialogue panel fits viewport")
	check(game.overlay_background.position.y >= 0 and game.overlay_background.position.y + game.overlay_background.size.y <= root.get_visible_rect().size.y, "dialogue panel fits viewport height")
	game._choose_fish(true)
	check(game.known_story and game.state == "idle", "release friend to unlock story")
	game._fishing_action()
	game.state = "dialogue"
	game._choose_fish(false)
	check(game.boss_in_box and not game.caught_boss, "boss is in box until returning")
	game.boat.position = Vector3(0, 0, 7)
	game._interact()
	check(not game.riding and game.caught_boss and not game.boss_in_box, "return deposits boss")
	check(game.boat_blocker.collision_layer == 1, "boat blocks walking again after disembarking")
	game.known_story = false
	game.caught_boss = false
	game._load_game()
	check(game.known_story and game.caught_boss, "story and boss survive save/load")
	game.energy = 0
	game.player.position = Vector3(1.3, 0, 21)
	game._interact()
	check(game.energy == 100.0, "sleep restores energy")
	check(game.pixel_renderer != null and game.pixel_camera != null, "pixel renderer and its camera are active")
	check(game._boat_blocked(Vector2(0, -18)), "central shore blocks the boat")
	check(not game._boat_blocked(Vector2(22, -30)), "deeper water remains reachable around the shores")
	check(game.campfire.is_playing(), "downloaded campfire effect is burning")
	game.clock_minutes = 23 * 60
	game._process(0.01)
	check(game.scene_sky.sky_material == game.night_sky_material, "night sky is active at night")
	game.clock_minutes = 12 * 60
	game._process(0.01)
	check(game.scene_sky.sky_material == game.day_sky_material, "day sky is active at noon")
	game.riding = true
	game.boat_blocker.collision_layer = 0
	game.boat.position = Vector3(-33, 0, -12)
	game.attempts = 1
	game._fishing_action()
	check(game.state == "casting" and game.current_zone == 1 and game.current_fish == "Окунь Секач", "western area has its own boss")
	game.state = "dialogue"
	game._choose_fish(false)
	game.boat.position = Vector3(33, 0, -12)
	game.attempts = 1
	game._fishing_action()
	check(game.state == "casting" and game.current_zone == 2 and game.current_fish == "Щука Костяная", "eastern area has its own boss")
	game.state = "dialogue"
	game._choose_fish(false)
	game.boat.position = Vector3(-33, 0, -12)
	game.attempts = 0
	game._fishing_action()
	check(game.current_fish == "Пескарь-разведчик", "western area has its own friendly fish")
	game.state = "dialogue"
	game._choose_fish(false)
	var before_delivery: int = game.stored_fish.size()
	game.boat.position = Vector3(0, 0, 7)
	game._interact()
	check(game.stored_fish.size() == before_delivery + 3 and game.pending_fish.is_empty(), "every kept fish is delivered home")
	check(game.caught_bosses.has("1") and game.caught_bosses.has("2"), "bosses from both new areas are recorded")
	check(get_nodes_in_group("tank_fish").size() == game.stored_fish.size(), "every stored fish has a swimming model")
	game.stored_fish.clear()
	game.caught_bosses.clear()
	game._load_game()
	check(game.stored_fish.size() == before_delivery + 3 and game.caught_bosses.has("2"), "collection and new bosses survive save/load")
	var legacy := FileAccess.open(game.save_path, FileAccess.WRITE)
	legacy.store_string(JSON.stringify({"boss": true, "story": true, "boss_in_box": false, "other": 1}))
	legacy.close()
	game._load_game()
	check(game.caught_bosses.has("0") and game.stored_fish.size() == 1, "older saved boss is migrated into the collection")
	check(game.story_zones.has("0") and game.pending_fish.size() == 1, "older story and pending fish are migrated")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.save_path))
	if failures == 0:
		print("PASS: full fishing, choice, return, save/load, and sleep flow")
	quit(1 if failures > 0 else 0)
