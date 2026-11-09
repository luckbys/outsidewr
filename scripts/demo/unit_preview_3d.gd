extends Node3D
## Animated preview of the two factions, not a second combat simulation.

@export var patrol := false
@export var endpoint_a := Vector3.ZERO
@export var endpoint_b := Vector3.ZERO
@export var start_fraction := 0.0
var progress := 0.0
var direction := 1.0

func _ready() -> void:
	progress = start_fraction
	$Character.walking = patrol
	if patrol:
		position = endpoint_a.lerp(endpoint_b, progress)
		update_heading()

func _process(delta: float) -> void:
	if not patrol:
		return
	var distance := endpoint_a.distance_to(endpoint_b)
	if distance < 0.01:
		return
	progress += direction * delta * 1.35 / distance
	if progress >= 1 or progress <= 0:
		progress = clampf(progress, 0, 1)
		direction *= -1
		update_heading()
	position = endpoint_a.lerp(endpoint_b, progress)

func update_heading() -> void:
	var target := endpoint_b if direction > 0 else endpoint_a
	if position.distance_to(target) > 0.01:
		look_at(get_parent().to_global(target), Vector3.UP)
