@tool
extends RefCounted

static func filter_wrappable_nodes(selected_nodes: Array, scene_root: Node) -> Array[Node]:
	var filtered: Array[Node] = []

	for node in selected_nodes:
		if not _is_wrappable_node(node, scene_root):
			continue
		if _has_selected_ancestor(node, selected_nodes):
			continue
		filtered.append(node)

	return filtered

static func find_insertion_parent(nodes: Array[Node], scene_root: Node) -> Node:
	if nodes.is_empty():
		return scene_root

	var first_parent := nodes[0].get_parent()
	if first_parent == null:
		return scene_root

	for node in nodes:
		if node.get_parent() != first_parent:
			return scene_root

	return first_parent

static func _is_wrappable_node(node: Variant, scene_root: Node) -> bool:
	if not node is Node:
		return false
	if node == scene_root:
		return false
	if not node is Node3D:
		return false
	if node is PixelArtRenderer:
		return false
	if _is_inside_pixel_art_renderer(node):
		return false
	return true

static func _has_selected_ancestor(node: Node, selected_nodes: Array) -> bool:
	var current := node.get_parent()
	while current != null:
		if selected_nodes.has(current):
			return true
		current = current.get_parent()
	return false

static func _is_inside_pixel_art_renderer(node: Node) -> bool:
	var current := node.get_parent()
	while current != null:
		if current is PixelArtRenderer:
			return true
		current = current.get_parent()
	return false
