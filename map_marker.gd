extends Control

var tracked_camera: Camera3D
var map_camera: Camera3D

func marker_position() -> Vector2:
	if tracked_camera == null or map_camera == null:
		return size * 0.5
	var world := tracked_camera.global_position - map_camera.global_position
	return Vector2((world.x / map_camera.size + 0.5) * size.x, (world.z / map_camera.size + 0.5) * size.y)

func _draw() -> void:
	if tracked_camera == null or map_camera == null:
		return
	for spot in [Vector2(0, -10), Vector2(-33, -8), Vector2(33, -8)]:
		var point := Vector2((spot.x / map_camera.size + 0.5) * size.x, (spot.y / map_camera.size + 0.5) * size.y)
		draw_arc(point, 9.0, 0.0, TAU, 24, Color(0.98, 0.85, 0.53, 0.9), 2.0)
	var center := marker_position()
	var forward := -tracked_camera.global_basis.z
	var heading := Vector2(forward.x, forward.z).normalized()
	if heading.length_squared() < 0.01:
		heading = Vector2.UP
	var side := Vector2(-heading.y, heading.x)
	# A light cone shows which way the player's camera is facing.
	draw_colored_polygon(PackedVector2Array([center, center + heading * 54.0 + side * 23.0, center + heading * 54.0 - side * 23.0]), Color(1.0, 0.9, 0.55, 0.28))
	draw_circle(center, 9.0, Color(0.07, 0.17, 0.16))
	draw_circle(center, 6.0, Color(1.0, 0.84, 0.42))
	draw_colored_polygon(PackedVector2Array([center + heading * 18.0, center - heading * 4.0 + side * 8.0, center - heading * 4.0 - side * 8.0]), Color(1.0, 0.90, 0.64))
