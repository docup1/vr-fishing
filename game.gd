extends Node3D

const Art = preload("res://prototype_art.gd")
const MapMarker = preload("res://map_marker.gd")
# The desktop controls are deliberately separate from the fishing rules so that
# a tracked VR rig can feed the same actions in a later version.
var camera: Camera3D
var vr_active := false
var xr_origin: XROrigin3D
var left_controller: XRController3D
var right_controller: XRController3D
var vr_ui_viewport: SubViewport
var vr_trigger_pressed := false
const VR_TURN_SPEED := 2.6 # radians per second at full stick deflection
const VR_TRIGGER_PRESS := 0.55
const VR_TRIGGER_RELEASE := 0.35
var boat: Node3D
var boat_hull: Node3D
var boat_wake: Node3D
var player: CharacterBody3D
var boat_blocker: StaticBody3D
var rod: Node3D
var fish_model: Node3D
var boss_model: Node3D
var sunlight: DirectionalLight3D
var home_light: OmniLight3D
var beacon_lights: Array[OmniLight3D] = []
var scene_environment: Environment
var scene_sky: Sky
var day_sky_material: Material
var night_sky_material: Material
var pixel_renderer: Control
var pixel_camera: Camera3D
var rod_tip: Node3D
var reeds: Array[Node3D] = []
var water_material: ShaderMaterial
var water_time := 0.0
var boat_velocity := Vector3.ZERO
var vr_boat_head_offset := Vector3.ZERO
var player_velocity := Vector3.ZERO
var bobber: Node3D
var fishing_center := Vector3.ZERO
var fishing_right := Vector3.RIGHT
var fishing_forward := Vector3.FORWARD
var fishing_aim := Vector2.ZERO
var aim_destination := Vector2.ZERO
var fish_offset := Vector2.ZERO
var fish_velocity := Vector2.ZERO
var cast_elapsed := 0.0
var cast_start := Vector3.ZERO
const CAST_DURATION := 0.9
var holding_zone: Node3D
var fish_wake: Node3D
var swimming_fish: Node3D
var fishing_line: MeshInstance3D
var line_segments: Array[MeshInstance3D] = []
var zone_material: StandardMaterial3D
var zone_ring_material: StandardMaterial3D
var trophy: Node3D
var fish_display: Node3D
var hud: Label
var hud_title: Label
var prompt: Label
var info: Label
var overlay: Label
var overlay_background: Panel
var hud_background: Panel
var prompt_background: Panel
var info_background: Panel
var progress_title: Label
var ui_root: Control
var map_background: Panel
var map_title: Label
var map_legend: Label
var map_footer: Label
var map_image: TextureRect
var map_marker: Control
var map_viewport: SubViewport
var map_camera: Camera3D
var bar: ProgressBar
var riding := false
var state := "idle"
var clock_minutes := 8.0 * 60.0
var energy := 100.0
var wait_seconds := 0.0
var bite_seconds := 0.0
var progress := 0.0
var line_tension := 0.0
var fish_time := 0.0
const ZONE_RADIUS := 0.85
const FISHING_RANGE := 2.2
var current_fish := ""
var current_type := ""
var known_story := false
var caught_boss := false
var boss_in_box := false
var caught_other := 0
var attempts := 0
var message := ""
var message_time := 0.0
var book_open := false
var map_open := false
var landed := false
var campfire: Node3D
var collection_root: Node3D
var stored_fish: Array = []
var pending_fish: Array = []
var story_zones: Dictionary = {}
var caught_bosses: Dictionary = {}
var current_zone := 0
const ZONES := [
	{"name": "Камышовая заводь", "center": Vector2(0, -10), "friend": "Карась-летописец", "boss": "Ёрш Игла"},
	{"name": "Старый причал", "center": Vector2(-33, -8), "friend": "Пескарь-разведчик", "boss": "Окунь Секач"},
	{"name": "Коряжник", "center": Vector2(33, -8), "friend": "Линь-наблюдатель", "boss": "Щука Костяная"},
]
const SAVE_PATH := "user://fishing_save.json"
var save_path := SAVE_PATH
const DOCK := Vector3(0, 0, 9)

func _ready() -> void:
	_init_vr()
	_build_world()
	if vr_active:
		_apply_vr_texture_filter(self)
	else:
		_setup_pixel_renderer()
	_build_ui()
	_load_game()
	_refresh_collection()
	if not vr_active:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_show_message("Осмотрись в доме. X — действие, Y — карта." if vr_active else "Осмотрись в доме. Таб — книга, E — взаимодействие.", 8.0)

func _init_vr() -> void:
	# Headless tests and servers do not have an XR display.
	if DisplayServer.get_name() == "headless":
		return
	var interface := XRServer.find_interface("OpenXR")
	if interface and (interface.is_initialized() or interface.initialize()):
		vr_active = true
		get_viewport().use_xr = true
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.physics_ticks_per_second = 90
		print("OpenXR подключён: VR-режим включён.")
	else:
		print("OpenXR недоступен. Запуск в обычном режиме; проверьте подключение шлема и OpenXR runtime.")

func _build_world() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	scene_environment = env
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	scene_sky = sky
	day_sky_material = load("res://Materials/EA_Sky_Meadow.tres") as Material
	var stars := ShaderMaterial.new()
	stars.shader = load("res://SkyStar.gdshader")
	night_sky_material = stars
	sky.sky_material = day_sky_material
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78, 0.86, 0.89)
	env.ambient_light_energy = 0.8
	environment.environment = env
	add_child(environment)
	sunlight = DirectionalLight3D.new()
	sunlight.rotation_degrees = Vector3(-55, -35, 0)
	sunlight.light_energy = 1.2
	sunlight.shadow_enabled = true
	add_child(sunlight)
	home_light = OmniLight3D.new()
	home_light.position = Vector3(0, 2.7, 18.8)
	home_light.light_color = Color(1.0, 0.66, 0.36)
	home_light.omni_range = 10.0
	add_child(home_light)
	_create_water()
	_box(self, Vector3(0, -0.05, 17), Vector3(32, 0.5, 14), Color(0.34, 0.46, 0.26))
	_box(self, Vector3(0, 0.14, 9), Vector3(3.0, 0.3, 10), Color(0.52, 0.33, 0.19))
	_box(self, Vector3(0, 0.15, 20), Vector3(9, 0.3, 7), Color(0.52, 0.33, 0.20))
	_box(self, Vector3(-4.4, 1.7, 20), Vector3(0.3, 3.4, 7), Color(0.68, 0.53, 0.36))
	_box(self, Vector3(4.4, 1.7, 20), Vector3(0.3, 3.4, 7), Color(0.68, 0.53, 0.36))
	_box(self, Vector3(0, 1.7, 23.4), Vector3(9, 3.4, 0.3), Color(0.68, 0.53, 0.36))
	_box(self, Vector3(-3.1, 1.7, 16.55), Vector3(2.7, 3.4, 0.28), Color(0.61, 0.46, 0.30))
	_box(self, Vector3(3.1, 1.7, 16.55), Vector3(2.7, 3.4, 0.28), Color(0.61, 0.46, 0.30))
	_box(self, Vector3(0, 3.1, 16.55), Vector3(3.5, 0.6, 0.28), Color(0.61, 0.46, 0.30))
	for side in [-1.0, 1.0]:
		var roof := _box(self, Vector3(side * 2.25, 4.1, 20), Vector3(5.0, 0.20, 7.8), Color(0.27, 0.18, 0.12))
		roof.rotation.z = -side * 0.28
		_box(self, Vector3(side * 1.8, 1.9, 23.20), Vector3(1.3, 1.25, 0.12), Color(0.40, 0.56, 0.54))
		_box(self, Vector3(side * 1.8, 1.9, 23.10), Vector3(0.08, 1.35, 0.10), Color(0.33, 0.23, 0.14))
		_box(self, Vector3(side * 1.8, 1.9, 23.10), Vector3(1.4, 0.08, 0.10), Color(0.33, 0.23, 0.14))
	Art.cabin_gable(self, 23.4)
	Art.cabin_gable(self, 16.55)
	for i in range(14):
		_box(self, Vector3(0, 0.35 + i * 0.21, 23.22), Vector3(8.7, 0.025, 0.05), Color(0.45, 0.32, 0.22))
	Art.decorate_land(self)
	# Book and clock stand on separate furniture, close enough to interact.
	_box(self, Vector3(-2.5, 0.5, 21), Vector3(2, 0.9, 1.0), Color(0.37, 0.23, 0.14))
	_box(self, Vector3(-2.5, 1.0, 21), Vector3(0.7, 0.12, 0.5), Color(0.84, 0.77, 0.57))
	_box(self, Vector3(2.8, 0.4, 21), Vector3(2.0, 0.7, 1.1), Color(0.8, 0.76, 0.64))
	_box(self, Vector3(0, 2.1, 23.15), Vector3(3.5, 0.9, 0.1), Color(0.26, 0.20, 0.13))
	# Match the visible walls, doorway, and furniture with solid shapes.
	_add_solid_box(self, Vector3(-4.4, 1.7, 20), Vector3(0.3, 3.4, 7))
	_add_solid_box(self, Vector3(4.4, 1.7, 20), Vector3(0.3, 3.4, 7))
	_add_solid_box(self, Vector3(0, 1.7, 23.4), Vector3(9, 3.4, 0.3))
	_add_solid_box(self, Vector3(-3.1, 1.7, 16.55), Vector3(2.7, 3.4, 0.28))
	_add_solid_box(self, Vector3(3.1, 1.7, 16.55), Vector3(2.7, 3.4, 0.28))
	_add_solid_box(self, Vector3(-2.5, 0.5, 21), Vector3(2, 0.9, 1.0))
	_add_solid_box(self, Vector3(2.8, 0.4, 21), Vector3(2, 0.7, 1.1))
	# Water either side of the narrow pier is outside the walking area.
	_add_solid_box(self, Vector3(-8.75, 0.9, 7), Vector3(14.5, 2, 6))
	_add_solid_box(self, Vector3(8.75, 0.9, 7), Vector3(14.5, 2, 6))
	trophy = Node3D.new()
	trophy.position = Vector3(0, 2.1, 23.0)
	add_child(trophy)
	_box(trophy, Vector3.ZERO, Vector3(0.65, 0.32, 0.18), Color(0.62, 0.69, 0.35))
	_box(trophy, Vector3(-0.42, 0, 0), Vector3(0.25, 0.4, 0.1), Color(0.45, 0.53, 0.25))
	trophy.visible = false
	# Reeds mark the first fishing spot. Their silhouettes are visible from the dock.
	Art.make_bank(self)
	_build_extra_areas()
	for beacon_pos in [Vector3(0, 0.25, -15), Vector3(-33, 0.25, -13), Vector3(33, 0.25, -13)]:
		_build_beacon(beacon_pos)
	for i in range(15):
		var x := float(i - 7) * 1.3
		var reed := Node3D.new()
		reed.position = Vector3(x, 0, -16.7 + float(i % 3) * 0.35)
		reed.name = "Reed%d" % i
		add_child(reed)
		Art.cylinder(reed, 0.045, 0.025, 2.2, Vector3(0, 1.1, 0), Color(0.35, 0.43, 0.18))
		Art.ellipsoid(reed, Vector3(0.105, 0.34, 0.105), Vector3(0, 2.0, 0), Color(0.27, 0.18, 0.10))
		reeds.append(reed)
	boat = Node3D.new()
	boat.position = Vector3(0, 0, 7)
	add_child(boat)
	boat_hull = Node3D.new()
	boat.add_child(boat_hull)
	var boat_asset := (load("res://GLB/Wood_BoatV1.glb") as PackedScene).instantiate() as Node3D
	boat_asset.name = "DownloadedBoat"
	boat_hull.add_child(boat_asset)
	for side in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.name = "LeftOar" if side < 0 else "RightOar"
		pivot.position = Vector3(side * 0.65, 0.65, 0.2)
		boat_hull.add_child(pivot)
		var paddle := (load("res://GLB/Paddle.glb") as PackedScene).instantiate() as Node3D
		paddle.scale = Vector3.ONE * 0.7
		paddle.rotation.z = -side * 0.7
		pivot.add_child(paddle)
	boat_blocker = _add_solid_box(boat, Vector3(0, 0.45, 0), Vector3(1.8, 0.9, 3.6))
	boat_wake = Node3D.new()
	add_child(boat_wake)
	_add_ring(boat_wake, 1.15, 0.035, Color(0.52, 0.73, 0.70))
	_add_ring(boat_wake, 1.48, 0.025, Color(0.42, 0.64, 0.63))
	boat_wake.visible = false
	player = CharacterBody3D.new()
	player.position = Vector3(0, 0, 20)
	add_child(player)
	var player_shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.28
	capsule.height = 1.45
	player_shape.shape = capsule
	player_shape.position.y = 1.025
	player.add_child(player_shape)
	if vr_active:
		xr_origin = XROrigin3D.new()
		player.add_child(xr_origin)
		camera = XRCamera3D.new()
		xr_origin.add_child(camera)
		left_controller = _make_controller("left_hand")
		right_controller = _make_controller("right_hand")
		left_controller.button_pressed.connect(_on_vr_left_button)
		right_controller.button_pressed.connect(_on_vr_right_button)
	else:
		camera = Camera3D.new()
		camera.position.y = 1.65
		player.add_child(camera)
	camera.current = true
	# A simple rod stays visible at the bottom right of the view.
	rod = Node3D.new()
	if vr_active:
		rod.position = Vector3(0, -0.04, -0.10)
		right_controller.add_child(rod)
	else:
		rod.position = Vector3(0.48, -0.43, -1.0)
		camera.add_child(rod)
	var rod_asset := (load("res://GLB/Fishing_Rod.glb") as PackedScene).instantiate() as Node3D
	rod_asset.scale = Vector3.ONE * 0.7
	if vr_active:
		# The GLB's tip points along +Z and its handle is at -Z.
		# Flip the model and place the handle at the controller's grip pose.
		rod_asset.rotation.x = PI
		# Turn the reel to the opposite side without moving the rod tip.
		rod_asset.rotation.z = PI
		rod_asset.position.z = -0.70
	rod.add_child(rod_asset)
	rod_tip = Node3D.new()
	rod_tip.position = Vector3(0, 0, -1.72 if vr_active else -0.76)
	rod.add_child(rod_tip)
	fish_display = Node3D.new()
	fish_display.position = Vector3(0, -0.05, -2.0)
	camera.add_child(fish_display)
	fish_model = Art.make_fish(fish_display, Color(0.51, 0.57, 0.34))
	boss_model = Art.make_fish(fish_display, Color(0.42, 0.43, 0.26), true)
	boss_model.visible = false
	fish_display.visible = false
	bobber = Node3D.new()
	add_child(bobber)
	Art.ellipsoid(bobber, Vector3(0.11, 0.15, 0.11), Vector3.ZERO, Color(0.8, 0.78, 0.66))
	Art.ellipsoid(bobber, Vector3(0.105, 0.07, 0.105), Vector3(0, 0.10, 0), Color(0.78, 0.12, 0.08))
	Art.cylinder(bobber, 0.014, 0.014, 0.25, Vector3(0, 0.25, 0), Color(0.16, 0.12, 0.08))
	bobber.visible = false
	_create_fishing_visuals()
	_build_campfire()
	collection_root = Node3D.new()
	collection_root.name = "FishCollection"
	add_child(collection_root)

func _make_controller(tracker_path: String) -> XRController3D:
	var controller := XRController3D.new()
	controller.tracker = tracker_path
	controller.pose = "grip"
	xr_origin.add_child(controller)
	var handle := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.035
	mesh.height = 0.18
	handle.mesh = mesh
	controller.add_child(handle)
	return controller

func _on_vr_left_button(action: String) -> void:
	if action == "ax_button" and state == "idle" and not book_open and not map_open:
		_interact()
	elif action == "by_button" and state == "idle":
		map_open = not map_open
		book_open = false

func _on_vr_right_button(action: String) -> void:
	if action == "ax_button":
		if state == "dialogue":
			_choose_fish(true)
		elif state == "idle":
			book_open = not book_open
			map_open = false
	elif action == "by_button" and state == "dialogue":
		_choose_fish(false)

func _update_vr_input(delta: float) -> void:
	_update_vr_trigger(right_controller.get_float("trigger"))
	var stick := right_controller.get_vector2("primary")
	if state == "reeling":
		aim_destination.x = clampf(aim_destination.x + stick.x * delta * 2.8, -FISHING_RANGE, FISHING_RANGE)
		aim_destination.y = clampf(aim_destination.y + stick.y * delta * 2.8, -FISHING_RANGE, FISHING_RANGE)
	else:
		_turn_vr(stick.x, delta)

func _update_vr_trigger(value: float) -> void:
	if vr_trigger_pressed:
		if value <= VR_TRIGGER_RELEASE:
			vr_trigger_pressed = false
	elif value >= VR_TRIGGER_PRESS:
		vr_trigger_pressed = true
		if not book_open and not map_open:
			_fishing_action()

func _turn_vr(axis: float, delta: float) -> void:
	const DEADZONE := 0.2
	if absf(axis) <= DEADZONE:
		return
	var strength := (minf(absf(axis), 1.0) - DEADZONE) / (1.0 - DEADZONE)
	# Rotate the rig around the tracked head without shifting it relative to the boat.
	var head_position := camera.global_position
	xr_origin.rotate_y(-signf(axis) * strength * VR_TURN_SPEED * delta)
	var head_delta := head_position - camera.global_position
	xr_origin.global_position += Vector3(head_delta.x, 0, head_delta.z)

func _movement_input() -> Vector2:
	if vr_active:
		var stick := left_controller.get_vector2("primary")
		if stick.length() < 0.2:
			return Vector2.ZERO
		return Vector2(stick.x, -stick.y)
	return Vector2(float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)), float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W)))

func _movement_direction(v: Vector2) -> Vector3:
	if not vr_active:
		return player.global_basis * Vector3(v.x, 0, v.y)
	var forward := -camera.global_basis.z
	forward.y = 0
	forward = forward.normalized()
	var right := Vector3(-forward.z, 0, forward.x)
	return right * v.x - forward * v.y

func _apply_vr_texture_filter(node: Node) -> void:
	# Keep texture edges sharp without sampling the XR screen buffer.
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		if mesh_node.mesh:
			for surface in range(mesh_node.mesh.get_surface_count()):
				var material := mesh_node.get_active_material(surface) as BaseMaterial3D
				if material and material.albedo_texture:
					material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	for child in node.get_children():
		_apply_vr_texture_filter(child)

func _setup_pixel_renderer() -> void:
	# Keep the existing world and input in the main viewport; the addon renders
	# the same 3D world through its own low-resolution camera. UI stays legible.
	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	pixel_renderer = load("res://addons/pixel_art_renderer/scripts/pixel_art_renderer.gd").new()
	pixel_renderer.name = "PixelArtRenderer"
	layer.add_child(pixel_renderer)
	pixel_renderer.set_anchors_preset(Control.PRESET_TOP_LEFT)
	pixel_renderer.position = Vector2.ZERO
	pixel_renderer.size = get_viewport().get_visible_rect().size
	pixel_renderer.virtual_width = 480
	pixel_renderer.virtual_height = 270
	pixel_renderer.target_fps = 60.0
	pixel_renderer.color_levels = 18.0
	pixel_renderer.dither_mode = 0
	pixel_renderer.outline_enabled = false
	var pixel_viewport := pixel_renderer.get_node("PixelSubViewport") as SubViewport
	pixel_viewport.world_3d = get_viewport().world_3d
	pixel_camera = Camera3D.new()
	pixel_viewport.add_child(pixel_camera)
	pixel_camera.current = true
	pixel_camera.global_transform = camera.global_transform
	pixel_camera.fov = camera.fov

func _build_extra_areas() -> void:
	for side in [-1.0, 1.0]:
		var x: float = side * 37.0
		_box(self, Vector3(x, -0.05, -18), Vector3(17, 0.5, 9), Color(0.28, 0.38, 0.22))
		for i in range(4):
			var tree_pos := Vector3(x - 6.0 + i * 4.0, 0.2, -20.0 + float(i % 2) * 1.3)
			var model := "Trees/EM_Tree1a_PRE" if i % 2 == 0 else "Trees/EM_Tree3a_PRE"
			Art.nature_asset(self, model, tree_pos, 0.55 + 0.05 * i, i * 1.4)
		for i in range(4):
			Art.nature_asset(self, "Rock/EA_Env_Rock_01b_PRE", Vector3(x - 6 + i * 4, 0.2, -14.4), 0.5, i)
		if side < 0:
			# A broken jetty is the landmark for the second fishing spot.
			_box(self, Vector3(x, 0.36, -13.8), Vector3(2.5, 0.24, 4.5), Color(0.40, 0.26, 0.15))
			for i in range(3):
				Art.cylinder(self, 0.13, 0.12, 1.7, Vector3(x + (i - 1) * 1.1, 0.5, -11.6), Color(0.32, 0.24, 0.17))
		else:
			# A fallen trunk distinguishes the third spot from the reed bed.
			var trunk := Art.cylinder(self, 0.40, 0.22, 6.5, Vector3(x, 0.45, -15.2), Color(0.29, 0.22, 0.13))
			trunk.rotation.z = PI / 2.0

func _build_campfire() -> void:
	var camp_scene := load("res://addons/pyrolux_fx/presets/3d/fire_campfire.tscn") as PackedScene
	campfire = camp_scene.instantiate() as Node3D
	campfire.position = Vector3(-3.8, 0.25, 13.2)
	campfire.scale = Vector3.ONE * 0.55
	add_child(campfire)
	for i in range(6):
		var angle := float(i) * TAU / 6.0
		var stone := Art.ellipsoid(self, Vector3(0.22, 0.13, 0.18), campfire.position + Vector3(cos(angle) * 0.5, 0, sin(angle) * 0.5), Color(0.32, 0.33, 0.28))
		stone.rotation.y = angle

func _build_beacon(pos: Vector3) -> void:
	Art.cylinder(self, 0.08, 0.06, 1.6, pos + Vector3(0, 0.8, 0), Color(0.31, 0.23, 0.14))
	var bulb := Art.ellipsoid(self, Vector3(0.16, 0.20, 0.16), pos + Vector3(0, 1.65, 0), Color(0.95, 0.65, 0.28))
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(1.0, 0.75, 0.38)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.54, 0.16)
	glow.emission_energy_multiplier = 1.5
	bulb.material_override = glow
	var light := OmniLight3D.new()
	light.position = pos + Vector3(0, 1.65, 0)
	light.light_color = Color(1.0, 0.65, 0.32)
	light.omni_range = 7.0
	add_child(light)
	beacon_lights.append(light)

func _refresh_collection() -> void:
	for child in collection_root.get_children():
		collection_root.remove_child(child)
		child.queue_free()
	var grouped := {}
	for entry in stored_fish:
		if entry is Dictionary:
			var fish_name := str(entry.get("name", "Рыба"))
			if not grouped.has(fish_name): grouped[fish_name] = []
			grouped[fish_name].append(entry)
	var index := 0
	for fish_name in grouped:
		var tank := Node3D.new()
		tank.name = "Tank%d" % index
		tank.position = Vector3(-3.6 + float(index % 7) * 1.2, 0.30, 22.25 - float(index / 7) * 1.2)
		collection_root.add_child(tank)
		_add_solid_box(tank, Vector3(0, 0.9, 0), Vector3(0.82, 1.7, 0.82))
		# Wooden aquarium with brass bands matches the rest of the cabin.
		var wood := Color(0.34, 0.21, 0.12)
		var brass := Color(0.62, 0.48, 0.25)
		Art.cylinder(tank, 0.43, 0.43, 0.18, Vector3(0, 0.20, 0), wood)
		Art.cylinder(tank, 0.43, 0.43, 0.12, Vector3(0, 1.59, 0), wood)
		Art.cylinder(tank, 0.44, 0.44, 0.035, Vector3(0, 0.30, 0), brass)
		Art.cylinder(tank, 0.44, 0.44, 0.035, Vector3(0, 1.52, 0), brass)
		var glass := MeshInstance3D.new()
		var glass_mesh := CylinderMesh.new()
		glass_mesh.top_radius = 0.36
		glass_mesh.bottom_radius = 0.36
		glass_mesh.height = 1.25
		glass.mesh = glass_mesh
		glass.position.y = 0.95
		var glass_material := StandardMaterial3D.new()
		glass_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glass_material.albedo_color = Color(0.30, 0.78, 0.66, 0.10)
		glass_material.roughness = 0.18
		glass_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		glass.material_override = glass_material
		glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		tank.add_child(glass)
		var lamp := OmniLight3D.new()
		lamp.position.y = 1.4
		lamp.light_color = Color(0.32, 0.8, 0.65)
		lamp.light_energy = 0.35
		lamp.omni_range = 2.0
		tank.add_child(lamp)
		var fish_index := 0
		for entry in grouped[fish_name]:
			var color := Color(0.51, 0.57, 0.34) if entry.get("type", "") != "boss" else Color(0.42, 0.43, 0.26)
			var fish := Art.make_fish(tank, color, entry.get("type", "") == "boss")
			fish.scale = Vector3.ONE * 0.38
			fish.set_meta("swim_index", fish_index)
			fish.add_to_group("tank_fish")
			fish_index += 1
		index += 1

func _animate_collection() -> void:
	for fish in get_tree().get_nodes_in_group("tank_fish"):
		var index := int(fish.get_meta("swim_index"))
		var phase := water_time * 0.7 + float(index) * 2.1
		fish.position = Vector3(cos(phase) * 0.12, 0.62 + fmod(float(index) * 0.22, 0.65) + 0.06 * sin(phase * 1.7), sin(phase) * 0.12)
		fish.rotation.y = -phase
		fish.get_node("Tail").rotation.y = sin(phase * 5.0) * 0.4

func _create_water() -> void:
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(100, 100)
	plane.subdivide_width = 200
	plane.subdivide_depth = 200
	water.mesh = plane
	water.position.y = -0.1
	water_material = ShaderMaterial.new()
	water_material.shader = load("res://water.gdshader")
	water.material_override = water_material
	add_child(water)

func _water_height(x: float, z: float) -> float:
	return -0.1 + 0.035 * sin(x * 0.65 + z * 0.35 + water_time * 0.9) + 0.022 * sin(-x * 0.35 + z * 0.75 + water_time * 0.65)

func _create_fishing_visuals() -> void:
	# The marker and wake live in world space, just above the pond surface.
	holding_zone = Node3D.new()
	add_child(holding_zone)
	var disc := MeshInstance3D.new()
	var disc_mesh := CylinderMesh.new()
	disc_mesh.top_radius = ZONE_RADIUS
	disc_mesh.bottom_radius = ZONE_RADIUS
	disc_mesh.height = 0.015
	disc.mesh = disc_mesh
	zone_material = StandardMaterial3D.new()
	zone_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	zone_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	zone_material.albedo_color = Color(0.22, 0.9, 0.59, 0.28)
	disc.material_override = zone_material
	holding_zone.add_child(disc)
	zone_ring_material = _add_ring(holding_zone, ZONE_RADIUS, 0.055, Color(0.55, 1.0, 0.68))
	holding_zone.visible = false
	fish_wake = Node3D.new()
	add_child(fish_wake)
	_add_ring(fish_wake, 0.34, 0.045, Color(0.94, 0.95, 0.78))
	_add_ring(fish_wake, 0.57, 0.025, Color(0.66, 0.88, 0.87))
	var marker := MeshInstance3D.new()
	var marker_mesh := SphereMesh.new()
	marker_mesh.radius = 0.17
	marker_mesh.height = 0.22
	marker.mesh = marker_mesh
	var marker_material := StandardMaterial3D.new()
	marker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker_material.albedo_color = Color(1.0, 0.79, 0.28)
	marker.material_override = marker_material
	marker.position.y = 0.06
	fish_wake.add_child(marker)
	swimming_fish = Art.make_fish(fish_wake, Color(0.50, 0.56, 0.32))
	swimming_fish.scale = Vector3.ONE * 0.55
	swimming_fish.position = Vector3(-0.32, 0.04, 0)
	fish_wake.visible = false
	var line_mesh := CylinderMesh.new()
	line_mesh.top_radius = 0.006
	line_mesh.bottom_radius = 0.006
	line_mesh.height = 1.0
	line_mesh.radial_segments = 6
	var line_material := StandardMaterial3D.new()
	line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_material.albedo_color = Color(0.94, 0.91, 0.72)
	for i in range(12):
		var segment := MeshInstance3D.new()
		segment.mesh = line_mesh
		segment.material_override = line_material
		segment.visible = false
		add_child(segment)
		line_segments.append(segment)
	fishing_line = line_segments[0]

func _set_line_visible(value: bool) -> void:
	for segment in line_segments:
		segment.visible = value

func _add_ring(parent: Node3D, radius: float, thickness: float, color: Color) -> StandardMaterial3D:
	var instance := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = radius - thickness
	ring.outer_radius = radius
	instance.mesh = ring
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	instance.material_override = material
	instance.position.y = 0.025
	parent.add_child(instance)
	return material

func _box(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh_instance.material_override = material
	mesh_instance.position = pos
	parent.add_child(mesh_instance)
	return mesh_instance

func _add_solid_box(parent: Node3D, pos: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	parent.add_child(body)
	return body

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 2
	if vr_active:
		vr_ui_viewport = SubViewport.new()
		vr_ui_viewport.size = Vector2i(1280, 720)
		vr_ui_viewport.transparent_bg = true
		vr_ui_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(vr_ui_viewport)
		vr_ui_viewport.add_child(layer)
		var ui_screen := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(2.4, 1.35)
		ui_screen.mesh = quad
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_texture = vr_ui_viewport.get_texture()
		material.no_depth_test = true
		material.render_priority = 120
		ui_screen.material_override = material
		ui_screen.position = Vector3(0, 0, -2.0)
		camera.add_child(ui_screen)
	else:
		add_child(layer)
	ui_root = Control.new()
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui_root)
	hud_background = _panel(Color(0.055, 0.13, 0.14, 0.93), Color(0.54, 0.60, 0.45, 0.8))
	hud_title = _label(ui_root, Vector2.ZERO, 13)
	hud_title.text = "Р Ы Б А Ц К И Й   Д Н Е В Н И К"
	hud_title.add_theme_color_override("font_color", Color(0.80, 0.77, 0.59))
	hud = _label(ui_root, Vector2.ZERO, 19)
	hud.add_theme_color_override("font_color", Color(0.96, 0.95, 0.85))
	prompt_background = _panel(Color(0.055, 0.13, 0.14, 0.93), Color(0.54, 0.60, 0.45, 0.7))
	prompt = _label(ui_root, Vector2.ZERO, 18)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_color_override("font_color", Color(0.95, 0.93, 0.82))
	info_background = _panel(Color(0.08, 0.16, 0.15, 0.94), Color(0.68, 0.65, 0.45, 0.8))
	info = _label(ui_root, Vector2.ZERO, 18)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_color_override("font_color", Color(1.0, 0.94, 0.77))
	overlay_background = _panel(Color(0.91, 0.87, 0.74, 0.98), Color(0.57, 0.47, 0.31))
	overlay = _label(ui_root, Vector2.ZERO, 21)
	overlay.add_theme_color_override("font_color", Color(0.17, 0.20, 0.17))
	overlay.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	overlay.visible = false
	bar = ProgressBar.new()
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", _panel_style(Color(0.04, 0.12, 0.12, 0.95), Color(0.66, 0.69, 0.54), 6))
	bar.add_theme_stylebox_override("fill", _panel_style(Color(0.63, 0.77, 0.55), Color(0.63, 0.77, 0.55), 6))
	bar.visible = false
	ui_root.add_child(bar)
	progress_title = _label(ui_root, Vector2.ZERO, 13)
	progress_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress_title.text = "В Ы В А Ж И В А Н И Е"
	progress_title.add_theme_color_override("font_color", Color(0.98, 0.95, 0.82))
	_build_map()
	_layout_ui()

func _build_map() -> void:
	map_background = _panel(Color(0.055, 0.13, 0.14, 0.98), Color(0.70, 0.66, 0.45))
	map_title = _label(ui_root, Vector2.ZERO, 23)
	map_title.text = "КАРТА ПРУДА"
	map_title.add_theme_color_override("font_color", Color(0.97, 0.94, 0.80))
	map_legend = _label(ui_root, Vector2.ZERO, 18)
	map_legend.text = "ОРИЕНТИРЫ\n\n▲  Вы и направление взгляда\n\nКамышовая заводь — север\nСтарый причал — запад\nКоряжник — восток\nДом — у южного причала\n\nM — закрыть карту"
	map_legend.add_theme_color_override("font_color", Color(0.92, 0.90, 0.75))
	map_legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	map_footer = _label(ui_root, Vector2.ZERO, 16)
	map_footer.text = "M  —  закрыть карту"
	map_footer.add_theme_color_override("font_color", Color(0.83, 0.80, 0.62))
	map_viewport = SubViewport.new()
	map_viewport.size = Vector2i(640, 640)
	map_viewport.own_world_3d = false
	map_viewport.world_3d = get_viewport().world_3d
	map_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	ui_root.add_child(map_viewport)
	map_camera = Camera3D.new()
	map_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	map_camera.size = 104.0
	map_camera.position = Vector3(0, 120, 0)
	map_camera.far = 220.0
	map_camera.rotation_degrees = Vector3(-90, 0, 0)
	map_camera.current = true
	map_viewport.add_child(map_camera)
	map_image = TextureRect.new()
	map_image.texture = map_viewport.get_texture()
	map_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map_image.stretch_mode = TextureRect.STRETCH_SCALE
	map_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(map_image)
	map_marker = MapMarker.new()
	map_marker.tracked_camera = camera
	map_marker.map_camera = map_camera
	map_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(map_marker)

func _panel_style(color: Color, border: Color, radius: int = 10) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0, 0, 0, 0.22)
	style.shadow_size = 5
	style.shadow_offset = Vector2(0, 2)
	return style

func _panel(color: Color, border: Color) -> Panel:
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", _panel_style(color, border))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(panel)
	return panel

func _label(parent: Node, pos: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.position = pos
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label

func _layout_ui() -> void:
	var screen := Vector2(vr_ui_viewport.size) if vr_active else get_viewport().get_visible_rect().size
	var margin := 24.0
	var small_screen := screen.x < 980.0 or screen.y < 560.0
	prompt.add_theme_font_size_override("font_size", 14 if small_screen else 18)
	hud.add_theme_font_size_override("font_size", 15 if small_screen else 19)
	overlay.add_theme_font_size_override("font_size", 16 if small_screen else 21)
	info.add_theme_font_size_override("font_size", 15 if small_screen else 18)
	var hud_width := minf(510.0, screen.x - margin * 2.0)
	hud_background.position = Vector2(margin, margin)
	hud_background.size = Vector2(hud_width, 112)
	hud_title.position = hud_background.position + Vector2(20, 13)
	hud_title.size = Vector2(hud_width - 40, 20)
	hud.position = hud_background.position + Vector2(20, 39)
	hud.size = Vector2(hud_width - 40, 58)
	var prompt_width := minf(1050.0, screen.x - margin * 2.0)
	prompt_background.position = Vector2((screen.x - prompt_width) * 0.5, screen.y - 73)
	prompt_background.size = Vector2(prompt_width, 49)
	prompt.position = prompt_background.position + Vector2(14, 12)
	prompt.size = Vector2(prompt_width - 28, 26)
	var notice_width := minf(770.0, screen.x - margin * 2.0)
	info_background.position = Vector2((screen.x - notice_width) * 0.5, screen.y - 141)
	info_background.size = Vector2(notice_width, 48)
	info.position = info_background.position + Vector2(12, 11)
	info.size = Vector2(notice_width - 24, 27)
	var progress_width := minf(420.0, screen.x - margin * 2.0)
	bar.position = Vector2((screen.x - progress_width) * 0.5, screen.y - 121)
	bar.size = Vector2(progress_width, 12)
	progress_title.position = bar.position + Vector2(0, -23)
	progress_title.size = Vector2(progress_width, 20)
	var dialogue := state == "dialogue"
	var panel_width := minf(960.0 if dialogue else 860.0, screen.x - margin * 2.0)
	var panel_height := 205.0 if dialogue else minf(390.0, screen.y - margin * 2.0)
	var panel_y := screen.y - panel_height - margin if dialogue else (screen.y - panel_height) * 0.5
	overlay_background.position = Vector2((screen.x - panel_width) * 0.5, panel_y)
	overlay_background.size = Vector2(panel_width, panel_height)
	overlay.position = overlay_background.position + Vector2(32, 24)
	overlay.size = Vector2(panel_width - 64, panel_height - 48)
	var map_width := minf(940.0, screen.x - margin * 2.0)
	var map_height := minf(660.0, screen.y - margin * 2.0)
	map_background.position = Vector2((screen.x - map_width) * 0.5, (screen.y - map_height) * 0.5)
	map_background.size = Vector2(map_width, map_height)
	map_title.position = map_background.position + Vector2(24, 16)
	var side := minf(map_height - 104.0, map_width * 0.62)
	map_image.position = map_background.position + Vector2(24, 58)
	map_image.size = Vector2(side, side)
	map_marker.position = map_image.position
	map_marker.size = map_image.size
	map_legend.position = map_image.position + Vector2(side + 22, 4)
	map_legend.size = Vector2(maxf(100.0, map_width - side - 70), side)
	map_legend.add_theme_font_size_override("font_size", 14 if small_screen else 18)
	map_footer.position = map_background.position + Vector2(24, map_height - 35)

func _unhandled_input(event: InputEvent) -> void:
	if vr_active:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		if state == "reeling":
			aim_destination.x = clampf(aim_destination.x + motion.relative.x * 0.008, -FISHING_RANGE, FISHING_RANGE)
			aim_destination.y = clampf(aim_destination.y - motion.relative.y * 0.008, -FISHING_RANGE, FISHING_RANGE)
		else:
			player.rotate_y(-motion.relative.x * 0.0025)
			camera.rotation.x = clampf(camera.rotation.x - motion.relative.y * 0.0025, -1.25, 1.1)
	if event is InputEventKey and event.pressed and not event.echo:
		var key := (event as InputEventKey).keycode
		if key == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
		elif key == KEY_TAB and state == "idle":
			book_open = not book_open
			map_open = false
		elif key == KEY_M and state == "idle":
			map_open = not map_open
			book_open = false
		elif key == KEY_E and state == "idle" and not book_open and not map_open:
			_interact()
		elif key == KEY_F and not book_open and not map_open:
			_fishing_action()
		elif key == KEY_1 and state == "dialogue":
			_choose_fish(true)
		elif key == KEY_2 and state == "dialogue":
			_choose_fish(false)

func _process(delta: float) -> void:
	if vr_active:
		_update_vr_input(delta)
	water_time += delta
	water_material.set_shader_parameter("wave_time", water_time)
	for i in range(reeds.size()):
		reeds[i].rotation.z = 0.035 * sin(water_time * 0.9 + float(i) * 0.7)
	if fish_display.visible:
		fish_display.position.y = -0.05 + 0.035 * sin(water_time * 2.0)
		var active_fish := boss_model if current_type == "boss" else fish_model
		active_fish.rotation.y = 0.08 * sin(water_time * 2.3)
		active_fish.get_node("Tail").rotation.y = 0.38 * sin(water_time * 5.0)
	if message_time > 0.0:
		message_time -= delta
		if message_time <= 0.0:
			message = ""
	if state == "casting":
		cast_elapsed = minf(cast_elapsed + delta, CAST_DURATION)
		var t := cast_elapsed / CAST_DURATION
		var destination := _water_position(Vector2.ZERO) + Vector3(0, 0.12, 0)
		bobber.global_position = cast_start.lerp(destination, t) + Vector3(0, 2.0 * 4.0 * t * (1.0 - t), 0)
		if t >= 1.0:
			state = "waiting"
			_show_message("Поплавок на воде. Жди поклёвки...", 5)
	elif state == "waiting":
		wait_seconds -= delta
		if wait_seconds <= 0.0:
			state = "bite"
			bite_seconds = 3.5
			_show_message("ПОКЛЁВКА! Нажми F, чтобы подсечь!", 3.5)
	elif state == "bite":
		bite_seconds -= delta
		if bite_seconds <= 0.0:
			_end_attempt("Рыба сорвалась. Попробуй ещё раз.")
	elif state == "reeling":
		_advance_reeling(delta, right_controller.get_float("trigger") > 0.55 if vr_active else Input.is_key_pressed(KEY_SPACE))
		if progress >= 1.0:
			energy = maxf(0, energy - 8)
			state = "dialogue"
			bobber.visible = false
			holding_zone.visible = false
			fish_wake.visible = false
			_set_line_visible(false)
			_show_message("", 0)
	if riding and state == "idle" and not book_open and not map_open:
		_move_boat(delta)
	_update_boat_pose(delta)
	if riding or state in ["casting", "waiting", "bite", "reeling"]:
		clock_minutes += delta * 1.5
	var daytime := maxf(0.0, sin((fmod(clock_minutes, 1440.0) / 1440.0 - 0.25) * TAU))
	sunlight.light_energy = lerpf(0.2, 1.2, daytime)
	sunlight.light_color = Color(0.58, 0.66, 0.82).lerp(Color(1.0, 0.91, 0.77), daytime)
	home_light.light_energy = lerpf(1.5, 0.35, daytime)
	for beacon in beacon_lights:
		beacon.light_energy = lerpf(1.4, 0.15, daytime)
	var hour := fmod(clock_minutes, 1440.0) / 60.0
	var selected_sky := night_sky_material if hour < 6.0 or hour >= 19.0 else day_sky_material
	if scene_sky.sky_material != selected_sky:
		scene_sky.sky_material = selected_sky
	scene_environment.ambient_light_energy = lerpf(0.35, 0.8, daytime)
	_animate_collection()
	if is_instance_valid(pixel_camera):
		pixel_renderer.size = get_viewport().get_visible_rect().size
		pixel_camera.global_transform = camera.global_transform
		pixel_camera.fov = camera.fov
	_update_fishing_visuals()
	_update_ui()

func _physics_process(delta: float) -> void:
	if not riding and state == "idle" and not book_open and not map_open:
		_move_player(delta)
	else:
		player_velocity = Vector3.ZERO

func _advance_reeling(delta: float, reel_pressed: bool) -> void:
	fish_time += delta
	# A damped pull gives both the rod and the fish momentum instead of teleporting.
	fishing_aim = fishing_aim.lerp(aim_destination, 1.0 - exp(-9.0 * delta))
	var struggle_speed := 1.25 if current_type == "boss" else 1.0
	var swim_time := fish_time * struggle_speed
	var fish_destination := Vector2(1.5 * sin(swim_time * 0.85) + 0.35 * sin(swim_time * 2.1), 0.85 * sin(swim_time * 1.2)) * (1.0 - progress * 0.35)
	var step := minf(delta, 0.05)
	fish_velocity += (fish_destination - fish_offset) * 8.0 * step
	fish_velocity *= exp(-4.0 * step)
	fish_offset += fish_velocity * step
	var desired_tension := clampf(fishing_aim.distance_to(fish_offset) / 2.5 + (0.3 if reel_pressed else 0.0), 0.0, 1.0)
	line_tension = lerpf(line_tension, desired_tension, 1.0 - exp(-3.0 * delta))
	if reel_pressed:
		if fishing_aim.distance_to(fish_offset) <= ZONE_RADIUS:
			progress += delta * 0.19
		else:
			progress -= delta * 0.10
	progress = clampf(progress, 0.0, 1.0)

func _water_position(offset: Vector2) -> Vector3:
	var point := fishing_center + fishing_right * offset.x + fishing_forward * offset.y
	point.y = _water_height(point.x, point.z) + 0.065
	return point

func _update_fishing_visuals() -> void:
	if state not in ["casting", "waiting", "bite", "reeling"]:
		rod.rotation = rod.rotation.lerp(Vector3.ZERO, 0.08)
		return
	if state == "reeling":
		holding_zone.position = _water_position(fishing_aim)
		fish_wake.position = _water_position(fish_offset)
		fish_wake.scale = Vector3.ONE * (1.0 + 0.12 * sin(fish_time * 4.0))
		var swim_direction := fishing_right * fish_velocity.x + fishing_forward * fish_velocity.y
		if swim_direction.length_squared() > 0.01:
			swimming_fish.rotation.y = atan2(-swim_direction.z, swim_direction.x)
		swimming_fish.get_node("Tail").rotation.y = 0.45 * sin(fish_time * 8.0)
		var in_zone := fishing_aim.distance_to(fish_offset) <= ZONE_RADIUS
		zone_material.albedo_color = Color(0.25, 0.95, 0.55, 0.38) if in_zone else Color(0.25, 0.7, 1.0, 0.24)
		zone_ring_material.albedo_color = Color(0.55, 1.0, 0.68) if in_zone else Color(0.54, 0.83, 1.0)
		bobber.position = fish_wake.position + Vector3(0, 0.14, 0)
	elif state == "bite":
		bobber.position.y = _water_height(bobber.position.x, bobber.position.z) + 0.13 + 0.08 * sin(bite_seconds * 18.0)
		bobber.rotation.z = 0.3 * sin(bite_seconds * 13.0)
	elif state == "waiting":
		bobber.position.y = _water_height(bobber.position.x, bobber.position.z) + 0.16
		bobber.rotation.z = 0.07 * sin(water_time * 2.0)
	var rod_target := Vector3(-fishing_aim.y * 0.06, -fishing_aim.x * 0.09, -fishing_aim.x * 0.05) if state == "reeling" else Vector3.ZERO
	if state == "reeling":
		rod_target.x += line_tension * 0.1 + sin(fish_time * 7.0) * line_tension * 0.015
	if state == "casting":
		rod_target.x = sin(cast_elapsed / CAST_DURATION * PI) * 0.45
	elif state == "bite":
		rod_target.x = 0.035 * sin(bite_seconds * 18.0)
	rod.rotation = rod.rotation.lerp(rod_target, 0.12)
	var line_start := rod_tip.global_position
	var line_end := bobber.global_position
	var previous := line_start
	var sag := lerpf(0.40, 0.06, line_tension) if state == "reeling" else 0.42
	for i in range(line_segments.size()):
		var t := float(i + 1) / float(line_segments.size())
		var point := line_start.lerp(line_end, t) - Vector3(0, sag * 4.0 * t * (1.0 - t), 0)
		var vector := point - previous
		var segment := line_segments[i]
		segment.global_position = (previous + point) * 0.5
		if vector.length_squared() > 0.0001:
			segment.look_at(point, Vector3.UP)
			segment.rotate_object_local(Vector3.RIGHT, PI / 2.0)
			segment.scale = Vector3(1, vector.length(), 1)
		previous = point

func _move_player(delta: float) -> void:
	var v := _movement_input()
	if v.length() > 1: v = v.normalized()
	var direction := _movement_direction(v)
	var speed := 5.0 if Input.is_key_pressed(KEY_SHIFT) else 3.0
	player_velocity = player_velocity.move_toward(direction * speed, 12.0 * delta)
	player.velocity = player_velocity
	player.move_and_slide()
	player_velocity = player.velocity
	if not vr_active:
		var walking_bob := sin(water_time * 8.0) * 0.025 * clampf(player_velocity.length() / 3.0, 0.0, 1.0)
		camera.position.y = lerpf(camera.position.y, 1.65 + walking_bob, 1.0 - exp(-8.0 * delta))
	player.position.x = clampf(player.position.x, -15.5, 15.5)
	player.position.z = clampf(player.position.z, 4.5, 23.5)

func _move_boat(delta: float) -> void:
	var v := _movement_input()
	_advance_boat(delta, v)

func _advance_boat(delta: float, v: Vector2) -> void:
	if v.length() > 1: v = v.normalized()
	var direction := _movement_direction(v)
	direction.y = 0.0
	# A boat carries momentum and eases to a stop after the player releases WASD.
	var acceleration := 1.8 if v.length_squared() > 0.0 else 1.0
	boat_velocity = boat_velocity.move_toward(direction * 3.0, acceleration * delta)
	var next_x := clampf(boat.position.x + boat_velocity.x * delta, -45.0, 45.0)
	if _boat_blocked(Vector2(next_x, boat.position.z)):
		boat_velocity.x = 0.0
	else:
		boat.position.x = next_x
	var next_z := clampf(boat.position.z + boat_velocity.z * delta, -45.0, 8.0)
	if _boat_blocked(Vector2(boat.position.x, next_z)):
		boat_velocity.z = 0.0
	else:
		boat.position.z = next_z
	if absf(boat.position.x) >= 45.0: boat_velocity.x = 0.0
	if boat.position.z <= -45.0 or boat.position.z >= 8.0: boat_velocity.z = 0.0
	if boat_velocity.length_squared() > 0.04:
		# The downloaded hull's bow is its +Z end, rather than Godot's -Z forward.
		var heading := atan2(boat_velocity.x, boat_velocity.z)
		boat_hull.rotation.y = lerp_angle(boat_hull.rotation.y, heading, 1.0 - exp(-2.0 * delta))

func _boat_blocked(pos: Vector2) -> bool:
	# Keep the hull out of the three shores while allowing routes around them.
	if pos.x >= -18.0 and pos.x <= 18.0 and pos.y >= -24.0 and pos.y <= -14.7:
		return true
	if absf(pos.x) >= 26.5 and absf(pos.x) <= 47.5 and pos.y >= -24.5 and pos.y <= -11.5:
		return true
	return false

func _update_boat_pose(delta: float) -> void:
	var height := _water_height(boat.position.x, boat.position.z) + 0.1
	boat_hull.position.y = lerpf(boat_hull.position.y, height, 1.0 - exp(-2.0 * delta))
	boat_hull.rotation.x = sin(water_time * 0.8 + boat.position.z * 0.13) * 0.018
	boat_hull.rotation.z = sin(water_time * 0.65 + boat.position.x * 0.1) * 0.025
	var stroke_strength := clampf(boat_velocity.length() / 2.5, 0.0, 1.0)
	for oar_name in ["LeftOar", "RightOar"]:
		var oar := boat_hull.get_node(oar_name) as Node3D
		oar.rotation.y = sin(water_time * 2.5) * 0.24 * stroke_strength
		oar.rotation.x = sin(water_time * 2.5 + PI / 2.0) * 0.12 * stroke_strength
	boat_wake.visible = boat_velocity.length() > 0.25
	boat_wake.position = boat.position
	boat_wake.position.y = _water_height(boat.position.x, boat.position.z) + 0.08
	boat_wake.scale = Vector3(1.0, 1.0, 1.0 + boat_velocity.length() * 0.3)
	if not riding:
		return
	player.position = boat.position - vr_boat_head_offset if vr_active else boat.position
	# Keep the camera level for comfort; only a small vertical bob follows the hull.
	player.position.y = 0.5 if vr_active else 0.5 + boat_hull.position.y

func _interact() -> void:
	if riding:
		if boat.position.distance_to(Vector3(0, 0, 7)) < 4.0:
			riding = false
			boat_blocker.collision_layer = 1
			boat_velocity = Vector3.ZERO
			player_velocity = Vector3.ZERO
			boat.position = Vector3(0, 0, 7)
			player.position = Vector3(0, 0, 10)
			if vr_active:
				var head_offset := camera.global_position - player.global_position
				player.position -= Vector3(head_offset.x, 0, head_offset.z)
			landed = true
			for entry in pending_fish:
				stored_fish.append(entry)
				if entry.get("type", "") == "boss":
					caught_bosses[str(entry.get("zone", 0))] = true
			caught_boss = caught_bosses.has("0")
			boss_in_box = false
			var delivered := pending_fish.size()
			pending_fish.clear()
			_refresh_collection()
			_show_message("Дома! Рыб в колбах: %d. Привезено за выход: %d." % [stored_fish.size(), delivered], 7)
			caught_other = 0
			_save_game()
		else:
			_show_message("Чтобы выйти, вернись к причалу у дома.", 4)
	elif player.position.z < 12.0 and absf(player.position.x - boat.position.x) < 3.0 and player.position.distance_to(boat.position) < 5.0:
		riding = true
		boat_blocker.collision_layer = 0
		boat_velocity = Vector3.ZERO
		player_velocity = Vector3.ZERO
		if vr_active:
			var head_offset := camera.global_position - player.global_position
			vr_boat_head_offset = Vector3(head_offset.x, 0, head_offset.z)
		player.position = boat.position - vr_boat_head_offset + Vector3(0, 0.5, 0) if vr_active else boat.position + Vector3(0, 0.5, 0)
		_show_message("Плыви к одному из трёх участков. Открой карту клавишей M.", 6)
	elif player.position.distance_to(Vector3(-2.5, 0, 21)) < 2.5:
		book_open = true
	elif player.position.distance_to(Vector3(2.8, 0, 21)) < 2.5:
		clock_minutes += 8 * 60
		energy = minf(100, energy + 8 * 15)
		_save_game()
		_show_message("Вы поспали 8 часов. Энергия восстановлена.", 5)
	else:
		_show_message("E: книга на столе, кровать или лодка у причала.", 4)

func _fishing_action() -> void:
	if state == "bite":
		state = "reeling"
		if not vr_active:
			camera.look_at(_water_position(Vector2.ZERO), Vector3.UP)
		progress = 0.0
		fish_time = 0.0
		fishing_aim = Vector2.ZERO
		aim_destination = Vector2.ZERO
		fish_offset = Vector2.ZERO
		fish_velocity = Vector2.ZERO
		line_tension = 0.0
		holding_zone.visible = true
		fish_wake.visible = true
		_show_message("", 0)
		return
	if state != "idle": return
	if not riding:
		_show_message("Для рыбалки сначала сядь в лодку у причала.", 4)
		return
	current_zone = _nearest_fishing_zone()
	if current_zone < 0:
		_show_message("Выбери место ловли на карте и подплыви ближе к берегу.", 4)
		return
	if energy < 8:
		_show_message("Мало энергии. Вернись домой и поспи.", 4)
		return
	# Fishing starts at anchor, so the boat cannot drift through the markers.
	boat_velocity = Vector3.ZERO
	energy -= 8
	attempts += 1
	var zone: Dictionary = ZONES[current_zone]
	if attempts % 2 == 1:
		current_fish = zone.friend
		current_type = "friend"
	else:
		var unavailable := caught_bosses.has(str(current_zone))
		for entry in pending_fish:
			if entry.get("type", "") == "boss" and int(entry.get("zone", -1)) == current_zone:
				unavailable = true
		current_fish = "Прудовая рыбка" if unavailable else zone.boss
		current_type = "other" if unavailable else "boss"
	state = "casting"
	wait_seconds = randf_range(3.0, 6.0)
	fishing_forward = -camera.global_basis.z if vr_active else -player.global_basis.z
	fishing_forward.y = 0
	fishing_forward = fishing_forward.normalized()
	fishing_right = Vector3(-fishing_forward.z, 0, fishing_forward.x)
	var cast_distance := clampf(5.0 + camera.rotation.x * 2.0, 3.5, 7.0)
	fishing_center = boat.position + fishing_forward * cast_distance
	# Keep the entire minigame on water even close to a shoreline.
	fishing_center.x = clampf(fishing_center.x, -47.0, 47.0)
	fishing_center.z = clampf(fishing_center.z, -12.6, 7.0)
	fishing_center.y = -0.06
	if not vr_active:
		camera.look_at(fishing_center, Vector3.UP)
	cast_elapsed = 0.0
	cast_start = rod_tip.global_position
	bobber.global_position = cast_start
	bobber.rotation = Vector3.ZERO
	bobber.visible = true
	_set_line_visible(true)
	_show_message("Заброс...", 1)

func _nearest_fishing_zone() -> int:
	var location := Vector2(boat.position.x, boat.position.z)
	for i in range(ZONES.size()):
		if location.distance_to(ZONES[i].center) <= 9.0:
			return i
	return -1

func _end_attempt(text: String) -> void:
	state = "idle"
	bobber.visible = false
	holding_zone.visible = false
	fish_wake.visible = false
	_set_line_visible(false)
	_show_message(text, 5)

func _choose_fish(release: bool) -> void:
	if current_type == "friend" and release:
		story_zones[str(current_zone)] = true
		known_story = story_zones.has("0")
		_show_message("Рыба рассказала часть истории Кузовка. Запись в книге.", 6)
	elif not release:
		pending_fish.append({"name": current_fish, "type": current_type, "zone": current_zone})
		if current_type == "boss": boss_in_box = true
		else: caught_other += 1
		_show_message("%s в ящике. Дома рыба попадёт в колбу." % current_fish, 6)
	else:
		_show_message("Рыба уплыла. Её можно будет встретить снова.", 5)
	state = "idle"
	_save_game()

func _update_ui() -> void:
	_layout_ui()
	var total_minutes := int(clock_minutes) % (24 * 60)
	hud.text = "%02d:%02d     Энергия  %d / 100\nИстория  %d / 6     Главари  %d / 6     Улов  %d" % [total_minutes / 60, total_minutes % 60, int(energy), story_zones.size(), caught_bosses.size(), pending_fish.size()]
	info.text = message
	info.visible = not message.is_empty() and state != "dialogue" and not book_open and not map_open
	info_background.visible = info.visible
	prompt.text = "WASD — движение   |   Мышь — обзор   |   E — действие   |   Tab — книга   |   M — карта"
	bar.visible = state == "reeling"
	progress_title.visible = bar.visible
	fish_display.visible = state == "dialogue"
	fish_model.visible = current_type != "boss"
	boss_model.visible = current_type == "boss"
	prompt.visible = state != "dialogue" and not map_open
	prompt_background.visible = prompt.visible
	hud.visible = not map_open
	hud_title.visible = not map_open
	hud_background.visible = not map_open
	overlay.visible = book_open or state == "dialogue"
	overlay_background.visible = overlay.visible
	map_background.visible = map_open
	map_title.visible = map_open
	map_legend.visible = map_open
	map_footer.visible = map_open
	map_image.visible = map_open
	map_marker.visible = map_open
	map_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if map_open else SubViewport.UPDATE_DISABLED
	if map_open:
		map_marker.queue_redraw()
	if book_open:
		overlay.text = "КНИГА РЫБАКА\n\nКузовок помогал рыбам находить путь домой.\nИсследуй камыши, старый причал и коряжник.\n\nЧастей истории: %d / 6     Главарей: %d / 6\nРыб в колбах дома: %d\n\nTab — закрыть книгу" % [story_zones.size(), caught_bosses.size(), stored_fish.size()]
	elif state == "dialogue":
		var speech := "Кузовок помогал рыбам. Отпусти меня — расскажу, что знаю."
		if current_type == "boss": speech = "Я охраняю этот участок пруда! Отпусти меня, рыбак!"
		if current_type == "other": speech = "Хороший сегодня день, чтобы поплавать."
		overlay.text = "%s\n\n«%s»\n\n1 — отпустить     2 — забрать в ящик" % [current_fish, speech]
	if state == "reeling":
		bar.value = progress * 100.0
	if riding and state == "idle":
		var zone_index := _nearest_fishing_zone()
		var location_name: String = ZONES[zone_index].name if zone_index >= 0 else "Озеро"
		prompt.text = "%s   •   WASD — плыть   |   F — ловить   |   M — карта   |   E — к дому" % location_name
	elif state == "bite":
		prompt.text = "ПОКЛЁВКА! Нажми F сейчас"
	elif state == "casting":
		prompt.text = "Заброс: леска летит к воде"
	elif state == "reeling":
		prompt.text = "Мышь — веди круг за рыбой на воде   |   Пробел — сматывать"
	if vr_active:
		map_legend.text = "ОРИЕНТИРЫ\n\n▲  Вы и направление взгляда\n\nКамышовая заводь — север\nСтарый причал — запад\nКоряжник — восток\nДом — у южного причала\n\nY — закрыть карту"
		prompt.text = "Левый стик — движение   |   X — действие   |   Y — карта   |   A — книга"
		if riding and state == "idle":
			prompt.text = "Левый стик — лодка   |   Правый курок — заброс   |   Y — карта   |   X — выйти"
		elif state == "bite":
			prompt.text = "ПОКЛЁВКА! Нажми правый курок"
		elif state == "reeling":
			prompt.text = "Правый стик — веди круг за рыбой   |   Держи курок — сматывать"
		if state == "dialogue":
			overlay.text = overlay.text.replace("1 — отпустить     2 — забрать в ящик", "A — отпустить     B — забрать в ящик")
		elif book_open:
			overlay.text = overlay.text.replace("Tab — закрыть книгу", "A — закрыть книгу")
		map_footer.text = "Y — закрыть карту"

func _show_message(text: String, duration: float) -> void:
	if vr_active:
		text = text.replace("Нажми F", "Нажми правый курок")
		text = text.replace("клавишей M", "кнопкой Y")
		text = text.replace("E: книга", "X: книга")
	message = text
	message_time = duration

func _save_game() -> void:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"clock": clock_minutes, "energy": energy, "story": known_story, "boss": caught_boss, "boss_in_box": boss_in_box, "other": caught_other, "attempts": attempts, "story_zones": story_zones, "caught_bosses": caught_bosses, "stored_fish": stored_fish, "pending_fish": pending_fish}))

func _load_game() -> void:
	if not FileAccess.file_exists(save_path): return
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null: return
	var data: Variant = JSON.parse_string(file.get_as_text())
	if not data is Dictionary: return
	clock_minutes = float(data.get("clock", clock_minutes))
	energy = float(data.get("energy", energy))
	known_story = bool(data.get("story", false))
	caught_boss = bool(data.get("boss", false))
	boss_in_box = bool(data.get("boss_in_box", false))
	caught_other = int(data.get("other", 0))
	attempts = int(data.get("attempts", 0))
	story_zones = data.get("story_zones", {}) if data.get("story_zones", {}) is Dictionary else {}
	caught_bosses = data.get("caught_bosses", {}) if data.get("caught_bosses", {}) is Dictionary else {}
	stored_fish = data.get("stored_fish", []) if data.get("stored_fish", []) is Array else []
	pending_fish = data.get("pending_fish", []) if data.get("pending_fish", []) is Array else []
	# Older saves recorded the first boss and the crate as flags, without fish entries.
	if not data.has("story_zones") and known_story: story_zones["0"] = true
	if not data.has("caught_bosses") and caught_boss:
		caught_bosses["0"] = true
		stored_fish.append({"name": "Ёрш Игла", "type": "boss", "zone": 0})
	if not data.has("pending_fish"):
		if boss_in_box: pending_fish.append({"name": "Ёрш Игла", "type": "boss", "zone": 0})
		for i in range(caught_other): pending_fish.append({"name": "Прудовая рыбка", "type": "other", "zone": 0})
