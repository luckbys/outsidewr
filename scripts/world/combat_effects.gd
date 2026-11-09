extends Node2D

var effects: Array[Dictionary] = []

func tick(delta: float) -> void:
	for effect in effects:
		effect.life -= delta
	effects = effects.filter(func(effect: Dictionary) -> bool: return effect.life > 0)
	queue_redraw()

func shot(from: Vector2, to: Vector2, color: Color) -> void:
	effects.append({"kind": "shot", "from": from, "to": to,
		"color": color, "life": 0.16, "duration": 0.16})

func ring(point: Vector2, radius: float, color: Color) -> void:
	effects.append({"kind": "ring", "point": point, "radius": radius,
		"color": color, "life": 0.65, "duration": 0.65})

func _draw() -> void:
	for effect in effects:
		var alpha: float = effect.life / effect.duration
		var color := Color(effect.color, alpha)
		if effect.kind == "shot":
			draw_line(Iso.project(effect.from) - Vector2(0, 22),
				Iso.project(effect.to) - Vector2(0, 22), color, 2.5, true)
		else:
			var points := PackedVector2Array()
			for i in 49:
				points.append(Iso.project(effect.point + Vector2.from_angle(TAU * i / 48.0)
					* effect.radius * (1 - alpha * 0.35)))
			draw_polyline(points, color, 2.5, true)
