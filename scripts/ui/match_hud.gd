extends Control
## Responsive match HUD; every counter and action reflects the actual simulation.

const AbilityButton = preload("res://scripts/ui/ability_button.gd")
const TacticalMinimap = preload("res://scripts/ui/tactical_minimap.gd")
const CREAM := HudTheme.TEXT
const MUTED := HudTheme.MUTED
const GOLD := HudTheme.GOLD

var arena: Node
var overlay: Control
var modal: Panel
var heading: Label
var description: Label
var blue_button: Button
var coral_button: Button
var secondary_button: Button
var pulse_button: Button
var dash_button: Button
var retreat_button: Button
var pause_button: Button
var minimap: Control
var overlay_kind := "menu"
var header_rect := Rect2()
var hero_rect := Rect2()
var skills_rect := Rect2()
var objective_rect := Rect2()
var target_rect := Rect2()
var hints_rect := Rect2()
var header_hit: Control
var hero_hit: Control
var objective_hit: Control
var target_hit: Control
var hints_hit: Control

func bind_match(match_node: Node) -> void:
	arena = match_node
	header_hit = hit_zone()
	hero_hit = hit_zone()
	objective_hit = hit_zone()
	target_hit = hit_zone()
	hints_hit = hit_zone()
	pulse_button = skill("Q", "IMPACTO", MatchRules.PULSE_COOLDOWN,
		"Q / Impacto\n%d de dano em área contra heróis e minions.\nRecarga de %d s." % [MatchRules.PULSE_DAMAGE, MatchRules.PULSE_COOLDOWN])
	dash_button = skill("E", "AVANÇO", MatchRules.DASH_COOLDOWN,
		"E / Avanço\nAvança na última direção apontada no mapa.\nRecarga de %d s." % MatchRules.DASH_COOLDOWN)
	retreat_button = skill("B", "RECUAR", 0,
		"B / Recuar\nCaminha até sua central para recuperar vida.")
	pulse_button.pressed.connect(func() -> void: arena.cast_pulse())
	dash_button.pressed.connect(func() -> void: arena.cast_dash(arena.aim_position))
	retreat_button.pressed.connect(func() -> void: arena.command_retreat())
	minimap = TacticalMinimap.new()
	minimap.name = "TacticalMinimap"
	minimap.arena = arena
	add_child(minimap)
	pause_button = make_button("II", HudTheme.RAISED, CREAM)
	pause_button.focus_mode = Control.FOCUS_NONE
	pause_button.tooltip_text = "Pausar a partida e consultar controles / Esc"
	pause_button.pressed.connect(func() -> void: arena.toggle_pause())
	add_child(pause_button)
	create_overlay()
	resized.connect(layout_controls)
	layout_controls()

func skill(key: String, title: String, duration: float, hint: String) -> Button:
	var control := AbilityButton.new()
	control.hotkey = key
	control.title = title
	control.duration = duration
	control.tooltip_text = hint
	add_child(control)
	return control

func hit_zone() -> Control:
	var control := Control.new()
	control.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(control)
	return control

func create_overlay() -> void:
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.055, 0.065, 0.82)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(shade)
	modal = Panel.new()
	modal.add_theme_stylebox_override("panel", HudTheme.panel(Color("ede6d5"), Color("bbb69f"), 12, 2))
	overlay.add_child(modal)
	heading = Label.new()
	heading.add_theme_font_size_override("font_size", 52)
	heading.add_theme_color_override("font_color", Color("112c30"))
	heading.position = Vector2(36, 65)
	modal.add_child(heading)
	description = Label.new()
	description.add_theme_font_size_override("font_size", 19)
	description.add_theme_color_override("font_color", Color("45605a"))
	description.position = Vector2(38, 230)
	description.size = Vector2(565, 90)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal.add_child(description)
	var kicker := Label.new()
	kicker.text = "MORRO DO SOL   /   MOBA ISOMÉTRICO"
	kicker.position = Vector2(38, 31)
	kicker.add_theme_font_size_override("font_size", 13)
	kicker.add_theme_color_override("font_color", Color("627668"))
	modal.add_child(kicker)
	blue_button = make_button("POLÍCIA\nEquipe Azul", Color("3a7183"), CREAM)
	coral_button = make_button("TRÁFICO\nEquipe Coral", Color("ae5a45"), CREAM)
	blue_button.position = Vector2(38, 335)
	coral_button.position = Vector2(333, 335)
	for control in [blue_button, coral_button]:
		control.size = Vector2(269, 81)
		control.add_theme_font_size_override("font_size", 20)
		modal.add_child(control)
	blue_button.pressed.connect(func() -> void: arena.start_match(0))
	coral_button.pressed.connect(func() -> void: arena.start_match(1))
	secondary_button = make_button("", HudTheme.SURFACE, CREAM)
	secondary_button.position = Vector2(38, 432)
	secondary_button.size = Vector2(564, 48)
	secondary_button.pressed.connect(on_secondary_pressed)
	modal.add_child(secondary_button)
	var footer := Label.new()
	footer.text = "PARTIDA LOCAL CONTRA BOT   /   UNIVERSO FICTÍCIO"
	footer.position = Vector2(38, 503)
	footer.add_theme_font_size_override("font_size", 12)
	footer.add_theme_color_override("font_color", Color("627668"))
	modal.add_child(footer)

func place(control: Control, rect: Rect2) -> void:
	control.position = rect.position
	control.size = rect.size

func layout_controls() -> void:
	if modal == null:
		return
	var w := size.x
	var h := size.y
	var margin := 20.0 if w >= 760 else 12.0
	header_rect = Rect2(margin, 16, w - margin * 2, 76)
	place(header_hit, header_rect)
	place(pause_button, Rect2(w - margin - 52, 33, 38, 38))
	if w >= 760:
		var hero_width := 278.0 if w >= 1180 else 236.0
		var map_width := 222.0 if w >= 1180 else 176.0
		hero_rect = Rect2(margin, h - margin - 108, hero_width, 108)
		var available := w - margin * 2 - hero_width - map_width - 32
		var skill_width := minf(420, available)
		skills_rect = Rect2(hero_rect.end.x + 16, h - margin - 108, skill_width, 108)
		place(minimap, Rect2(w - margin - map_width, h - margin - 174, map_width, 174))
		objective_rect = Rect2(margin, 106, 302, 92)
		target_rect = Rect2(skills_rect.position.x, skills_rect.position.y - 78, skill_width, 66)
		var extra := minimap.position.x - skills_rect.end.x - 28
		hints_rect = Rect2(skills_rect.end.x + 14, h - margin - 108, maxf(0, extra), 108)
	else:
		hero_rect = Rect2(margin, h - margin - 92, w - margin * 2, 92)
		skills_rect = Rect2(margin, hero_rect.position.y - 90, hero_rect.size.x, 78)
		place(minimap, Rect2(w - margin - 144, 106, 144, 136))
		objective_rect = Rect2(margin, 106, maxf(155, w - margin * 2 - 156), 110)
		target_rect = Rect2(margin, skills_rect.position.y - 76, skills_rect.size.x, 64)
		hints_rect = Rect2()
	place(hero_hit, hero_rect)
	place(objective_hit, objective_rect)
	place(target_hit, target_rect)
	target_hit.visible = h >= 650
	place(hints_hit, hints_rect)
	hints_hit.visible = hints_rect.size.x >= 155
	var gap := 8.0
	var card_width := (skills_rect.size.x - gap * 2) / 3
	for i in 3:
		var control: Button = [pulse_button, dash_button, retreat_button][i]
		place(control, Rect2(skills_rect.position + Vector2(i * (card_width + gap), 0), Vector2(card_width, skills_rect.size.y)))
	modal.size = Vector2(640, 548)
	var factor := minf(1, minf((w - 28) / 640, (h - 28) / 548))
	modal.scale = Vector2.ONE * factor
	modal.position = (size - modal.size * factor) * 0.5
	minimap.update_geometry()
	queue_redraw()

func show_menu() -> void:
	overlay_kind = "menu"
	overlay.show()
	heading.text = "MORRO\nEM DISPUTA"
	description.text = "Duas equipes. Uma rota.\nAcompanhe as tropas, rompa as barricadas e conquiste a central rival."
	blue_button.show()
	coral_button.show()
	secondary_button.hide()

func hide_overlay() -> void:
	overlay.hide()

func show_pause() -> void:
	overlay_kind = "pause"
	overlay.show()
	heading.text = "PARTIDA\nEM PAUSA."
	description.text = "Clique: mover / atacar. WASD: mover.\nQ: impacto. E: avanço. B: recuar. Espaço: parar. Esc: continuar."
	blue_button.hide()
	coral_button.hide()
	secondary_button.text = "CONTINUAR   /   ESC"
	secondary_button.show()

func show_result(victory: bool) -> void:
	overlay_kind = "result"
	overlay.show()
	heading.text = "CENTRAL\nCONQUISTADA." if victory else "A CENTRAL\nCAIU."
	description.text = ("Vitória! " if victory else "Derrota. ") + "%s de partida | %d alvos | %d quedas\nEscolha uma equipe para jogar novamente." % [clock_text(arena.elapsed), arena.takedowns, arena.deaths]
	blue_button.show()
	coral_button.show()
	secondary_button.hide()

func on_secondary_pressed() -> void:
	if overlay_kind == "pause":
		arena.toggle_pause()

func _process(_delta: float) -> void:
	if arena == null or not is_instance_valid(arena.player):
		return
	var active: bool = arena.state == arena.State.PLAYING and not arena.paused and arena.player.alive
	var color: Color = MatchRules.FACTIONS[arena.player_team].color
	pulse_button.update_state(arena.pulse_timer, active, color)
	dash_button.update_state(arena.dash_timer, active, color)
	retreat_button.update_state(0, active, color)
	minimap.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if active else Control.CURSOR_ARROW
	minimap.queue_redraw()
	queue_redraw()

func defense_count(team: int) -> int:
	var count := 0
	for unit in arena.units:
		if unit.alive and unit.team == team and unit.role == UnitActor.Role.BARRICADE:
			count += 1
	return count

func _draw() -> void:
	if arena == null or not is_instance_valid(arena.player):
		return
	draw_header()
	draw_objectives()
	draw_hero()
	if size.y >= 650:
		draw_target()
	if hints_rect.size.x >= 155:
		box(hints_rect)
		text_at(hints_rect.position + Vector2(14, 26), "CONTROLE DA ROTA", 11, GOLD)
		text_at(hints_rect.position + Vector2(14, 50), "Clique / WASD: mover", 12, CREAM)
		text_at(hints_rect.position + Vector2(14, 71), "Espaço: parar", 12, MUTED)
		text_at(hints_rect.position + Vector2(14, 92), "Esc: pausa e controles", 11, MUTED)
	if not arena.player.alive and arena.state == arena.State.PLAYING:
		var rect := Rect2(size.x * 0.5 - 180, size.y * 0.5 - 36, 360, 72)
		box(rect, HudTheme.SURFACE, GOLD)
		text_at(rect.position + Vector2(18, 29), "RETORNANDO À CENTRAL", 16, CREAM)
		text_at(rect.position + Vector2(18, 54), "%d s para voltar à partida" % ceili(arena.respawn_timers[arena.player_team]), 15, GOLD)
	elif arena.notice_timer > 0 and not overlay.visible:
		var width := minf(size.x - 40, 760)
		var y := maxf(230, target_rect.position.y - 42) if size.y >= 650 else 208.0
		var rect := Rect2((size.x - width) * 0.5, y, width, 32)
		box(rect, Color(0.07, 0.14, 0.16, 0.96), HudTheme.BORDER)
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(12, 22), arena.notice,
			HORIZONTAL_ALIGNMENT_CENTER, width - 24, 12, CREAM)

func draw_header() -> void:
	box(header_rect)
	if size.x >= 600:
		text_at(header_rect.position + Vector2(16, 45), "M /", 24, GOLD)
	if size.x >= 1180:
		text_at(header_rect.position + Vector2(78, 32), "MORRO EM DISPUTA", 16, CREAM)
		text_at(header_rect.position + Vector2(78, 53), "MORRO DO SOL", 10, MUTED)
	var center := size.x * 0.5 if size.x >= 600 else (size.x - 64) * 0.5
	text_at(Vector2(center - 28, 49), clock_text(arena.elapsed), 23, CREAM)
	text_at(Vector2(center - 29, 70), "ONDA %02d" % arena.wave_number, 10, GOLD)
	var team_width := minf(220, (size.x - (260 if size.x >= 600 else 120)) / 3)
	var spacing := 70.0 if size.x >= 600 else 50.0
	for team in 2:
		var x := center - spacing - team_width if team == 0 else center + spacing
		var color := MatchRules.FACTIONS[team].color
		var ratio: float = arena.core_health(team)
		var caption: String = MatchRules.FACTIONS[team].title if team_width >= 145 else ("AZUL" if team == 0 else "CORAL")
		text_at(Vector2(x, 39), caption, 12, color)
		draw_string(ThemeDB.fallback_font, Vector2(x, 39), "%d%%" % roundi(ratio * 100), HORIZONTAL_ALIGNMENT_RIGHT, team_width, 12, CREAM)
		bar(Rect2(x, 48, team_width, 6), ratio, color)
		text_at(Vector2(x, 72), ("%d/2 BARRICADAS" if team_width >= 170 else "%d/2 BLOQ.") % defense_count(team), 10, MUTED)
		for i in 2:
			var point := Vector2(x + team_width - 18 + i * 10, 66)
			draw_rect(Rect2(point, Vector2(6, 6)), color if i < defense_count(team) else HudTheme.BORDER)

func draw_objectives() -> void:
	box(objective_rect)
	var pos := objective_rect.position
	var enemy: int = 1 - arena.player_team
	var left := defense_count(enemy)
	text_at(pos + Vector2(14, 23), "PRÓXIMO OBJETIVO", 10, GOLD)
	text_at(pos + Vector2(14, 45), "Romper barricadas" if left > 0 else "Conquistar a central", 16, CREAM)
	text_at(pos + Vector2(14, 66), "%d bloqueios inimigos ativos" % left if left > 0 else "Central rival vulnerável", 11, MUTED)
	if objective_rect.size.x >= 260:
		text_at(pos + Vector2(14, 83), "PRÓXIMA TROPA  %02d s" % maxi(0, ceili(arena.wave_timer)), 10, MUTED)
	else:
		text_at(pos + Vector2(14, 89), "Tropas em %d s" % maxi(0, ceili(arena.wave_timer)), 11, MUTED)

func draw_hero() -> void:
	var ratio: float = arena.player.hp / arena.player.max_hp
	var color: Color = MatchRules.FACTIONS[arena.player_team].color
	var low: bool = ratio < 0.3 and arena.player.alive
	box(hero_rect, HudTheme.SURFACE, HudTheme.DANGER if low else HudTheme.BORDER)
	var p := hero_rect.position
	var center := p + Vector2(37, 42)
	draw_circle(center, 23, HudTheme.RAISED)
	draw_arc(center, 24, -PI / 2, PI * 1.5, 32, color, 2, true)
	# Portrait follows the faction's actual cap/helmet and uniform silhouette.
	draw_colored_polygon(PackedVector2Array([center + Vector2(-15, 18), center + Vector2(-10, 3),
		center + Vector2(10, 3), center + Vector2(15, 18)]), Color("304757") if arena.player_team == 0 else Color("53584b"))
	draw_circle(center + Vector2(0, -5), 9, Color("b58161"))
	draw_arc(center + Vector2(0, -8), 10, PI, TAU, 20, Color("24383e"), 7, true)
	if arena.player_team == 1:
		draw_line(center + Vector2(-1, -16), center + Vector2(13, -13), Color("3d494a"), 4, true)
	draw_rect(Rect2(center + Vector2(-6, 6), Vector2(12, 13)), Color("1d2e32"))
	var x := p.x + 75
	text_at(Vector2(x, p.y + 25), MatchRules.FACTIONS[arena.player_team].hero_name.to_upper(), 15, CREAM)
	text_at(Vector2(x, p.y + 43), player_state(), 10, HudTheme.DANGER if low else color)
	var width := hero_rect.size.x - 91
	bar(Rect2(x, p.y + 54, width, 9), ratio, HudTheme.DANGER if low else color)
	text_at(Vector2(x, p.y + 82), "%d / %d PV" % [int(arena.player.hp), int(arena.player.max_hp)], 11, CREAM)
	if hero_rect.size.y >= 100:
		text_at(Vector2(p.x + 15, p.y + 99), "%d ALVOS    /    %d QUEDAS" % [arena.takedowns, arena.deaths], 10, MUTED)

func player_state() -> String:
	if not arena.player.alive:
		return "AGUARDANDO RETORNO"
	var distance: float = arena.player.world_position.distance_to(MatchRules.FACTIONS[arena.player_team].spawn_point)
	if distance < 95 and arena.player.hp < arena.player.max_hp:
		return "RECUPERANDO VIDA"
	if arena.player.hp / arena.player.max_hp < 0.3:
		return "VIDA BAIXA / RECUE"
	if distance < 95:
		return "NA CENTRAL"
	if is_instance_valid(arena.player.attack_target) and arena.player.attack_target.alive:
		return "EM COMBATE"
	return "EM MOVIMENTO" if arena.player.world_position.distance_to(arena.player.destination) > 3 else "POSICIONADO"

func draw_target() -> void:
	box(target_rect)
	var p := target_rect.position
	var target: UnitActor = arena.player.attack_target
	if is_instance_valid(target) and target.alive:
		var role_name: String = {UnitActor.Role.HERO: "HERÓI", UnitActor.Role.TROOP: "MINION",
			UnitActor.Role.BARRICADE: "BARRICADA", UnitActor.Role.CORE: "CENTRAL"}[target.role]
		text_at(p + Vector2(13, 22), "ALVO / " + role_name, 11, MatchRules.FACTIONS[target.team].color)
		bar(Rect2(p + Vector2(13, 33), Vector2(target_rect.size.x - 26, 5)), target.hp / target.max_hp, MatchRules.FACTIONS[target.team].color)
		text_at(p + Vector2(13, 55), "%d / %d PV" % [int(target.hp), int(target.max_hp)], 11, CREAM)
	else:
		text_at(p + Vector2(13, 24), "AVANCE COM SUAS TROPAS", 11, GOLD)
		text_at(p + Vector2(13, 46), "Clique em um rival para selecionar o alvo.", 11, MUTED)

func text_at(point: Vector2, value: String, font_size: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, point, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func box(rect: Rect2, fill: Color = HudTheme.SURFACE, stroke: Color = HudTheme.BORDER) -> void:
	draw_style_box(HudTheme.panel(fill, stroke), rect)

func bar(rect: Rect2, ratio: float, color: Color) -> void:
	draw_rect(rect, HudTheme.BORDER.darkened(0.3))
	draw_rect(Rect2(rect.position, Vector2(rect.size.x * clampf(ratio, 0, 1), rect.size.y)), color)

func make_button(value: String, fill: Color, foreground: Color) -> Button:
	var control := Button.new()
	control.text = value
	HudTheme.button(control, fill, foreground)
	return control

func clock_text(seconds: float) -> String:
	return "%02d:%02d" % [int(seconds) / 60, int(seconds) % 60]
