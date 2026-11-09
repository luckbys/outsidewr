extends SceneTree
## Integration checks run the actual scene and simulation, not substitute objects.

var checks := 0
var failures := 0
var arena: Node

func _initialize() -> void:
	call_deferred("run")

func verify(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
	else:
		print("PASS: " + message)

func run() -> void:
	arena = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	arena.set_process(false)
	verify(arena.state == arena.State.MENU, "Scene opens at faction selection")
	verify(arena.units.size() == 8, "Both sides have a hero, two barricades and a core")
	for point in [Vector2(-521, 110), Vector2(380, -70), Vector2.ZERO]:
		verify(Iso.unproject(Iso.project(point)).distance_to(point) < 0.001, "Isometric picking round trip")
	arena.start_match(0)
	verify(arena.player.team == 0 and arena.player.controlled, "Police selection assigns the player")
	arena.spawn_wave()
	verify(arena.units.size() == 14, "A wave spawns three troops on each side")
	arena.command_move(Vector2(2000, 2000))
	verify(arena.player.destination == Iso.WALK_RECT.end, "Movement cannot leave the walkable lane")
	var origin: Vector2 = arena.player.world_position
	arena.simulate(0.1)
	verify(arena.player.world_position.distance_to(origin) > 0, "Move commands advance the actual hero")
	verify(arena.player.position.distance_to(Iso.project(arena.player.world_position)) < 0.001,
		"Rendered and logical hero positions stay aligned")
	# Abilities, friendly fire, cooldowns and range.
	arena.start_match(0)
	var opponent: UnitActor = arena.spawn_unit(1, UnitActor.Role.TROOP, arena.player.world_position + Vector2(40, 0))
	var distant: UnitActor = arena.spawn_unit(1, UnitActor.Role.TROOP, arena.player.world_position + Vector2(200, 0))
	var friend: UnitActor = arena.spawn_unit(0, UnitActor.Role.TROOP, arena.player.world_position + Vector2(20, 0))
	verify(arena.cast_pulse(), "Q activates")
	verify(opponent.hp == opponent.max_hp - MatchRules.PULSE_DAMAGE, "Q damages a nearby enemy")
	verify(friend.hp == friend.max_hp and distant.hp == distant.max_hp, "Q respects team and radius")
	verify(not arena.cast_pulse(), "Q cannot bypass its cooldown")
	friend.take_damage(50, arena.player)
	verify(friend.hp == friend.max_hp, "Regular attacks reject friendly fire")
	origin = arena.player.world_position
	verify(arena.cast_dash(origin + Vector2(300, 0)), "E activates")
	verify(is_equal_approx(arena.player.world_position.distance_to(origin), MatchRules.DASH_DISTANCE), "E moves the hero the configured distance")
	verify(not arena.cast_dash(origin), "E cannot bypass its cooldown")
	# Barricades gate victory; a dead core must stop the match.
	arena.start_match(0)
	var core: UnitActor
	for unit in arena.units:
		if unit.team == 1 and unit.role == UnitActor.Role.CORE:
			core = unit
	core.take_damage(50, arena.player)
	verify(core.hp == core.max_hp, "An intact barricade protects its core")
	for unit in arena.units.duplicate():
		if unit.team == 1 and unit.role == UnitActor.Role.BARRICADE:
			unit.take_damage(10000, arena.player)
	core.take_damage(50, arena.player)
	verify(core.hp == core.max_hp - 50, "Destroying both barricades unlocks core damage")
	core.take_damage(10000, arena.player)
	verify(arena.state == arena.State.FINISHED and arena.winner == 0, "Destroying the enemy core produces victory")
	var time: float = arena.elapsed
	arena.simulate(3)
	verify(arena.elapsed == time, "A completed match no longer simulates")
	# Switching factions also resets all transient state.
	arena.start_match(1)
	verify(arena.player.team == 1 and arena.units.size() == 8 and arena.winner == -1,
		"Replay switches factions and clears the previous match")
	arena.paused = true
	time = arena.elapsed
	arena.simulate(2)
	verify(arena.elapsed == time, "Pause freezes simulation and timers")
	arena.paused = false
	var old_player: UnitActor = arena.player
	var enemy: UnitActor
	for unit in arena.units:
		if unit.team == 0 and unit.role == UnitActor.Role.HERO:
			enemy = unit
	old_player.take_damage(10000, enemy)
	verify(not old_player.alive and arena.deaths == 1, "Player defeat schedules a respawn")
	for i in 82:
		arena.simulate(0.1)
	verify(arena.player != old_player and arena.player.alive and arena.player.team == 1,
		"Player respawns on the correct faction after the countdown")
	# Exercise actual autonomous combat over multiple ticks.
	arena.start_match(0)
	var left: UnitActor = arena.spawn_unit(0, UnitActor.Role.TROOP, Vector2(-20, -70))
	var right: UnitActor = arena.spawn_unit(1, UnitActor.Role.TROOP, Vector2(20, -70))
	for i in 10:
		arena.simulate(0.1)
	verify(left.hp < left.max_hp and right.hp < right.max_hp, "Opposing troops acquire targets and exchange damage")
	# A hero that advances and uses Q should be able to win a full match.
	# Equal bots can legitimately hold the lane; the player's ability breaks that tie.
	arena.start_match(0)
	arena.player.controlled = false
	for i in 12000:
		arena.cast_pulse()
		arena.simulate(0.1)
		if arena.player.alive:
			arena.player.controlled = false
		if arena.state == arena.State.FINISHED:
			break
	verify(arena.state == arena.State.FINISHED and arena.winner == 0,
		"An advancing hero using Q can win a complete match within 20 simulated minutes")
	verify(arena.units.size() < 150, "Dead actors are cleaned up during a full match")
	print("\n%d checks, %d failures" % [checks, failures])
	arena.free()
	await process_frame
	quit(1 if failures > 0 else 0)
