extends RefCounted

const Art = preload("res://prototype_art.gd")
var game

func _init(owner):
	game = owner

func _build_world() -> void:
	var environment = WorldEnvironment.new()
	var env = Environment.new()
	game.scene_environment = env
	env.background_mode = Environment.BG_SKY
	var sky = Sky.new()
	game.scene_sky = sky
	game.day_sky_material = load("res://Materials/EA_Sky_Meadow.tres") as Material
	var stars = ShaderMaterial.new()
	stars.shader = load("res://SkyStar.gdshader")
	game.night_sky_material = stars
	sky.sky_material = game.day_sky_material
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78, 0.86, 0.89)
	env.ambient_light_energy = 0.8
	environment.environment = env
	game.add_child(environment)
	game.sunlight = DirectionalLight3D.new()
	game.sunlight.rotation_degrees = Vector3(-55, -35, 0)
	game.sunlight.light_energy = 1.2
	game.sunlight.shadow_enabled = true
	game.add_child(game.sunlight)
	game.home_light = OmniLight3D.new()
	game.home_light.position = Vector3(0, 2.7, 18.8)
	game.home_light.light_color = Color(1.0, 0.66, 0.36)
	game.home_light.omni_range = 10.0
	game.add_child(game.home_light)
	_create_water()
	_box(game, Vector3(0, -0.05, 17), Vector3(32, 0.5, 14), Color(0.34, 0.46, 0.26))
	_box(game, Vector3(0, 0.14, 9), Vector3(3.0, 0.3, 10), Color(0.52, 0.33, 0.19))
	_box(game, Vector3(0, 0.15, 20), Vector3(9, 0.3, 7), Color(0.52, 0.33, 0.20))
	_box(game, Vector3(-4.4, 1.7, 20), Vector3(0.3, 3.4, 7), Color(0.68, 0.53, 0.36))
	_box(game, Vector3(4.4, 1.7, 20), Vector3(0.3, 3.4, 7), Color(0.68, 0.53, 0.36))
	_box(game, Vector3(0, 1.7, 23.4), Vector3(9, 3.4, 0.3), Color(0.68, 0.53, 0.36))
	_box(game, Vector3(-3.1, 1.7, 16.55), Vector3(2.7, 3.4, 0.28), Color(0.61, 0.46, 0.30))
	_box(game, Vector3(3.1, 1.7, 16.55), Vector3(2.7, 3.4, 0.28), Color(0.61, 0.46, 0.30))
	_box(game, Vector3(0, 3.1, 16.55), Vector3(3.5, 0.6, 0.28), Color(0.61, 0.46, 0.30))
	for side in [-1.0, 1.0]:
		var roof = _box(game, Vector3(side * 2.25, 4.1, 20), Vector3(5.0, 0.20, 7.8), Color(0.27, 0.18, 0.12))
		roof.rotation.z = -side * 0.28
		_box(game, Vector3(side * 1.8, 1.9, 23.20), Vector3(1.3, 1.25, 0.12), Color(0.40, 0.56, 0.54))
		_box(game, Vector3(side * 1.8, 1.9, 23.10), Vector3(0.08, 1.35, 0.10), Color(0.33, 0.23, 0.14))
		_box(game, Vector3(side * 1.8, 1.9, 23.10), Vector3(1.4, 0.08, 0.10), Color(0.33, 0.23, 0.14))
	Art.cabin_gable(game, 23.4)
	Art.cabin_gable(game, 16.55)
	for i in range(14):
		_box(game, Vector3(0, 0.35 + i * 0.21, 23.22), Vector3(8.7, 0.025, 0.05), Color(0.45, 0.32, 0.22))
	Art.decorate_land(game)
	# Book and clock stand on separate furniture, close enough to interact.
	_box(game, Vector3(-2.5, 0.5, 21), Vector3(2, 0.9, 1.0), Color(0.37, 0.23, 0.14))
	_box(game, Vector3(-2.5, 1.0, 21), Vector3(0.7, 0.12, 0.5), Color(0.84, 0.77, 0.57))
	_box(game, Vector3(2.8, 0.4, 21), Vector3(2.0, 0.7, 1.1), Color(0.8, 0.76, 0.64))
	_box(game, Vector3(0, 2.1, 23.15), Vector3(3.5, 0.9, 0.1), Color(0.26, 0.20, 0.13))
	# Match the visible walls, doorway, and furniture with solid shapes.
	_add_solid_box(game, Vector3(-4.4, 1.7, 20), Vector3(0.3, 3.4, 7))
	_add_solid_box(game, Vector3(4.4, 1.7, 20), Vector3(0.3, 3.4, 7))
	_add_solid_box(game, Vector3(0, 1.7, 23.4), Vector3(9, 3.4, 0.3))
	_add_solid_box(game, Vector3(-3.1, 1.7, 16.55), Vector3(2.7, 3.4, 0.28))
	_add_solid_box(game, Vector3(3.1, 1.7, 16.55), Vector3(2.7, 3.4, 0.28))
	_add_solid_box(game, Vector3(-2.5, 0.5, 21), Vector3(2, 0.9, 1.0))
	_add_solid_box(game, Vector3(2.8, 0.4, 21), Vector3(2, 0.7, 1.1))
	# Water either side of the narrow pier is outside the walking area.
	_add_solid_box(game, Vector3(-8.75, 0.9, 7), Vector3(14.5, 2, 6))
	_add_solid_box(game, Vector3(8.75, 0.9, 7), Vector3(14.5, 2, 6))
	game.trophy = Node3D.new()
	game.trophy.position = Vector3(0, 2.1, 23.0)
	game.add_child(game.trophy)
	_box(game.trophy, Vector3.ZERO, Vector3(0.65, 0.32, 0.18), Color(0.62, 0.69, 0.35))
	_box(game.trophy, Vector3(-0.42, 0, 0), Vector3(0.25, 0.4, 0.1), Color(0.45, 0.53, 0.25))
	game.trophy.visible = false
	# Reeds mark the first fishing spot. Their silhouettes are visible from the dock.
	Art.make_bank(game)
	_build_extra_areas()
	for beacon_pos in [Vector3(0, 0.25, -15), Vector3(-33, 0.25, -13), Vector3(33, 0.25, -13)]:
		_build_beacon(beacon_pos)
	for i in range(15):
		var x = float(i - 7) * 1.3
		var reed = Node3D.new()
		reed.position = Vector3(x, 0, -16.7 + float(i % 3) * 0.35)
		reed.name = "Reed%d" % i
		game.add_child(reed)
		Art.cylinder(reed, 0.045, 0.025, 2.2, Vector3(0, 1.1, 0), Color(0.35, 0.43, 0.18))
		Art.ellipsoid(reed, Vector3(0.105, 0.34, 0.105), Vector3(0, 2.0, 0), Color(0.27, 0.18, 0.10))
		game.reeds.append(reed)
	game.boat = Node3D.new()
	game.boat.position = game.BOAT_MOORING
	game.add_child(game.boat)
	game.boat_hull = Node3D.new()
	game.boat.add_child(game.boat_hull)
	var boat_asset = (load("res://GLB/Wood_BoatV2.glb") as PackedScene).instantiate() as Node3D
	boat_asset.name = "DownloadedBoat"
	boat_asset.scale = Vector3.ONE * 0.9
	# This model's origin sits above the keel, unlike the previous boat.
	boat_asset.position.y = 0.03
	game.boat_hull.add_child(boat_asset)
	for side in [-1.0, 1.0]:
		var pivot = Node3D.new()
		pivot.name = "LeftOar" if side < 0 else "RightOar"
		pivot.position = Vector3(side * 0.98, 0.65, 0.2)
		pivot.rotation.z = side * 0.85
		game.boat_hull.add_child(pivot)
		var paddle = (load("res://GLB/Paddle.glb") as PackedScene).instantiate() as Node3D
		paddle.scale = Vector3.ONE * 0.70
		# The broad blade is the positive end of the imported paddle's Z axis.
		paddle.rotation.x = PI / 2.0
		# Shift the shaft through the oarlock: handle inside, blade outside.
		paddle.position.y = 0.05
		pivot.add_child(paddle)
		var grip_point = Marker3D.new()
		grip_point.name = "GripPoint"
		grip_point.position.y = 0.70
		pivot.add_child(grip_point)
		var water_fx = Node3D.new()
		water_fx.name = "OarWaterEffect"
		game.add_child(water_fx)
		_add_ring(water_fx, 0.22, 0.025, Color(0.68, 0.9, 0.87))
		water_fx.visible = false
		game.oar_water_fx.append(water_fx)
	game.boat_blocker = _add_solid_box(game.boat, Vector3(0, 0.45, -0.12), Vector3(1.5, 0.9, 4.0))
	game.boat_wake = Node3D.new()
	game.add_child(game.boat_wake)
	_add_ring(game.boat_wake, 1.15, 0.035, Color(0.52, 0.73, 0.70))
	_add_ring(game.boat_wake, 1.48, 0.025, Color(0.42, 0.64, 0.63))
	game.boat_wake.visible = false
	game.player = CharacterBody3D.new()
	game.player.position = Vector3(0, 0, 20)
	game.add_child(game.player)
	var player_shape = CollisionShape3D.new()
	var capsule = CapsuleShape3D.new()
	capsule.radius = 0.28
	capsule.height = 1.45
	player_shape.shape = capsule
	player_shape.position.y = 1.025
	game.player.add_child(player_shape)
	if game.vr_active:
		game.xr_origin = XROrigin3D.new()
		game.player.add_child(game.xr_origin)
		game.camera = XRCamera3D.new()
		game.xr_origin.add_child(game.camera)
		if game.vr_simulator:
			game.camera.position.y = 1.65
		game.left_controller = game._make_controller("left_hand")
		game.right_controller = game._make_controller("right_hand")
		game.left_controller.button_pressed.connect(game._on_vr_left_button)
		game.right_controller.button_pressed.connect(game._on_vr_right_button)
	else:
		game.camera = Camera3D.new()
		game.camera.position.y = 1.65
		game.player.add_child(game.camera)
	game.camera.current = true
	# A simple rod stays visible at the bottom right of the view.
	game.rod = Node3D.new()
	if game.vr_active:
		game.rod.position = Vector3(0, -0.04, -0.10)
		game.right_controller.add_child(game.rod)
	else:
		game.rod.position = Vector3(0.38, -0.32, -1.15)
		game.camera.add_child(game.rod)
	var rod_asset = (load("res://GLB/Fishing_Rod.glb") as PackedScene).instantiate() as Node3D
	rod_asset.scale = Vector3.ONE * 0.7
	if game.vr_active:
		# Match the same orientation as the boat oars and keep the handle at the grip.
		rod_asset.rotation.x = PI / 2.0
		rod_asset.position.y = -0.70
	else:
		# The asset's handle is on -Z; keep it near the player in desktop view.
		rod_asset.rotation.y = PI
	game.rod.add_child(rod_asset)
	game.rod_tip = Node3D.new()
	game.rod_tip.position = Vector3(0, -1.72, 0) if game.vr_active else Vector3(0, 0, -1.02)
	game.rod.add_child(game.rod_tip)
	game.fish_display = Node3D.new()
	game.fish_display.position = Vector3(0, -0.05, -2.0)
	game.camera.add_child(game.fish_display)
	game.fish_model = _make_downloaded_fish(game.fish_display)
	game.boss_model = Art.make_fish(game.fish_display, Color(0.42, 0.43, 0.26), true)
	game.boss_model.visible = false
	game.fish_display.visible = false
	game.bobber = Node3D.new()
	game.add_child(game.bobber)
	Art.ellipsoid(game.bobber, Vector3(0.11, 0.15, 0.11), Vector3.ZERO, Color(0.8, 0.78, 0.66))
	Art.ellipsoid(game.bobber, Vector3(0.105, 0.07, 0.105), Vector3(0, 0.10, 0), Color(0.78, 0.12, 0.08))
	Art.cylinder(game.bobber, 0.014, 0.014, 0.25, Vector3(0, 0.25, 0), Color(0.16, 0.12, 0.08))
	game.bobber.visible = false
	_create_fishing_visuals()
	_build_campfire()
	game.collection_root = Node3D.new()
	game.collection_root.name = "FishCollection"
	game.add_child(game.collection_root)

func _make_downloaded_fish(parent: Node3D) -> Node3D:
	var fish = Node3D.new()
	fish.name = "Fish1"
	parent.add_child(fish)
	var model = (load("res://GLB/fish1.glb") as PackedScene).instantiate() as Node3D
	model.scale = Vector3.ONE * 0.35
	model.rotation.y = PI
	fish.add_child(model)
	# Keep the existing animation interface; this model has no separate tail.
	var tail = Node3D.new()
	tail.name = "Tail"
	fish.add_child(tail)
	return fish

func _apply_vr_texture_filter(node: Node) -> void:
	# Keep texture edges sharp without sampling the XR screen buffer.
	if node is MeshInstance3D:
		var mesh_node = node as MeshInstance3D
		if mesh_node.mesh:
			for surface in range(mesh_node.mesh.get_surface_count()):
				var material = mesh_node.get_active_material(surface) as BaseMaterial3D
				if material and material.albedo_texture:
					material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	for child in node.get_children():
		_apply_vr_texture_filter(child)

func _setup_pixel_renderer() -> void:
	# Keep the existing world and input in the main viewport; the addon renders
	# the same 3D world through its own low-resolution camera. UI stays legible.
	var layer = CanvasLayer.new()
	layer.layer = 1
	game.add_child(layer)
	game.pixel_renderer = load("res://addons/pixel_art_renderer/scripts/pixel_art_renderer.gd").new()
	game.pixel_renderer.name = "PixelArtRenderer"
	layer.add_child(game.pixel_renderer)
	game.pixel_renderer.set_anchors_preset(Control.PRESET_TOP_LEFT)
	game.pixel_renderer.position = Vector2.ZERO
	game.pixel_renderer.size = game.get_viewport().get_visible_rect().size
	game.pixel_renderer.virtual_width = 480
	game.pixel_renderer.virtual_height = 270
	game.pixel_renderer.target_fps = 60.0
	game.pixel_renderer.color_levels = 18.0
	game.pixel_renderer.dither_mode = 0
	game.pixel_renderer.outline_enabled = false
	var pixel_viewport = game.pixel_renderer.get_node("PixelSubViewport") as SubViewport
	pixel_viewport.world_3d = game.get_viewport().world_3d
	game.pixel_camera = Camera3D.new()
	pixel_viewport.add_child(game.pixel_camera)
	game.pixel_camera.current = true
	game.pixel_camera.global_transform = game.camera.global_transform
	game.pixel_camera.fov = game.camera.fov

func _build_extra_areas() -> void:
	for side in [-1.0, 1.0]:
		var x: float = side * 37.0
		_box(game, Vector3(x, -0.05, -18), Vector3(17, 0.5, 9), Color(0.28, 0.38, 0.22))
		for i in range(4):
			var tree_pos = Vector3(x - 6.0 + i * 4.0, 0.2, -20.0 + float(i % 2) * 1.3)
			var model = "Trees/EM_Tree1a_PRE" if i % 2 == 0 else "Trees/EM_Tree3a_PRE"
			Art.nature_asset(game, model, tree_pos, 0.55 + 0.05 * i, i * 1.4)
		for i in range(4):
			Art.nature_asset(game, "Rock/EA_Env_Rock_01b_PRE", Vector3(x - 6 + i * 4, 0.2, -14.4), 0.5, i)
		if side < 0:
			# A broken jetty is the landmark for the second fishing spot.
			_box(game, Vector3(x, 0.36, -13.8), Vector3(2.5, 0.24, 4.5), Color(0.40, 0.26, 0.15))
			for i in range(3):
				Art.cylinder(game, 0.13, 0.12, 1.7, Vector3(x + (i - 1) * 1.1, 0.5, -11.6), Color(0.32, 0.24, 0.17))
		else:
			# A fallen trunk distinguishes the third spot from the reed bed.
			var trunk = Art.cylinder(game, 0.40, 0.22, 6.5, Vector3(x, 0.45, -15.2), Color(0.29, 0.22, 0.13))
			trunk.rotation.z = PI / 2.0

func _build_campfire() -> void:
	var camp_scene = load("res://addons/pyrolux_fx/presets/3d/fire_campfire.tscn") as PackedScene
	game.campfire = camp_scene.instantiate() as Node3D
	game.campfire.position = Vector3(-3.8, 0.25, 13.2)
	game.campfire.scale = Vector3.ONE * 0.55
	game.add_child(game.campfire)
	for i in range(6):
		var angle = float(i) * TAU / 6.0
		var stone = Art.ellipsoid(game, Vector3(0.22, 0.13, 0.18), game.campfire.position + Vector3(cos(angle) * 0.5, 0, sin(angle) * 0.5), Color(0.32, 0.33, 0.28))
		stone.rotation.y = angle

func _build_beacon(pos: Vector3) -> void:
	Art.cylinder(game, 0.08, 0.06, 1.6, pos + Vector3(0, 0.8, 0), Color(0.31, 0.23, 0.14))
	var bulb = Art.ellipsoid(game, Vector3(0.16, 0.20, 0.16), pos + Vector3(0, 1.65, 0), Color(0.95, 0.65, 0.28))
	var glow = StandardMaterial3D.new()
	glow.albedo_color = Color(1.0, 0.75, 0.38)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.54, 0.16)
	glow.emission_energy_multiplier = 1.5
	bulb.material_override = glow
	var light = OmniLight3D.new()
	light.position = pos + Vector3(0, 1.65, 0)
	light.light_color = Color(1.0, 0.65, 0.32)
	light.omni_range = 7.0
	game.add_child(light)
	game.beacon_lights.append(light)

func _refresh_collection() -> void:
	for child in game.collection_root.get_children():
		game.collection_root.remove_child(child)
		child.queue_free()
	var grouped = {}
	for entry in game.stored_fish:
		if entry is Dictionary:
			var fish_name = str(entry.get("name", "Рыба"))
			if not grouped.has(fish_name): grouped[fish_name] = []
			grouped[fish_name].append(entry)
	var index = 0
	for fish_name in grouped:
		var tank = Node3D.new()
		tank.name = "Tank%d" % index
		tank.position = Vector3(-3.6 + float(index % 7) * 1.2, 0.30, 22.25 - float(index / 7) * 1.2)
		game.collection_root.add_child(tank)
		_add_solid_box(tank, Vector3(0, 0.9, 0), Vector3(0.82, 1.7, 0.82))
		# Wooden aquarium with brass bands matches the rest of the cabin.
		var wood = Color(0.34, 0.21, 0.12)
		var brass = Color(0.62, 0.48, 0.25)
		Art.cylinder(tank, 0.43, 0.43, 0.18, Vector3(0, 0.20, 0), wood)
		Art.cylinder(tank, 0.43, 0.43, 0.12, Vector3(0, 1.59, 0), wood)
		Art.cylinder(tank, 0.44, 0.44, 0.035, Vector3(0, 0.30, 0), brass)
		Art.cylinder(tank, 0.44, 0.44, 0.035, Vector3(0, 1.52, 0), brass)
		var glass = MeshInstance3D.new()
		var glass_mesh = CylinderMesh.new()
		glass_mesh.top_radius = 0.36
		glass_mesh.bottom_radius = 0.36
		glass_mesh.height = 1.25
		glass.mesh = glass_mesh
		glass.position.y = 0.95
		var glass_material = StandardMaterial3D.new()
		glass_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glass_material.albedo_color = Color(0.30, 0.78, 0.66, 0.10)
		glass_material.roughness = 0.18
		glass_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		glass.material_override = glass_material
		glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		tank.add_child(glass)
		var lamp = OmniLight3D.new()
		lamp.position.y = 1.4
		lamp.light_color = Color(0.32, 0.8, 0.65)
		lamp.light_energy = 0.35
		lamp.omni_range = 2.0
		tank.add_child(lamp)
		var fish_index = 0
		for entry in grouped[fish_name]:
			var color = Color(0.51, 0.57, 0.34) if entry.get("type", "") != "boss" else Color(0.42, 0.43, 0.26)
			var fish = Art.make_fish(tank, color, entry.get("type", "") == "boss")
			fish.scale = Vector3.ONE * 0.38
			fish.set_meta("swim_index", fish_index)
			fish.add_to_group("tank_fish")
			fish_index += 1
		index += 1

func _animate_collection() -> void:
	for fish in game.get_tree().get_nodes_in_group("tank_fish"):
		var index = int(fish.get_meta("swim_index"))
		var phase = game.water_time * 0.7 + float(index) * 2.1
		fish.position = Vector3(cos(phase) * 0.12, 0.62 + fmod(float(index) * 0.22, 0.65) + 0.06 * sin(phase * 1.7), sin(phase) * 0.12)
		fish.rotation.y = -phase
		fish.get_node("Tail").rotation.y = sin(phase * 5.0) * 0.4

func _create_water() -> void:
	var water = MeshInstance3D.new()
	var plane = PlaneMesh.new()
	plane.size = Vector2(100, 100)
	plane.subdivide_width = 200
	plane.subdivide_depth = 200
	water.mesh = plane
	water.position.y = -0.1
	game.water_material = ShaderMaterial.new()
	game.water_material.shader = load("res://water.gdshader")
	water.material_override = game.water_material
	game.add_child(water)

func _water_height(x: float, z: float) -> float:
	return -0.1 + 0.035 * sin(x * 0.65 + z * 0.35 + game.water_time * 0.9) + 0.022 * sin(-x * 0.35 + z * 0.75 + game.water_time * 0.65)

func _create_fishing_visuals() -> void:
	# The marker and wake live in world space, just above the pond surface.
	game.holding_zone = Node3D.new()
	game.add_child(game.holding_zone)
	var disc = MeshInstance3D.new()
	var disc_mesh = CylinderMesh.new()
	disc_mesh.top_radius = game.ZONE_RADIUS
	disc_mesh.bottom_radius = game.ZONE_RADIUS
	disc_mesh.height = 0.015
	disc.mesh = disc_mesh
	game.zone_material = StandardMaterial3D.new()
	game.zone_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	game.zone_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	game.zone_material.albedo_color = Color(0.22, 0.9, 0.59, 0.28)
	disc.material_override = game.zone_material
	game.holding_zone.add_child(disc)
	game.zone_ring_material = _add_ring(game.holding_zone, game.ZONE_RADIUS, 0.055, Color(0.55, 1.0, 0.68))
	game.holding_zone.visible = false
	game.fish_wake = Node3D.new()
	game.add_child(game.fish_wake)
	_add_ring(game.fish_wake, 0.34, 0.045, Color(0.94, 0.95, 0.78))
	_add_ring(game.fish_wake, 0.57, 0.025, Color(0.66, 0.88, 0.87))
	var marker = MeshInstance3D.new()
	var marker_mesh = SphereMesh.new()
	marker_mesh.radius = 0.17
	marker_mesh.height = 0.22
	marker.mesh = marker_mesh
	var marker_material = StandardMaterial3D.new()
	marker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker_material.albedo_color = Color(1.0, 0.79, 0.28)
	marker.material_override = marker_material
	marker.position.y = 0.06
	game.fish_wake.add_child(marker)
	game.swimming_fish = Art.make_fish(game.fish_wake, Color(0.50, 0.56, 0.32))
	game.swimming_fish.scale = Vector3.ONE * 0.55
	game.swimming_fish.position = Vector3(-0.32, 0.04, 0)
	game.fish_wake.visible = false
	var line_mesh = CylinderMesh.new()
	line_mesh.top_radius = 0.006
	line_mesh.bottom_radius = 0.006
	line_mesh.height = 1.0
	line_mesh.radial_segments = 6
	var line_material = StandardMaterial3D.new()
	line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_material.albedo_color = Color(0.94, 0.91, 0.72)
	for i in range(12):
		var segment = MeshInstance3D.new()
		segment.mesh = line_mesh
		segment.material_override = line_material
		segment.visible = false
		game.add_child(segment)
		game.line_segments.append(segment)
	game.fishing_line = game.line_segments[0]

func _set_line_visible(value: bool) -> void:
	for segment in game.line_segments:
		segment.visible = value

func _add_ring(parent: Node3D, radius: float, thickness: float, color: Color) -> StandardMaterial3D:
	var instance = MeshInstance3D.new()
	var ring = TorusMesh.new()
	ring.inner_radius = radius - thickness
	ring.outer_radius = radius
	instance.mesh = ring
	var material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	instance.material_override = material
	instance.position.y = 0.025
	parent.add_child(instance)
	return material

func _box(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh_instance = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	mesh_instance.material_override = material
	mesh_instance.position = pos
	parent.add_child(mesh_instance)
	return mesh_instance

func _add_solid_box(parent: Node3D, pos: Vector3, size: Vector3) -> StaticBody3D:
	var body = StaticBody3D.new()
	body.position = pos
	var collider = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	parent.add_child(body)
	return body
