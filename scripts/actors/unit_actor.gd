class_name UnitActor
extends Node2D

signal died(unit: UnitActor, attacker: UnitActor)

enum Role { HERO, TROOP, TOWER, CORE }

var team: int = 0
var role: Role = Role.TROOP
var arena: Node
var world_position := Vector2.ZERO
var destination := Vector2.ZERO
var attack_target: UnitActor
var controlled := false
var alive := true
var hp: float = 100.0
var max_hp: float = 100.0
var speed: float = 0.0
var damage: float = 0.0
var attack_range: float = 0.0
var attack_interval: float = 1.0
var attack_timer := 0.0
var hit_flash := 0.0
var animation_time := 0.0
var moving := false
var reward := 0

func setup(match_node: Node, side: int, kind: Role, point: Vector2, player: bool = false) -> void:
	arena = match_node
	team = side
	role = kind
	controlled = player
	world_position = point
	destination = point
	var values := MatchRules.stats(kind)
	max_hp = values.hp
	hp = max_hp
	speed = values.speed
	damage = values.damage
	attack_range = values.range
	attack_interval = values.interval
	reward = values.reward
	position = Iso.project(world_position)

func tick(delta: float) -> void:
	if not alive:
		return
	animation_time += delta
	attack_timer = maxf(0.0, attack_timer - delta)
	hit_flash = maxf(0.0, hit_flash - delta)
	moving = false
	if is_instance_valid(attack_target) and not attack_target.alive:
		attack_target = null
	if not controlled:
		# Troops take tower aggro before a hero when they enter together.
		attack_target = arena.nearest_enemy(self, attack_range if speed == 0 else 205.0)
		if speed > 0:
			destination = Vector2(515 if team == 0 else -515, world_position.y)
	var has_target := is_instance_valid(attack_target) and attack_target.alive
	if has_target:
		var distance := world_position.distance_to(attack_target.world_position)
		if distance <= attack_range:
			if attack_timer <= 0:
				attack_timer = attack_interval
				arena.add_shot(world_position, attack_target.world_position, team)
				attack_target.take_damage(damage, self)
		else:
			move_towards(attack_target.world_position, delta)
	elif controlled:
		move_towards(destination, delta)
		# Moving takes precedence. A stopped hero automatically attacks in range.
		if not moving:
			attack_target = arena.nearest_enemy(self, attack_range)
	else:
		move_towards(destination, delta)
	position = Iso.project(world_position)
	queue_redraw()

func move_towards(point: Vector2, delta: float) -> void:
	if speed <= 0 or world_position.distance_to(point) < 3:
		return
	world_position = Iso.clamp_to_lane(world_position.move_toward(point, speed * delta))
	moving = true

func take_damage(amount: float, attacker: UnitActor) -> void:
	if not alive or amount <= 0:
		return
	if is_instance_valid(attacker) and attacker.team == team:
		return
	# An intact tower on this team protects its core.
	if role == Role.CORE and arena.has_towers(team):
		return
	hp = maxf(0, hp - amount)
	hit_flash = 0.14
	queue_redraw()
	if hp <= 0:
		alive = false
		visible = false
		died.emit(self, attacker)

func heal(amount: float) -> void:
	if alive:
		hp = minf(max_hp, hp + maxf(0, amount))

func _draw() -> void:
	if not alive:
		return
	var color := MatchRules.FACTIONS[team].color
	if hit_flash > 0:
		color = Color("fff2d0")
	# Ground shadows and selection stay aligned with the logical position.
	draw_set_transform(Vector2(0, 2), 0, Vector2(1, 0.45))
	draw_circle(Vector2.ZERO, 20 if role == Role.HERO else 13, Color(0.03, 0.08, 0.08, 0.4))
	if controlled:
		draw_arc(Vector2.ZERO, 28, 0, TAU, 40, Color("eee3bb"), 2, true)
	draw_set_transform(Vector2.ZERO)
	if role == Role.TOWER or role == Role.CORE:
		draw_structure(color)
	else:
		draw_person(color)
	var width := 57.0 if role == Role.HERO else 46.0
	var height := 76.0 if role == Role.CORE else (101.0 if role == Role.TOWER else 57.0)
	draw_rect(Rect2(-width / 2 - 1, -height - 1, width + 2, 7), Color("1b302d"))
	draw_rect(Rect2(-width / 2, -height, width * hp / max_hp, 5), color)
	if role == Role.HERO:
		draw_string(ThemeDB.fallback_font, Vector2(-24, -height - 7),
			"VOCÊ" if controlled else "BOT", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("f5e8cc"))

func draw_person(color: Color) -> void:
	var hero := role == Role.HERO
	var factor := 1.2 if hero else 0.83
	var stride := sin(animation_time * 14) * 3 if moving else 0.0
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE * factor)
	draw_line(Vector2(-5, -15), Vector2(-6 + stride, -1), Color("243e3d"), 6, true)
	draw_line(Vector2(5, -15), Vector2(6 - stride, -1), Color("243e3d"), 6, true)
	draw_colored_polygon(PackedVector2Array([Vector2(-10, -33), Vector2(7, -33),
		Vector2(10, -13), Vector2(-9, -13)]), color)
	draw_line(Vector2(-9, -29), Vector2(-14, -17), color.darkened(0.1), 5, true)
	draw_line(Vector2(8, -28), Vector2(15, -22), color.darkened(0.1), 5, true)
	draw_circle(Vector2(-1, -40), 8, Color("c79b78"))
	if team == 0:
		draw_arc(Vector2(-1, -41), 8, PI, TAU, 15, Color("254451"), 5, true)
		draw_rect(Rect2(-5, -29, 9, 9), color.darkened(0.45))
	else:
		draw_line(Vector2(-8, -45), Vector2(6, -45), color, 4, true)
		draw_line(Vector2(3, -31), Vector2(-4, -15), color.lightened(0.35), 2, true)
	# Abstract equipment, deliberately kept as placeholder silhouettes.
	draw_line(Vector2(9, -23), Vector2(23 if team == 0 else -20, -30), Color("273d39"), 4, true)
	draw_set_transform(Vector2.ZERO)

func draw_structure(color: Color) -> void:
	var core := role == Role.CORE
	var rect := Rect2(-31, -28, 62, 56) if core else Rect2(-16, -16, 32, 32)
	var height := 47.0 if core else 72.0
	var roof := Iso.diamond(rect, height)
	var floor_points := Iso.diamond(rect)
	draw_colored_polygon(PackedVector2Array([floor_points[1], floor_points[2], roof[2], roof[1]]), Color("37534e"))
	draw_colored_polygon(PackedVector2Array([floor_points[2], floor_points[3], roof[3], roof[2]]), Color("778779"))
	draw_colored_polygon(roof, Color("c2b896"))
	draw_line(Vector2(0, -height), Vector2(0, -height - 27), color.lightened(0.2), 3, true)
	draw_colored_polygon(PackedVector2Array([Vector2(0, -height - 27),
		Vector2(24, -height - 20), Vector2(0, -height - 13)]), color)
	draw_circle(Vector2(0, -height + 2), 7, color)
	if core and arena.has_towers(team):
		draw_arc(Vector2(0, -32), 40, PI, TAU, 32, Color(color, 0.4), 2, true)
