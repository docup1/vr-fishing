@tool
class_name PixelArtRenderer
extends Control

enum DitherMode {
	NONE = 0,
	NOISE = 1,
	BAYER_4X4 = 2,
}

const SUBVIEWPORT_NAME := "PixelSubViewport"
const VIEWPORT_ROOT_NAME := "ViewportRoot"
const OUTPUT_NAME := "PixelOutput"
const DEBUG_LABEL_NAME := "PixelDebugLabel"
const POSTPROCESS_SHADER := preload("res://addons/pixel_art_renderer/shaders/pixel_art_postprocess.gdshader")

@export_group("Pixel Output")
@export var preset: PixelArtRendererPreset:
	set(value):
		preset = value
		if value != null:
			_apply_preset(value)

@export_range(16, 4096, 1) var virtual_width := 320:
	set(value):
		virtual_width = max(16, value)
		_sync_pipeline()

@export_range(16, 4096, 1) var virtual_height := 180:
	set(value):
		virtual_height = max(16, value)
		_sync_pipeline()

@export_range(1.0, 60.0, 1.0) var target_fps := 12.0:
	set(value):
		target_fps = max(1.0, value)
		_sync_pipeline()

@export_group("Color")
@export_range(2.0, 32.0, 1.0) var color_levels := 7.0:
	set(value):
		color_levels = clamp(value, 2.0, 32.0)
		_sync_pipeline()

@export_enum("None", "Noise", "Bayer 4x4") var dither_mode: int = DitherMode.NOISE:
	set(value):
		dither_mode = clamp(value, DitherMode.NONE, DitherMode.BAYER_4X4)
		_sync_pipeline()

@export_range(0.0, 1.0, 0.01) var dither_strength := 0.24:
	set(value):
		dither_strength = clamp(value, 0.0, 1.0)
		_sync_pipeline()

@export_group("Outline")
@export var outline_enabled := true:
	set(value):
		outline_enabled = value
		_sync_pipeline()

@export_range(0.0, 1.0, 0.01) var outline_strength := 0.52:
	set(value):
		outline_strength = clamp(value, 0.0, 1.0)
		_sync_pipeline()

@export_range(0.02, 0.8, 0.01) var outline_threshold := 0.18:
	set(value):
		outline_threshold = clamp(value, 0.02, 0.8)
		_sync_pipeline()

@export_group("Debug")
@export var show_debug_stats := false:
	set(value):
		show_debug_stats = value
		_sync_debug_label()

@export var rebuild_internal_nodes := false:
	set(value):
		rebuild_internal_nodes = false
		if value:
			rebuild_pipeline()

var _subviewport: SubViewport
var _viewport_root: Node3D
var _output: TextureRect
var _shader_material: ShaderMaterial
var _debug_label: Label
var _frame_accumulator := 0.0
var _scene_updates := 0
var _debug_accumulator := 0.0

func _enter_tree() -> void:
	if is_inside_tree():
		rebuild_pipeline()

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)
	rebuild_pipeline()

func _process(delta: float) -> void:
	if not is_instance_valid(_subviewport):
		return

	_frame_accumulator += delta
	var step: float = 1.0 / maxf(target_fps, 1.0)

	if _frame_accumulator >= step:
		_frame_accumulator = fmod(_frame_accumulator, step)
		_request_viewport_frame()

	_update_debug_stats(delta)

func get_viewport_root() -> Node3D:
	if not is_instance_valid(_viewport_root):
		rebuild_pipeline()
	return _viewport_root

func rebuild_pipeline() -> void:
	if not is_inside_tree():
		return

	_ensure_nodes()
	_ensure_material()
	_sync_pipeline()
	_sync_debug_label()
	_request_viewport_frame()

func _ensure_nodes() -> void:
	_subviewport = get_node_or_null(SUBVIEWPORT_NAME) as SubViewport
	if _subviewport == null:
		_subviewport = SubViewport.new()
		_subviewport.name = SUBVIEWPORT_NAME
		add_child(_subviewport)
		_assign_scene_owner(_subviewport)

	_viewport_root = _subviewport.get_node_or_null(VIEWPORT_ROOT_NAME) as Node3D
	if _viewport_root == null:
		_viewport_root = Node3D.new()
		_viewport_root.name = VIEWPORT_ROOT_NAME
		_subviewport.add_child(_viewport_root)
		_assign_scene_owner(_viewport_root)

	_output = get_node_or_null(OUTPUT_NAME) as TextureRect
	if _output == null:
		_output = TextureRect.new()
		_output.name = OUTPUT_NAME
		add_child(_output)
		_assign_scene_owner(_output)

	_configure_subviewport()
	_configure_output()

func _ensure_material() -> void:
	if not is_instance_valid(_output):
		return

	_shader_material = _output.material as ShaderMaterial
	if _shader_material == null:
		_shader_material = ShaderMaterial.new()
		_shader_material.resource_local_to_scene = true
		_output.material = _shader_material

	_shader_material.shader = POSTPROCESS_SHADER

func _configure_subviewport() -> void:
	_subviewport.size = Vector2i(virtual_width, virtual_height)
	_subviewport.disable_3d = false
	_subviewport.transparent_bg = false
	_subviewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	_subviewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

func _configure_output() -> void:
	_output.set_anchors_preset(Control.PRESET_FULL_RECT)
	_output.offset_left = 0.0
	_output.offset_top = 0.0
	_output.offset_right = 0.0
	_output.offset_bottom = 0.0
	_output.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_output.stretch_mode = TextureRect.STRETCH_SCALE
	_output.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_output.texture = _subviewport.get_texture()
	_output.z_index = 0

func _sync_pipeline() -> void:
	if not is_inside_tree():
		return

	if virtual_width < 16 or virtual_height < 16:
		push_warning("PixelArtRenderer virtual resolution must be at least 16 x 16.")

	if target_fps < 1.0:
		push_warning("PixelArtRenderer target_fps must be at least 1.")

	if is_instance_valid(_subviewport):
		_subviewport.size = Vector2i(max(16, virtual_width), max(16, virtual_height))

	if is_instance_valid(_shader_material):
		if is_instance_valid(_subviewport):
			_shader_material.set_shader_parameter("source_texture", _subviewport.get_texture())
		_shader_material.set_shader_parameter("virtual_resolution", Vector2(virtual_width, virtual_height))
		_shader_material.set_shader_parameter("color_levels", color_levels)
		_shader_material.set_shader_parameter("dither_mode", dither_mode)
		_shader_material.set_shader_parameter("dither_strength", dither_strength)
		_shader_material.set_shader_parameter("outline_enabled", outline_enabled)
		_shader_material.set_shader_parameter("outline_strength", outline_strength)
		_shader_material.set_shader_parameter("outline_threshold", outline_threshold)

	_request_viewport_frame()

func _sync_debug_label() -> void:
	if not is_inside_tree():
		return

	_debug_label = get_node_or_null(DEBUG_LABEL_NAME) as Label

	if show_debug_stats and _debug_label == null:
		_debug_label = Label.new()
		_debug_label.name = DEBUG_LABEL_NAME
		add_child(_debug_label)
		_assign_scene_owner(_debug_label)
		_debug_label.z_index = 100
		_debug_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_debug_label.position = Vector2(12.0, 12.0)

	if is_instance_valid(_debug_label):
		_debug_label.visible = show_debug_stats
		_debug_label.text = _debug_text()

func _request_viewport_frame() -> void:
	if not is_instance_valid(_subviewport):
		return

	_subviewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_scene_updates += 1

func _update_debug_stats(delta: float) -> void:
	if not show_debug_stats or not is_instance_valid(_debug_label):
		return

	_debug_accumulator += delta
	if _debug_accumulator < 0.25:
		return

	_debug_accumulator = 0.0
	_debug_label.text = _debug_text()

func _debug_text() -> String:
	return "dddpix %dx%d @ %.0f FPS\nLevels %.0f | Dither %d | Outline %s\nViewport updates %d" % [
		virtual_width,
		virtual_height,
		target_fps,
		color_levels,
		dither_mode,
		"on" if outline_enabled else "off",
		_scene_updates,
	]

func _apply_preset(value: PixelArtRendererPreset) -> void:
	virtual_width = value.virtual_width
	virtual_height = value.virtual_height
	target_fps = value.target_fps
	color_levels = value.color_levels
	dither_mode = value.dither_mode
	dither_strength = value.dither_strength
	outline_enabled = value.outline_enabled
	outline_strength = value.outline_strength
	outline_threshold = value.outline_threshold
	_sync_pipeline()

func _assign_scene_owner(node: Node) -> void:
	if not Engine.is_editor_hint():
		return

	var scene_owner := owner
	if get_tree() != null and get_tree().edited_scene_root != null:
		scene_owner = get_tree().edited_scene_root

	if scene_owner != null:
		node.owner = scene_owner
