extends Node2D

var effects: Array[Dictionary] = []
var arena: Node

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
	draw_orders_and_threats()
	for effect in effects:
		var alpha: float = effect.life / effect.duration
		var color := Color(effect.color, alpha)
		if effect.kind == "shot":
			draw_line(Iso.project(effect.from) - Vector2(0, 22),
				Iso.project(effect.to) - Vector2(0, 22), color, 2.5, true)
		else:
			ground_ring(effect.point, effect.radius * (1 - alpha * 0.35), color, 2.5)

func ground_ring(point: Vector2, radius: float, color: Color, width: float = 2) -> void:
	var points := PackedVector2Array()
	for i in 49:
		points.append(Iso.project(point + Vector2.from_angle(TAU * i / 48.0) * radius))
	draw_polyline(points, color, width, true)

func draw_orders_and_threats() -> void:
	if arena == null or not is_instance_valid(arena.player) or not arena.player.alive:
		return
	var player: UnitActor = arena.player
	if is_instance_valid(player.attack_target) and player.attack_target.alive:
		ground_ring(player.attack_target.world_position, 26, Color("f19279"))
	elif player.order == UnitActor.Order.ATTACK_MOVE:
		ground_ring(player.destination, 19, Color("dfbd7b"))
		var point := Iso.project(player.destination)
		draw_line(point - Vector2(6, 0), point + Vector2(6, 0), Color("dfbd7b"), 2, true)
		draw_line(point - Vector2(0, 5), point + Vector2(0, 5), Color("dfbd7b"), 2, true)
	for defense in arena.units:
		if not defense.alive or defense.role not in [UnitActor.Role.BARRICADE, UnitActor.Role.CORE]:
			continue
		if not is_instance_valid(defense.windup_target) or defense.windup_timer <= 0:
			continue
		var target: UnitActor = defense.windup_target
		if not target.alive:
			continue
		var threatening := target == player
		var color := Color("f19279") if threatening else Color(MatchRules.FACTIONS[defense.team].color, 0.4)
		draw_line(Iso.project(defense.world_position) - Vector2(0, 22),
			Iso.project(target.world_position) - Vector2(0, 22), color, 1.5, true)
		if threatening:
			ground_ring(defense.world_position, defense.attack_range, Color(color, 0.32), 1.5)
			ground_ring(player.world_position, 20 + defense.windup_timer * 22, color)
