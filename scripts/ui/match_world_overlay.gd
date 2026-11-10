extends Control
## Small health bars and status labels above actual rendered mesh positions.

var view: Control

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if view == null or view.arena == null:
		return
	var font := ThemeDB.fallback_font
	for unit in view.arena.units:
		if not unit.alive:
			continue
		var height := 2.25 if unit.role == UnitActor.Role.HERO else (1.95 if unit.role == UnitActor.Role.TROOP else 1.65)
		var point: Vector2 = view.project(unit.world_position, height)
		var width := 40.0 if unit.role == UnitActor.Role.HERO else (46.0 if unit.role == UnitActor.Role.BARRICADE else 28.0)
		var color := MatchRules.FACTIONS[unit.team].color
		draw_rect(Rect2(point - Vector2(width * 0.5 + 1, 1), Vector2(width + 2, 5)), Color("152220"))
		draw_rect(Rect2(point - Vector2(width * 0.5, 0), Vector2(width * unit.hp / unit.max_hp, 3)), color)
		if unit.role == UnitActor.Role.HERO:
			draw_string(font, point + Vector2(-13, -5), "VOCÊ" if unit.controlled else "BOT", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("eee8d9"))
		if unit.slow_timer > 0 or unit.ai_retreating:
			draw_string(font, point + Vector2(-18, -16), "LENTO" if unit.slow_timer > 0 else "RECUANDO", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("bde3df"))
