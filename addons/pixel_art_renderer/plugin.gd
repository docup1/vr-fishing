@tool
extends EditorPlugin

const PIXEL_ART_RENDERER_SCRIPT := preload("res://addons/pixel_art_renderer/scripts/pixel_art_renderer.gd")
const PIXEL_ART_RENDERER_ICON_PATH := "res://addons/pixel_art_renderer/icons/pixel_art_renderer.svg"
const WRAP_SELECTION_HELPER := preload("res://addons/pixel_art_renderer/scripts/editor/pixel_art_wrap_selection.gd")

const TOOL_MENU_NAME := "dddpix"
const MENU_WRAP_SELECTION := 1
const WRAP_ACTION_NAME := "Wrap Selection With PixelArtRenderer"

var _tool_menu: PopupMenu

func _enter_tree() -> void:
	var icon := load(PIXEL_ART_RENDERER_ICON_PATH) as Texture2D
	add_custom_type(
		"PixelArtRenderer",
		"Control",
		PIXEL_ART_RENDERER_SCRIPT,
		icon
	)
	_add_tool_menu()

func _exit_tree() -> void:
	remove_custom_type("PixelArtRenderer")
	_remove_tool_menu()

func _add_tool_menu() -> void:
	_tool_menu = PopupMenu.new()
	_tool_menu.add_item(WRAP_ACTION_NAME, MENU_WRAP_SELECTION)
	_tool_menu.id_pressed.connect(_on_tool_menu_id_pressed)
	add_tool_submenu_item(TOOL_MENU_NAME, _tool_menu)

func _remove_tool_menu() -> void:
	remove_tool_menu_item(TOOL_MENU_NAME)
	if is_instance_valid(_tool_menu):
		_tool_menu.queue_free()
	_tool_menu = null

func _on_tool_menu_id_pressed(id: int) -> void:
	if id == MENU_WRAP_SELECTION:
		_wrap_selected_nodes()

func _wrap_selected_nodes() -> void:
	var scene_root := EditorInterface.get_edited_scene_root()
	if scene_root == null:
		_warn_user("Open a scene before wrapping content.")
		return

	var selection := EditorInterface.get_selection()
	var selected_nodes := selection.get_top_selected_nodes()
	var nodes_to_wrap := WRAP_SELECTION_HELPER.filter_wrappable_nodes(selected_nodes, scene_root)
	if nodes_to_wrap.is_empty():
		_warn_user("Select one or more Node3D scene nodes that are not already inside PixelArtRenderer.")
		return

	var insertion_parent := WRAP_SELECTION_HELPER.find_insertion_parent(nodes_to_wrap, scene_root)
	if insertion_parent == null:
		_warn_user("Could not find a valid parent for PixelArtRenderer.")
		return

	var renderer := PIXEL_ART_RENDERER_SCRIPT.new() as PixelArtRenderer
	renderer.name = "PixelArtRenderer"

	var move_records := _build_move_records(nodes_to_wrap)
	var insert_index := _find_renderer_insert_index(nodes_to_wrap, insertion_parent)

	var undo_redo := get_undo_redo()
	undo_redo.create_action(WRAP_ACTION_NAME, UndoRedo.MERGE_DISABLE, scene_root)
	undo_redo.add_do_method(self, "_do_wrap_selection", scene_root, insertion_parent, renderer, move_records, insert_index)
	undo_redo.add_undo_method(self, "_undo_wrap_selection", renderer, move_records)
	undo_redo.add_do_reference(renderer)
	undo_redo.commit_action()

func _build_move_records(nodes_to_wrap: Array[Node]) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for node in nodes_to_wrap:
		records.append({
			"node": node,
			"parent": node.get_parent(),
			"index": node.get_index(),
			"owner": node.owner,
			"global_transform": node.global_transform if node is Node3D else Transform3D.IDENTITY,
		})
	return records

func _find_renderer_insert_index(nodes_to_wrap: Array[Node], insertion_parent: Node) -> int:
	var insert_index := insertion_parent.get_child_count()
	for node in nodes_to_wrap:
		if node.get_parent() == insertion_parent:
			insert_index = mini(insert_index, node.get_index())
	return insert_index

func _do_wrap_selection(
	scene_root: Node,
	insertion_parent: Node,
	renderer: PixelArtRenderer,
	move_records: Array[Dictionary],
	insert_index: int
) -> void:
	if not is_instance_valid(scene_root) or not is_instance_valid(insertion_parent):
		_warn_user("Scene changed before wrapping could run.")
		return

	if renderer.get_parent() == null:
		insertion_parent.add_child(renderer, true)
	renderer.owner = scene_root
	if renderer.get_parent() == insertion_parent:
		var clamped_index := clampi(insert_index, 0, insertion_parent.get_child_count() - 1)
		insertion_parent.move_child(renderer, clamped_index)

	renderer.rebuild_pipeline()
	var viewport_root := renderer.get_viewport_root()
	if viewport_root == null:
		_warn_user("PixelArtRenderer could not create ViewportRoot.")
		return

	for record in move_records:
		var node := record["node"] as Node
		if not is_instance_valid(node):
			continue
		node.reparent(viewport_root, true)
		node.owner = scene_root
		if node is Node3D:
			node.global_transform = record["global_transform"] as Transform3D

	var selection := EditorInterface.get_selection()
	selection.clear()
	selection.add_node(renderer)
	EditorInterface.edit_node(renderer)
	EditorInterface.mark_scene_as_unsaved()

func _undo_wrap_selection(renderer: PixelArtRenderer, move_records: Array[Dictionary]) -> void:
	for i in range(move_records.size() - 1, -1, -1):
		var record := move_records[i]
		var node := record["node"] as Node
		var parent := record["parent"] as Node
		if not is_instance_valid(node) or not is_instance_valid(parent):
			continue
		node.reparent(parent, true)
		var clamped_index := clampi(int(record["index"]), 0, parent.get_child_count() - 1)
		parent.move_child(node, clamped_index)
		node.owner = record["owner"] as Node
		if node is Node3D:
			node.global_transform = record["global_transform"] as Transform3D

	if is_instance_valid(renderer) and renderer.get_parent() != null:
		renderer.get_parent().remove_child(renderer)

	var selection := EditorInterface.get_selection()
	selection.clear()
	for record in move_records:
		var node := record["node"] as Node
		if is_instance_valid(node):
			selection.add_node(node)
	EditorInterface.mark_scene_as_unsaved()

func _warn_user(message: String) -> void:
	push_warning("dddpix: %s" % message)
