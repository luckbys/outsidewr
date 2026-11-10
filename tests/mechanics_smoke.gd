extends SceneTree
## Test commands, combat timing and autonomous decisions in the actual match.

var arena: Node
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func verify(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func place(unit: UnitActor, point: Vector2) -> void:
	unit.world_position = point
	unit.position = Iso.project(point)
	unit.hold_position()

func empty_lane() -> void:
	arena.start_match(0)
	for unit in arena.units.duplicate():
		if unit != arena.player:
			arena.units.erase(unit)
			unit.free()
	place(arena.player, Vector2.ZERO)
	arena.wave_timer = 9999

func dummy(team: int, role: UnitActor.Role, point: Vector2) -> UnitActor:
	var unit: UnitActor = arena.spawn_unit(team, role, point)
	unit.speed = 0
	unit.attack_timer = 9999
	return unit

func click(point: Vector2, advancing: bool = false) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.pressed = pressed
		event.button_index = MOUSE_BUTTON_LEFT
		event.shift_pressed = advancing
		root.push_input(event, true)

func key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event, true)

func advance(seconds: float) -> void:
	for i in ceili(seconds / 0.05):
		arena.simulate(0.05)

func test_orders() -> void:
	empty_lane()
	var enemy := dummy(1, UnitActor.Role.TROOP, Vector2(70, 0))
	arena.command_move(Vector2(260, 0))
	arena.simulate(0.1)
	verify(arena.player.world_position.x > 0 and enemy.hp == enemy.max_hp,
		"A move order passes enemies without interrupting movement to attack")
	place(arena.player, Vector2.ZERO)
	arena.command_move(Vector2(260, 0), true)
	arena.simulate(0.1)
	verify(arena.player.world_position == Vector2.ZERO and enemy.hp < enemy.max_hp,
		"Attack-move stops and fires at an opponent in range")
	enemy.take_damage(1000, arena.player)
	arena.simulate(0.1)
	verify(arena.player.world_position.x > 0 and arena.player.destination == Vector2(260, 0),
		"Attack-move resumes its original destination after the enemy dies")
	empty_lane()
	enemy = dummy(1, UnitActor.Role.TROOP, Vector2(180, 0))
	arena.command_attack(enemy)
	arena.simulate(0.1)
	verify(arena.player.world_position.x > 0, "Selecting an enemy explicitly pursues it into attack range")
	key(KEY_SPACE)
	var origin: Vector2 = arena.player.world_position
	place(enemy, origin + Vector2(60, 0))
	arena.simulate(0.1)
	verify(arena.player.world_position == origin and enemy.hp < enemy.max_hp,
		"Space holds position while still allowing attacks within reach")
	place(enemy, origin + Vector2(220, 0))
	advance(1)
	verify(arena.player.world_position == origin and arena.player.attack_target == null,
		"A stopped hero never follows an enemy leaving its attack range")
	var goal := Vector2(240, -70)
	click(arena.world.get_global_transform_with_canvas() * Iso.project(goal), true)
	verify(arena.player.order == UnitActor.Order.ATTACK_MOVE and arena.player.destination.distance_to(goal) < 0.01,
		"Shift-click dispatches attack-move through actual world input")
	click(arena.hud.minimap.get_global_transform_with_canvas() * arena.hud.minimap.project(Vector2(-180, 20)), true)
	verify(arena.player.order == UnitActor.Order.ATTACK_MOVE and arena.player.destination.distance_to(Vector2(-180, 20)) < 0.01,
		"Shift-click on the minimap uses the same attack-move command")
	arena.paused = true
	var destination: Vector2 = arena.player.destination
	arena.command_move(Vector2.ZERO, true)
	arena.command_attack(enemy)
	arena.command_stop()
	verify(arena.player.destination == destination and arena.player.order == UnitActor.Order.ATTACK_MOVE,
		"Pausing blocks movement, attack and stop commands")
	arena.paused = false
	arena.state = arena.State.FINISHED
	arena.command_move(Vector2.ZERO, true)
	verify(arena.player.destination == destination, "A finished match rejects new movement orders")
	empty_lane()
	enemy = dummy(1, UnitActor.Role.TROOP, Vector2(180, 0))
	arena.command_attack(enemy)
	arena.simulate(0.1)
	enemy.take_damage(1000, arena.player)
	origin = arena.player.world_position
	advance(0.5)
	verify(arena.player.world_position == origin, "An explicit attack stops where its target died instead of returning to an old destination")

func test_slow_and_dash() -> void:
	empty_lane()
	var enemy: UnitActor = arena.spawn_unit(1, UnitActor.Role.TROOP, Vector2(140, 0), true)
	enemy.order = UnitActor.Order.MOVE
	enemy.destination = Vector2(550, 0)
	var friend := dummy(0, UnitActor.Role.TROOP, Vector2(30, 0))
	var defense := dummy(1, UnitActor.Role.BARRICADE, Vector2(130, 70))
	arena.cast_pulse()
	verify(enemy.hp == enemy.max_hp - MatchRules.PULSE_DAMAGE and enemy.slow_timer > 0,
		"Impacto damages and slows living enemy troops")
	verify(friend.hp == friend.max_hp and friend.slow_timer == 0 and defense.hp == defense.max_hp and defense.slow_timer == 0,
		"Impacto neither slows allies nor damages or slows structures")
	var remaining: float = enemy.slow_timer
	arena.paused = true
	arena.simulate(2)
	verify(enemy.slow_timer == remaining, "Pause freezes active status effects")
	arena.paused = false
	var origin: Vector2 = enemy.world_position
	arena.simulate(0.1)
	verify(is_equal_approx(enemy.world_position.distance_to(origin), enemy.speed * (1 - MatchRules.PULSE_SLOW) * 0.1),
		"Slow reduces actual movement by the configured percentage")
	advance(MatchRules.PULSE_SLOW_DURATION)
	origin = enemy.world_position
	arena.simulate(0.1)
	verify(enemy.slow_timer == 0 and is_equal_approx(enemy.world_position.distance_to(origin), enemy.speed * 0.1),
		"Movement returns to normal after slow expires")
	empty_lane()
	place(arena.player, Iso.WALK_RECT.end)
	verify(not arena.cast_dash(arena.player.world_position + Vector2(100, 100)) and arena.dash_timer == 0,
		"An outward dash at the lane corner does not waste its cooldown")
	place(arena.player, Vector2.ZERO)
	arena.player.apply_slow(MatchRules.PULSE_SLOW, MatchRules.PULSE_SLOW_DURATION)
	verify(arena.cast_dash(Vector2(400, 0)) and is_equal_approx(arena.player.world_position.x, MatchRules.DASH_DISTANCE),
		"Avanço remains a useful escape while slowed and still respects its distance")

func test_defenses() -> void:
	empty_lane()
	var defense: UnitActor = arena.spawn_unit(1, UnitActor.Role.BARRICADE, Vector2(100, 0))
	var troop := dummy(0, UnitActor.Role.TROOP, Vector2(-70, 0))
	var hero := dummy(1, UnitActor.Role.HERO, Vector2(120, 0))
	arena.simulate(0.05)
	verify(defense.attack_target == troop and defense.windup_target == troop,
		"A defense targets an allied minion before the closer player")
	verify(troop.hp == troop.max_hp, "A defense signals its shot before applying damage")
	dummy(0, UnitActor.Role.TROOP, Vector2(60, 0))
	arena.simulate(0.05)
	verify(defense.attack_target == troop, "A defense keeps its target when another minion moves closer")
	advance(MatchRules.DEFENSE_WINDUP)
	verify(troop.hp == troop.max_hp - defense.damage and arena.player.hp == arena.player.max_hp,
		"The signaled defensive shot hits its minion after the windup")
	hero.take_damage(1, arena.player)
	arena.simulate(0.05)
	verify(defense.attack_target == arena.player and arena.player_under_defense_threat(),
		"Attacking an enemy hero under its defense redirects aggro to the attacker")
	verify(arena.hud.player_state() == "MIRA DA DEFESA / RECUE", "The HUD warns when the defense targets the player")
	advance(1.3)
	verify(arena.player.hp < arena.player.max_hp, "Defensive retaliation applies actual damage")
	advance(MatchRules.DEFENSE_AGGRO_TIME)
	verify(defense.aggro_timer == 0 and defense.attack_target != arena.player,
		"After retaliation expires the defense reacquires a minion")
	empty_lane()
	defense = arena.spawn_unit(1, UnitActor.Role.BARRICADE, Vector2(175, 0))
	arena.simulate(0.05)
	verify(defense.windup_target == arena.player, "An exposed hero receives a visible defensive warning")
	arena.command_move(Vector2(-500, 0))
	advance(0.3)
	verify(arena.player.hp == arena.player.max_hp and defense.windup_target == null,
		"Leaving range during windup cancels the shot without unavoidable damage")
	empty_lane()
	defense = arena.spawn_unit(1, UnitActor.Role.BARRICADE, Vector2(100, 0))
	troop = dummy(0, UnitActor.Role.TROOP, Vector2(-70, 0))
	hero = dummy(1, UnitActor.Role.HERO, Vector2(120, 0))
	arena.simulate(0.05)
	arena.cast_pulse()
	arena.simulate(0.05)
	verify(defense.attack_target == arena.player, "Impacto also triggers defensive protection of a hero")
	place(arena.player, Vector2(-300, 0))
	arena.simulate(0.05)
	verify(defense.attack_target == troop and defense.aggro_target == null,
		"Leaving defensive range releases retaliation immediately")
	# A defeated aggressor can be freed between simulation frames.
	var attacker := dummy(0, UnitActor.Role.HERO, Vector2.ZERO)
	hero.take_damage(1, attacker)
	arena.simulate(0.05)
	attacker.take_damage(1000, hero)
	arena.units.erase(attacker)
	attacker.free()
	arena.simulate(0.05)
	verify(defense.attack_target == troop and defense.aggro_timer == 0,
		"A freed aggressor immediately clears retaliation without disturbing the new minion target later")

func test_bot() -> void:
	empty_lane()
	place(arena.player, Vector2(-500, -100))
	var bot: UnitActor = arena.spawn_unit(1, UnitActor.Role.HERO, Vector2.ZERO)
	bot.hp = 100
	arena.simulate(0.1)
	verify(bot.ai_retreating and bot.destination == MatchRules.FACTIONS[1].spawn_point and bot.world_position.x > 0,
		"A low-health bot stops attacking and physically retreats to its own central")
	var origin: Vector2 = bot.world_position
	arena.paused = true
	arena.simulate(5)
	verify(bot.world_position == origin, "Pause also freezes the retreating bot")
	arena.paused = false
	advance(12)
	verify(bot.alive and bot.hp > 100, "The bot recovers through the same base healing used by the player")
	advance(5)
	verify(not bot.ai_retreating and bot.hp >= bot.max_hp * MatchRules.BOT_RETURN_HEALTH,
		"The bot returns to the route only after recovering enough health")

func test_full_matches() -> void:
	for team in 2:
		arena.start_match(team)
		for i in 18000:
			if arena.player.alive:
				# This pilot uses only the public player commands and abilities.
				var home: Vector2 = MatchRules.FACTIONS[team].spawn_point
				var healing: bool = arena.player.destination == home and arena.player.hp < arena.player.max_hp * 0.85
				if arena.player.hp / arena.player.max_hp < 0.32 or healing:
					if arena.player.destination != home:
						arena.command_retreat()
				else:
					var goal := Vector2(540 if team == 0 else -540, 0)
					if arena.player.order != UnitActor.Order.ATTACK_MOVE:
						arena.command_move(goal, true)
				arena.cast_pulse()
			arena.simulate(0.1)
			if arena.state == arena.State.FINISHED:
				break
		verify(arena.state == arena.State.FINISHED and arena.winner == team,
			"Faction %d can win a full match with attack-move, Q and healing within 30 simulated minutes" % team)
		verify(arena.units.size() < 150, "Faction %d full-match simulation cleans up defeated actors" % team)

func run() -> void:
	create_timer(20).timeout.connect(func() -> void:
		push_error("Gameplay mechanics checks timed out")
		quit(1))
	root.size = Vector2i(1440, 900)
	arena = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	arena.set_process(false)
	await process_frame
	test_orders()
	test_slow_and_dash()
	test_defenses()
	test_bot()
	test_full_matches()
	print("\n%d mechanics checks, %d failures" % [checks, failures])
	arena.free()
	await process_frame
	quit(1 if failures else 0)
