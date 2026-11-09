extends Control
## Screen-space UI is independent of the isometric world transform.

const INK := Color("102b2c")
const CREAM := Color("efe7d2")
const MUTED := Color("99ada3")
const GOLD := Color("e2bd78")

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
var overlay_kind := "menu"

func bind_match(match_node: Node) -> void:
	arena = match_node
	pulse_button = make_button("Q   IMPACTO", Color("304b45"), CREAM)
	dash_button = make_button("E   AVANÇO", Color("304b45"), CREAM)
	add_child(pulse_button)
	add_child(dash_button)
	pulse_button.pressed.connect(func() -> void: arena.cast_pulse())
	dash_button.pressed.connect(func() -> void: arena.cast_dash(arena.mouse_world_position()))
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.065, 0.065, 0.77)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(shade)
	modal = Panel.new()
	modal.add_theme_stylebox_override("panel", panel_style(CREAM, Color("b8b59b"), 2, 12))
	overlay.add_child(modal)
	heading = Label.new()
	heading.add_theme_font_size_override("font_size", 55)
	heading.add_theme_color_override("font_color", INK)
	heading.position = Vector2(36, 65)
	modal.add_child(heading)
	description = Label.new()
	description.add_theme_font_size_override("font_size", 17)
	description.add_theme_color_override("font_color", Color("50665c"))
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
	blue_button = make_button("POLÍCIA\nEquipe Azul", Color("3a7183"), Color("fff6df"))
	coral_button = make_button("TRÁFICO\nEquipe Coral", Color("ae5a45"), Color("fff6df"))
	blue_button.position = Vector2(38, 335)
	coral_button.position = Vector2(333, 335)
	for button in [blue_button, coral_button]:
		button.size = Vector2(269, 81)
		modal.add_child(button)
	blue_button.pressed.connect(func() -> void: arena.start_match(0))
	coral_button.pressed.connect(func() -> void: arena.start_match(1))
	secondary_button = make_button("", INK, CREAM)
	secondary_button.position = Vector2(38, 432)
	secondary_button.size = Vector2(564, 48)
	secondary_button.pressed.connect(on_secondary_pressed)
	modal.add_child(secondary_button)
	var footer := Label.new()
	footer.text = "UNIVERSO FICTÍCIO  ·  PARTIDA LOCAL CONTRA BOT  ·  v0.1"
	footer.position = Vector2(38, 503)
	footer.add_theme_font_size_override("font_size", 11)
	footer.add_theme_color_override("font_color", Color("627668"))
	modal.add_child(footer)
	resized.connect(layout_controls)
	layout_controls()

func layout_controls() -> void:
	if modal == null:
		return
	modal.size = Vector2(640, 548)
	modal.position = (size - modal.size) * 0.5
	pulse_button.position = Vector2(401, size.y - 100)
	dash_button.position = Vector2(592, size.y - 100)
	pulse_button.size = Vector2(179, 67)
	dash_button.size = Vector2(179, 67)

func show_menu() -> void:
	overlay_kind = "menu"
	overlay.show()
	heading.text = "MORRO\nEM DISPUTA"
	description.text = "Duas equipes. Uma rota. A disputa pelo Morro do Sol.\nEscolha seu lado, acompanhe as tropas e derrube a central rival."
	blue_button.show()
	coral_button.show()
	secondary_button.hide()

func hide_overlay() -> void:
	overlay.hide()

func show_pause() -> void:
	overlay_kind = "pause"
	overlay.show()
	heading.text = "RESPIRE.\nJOGO PAUSADO."
	description.text = "Clique no chão para andar e em um rival para atacar.\nQ: impacto em área. E: avanço em direção ao cursor."
	blue_button.hide()
	coral_button.hide()
	secondary_button.text = "CONTINUAR   /   ESC"
	secondary_button.show()

func show_result(victory: bool) -> void:
	overlay_kind = "result"
	overlay.show()
	heading.text = "CENTRAL\nCONQUISTADA." if victory else "A CENTRAL\nCAIU."
	description.text = ("Vitória! " if victory else "Derrota. ") + "A partida terminou em %s.\nEscolha uma equipe abaixo para jogar novamente." % clock_text(arena.elapsed)
	blue_button.show()
	coral_button.show()
	secondary_button.hide()

func on_secondary_pressed() -> void:
	if overlay_kind == "pause":
		arena.paused = false
		hide_overlay()

func _process(_delta: float) -> void:
	if arena == null:
		return
	var active: bool = arena.state == arena.State.PLAYING and not arena.paused and arena.player.alive
	pulse_button.disabled = not active or arena.pulse_timer > 0
	dash_button.disabled = not active or arena.dash_timer > 0
	pulse_button.text = "Q   IMPACTO\n%s" % ("Área · 7 s" if arena.pulse_timer <= 0 else "%.1f s" % arena.pulse_timer)
	dash_button.text = "E   AVANÇO\n%s" % ("Mobilidade · 5 s" if arena.dash_timer <= 0 else "%.1f s" % arena.dash_timer)

func _draw() -> void:
	if arena == null:
		return
	var w := size.x
	var h := size.y
	# Match header.
	box(Rect2(24, 22, w - 48, 76), Color("112c2c"), Color("3b5146"))
	text_at(Vector2(43, 54), "M /", 27, GOLD)
	text_at(Vector2(107, 51), "MORRO EM DISPUTA", 17, CREAM)
	text_at(Vector2(107, 75), "MORRO DO SOL  /  PROTÓTIPO 0.1", 11, MUTED)
	text_at(Vector2(w / 2 - 26, 54), clock_text(arena.elapsed), 22, CREAM)
	text_at(Vector2(w / 2 - 32, 76), "TEMPO DE JOGO", 9, MUTED)
	for team in 2:
		var x: float = w / 2 - 254 if team == 0 else w / 2 + 84
		var color := MatchRules.FACTIONS[team].color
		text_at(Vector2(x, 51), MatchRules.FACTIONS[team].title, 12, color)
		bar(Rect2(x, 63, 171, 5), arena.core_health(team), color)
	# A small live tactical map; every dot corresponds to an actual living unit.
	box(Rect2(w - 235, 117, 211, 133), Color("112c2c"), Color("3b5146"))
	text_at(Vector2(w - 220, 141), "MAPA DA ROTA", 11, MUTED)
	var map_origin := Vector2(w - 129, 190)
	draw_colored_polygon(PackedVector2Array([map_origin + Vector2(-91, 0), map_origin + Vector2(0, -31),
		map_origin + Vector2(91, 0), map_origin + Vector2(0, 31)]), Color("44584b"))
	draw_line(map_origin + Vector2(-70, -24), map_origin + Vector2(70, 24), Color("a19474"), 5, true)
	for unit in arena.units:
		if unit.alive:
			var point: Vector2 = map_origin + Iso.project(unit.world_position) * Vector2(0.16, 0.10)
			draw_circle(point, 3.5 if unit.role != UnitActor.Role.TROOP else 1.8,
				MatchRules.FACTIONS[unit.team].color)
	text_at(Vector2(w - 218, 235), "AZUL / OESTE     |     CORAL / LESTE", 9, MUTED)
	text_at(Vector2(29, 130), "01 / A DISPUTA", 12, GOLD)
	text_at(Vector2(29, 153), "Derrube as barricadas. Avance à central.", 14, CREAM)
	text_at(Vector2(29, 177), "Próxima tropa: %02ds   ·   Onda %d" % [ceili(arena.wave_timer), arena.wave_number], 12, MUTED)
	# Player card and abilities.
	box(Rect2(24, h - 116, 359, 100), Color("112c2c"), Color("3b5146"))
	var color := MatchRules.FACTIONS[arena.player_team].color
	draw_circle(Vector2(64, h - 67), 24, Color("304c47"))
	draw_arc(Vector2(64, h - 67), 24, 0, TAU, 32, color, 2, true)
	text_at(Vector2(53, h - 59), "A" if arena.player_team == 0 else "O", 24, color)
	text_at(Vector2(104, h - 86), MatchRules.FACTIONS[arena.player_team].hero_name.to_upper(), 16, CREAM)
	text_at(Vector2(104, h - 66), "POLÍCIA / AZUL" if arena.player_team == 0 else "TRÁFICO / CORAL", 10, color)
	bar(Rect2(104, h - 53, 252, 8), arena.player.hp / arena.player.max_hp, color)
	text_at(Vector2(104, h - 27), "%d / %d PV    ·    %d abates    ·    %d quedas" % [
		int(arena.player.hp), int(arena.player.max_hp), arena.takedowns, arena.deaths], 11, MUTED)
	if w > 1050:
		box(Rect2(791, h - 116, w - 815, 100), Color("112c2c"), Color("3b5146"))
		text_at(Vector2(811, h - 88), "SEU PRÓXIMO MOVIMENTO", 11, GOLD)
		text_at(Vector2(811, h - 65), "Clique: mover / atacar   ·   WASD: andar", 13, CREAM)
		text_at(Vector2(811, h - 40), "Espaço: parar   ·   Esc: pausar   ·   Base: curar", 12, MUTED)
	if not arena.player.alive and arena.state == arena.State.PLAYING:
		box(Rect2(w / 2 - 195, h / 2 - 36, 390, 72), Color("112c2c"), GOLD)
		text_at(Vector2(w / 2 - 168, h / 2 + 5), "RETORNO À BASE EM %d s" % ceili(arena.respawn_timers[arena.player_team]), 21, CREAM)
	elif arena.notice_timer > 0:
		var width := minf(w - 80, 780)
		box(Rect2((w - width) / 2, h - 166, width, 34), Color(0.06, 0.15, 0.14, 0.92), Color("607260"))
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2((w - width) / 2 + 15, h - 143), arena.notice,
			HORIZONTAL_ALIGNMENT_CENTER, width - 30, 13, CREAM)

func text_at(point: Vector2, value: String, font_size: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, point, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func box(rect: Rect2, fill: Color, border: Color) -> void:
	draw_style_box(panel_style(fill, border, 1, 5), rect)

func bar(rect: Rect2, ratio: float, color: Color) -> void:
	draw_rect(rect, Color("31463f"))
	draw_rect(Rect2(rect.position, Vector2(rect.size.x * clampf(ratio, 0, 1), rect.size.y)), color)

func panel_style(fill: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	return style

func make_button(value: String, fill: Color, foreground: Color) -> Button:
	var button := Button.new()
	button.text = value
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", foreground)
	button.add_theme_color_override("font_hover_color", foreground)
	button.add_theme_color_override("font_pressed_color", foreground)
	button.add_theme_color_override("font_disabled_color", MUTED)
	button.add_theme_stylebox_override("normal", panel_style(fill, fill.lightened(0.1), 1, 5))
	button.add_theme_stylebox_override("hover", panel_style(fill.lightened(0.12), GOLD, 2, 5))
	button.add_theme_stylebox_override("pressed", panel_style(fill.darkened(0.1), GOLD, 2, 5))
	button.add_theme_stylebox_override("disabled", panel_style(Color("223a35"), Color("3b5146"), 1, 5))
	button.add_theme_stylebox_override("focus", panel_style(Color(0, 0, 0, 0), GOLD, 2, 5))
	return button

func clock_text(seconds: float) -> String:
	return "%02d:%02d" % [int(seconds) / 60, int(seconds) % 60]
