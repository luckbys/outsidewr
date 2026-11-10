class_name UnitActor
extends Node2D

signal died(unit: UnitActor, attacker: UnitActor)

enum Role { HERO, TROOP, BARRICADE, CORE }
enum Order { HOLD, MOVE, ATTACK_MOVE, ATTACK_TARGET }

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
var visual_variant := 0
var facing := 1.0
var order: Order = Order.HOLD
var slow_timer := 0.0
var slow_fraction := 0.0
var aggro_target: UnitActor
var aggro_timer := 0.0
var windup_target: UnitActor
var windup_timer := 0.0
var ai_retreating := false

func setup(match_node: Node, side: int, kind: Role, point: Vector2, player: bool = false) -> void:
	arena = match_node
	team = side
	role = kind
	controlled = player
	world_position = point
	destination = point
	visual_variant = posmod(int(point.y / 27.0) + side, 4)
	facing = 1.0 if side == 0 else -1.0
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
	slow_timer = maxf(0.0, slow_timer - delta)
	if aggro_timer > 0:
		aggro_timer = maxf(0.0, aggro_timer - delta)
		if aggro_timer <= 0:
			aggro_target = null
			attack_target = null
	moving = false
	if is_instance_valid(attack_target) and not attack_target.alive:
		attack_target = null
	if controlled:
		update_player_order()
	elif speed == 0:
		attack_target = arena.defense_target(self)
	elif role == Role.HERO:
		update_hero_ai()
	else:
		# Keep the current opponent until it dies or leaves detection range.
		if not target_in_range(attack_target, 205):
			attack_target = arena.nearest_enemy(self, 205)
		destination = Vector2(515 if team == 0 else -515, world_position.y)
	var has_target := is_instance_valid(attack_target) and attack_target.alive
	if speed == 0:
		update_defense_attack(delta)
	if has_target:
		var distance := world_position.distance_to(attack_target.world_position)
		if distance <= attack_range:
			if speed > 0 and attack_timer <= 0:
				attack_timer = attack_interval
				fire_at(attack_target)
		else:
			move_towards(attack_target.world_position, delta)
	else:
		move_towards(destination, delta)
	position = Iso.project(world_position)
	queue_redraw()

func target_in_range(target: Variant, radius: float) -> bool:
	# Freed targets must reach this guard before Godot validates a Node argument.
	return is_instance_valid(target) and target.alive and world_position.distance_to(target.world_position) <= radius

func update_player_order() -> void:
	if order == Order.ATTACK_TARGET:
		if is_instance_valid(attack_target) and attack_target.alive:
			return
		hold_position()
	if order == Order.MOVE:
		attack_target = null
		if world_position.distance_to(destination) >= 3:
			return
		order = Order.HOLD
	if order == Order.ATTACK_MOVE and world_position.distance_to(destination) < 3:
		order = Order.HOLD
	# Hold never chases. Attack-move stops only for opponents already in range,
	# then resumes its original destination when they die or move away.
	if not target_in_range(attack_target, attack_range):
		attack_target = arena.nearest_enemy(self, attack_range)

func hold_position() -> void:
	order = Order.HOLD
	attack_target = null
	destination = world_position

func update_hero_ai() -> void:
	var home: Vector2 = MatchRules.FACTIONS[team].spawn_point
	if hp / max_hp <= MatchRules.BOT_RETREAT_HEALTH:
		ai_retreating = true
	if ai_retreating:
		if world_position.distance_to(home) < 95 and hp / max_hp >= MatchRules.BOT_RETURN_HEALTH:
			ai_retreating = false
		else:
			attack_target = null
			destination = home
			return
	if not target_in_range(attack_target, 205):
		attack_target = arena.nearest_enemy(self, 205)
	destination = Vector2(515 if team == 0 else -515, world_position.y)

func update_defense_attack(delta: float) -> void:
	if is_instance_valid(windup_target):
		if windup_target != attack_target or not target_in_range(windup_target, attack_range):
			windup_target = null
			windup_timer = 0
		else:
			windup_timer = maxf(0, windup_timer - delta)
			if windup_timer <= 0:
				fire_at(windup_target)
				windup_target = null
	if not is_instance_valid(windup_target) and target_in_range(attack_target, attack_range) and attack_timer <= 0:
		windup_target = attack_target
		windup_timer = MatchRules.DEFENSE_WINDUP
		attack_timer = attack_interval

func fire_at(target: UnitActor) -> void:
	var aim := Iso.project(target.world_position - world_position)
	if absf(aim.x) > 0.1:
		facing = signf(aim.x)
	arena.add_shot(world_position, target.world_position, team)
	target.take_damage(damage, self)

func movement_speed() -> float:
	return speed * (1.0 - slow_fraction if slow_timer > 0 else 1.0)

func apply_slow(fraction: float, duration: float) -> void:
	if not alive or speed <= 0 or duration <= 0:
		return
	if slow_timer <= 0:
		slow_fraction = clampf(fraction, 0, 0.9)
	else:
		slow_fraction = maxf(slow_fraction, clampf(fraction, 0, 0.9))
	slow_timer = maxf(slow_timer, duration)
	queue_redraw()

func move_towards(point: Vector2, delta: float) -> void:
	if speed <= 0 or world_position.distance_to(point) < 3:
		return
	var direction := Iso.project(point - world_position)
	if absf(direction.x) > 0.1:
		facing = signf(direction.x)
	world_position = Iso.clamp_to_lane(world_position.move_toward(point, movement_speed() * delta))
	moving = true

func take_damage(amount: float, attacker: UnitActor) -> void:
	if not alive or amount <= 0:
		return
	if is_instance_valid(attacker) and attacker.team == team:
		return
	# An intact barricade on this team protects its core.
	if role == Role.CORE and arena.has_barricades(team):
		return
	hp = maxf(0, hp - amount)
	arena.notify_hostile_action(attacker, self)
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
	if slow_timer > 0:
		draw_arc(Vector2.ZERO, 24, 0, TAU, 40, Color("9bc9c6"), 3, true)
	draw_set_transform(Vector2.ZERO)
	if role == Role.BARRICADE or role == Role.CORE:
		draw_structure(color)
	else:
		draw_person(color)
	var width := 62.0 if role == Role.HERO else (85.0 if role == Role.BARRICADE else 46.0)
	var height := 76.0 if role == Role.CORE else (66.0 if role == Role.BARRICADE else (84.0 if role == Role.HERO else 73.0))
	draw_rect(Rect2(-width / 2 - 1, -height - 1, width + 2, 7), Color("1b302d"))
	draw_rect(Rect2(-width / 2, -height, width * hp / max_hp, 5), color)
	if role == Role.HERO:
		draw_string(ThemeDB.fallback_font, Vector2(-24, -height - 7),
			"VOCÊ" if controlled else "BOT", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("f5e8cc"))
	var status := "LENTO" if slow_timer > 0 else ("RECUANDO" if ai_retreating else "")
	if not status.is_empty():
		draw_string(ThemeDB.fallback_font, Vector2(-20, -height - (21 if role == Role.HERO else 6)),
			status, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("bde3df"))

func draw_person(color: Color) -> void:
	var hero := role == Role.HERO
	var scale_factor := 1.12 if hero else 0.98
	var stride := sin(animation_time * 10.5) * 4.5 if moving else 0.0
	var breath := sin(animation_time * 2) * 0.5
	var skins := [Color("b58161"), Color("825a44"), Color("d0a080"), Color("684a3b")]
	var skin: Color = skins[visual_variant]
	var shirt: Color = Color("263c4d") if team == 0 else [Color("50584c"), Color("665c50"), Color("4c5159"), Color("494e4e")][visual_variant]
	var trousers := Color("273540") if team == 0 else Color("3d4851")
	var vest := Color("1c292e") if team == 0 else Color("3d4238")
	if hit_flash > 0:
		shirt = shirt.lightened(0.55)
		vest = vest.lightened(0.4)
		skin = skin.lightened(0.2)
	draw_set_transform(Vector2(0, breath), 0, Vector2(facing, 1) * scale_factor)
	# Legs have separate thighs, knees, shins, boots and soles.
	for side in [-1, 1]:
		var hip := Vector2(side * 4.8, -28)
		var knee := Vector2(side * 5 + stride * side * 0.45, -15)
		var ankle := Vector2(side * 5 - stride * side, -3)
		draw_line(hip, knee, trousers, 7, true)
		draw_line(knee, ankle, trousers.darkened(0.1), 6, true)
		draw_line(ankle + Vector2(-2, 1), ankle + Vector2(5, 1), Color("202826"), 6, true)
		draw_line(ankle + Vector2(-3, 4), ankle + Vector2(7, 4), Color("6d7265"), 1.3, true)
	# The far arm sits behind the torso.
	draw_line(Vector2(-8, -48), Vector2(-13, -35), shirt.darkened(0.15), 6, true)
	draw_line(Vector2(-13, -35), Vector2(4, -34), skin.darkened(0.12), 4.5, true)
	draw_colored_polygon(PackedVector2Array([Vector2(-9, -52), Vector2(8, -52),
		Vector2(10, -45), Vector2(7, -30), Vector2(-7, -30), Vector2(-11, -44)]), shirt)
	if hero or team == 0:
		draw_colored_polygon(PackedVector2Array([Vector2(-7, -49), Vector2(7, -49),
			Vector2(6, -33), Vector2(-6, -33)]), vest)
		draw_line(Vector2(-5, -48), Vector2(-4, -33), vest.lightened(0.16), 1, true)
		for x in [-4, 2]:
			draw_rect(Rect2(x, -41, 4, 6), vest.lightened(0.1))
	draw_line(Vector2(-7, -30), Vector2(7, -30), Color("202825"), 3.5, true)
	draw_rect(Rect2(-8, -29, 4, 5), vest)
	draw_circle(Vector2(2, -54), 3, skin)
	# A proportionate face, ear, nose and the headwear of each faction.
	draw_circle(Vector2(1, -61), 6.5, skin)
	draw_circle(Vector2(-5, -61), 2, skin.darkened(0.12))
	draw_colored_polygon(PackedVector2Array([Vector2(5, -63), Vector2(9, -60), Vector2(5, -59)]), skin)
	draw_line(Vector2(3, -63), Vector2(5, -63), Color("30352e"), 1.2, true)
	if team == 0 and hero:
		draw_arc(Vector2(0, -62), 7, PI, TAU + 0.25, 20, Color("293c46"), 5, true)
		draw_line(Vector2(-6, -60), Vector2(-3, -55), Color("25332e"), 1.4, true)
	else:
		draw_arc(Vector2(0, -63), 6, PI, TAU, 16, shirt.darkened(0.2), 4, true)
		draw_line(Vector2(1, -67), Vector2(10, -66), shirt.darkened(0.3), 3, true)
	# Small patches preserve team readability without neon uniforms.
	draw_rect(Rect2(-10, -46, 3, 5), color.darkened(0.1))
	draw_rect(Rect2(3, -47, 3, 3), color.lightened(0.1))
	if hero and team == 1:
		draw_line(Vector2(-6, -50), Vector2(7, -31), Color("867b62"), 2, true)
	if hero and team == 0:
		draw_rect(Rect2(-6, -49, 3, 5), Color("424b48"))
	# Near arm and abstract carried equipment share a stable two-handed pose.
	draw_line(Vector2(8, -48), Vector2(12, -38), shirt, 6, true)
	draw_line(Vector2(12, -38), Vector2(5, -34), skin, 4.5, true)
	draw_line(Vector2(-1, -35), Vector2(19, -41), Color("262f30"), 4, true)
	draw_line(Vector2(17, -41), Vector2(26, -43), Color("354044"), 2.3, true)
	draw_line(Vector2(4, -35), Vector2(7, -31), Color("242c2b"), 2, true)
	draw_circle(Vector2(5, -35), 2, skin)
	draw_set_transform(Vector2.ZERO)

func draw_barricade(color: Color) -> void:
	# Sloped concrete, worn paint, sandbags and stacked tires replace the tower.
	var ground := Iso.diamond(Rect2(-16, -46, 32, 92))
	var top := Iso.diamond(Rect2(-6, -46, 12, 92), 24)
	draw_colored_polygon(PackedVector2Array([ground[1], ground[2], top[2], top[1]]), Color("747870"))
	draw_colored_polygon(PackedVector2Array([ground[2], ground[3], top[3], top[2]]), Color("929387"))
	draw_colored_polygon(top, Color("b7b5a4"))
	for i in 5:
		var point := Iso.project(Vector2(11, -35 + i * 17)) - Vector2(0, 13)
		draw_line(point, point + Vector2(-3, 7), Color("c7b469") if i % 2 == 0 else Color("444a42"), 4, true)
	var plate := Iso.project(Vector2(10, 2)) - Vector2(0, 18)
	draw_line(plate, plate + Vector2(-14, 7), color.darkened(0.12), 5, true)
	for i in 4:
		var point := ground[2].lerp(top[2], 0.2 + i * 0.17)
		draw_line(point + Vector2(-5 - i * 5, -2), point + Vector2(-13 - i * 5, -1), Color("636c61"), 1, true)
	for i in 4:
		var point := Iso.project(Vector2(24, -24 + i * 17)) - Vector2(0, 5)
		draw_set_transform(point, -0.45, Vector2(1, 0.6))
		draw_circle(Vector2.ZERO, 8, Color("8d8061"))
		draw_line(Vector2(-5, -1), Vector2(5, -1), Color("a19371"), 1, true)
		draw_set_transform(Vector2.ZERO)
	for i in 3:
		var point := Iso.project(Vector2(25, 44)) - Vector2(0, 5 + i * 7)
		draw_set_transform(point, 0, Vector2(1, 0.5))
		draw_circle(Vector2.ZERO, 10, Color("282e29"))
		draw_arc(Vector2.ZERO, 8, 0, TAU, 20, Color("4d554c"), 1.5, true)
		draw_circle(Vector2.ZERO, 4, Color("666f61"))
		draw_set_transform(Vector2.ZERO)

func draw_structure(color: Color) -> void:
	if role == Role.BARRICADE:
		draw_barricade(color)
		return
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
	if core and arena.has_barricades(team):
		draw_arc(Vector2(0, -32), 40, PI, TAU, 32, Color(color, 0.4), 2, true)
