extends Node
## Owns match lifetime and simulation. Actors never modify UI or start a new match.

enum State { MENU, PLAYING, FINISHED }

const EffectsScript = preload("res://scripts/world/combat_effects.gd")

@onready var world: Node2D = $World
@onready var actor_root: Node2D = $World/Actors
@onready var hud: Control = $Interface/HUD
@onready var effects: Node2D = $World/Effects

var state := State.MENU
var paused := false
var player_team := 0
var player: UnitActor
var units: Array[UnitActor] = []
var elapsed := 0.0
var wave_timer := 2.0
var wave_number := 0
var pulse_timer := 0.0
var dash_timer := 0.0
var respawn_timers: Array[float] = [0.0, 0.0]
var takedowns := 0
var deaths := 0
var winner := -1
var notice := ""
var notice_timer := 0.0

func _ready() -> void:
	effects.set_script(EffectsScript)
	get_viewport().size_changed.connect(resize_world)
	resize_world()
	hud.bind_match(self)
	start_match(0)
	state = State.MENU
	hud.show_menu()

func resize_world() -> void:
	var size := get_viewport().get_visible_rect().size
	world.position = Vector2(size.x * 0.5, size.y * 0.5 + 30)
	world.scale = Vector2.ONE * minf((size.x - 60) / 1900, (size.y - 190) / 1050)

func start_match(team: int) -> void:
	for unit in units:
		unit.free()
	units.clear()
	effects.effects.clear()
	player = null
	player_team = clampi(team, 0, 1)
	elapsed = 0
	wave_timer = 2
	wave_number = 0
	pulse_timer = 0
	dash_timer = 0
	respawn_timers = [0.0, 0.0]
	takedowns = 0
	deaths = 0
	winner = -1
	paused = false
	state = State.PLAYING
	for side in 2:
		var direction := -1.0 if side == 0 else 1.0
		spawn_unit(side, UnitActor.Role.CORE, Vector2(direction * 540, 0))
		for x in [290, 140]:
			spawn_unit(side, UnitActor.Role.BARRICADE, Vector2(direction * x, 50))
		spawn_hero(side)
	hud.hide_overlay()
	announce("Acompanhe suas tropas. Destrua as barricadas e depois a central rival.")

func spawn_unit(team: int, role: UnitActor.Role, point: Vector2, controlled: bool = false) -> UnitActor:
	var unit := UnitActor.new()
	unit.setup(self, team, role, point, controlled)
	unit.died.connect(on_unit_died)
	actor_root.add_child(unit)
	units.append(unit)
	return unit

func spawn_hero(team: int) -> UnitActor:
	var hero := spawn_unit(team, UnitActor.Role.HERO,
		MatchRules.FACTIONS[team].spawn_point, team == player_team)
	if hero.controlled:
		player = hero
	return hero

func spawn_wave() -> void:
	wave_number += 1
	for team in 2:
		for i in MatchRules.WAVE_SIZE:
			spawn_unit(team, UnitActor.Role.TROOP,
				Vector2(-490 if team == 0 else 490, (i - 1) * 27))

func _process(delta: float) -> void:
	if state == State.PLAYING and not paused:
		handle_keyboard_movement(delta)
		simulate(delta)
	hud.queue_redraw()

func simulate(delta: float) -> void:
	if state != State.PLAYING or paused:
		return
	elapsed += delta
	pulse_timer = maxf(0, pulse_timer - delta)
	dash_timer = maxf(0, dash_timer - delta)
	notice_timer = maxf(0, notice_timer - delta)
	wave_timer -= delta
	if wave_timer <= 0:
		wave_timer += MatchRules.WAVE_INTERVAL
		spawn_wave()
	for team in 2:
		if respawn_timers[team] > 0:
			respawn_timers[team] = maxf(0, respawn_timers[team] - delta)
			if respawn_timers[team] <= 0:
				spawn_hero(team)
	# Copy because a unit can die while another unit is resolving an attack.
	for unit in units.duplicate():
		if state != State.PLAYING:
			break
		if unit.alive:
			unit.tick(delta)
			if unit.role == UnitActor.Role.HERO:
				var home := MatchRules.FACTIONS[unit.team].spawn_point
				if unit.world_position.distance_to(home) < 95:
					unit.heal(MatchRules.BASE_HEAL_PER_SECOND * delta)
	effects.tick(delta)
	# Dead player survives as a hidden node until respawn to keep UI references valid.
	for index in range(units.size() - 1, -1, -1):
		var unit := units[index]
		if not unit.alive and unit != player:
			for other in units:
				if other.attack_target == unit:
					other.attack_target = null
			units.remove_at(index)
			unit.queue_free()

func nearest_enemy(source: UnitActor, radius: float) -> UnitActor:
	var nearest: UnitActor = null
	var best := radius
	for other in units:
		if not other.alive or other.team == source.team:
			continue
		if other.role == UnitActor.Role.CORE and has_barricades(other.team):
			continue
		var distance := source.world_position.distance_to(other.world_position)
		if distance < best:
			best = distance
			nearest = other
	return nearest

func has_barricades(team: int) -> bool:
	for unit in units:
		if unit.alive and unit.team == team and unit.role == UnitActor.Role.BARRICADE:
			return true
	return false

func core_health(team: int) -> float:
	for unit in units:
		if unit.team == team and unit.role == UnitActor.Role.CORE:
			return unit.hp / unit.max_hp
	return 0.0

func on_unit_died(unit: UnitActor, attacker: UnitActor) -> void:
	if unit.team != player_team and is_instance_valid(attacker) and attacker.controlled:
		takedowns += 1
	if unit.role == UnitActor.Role.HERO:
		respawn_timers[unit.team] = MatchRules.RESPAWN_TIME
		if unit.controlled:
			deaths += 1
			announce("Você caiu. Retorno à central em %d segundos." % int(MatchRules.RESPAWN_TIME))
	elif unit.role == UnitActor.Role.CORE:
		winner = 1 - unit.team
		state = State.FINISHED
		hud.show_result(winner == player_team)
	elif unit.role == UnitActor.Role.BARRICADE:
		announce("Barricada destruída!" if unit.team != player_team else "Sua equipe perdeu uma barricada!")
		effects.ring(unit.world_position, 80, MatchRules.FACTIONS[unit.team].color)

func add_shot(from: Vector2, to: Vector2, team: int) -> void:
	effects.shot(from, to, MatchRules.FACTIONS[team].color)

func announce(message: String) -> void:
	notice = message
	notice_timer = 4.5

func mouse_world_position() -> Vector2:
	return Iso.clamp_to_lane(Iso.unproject(world.get_local_mouse_position()))

func command_move(point: Vector2) -> void:
	if not is_instance_valid(player) or not player.alive:
		return
	player.attack_target = null
	player.destination = Iso.clamp_to_lane(point)
	effects.ring(player.destination, 15, Color("e1d5a8"))

func command_pointer(screen_position: Vector2) -> void:
	if not player.alive:
		return
	# Picking uses the visible silhouette, not just the actor's ground point.
	var pointer := world.get_global_transform_with_canvas().affine_inverse() * screen_position
	var target: UnitActor = null
	var best := 1.0
	for unit in units:
		if not unit.alive or unit.team == player_team:
			continue
		var person := unit.role in [UnitActor.Role.HERO, UnitActor.Role.TROOP]
		var offset := 38.0 if person else 18.0
		var radius := 45.0 if person else 55.0
		var distance := (unit.position - Vector2(0, offset)).distance_to(pointer) / radius
		if distance < best:
			best = distance
			target = unit
	if target != null:
		if target.role == UnitActor.Role.CORE and has_barricades(target.team):
			announce("A central está protegida. Destrua as duas barricadas primeiro.")
			return
		player.attack_target = target
		effects.ring(target.world_position, 22, MatchRules.FACTIONS[target.team].color)
	else:
		command_move(Iso.clamp_to_lane(Iso.unproject(pointer)))

func cast_pulse() -> bool:
	if state != State.PLAYING or paused or not player.alive or pulse_timer > 0:
		return false
	pulse_timer = MatchRules.PULSE_COOLDOWN
	effects.ring(player.world_position, MatchRules.PULSE_RADIUS, MatchRules.FACTIONS[player_team].color)
	for unit in units.duplicate():
		if unit.alive and unit.team != player_team and unit.role in [UnitActor.Role.HERO, UnitActor.Role.TROOP]:
			if player.world_position.distance_to(unit.world_position) <= MatchRules.PULSE_RADIUS:
				unit.take_damage(MatchRules.PULSE_DAMAGE, player)
	return true

func cast_dash(towards: Vector2) -> bool:
	if state != State.PLAYING or paused or not player.alive or dash_timer > 0:
		return false
	var direction := player.world_position.direction_to(towards)
	if direction == Vector2.ZERO:
		return false
	dash_timer = MatchRules.DASH_COOLDOWN
	effects.shot(player.world_position, player.world_position + direction * MatchRules.DASH_DISTANCE,
		MatchRules.FACTIONS[player_team].color)
	player.world_position = Iso.clamp_to_lane(player.world_position + direction * MatchRules.DASH_DISTANCE)
	player.position = Iso.project(player.world_position)
	player.destination = player.world_position
	player.attack_target = null
	return true

func handle_keyboard_movement(delta: float) -> void:
	if not player.alive:
		return
	var screen_direction := Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	if screen_direction != Vector2.ZERO:
		player.attack_target = null
		player.destination = Iso.clamp_to_lane(player.world_position +
			Iso.unproject(screen_direction).normalized() * player.speed * maxf(delta, 0.04))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		if state == State.PLAYING:
			paused = not paused
			hud.show_pause() if paused else hud.hide_overlay()
		return
	if state != State.PLAYING or paused:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		command_pointer(event.position)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_Q: cast_pulse()
			KEY_E: cast_dash(mouse_world_position())
			KEY_SPACE:
				if player.alive:
					player.attack_target = null
					player.destination = player.world_position
