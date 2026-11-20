extends Node3D

# Shared session state and entry points for the gameplay systems.
var camera: Camera3D
var vr_active := false
var vr_simulator := false
var sim_grips := [false, false]
var sim_joy_id := -1
var sim_hand_offsets := [Vector3.ZERO, Vector3.ZERO]
var sim_hand_base := [Vector3.ZERO, Vector3.ZERO]
var sim_hand_grabbed := [false, false]
var xr_origin: XROrigin3D
var left_controller: XRController3D
var right_controller: XRController3D
var vr_hand_anchors: Array[CharacterBody3D] = []
var vr_ui_viewport: SubViewport
var vr_trigger_pressed := false
var vr_row_previous := [Vector3.ZERO, Vector3.ZERO]
var vr_row_tracking := [false, false]
var vr_row_strength := 0.0
var vr_oar_force := [0.0, 0.0]
var boat_yaw_velocity := 0.0
var vr_holding_oar := [false, false]
var vr_haptic_cooldown := [0.0, 0.0]
const VR_OAR_GRAB_RADIUS := 0.65
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
var vr_boat_last_yaw := 0.0
var oar_water_fx: Array[Node3D] = []
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
var persistence_enabled := false
const BOAT_MOORING := Vector3(0, 0, 1.8)

var _world_system
var _vr_system
var _boat_system
var _fishing_system
var _ui_system
var _save_system

func _ready() -> void:
	_world_system = preload("res://systems/world.gd").new(self)
	_vr_system = preload("res://systems/vr.gd").new(self)
	_boat_system = preload("res://systems/boat.gd").new(self)
	_fishing_system = preload("res://systems/fishing.gd").new(self)
	_ui_system = preload("res://systems/ui.gd").new(self)
	_save_system = preload("res://systems/save.gd").new(self)
	vr_simulator = "--simulate-vr" in OS.get_cmdline_user_args()
	if vr_simulator:
		vr_active = true
		save_path = "user://simulator_save.json"
	else:
		_init_vr()
	_build_world()
	if vr_active:
		_apply_vr_texture_filter(self)
	else:
		_setup_pixel_renderer()
	_build_ui()
	_load_game()
	_refresh_collection()
	if not vr_active or vr_simulator:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_show_message("Осмотрись в доме. X — действие, Y — карта." if vr_active else "Осмотрись в доме. Таб — книга, E — взаимодействие.", 8.0)

func _init_vr() -> void:
	_vr_system._init_vr()

func _build_world() -> void:
	_world_system._build_world()

func _make_controller(tracker_path: String) -> XRController3D:
	return _vr_system._make_controller(tracker_path)

func _on_vr_left_button(action: String) -> void:
	_vr_system._on_vr_left_button(action)

func _on_vr_right_button(action: String) -> void:
	_vr_system._on_vr_right_button(action)

func _update_vr_input(delta: float) -> void:
	_vr_system._update_vr_input(delta)

func _update_vr_trigger(value: float) -> void:
	_vr_system._update_vr_trigger(value)

func _row_hand_strength(index: int, local_position: Vector3, gripping: bool, delta: float) -> float:
	return _vr_system._row_hand_strength(index, local_position, gripping, delta)

func _update_vr_rowing(delta: float) -> void:
	_vr_system._update_vr_rowing(delta)

func _oar_water_force(hand_force: float, depth: float, gripping: bool) -> float:
	return _vr_system._oar_water_force(hand_force, depth, gripping)

func _update_oar_grab(index: int, hand_position: Vector3, pressed: bool, can_row: bool) -> bool:
	return _vr_system._update_oar_grab(index, hand_position, pressed, can_row)

func _update_simulated_hands(delta: float) -> void:
	_vr_system._update_simulated_hands(delta)

func _turn_vr(axis: float, delta: float) -> void:
	_vr_system._turn_vr(axis, delta)

func _movement_input() -> Vector2:
	return _vr_system._movement_input()

func _movement_direction(v: Vector2) -> Vector3:
	return _vr_system._movement_direction(v)

func _apply_vr_texture_filter(node: Node) -> void:
	_world_system._apply_vr_texture_filter(node)

func _setup_pixel_renderer() -> void:
	_world_system._setup_pixel_renderer()

func _refresh_collection() -> void:
	_world_system._refresh_collection()

func _animate_collection() -> void:
	_world_system._animate_collection()

func _water_height(x: float, z: float) -> float:
	return _world_system._water_height(x, z)

func _set_line_visible(value: bool) -> void:
	_world_system._set_line_visible(value)

func _build_ui() -> void:
	_ui_system._build_ui()

func _unhandled_input(event: InputEvent) -> void:
	_vr_system._unhandled_input(event)

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
		_advance_reeling(delta, ((Input.is_key_pressed(KEY_SPACE) or (sim_joy_id >= 0 and Input.is_joy_button_pressed(sim_joy_id, JOY_BUTTON_RIGHT_SHOULDER))) if vr_simulator else right_controller.get_float("trigger") > 0.55) if vr_active else Input.is_key_pressed(KEY_SPACE))
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
	_fishing_system._advance_reeling(delta, reel_pressed)

func _water_position(offset: Vector2) -> Vector3:
	return _fishing_system._water_position(offset)

func _update_fishing_visuals() -> void:
	_fishing_system._update_fishing_visuals()

func _move_player(delta: float) -> void:
	_boat_system._move_player(delta)

func _move_boat(delta: float) -> void:
	_boat_system._move_boat(delta)

func _advance_rowing_boat(delta: float, left_force: float, right_force: float) -> void:
	_boat_system._advance_rowing_boat(delta, left_force, right_force)

func _advance_boat(delta: float, v: Vector2) -> void:
	_boat_system._advance_boat(delta, v)

func _boat_blocked(pos: Vector2) -> bool:
	return _boat_system._boat_blocked(pos)

func _update_boat_pose(delta: float) -> void:
	_boat_system._update_boat_pose(delta)

func _interact() -> void:
	_boat_system._interact()

func _fishing_action() -> void:
	_fishing_system._fishing_action()

func _nearest_fishing_zone() -> int:
	return _fishing_system._nearest_fishing_zone()

func _end_attempt(text: String) -> void:
	_fishing_system._end_attempt(text)

func _choose_fish(release: bool) -> void:
	_fishing_system._choose_fish(release)

func _update_ui() -> void:
	_ui_system._update_ui()

func _show_message(text: String, duration: float) -> void:
	_ui_system._show_message(text, duration)

func _save_game() -> void:
	_save_system._save_game()

func _load_game() -> void:
	_save_system._load_game()
