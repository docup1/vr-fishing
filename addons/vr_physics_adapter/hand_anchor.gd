extends CharacterBody3D
# Adapted from jtnicholl/godot4-vr-physics-template player/hand_anchor.gd (MIT).
var controller: XRController3D

func _physics_process(delta: float) -> void:
	if not is_instance_valid(controller) or delta <= 0.0:
		return
	var displacement := controller.global_position - global_position
	if displacement.length_squared() < 1.0:
		velocity = displacement / delta
		move_and_slide()
	else:
		global_position = controller.global_position
