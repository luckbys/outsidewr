extends Control
## Markers and click-to-move use the same transform in both directions.

var arena: Node
var map_scale := 0.1
var map_center := Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = "Clique na rota para mover.\nShift + clique: avançar e atacar.\nCírculo branco: você.\nLosangos: barricadas. Quadrados: centrais."

func update_geometry() -> void:
	map_center = Vector2(size.x * 0.5, size.y * 0.5 + 3)
	map_scale = minf((size.x - 24) / 1900.0, (size.y - 58) / 960.0)

func _draw() -> void:
	if arena == null:
		return
	update_geometry()
	draw_style_box(HudTheme.panel(), Rect2(Vector2.ZERO, size))
	draw_string(ThemeDB.fallback_font, Vector2(13, 22), "MAPA TÁTICO", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, HudTheme.GOLD)
	var outline := Iso.diamond(Iso.MAP_RECT)
	for i in outline.size():
		outline[i] = map_center + outline[i] * map_scale
	draw_colored_polygon(outline, Color("344b43"))
	draw_line(project(Vector2(-600, 0)), project(Vector2(600, 0)), Color("9e987a"), 5, true)
	if is_instance_valid(arena.player) and arena.player.alive:
		var goal: Vector2 = arena.player.destination
		if is_instance_valid(arena.player.attack_target) and arena.player.attack_target.alive:
			goal = arena.player.attack_target.world_position
		if arena.player.world_position.distance_to(goal) > 6:
			draw_line(project(arena.player.world_position), project(goal), Color(HudTheme.GOLD, 0.6), 1, true)
			draw_arc(project(goal), 4, 0, TAU, 20, HudTheme.GOLD, 1.5, true)
	for unit in arena.units:
		if not unit.alive:
			continue
		var point := project(unit.world_position)
		var color := MatchRules.FACTIONS[unit.team].color
		if unit.role == UnitActor.Role.CORE:
			draw_rect(Rect2(point - Vector2(3.5, 3.5), Vector2(7, 7)), color)
		elif unit.role == UnitActor.Role.BARRICADE:
			draw_colored_polygon(PackedVector2Array([point + Vector2(0, -4), point + Vector2(4, 0),
				point + Vector2(0, 4), point + Vector2(-4, 0)]), color)
		else:
			draw_circle(point, 3.5 if unit.role == UnitActor.Role.HERO else 1.7, color)
		if unit.controlled:
			draw_arc(point, 6, 0, TAU, 24, HudTheme.TEXT, 1.5, true)
	draw_string(ThemeDB.fallback_font, Vector2(13, size.y - 12), "CLIQUE PARA MOVER", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, HudTheme.MUTED)

func project(point: Vector2) -> Vector2:
	return map_center + Iso.project(point) * map_scale

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if arena.state == arena.State.PLAYING and not arena.paused and arena.player.alive:
			update_geometry()
			var point := Iso.unproject((event.position - map_center) / map_scale)
			arena.command_move(Iso.clamp_to_lane(point), event.shift_pressed)
		accept_event()
