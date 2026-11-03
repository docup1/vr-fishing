extends RefCounted

# Procedural geometry keeps the prototype self-contained and easy to replace.
static func material(color: Color, roughness: float = 0.8) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	return m

static func box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = material(color)
	node.position = pos
	parent.add_child(node)
	return node

static func ellipsoid(parent: Node3D, radii: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 24
	mesh.rings = 12
	node.mesh = mesh
	node.scale = radii * 2.0
	node.position = pos
	node.material_override = material(color, 0.5)
	parent.add_child(node)
	return node

static func cylinder(parent: Node3D, radius_bottom: float, radius_top: float, height: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius_bottom
	mesh.top_radius = radius_top
	mesh.height = height
	mesh.radial_segments = 12
	node.mesh = mesh
	node.position = pos
	node.material_override = material(color)
	parent.add_child(node)
	return node

static func cabin_gable(parent: Node3D, z: float) -> void:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-4.4, 3.35, z), Vector3(4.4, 3.35, z), Vector3(0, 4.77, z)])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.FORWARD, Vector3.FORWARD, Vector3.FORWARD])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var node := MeshInstance3D.new()
	node.mesh = mesh
	var wood := material(Color(0.60, 0.46, 0.31))
	wood.cull_mode = BaseMaterial3D.CULL_DISABLED
	node.material_override = wood
	parent.add_child(node)

static func make_boat(parent: Node3D) -> void:
	# Two elliptical strips form the outside and inside of a small wooden hull.
	var count := 32
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for band in range(3):
		for i in range(count + 1):
			var angle := TAU * float(i) / float(count)
			var width := 0.95 if band != 2 else 0.65
			var length := 1.95 if band != 2 else 1.57
			var y := 0.68 if band == 0 else (0.13 if band == 1 else 0.19)
			var z := cos(angle) * length
			# Raised ends give the hull a recognisable bow and stern.
			y += 0.20 * pow(absf(cos(angle)), 4.0)
			vertices.append(Vector3(sin(angle) * width, y, z))
			normals.append(Vector3(sin(angle), 0.35 if band != 1 else -0.3, cos(angle)).normalized())
	for band in range(2):
		for i in range(count):
			var a := band * (count + 1) + i
			var b := a + count + 1
			indices.append_array(PackedInt32Array([a, b, a + 1, a + 1, b, b + 1]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var hull := MeshInstance3D.new()
	hull.mesh = mesh
	var hull_material := material(Color(0.31, 0.19, 0.11))
	hull_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	hull.material_override = hull_material
	parent.add_child(hull)
	# Close the bottom so the pond cannot be seen through the cockpit.
	var floor_vertices := PackedVector3Array([Vector3(0, 0.23, 0)])
	var floor_normals := PackedVector3Array([Vector3.UP])
	var floor_indices := PackedInt32Array()
	for i in range(count + 1):
		var angle := TAU * float(i) / float(count)
		floor_vertices.append(Vector3(sin(angle) * 0.65, 0.23 + 0.20 * pow(absf(cos(angle)), 4.0), cos(angle) * 1.57))
		floor_normals.append(Vector3.UP)
		if i > 0:
			floor_indices.append_array(PackedInt32Array([0, i, i + 1]))
	var floor_arrays := []
	floor_arrays.resize(Mesh.ARRAY_MAX)
	floor_arrays[Mesh.ARRAY_VERTEX] = floor_vertices
	floor_arrays[Mesh.ARRAY_NORMAL] = floor_normals
	floor_arrays[Mesh.ARRAY_INDEX] = floor_indices
	var floor_mesh := ArrayMesh.new()
	floor_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, floor_arrays)
	var floor_node := MeshInstance3D.new()
	floor_node.mesh = floor_mesh
	floor_node.material_override = hull_material
	parent.add_child(floor_node)
	for plank in range(5):
		box(parent, Vector3(0.24, 0.08, 2.6), Vector3((plank - 2) * 0.25, 0.24, 0), Color(0.43 + plank * 0.012, 0.27, 0.15))
	for z in [-0.85, 0.75]:
		box(parent, Vector3(1.45, 0.12, 0.35), Vector3(0, 0.49, z), Color(0.48, 0.31, 0.18))
	for side in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.name = "LeftOar" if side < 0 else "RightOar"
		pivot.position = Vector3(side * 0.85, 0.67, 0.35)
		parent.add_child(pivot)
		var oar := cylinder(pivot, 0.035, 0.035, 2.5, Vector3(side * 0.22, -0.12, 0), Color(0.55, 0.37, 0.21))
		oar.rotation.z = -side * 1.15
		var blade := box(pivot, Vector3(0.18, 0.04, 0.44), Vector3(side * 1.30, -0.56, 0), Color(0.45, 0.28, 0.15))
		blade.rotation.y = side * 0.25

static func make_fish(parent: Node3D, color: Color, spiky: bool = false) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	ellipsoid(root, Vector3(0.44, 0.25, 0.18), Vector3.ZERO, color)
	ellipsoid(root, Vector3(0.33, 0.11, 0.16), Vector3(0, -0.12, 0), color.lightened(0.25))
	for side in [-1.0, 1.0]:
		ellipsoid(root, Vector3(0.055, 0.055, 0.028), Vector3(0.26, 0.06, side * 0.16), Color(0.81, 0.71, 0.48))
		ellipsoid(root, Vector3(0.027, 0.03, 0.014), Vector3(0.27, 0.06, side * 0.184), Color(0.025, 0.025, 0.02))
	var tail := Node3D.new()
	tail.name = "Tail"
	tail.position.x = -0.4
	root.add_child(tail)
	var fin_vertices := PackedVector3Array([Vector3(0, 0, 0), Vector3(-0.34, 0.24, 0), Vector3(-0.24, 0, 0), Vector3(-0.34, -0.24, 0)])
	var fin_arrays := []
	fin_arrays.resize(Mesh.ARRAY_MAX)
	fin_arrays[Mesh.ARRAY_VERTEX] = fin_vertices
	fin_arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK])
	fin_arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var fin_mesh := ArrayMesh.new()
	fin_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, fin_arrays)
	var fin := MeshInstance3D.new()
	fin.mesh = fin_mesh
	var fin_material := material(color.darkened(0.18))
	fin_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	fin.material_override = fin_material
	tail.add_child(fin)
	var dorsal := ellipsoid(root, Vector3(0.22, 0.12, 0.03), Vector3(-0.05, 0.22, 0), color.darkened(0.15))
	dorsal.rotation.z = 0.2
	if spiky:
		for i in range(5):
			var spine := cylinder(root, 0.024, 0.002, 0.18, Vector3(-0.2 + i * 0.085, 0.31, 0), color.darkened(0.28))
			spine.rotation.z = -0.35
	return root

static func make_bank(parent: Node3D) -> void:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var columns := 36
	for row in range(3):
		for i in range(columns + 1):
			var x := -16.0 + 32.0 * float(i) / float(columns)
			var variation := sin(x * 0.7) * 0.35 + sin(x * 1.3) * 0.12
			var z := -22.0 if row == 0 else (-18.3 + variation if row == 1 else -16.7 + variation)
			var y := 0.32 if row == 0 else (0.38 + 0.09 * sin(x) if row == 1 else -0.08)
			vertices.append(Vector3(x, y, z))
			normals.append(Vector3(0, 1, 0.20 if row == 2 else 0).normalized())
			colors.append(Color(0.33, 0.40, 0.25) if row == 0 else (Color(0.38, 0.46, 0.27) if row == 1 else Color(0.32, 0.30, 0.22)))
	for row in range(2):
		for i in range(columns):
			var a := row * (columns + 1) + i
			var b := a + columns + 1
			indices.append_array(PackedInt32Array([a, a + 1, b, a + 1, b + 1, b]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var node := MeshInstance3D.new()
	node.mesh = mesh
	var m := material(Color.WHITE)
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	node.material_override = m
	parent.add_child(node)

static func nature_asset(parent: Node3D, name: String, position: Vector3, size: float, rotation_y: float) -> Node3D:
	var scene := load("res://Prefabs/%s.prefab.scn" % name) as PackedScene
	if scene == null:
		push_error("Не удалось загрузить модель природы: " + name)
		return null
	var model := scene.instantiate() as Node3D
	model.position = position
	model.scale = Vector3.ONE * size
	model.rotation.y = rotation_y
	parent.add_child(model)
	model.add_to_group("nature_assets")
	return model

static func solid_cylinder(parent: Node3D, position: Vector3, radius: float, height: float) -> void:
	var body := StaticBody3D.new()
	body.position = position + Vector3(0, height * 0.5, 0)
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)

static func decorate_land(parent: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 73829
	# NatureForge prefab scenes use their supplied shared atlas material.
	var tree_models := ["Trees/EM_Tree1a_PRE", "Trees/EM_Tree2a_PRE", "Trees/EM_Tree3a_PRE"]
	var rock_models := ["Rock/EA_Env_Rock_01a_PRE", "Rock/EA_Env_Rock_01b_PRE", "Rock/EA_Env_Rock_01c_PRE"]
	for side in [-1.0, 1.0]:
		for i in range(7):
			var x: float = side * rng.randf_range(5.6, 13.5)
			var z := rng.randf_range(12.0, 23.5)
			var scale_value := rng.randf_range(0.65, 0.9)
			var position := Vector3(x, 0.2, z)
			nature_asset(parent, tree_models[i % tree_models.size()], position, scale_value, rng.randf_range(0, TAU))
			solid_cylinder(parent, position, 0.42 * scale_value, 3.0 * scale_value)
	# Across the pond, silhouettes and large rocks give the first spot landmarks.
	for i in range(9):
		var x := -14.0 + i * 3.5 + rng.randf_range(-0.5, 0.5)
		var position := Vector3(x, 0.35, rng.randf_range(-21.8, -19.7))
		var scale_value := rng.randf_range(0.5, 0.7)
		nature_asset(parent, tree_models[(i + 1) % tree_models.size()], position, scale_value, rng.randf_range(0, TAU))
	for i in range(15):
		var position := Vector3(rng.randf_range(-14, 14), 0.26, rng.randf_range(-19.2, -17.6))
		nature_asset(parent, rock_models[i % rock_models.size()], position, rng.randf_range(0.35, 0.65), rng.randf_range(0, TAU))
	# Vegetation is kept clear of the door and the path along the pier.
	for i in range(40):
		var side := -1.0 if i % 2 == 0 else 1.0
		var position := Vector3(side * rng.randf_range(5.3, 14.5), 0.21, rng.randf_range(10.8, 23.0))
		var model_name := "Grass/EA_M_Env_Grass_01a_PRE" if i % 4 != 0 else "Grass/EA_M_Env_TallGrass_01a_PRE"
		var scale_value := rng.randf_range(0.18, 0.32)
		nature_asset(parent, model_name, position, scale_value, rng.randf_range(0, TAU))
	for i in range(8):
		var side := -1.0 if i % 2 == 0 else 1.0
		var position := Vector3(side * rng.randf_range(5.5, 14.0), 0.2, rng.randf_range(11.5, 22.5))
		var scale_value := rng.randf_range(0.55, 0.75)
		var bush_name := "Bush/EA_M_Env_Bush_BerryDome_01a_PRE" if i % 3 == 0 else "Bush/EA_M_Env_Bush_LeafClusterLarge_01ax_PRE"
		nature_asset(parent, bush_name, position, scale_value, rng.randf_range(0, TAU))
		solid_cylinder(parent, position, 0.65 * scale_value, 1.2 * scale_value)
	for side in [-1.0, 1.0]:
		for i in range(3):
			var position := Vector3(side * rng.randf_range(6.0, 13.0), 0.2, rng.randf_range(11.5, 22.5))
			var scale_value := rng.randf_range(0.6, 0.9)
			nature_asset(parent, rock_models[i], position, scale_value, rng.randf_range(0, TAU))
			solid_cylinder(parent, position, 0.55 * scale_value, 0.7 * scale_value)
	# Timber lines on the dock and floor add scale without obstructing movement.
	for i in range(23):
		box(parent, Vector3(2.9, 0.018, 0.025), Vector3(0, 0.30, 4.4 + i * 0.4), Color(0.30, 0.20, 0.13))
