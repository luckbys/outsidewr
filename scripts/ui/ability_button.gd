extends Button
## An actual ability button with readable numeric and graphical cooldown state.

var hotkey := "Q"
var title := "IMPACTO"
var remaining := 0.0
var duration := 7.0
var accent := HudTheme.GOLD

func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	HudTheme.button(self)

func _draw() -> void:
	var color := HudTheme.MUTED if disabled else accent
	var font := ThemeDB.fallback_font
	var state := "%.1f s" % remaining if remaining > 0 else ("AGUARDE" if disabled else "PRONTO")
	if size.x < 110:
		draw_string(font, Vector2(12, 25), hotkey, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, color)
		draw_string(font, Vector2(33, 25), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, HudTheme.TEXT)
		draw_string(font, Vector2(12, size.y * 0.5 + 19), state, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)
		var compact_ready := 1.0 - clampf(remaining / maxf(duration, 0.01), 0, 1)
		draw_rect(Rect2(10, size.y - 8, (size.x - 20) * compact_ready, 3), color)
		return
	var center := Vector2(24, size.y * 0.5 - 2)
	draw_arc(center, 15, -PI * 0.5, PI * 1.5, 32, HudTheme.BORDER, 2, true)
	var ready_fraction := 1.0 - clampf(remaining / maxf(duration, 0.01), 0, 1)
	draw_arc(center, 15, -PI * 0.5, -PI * 0.5 + TAU * ready_fraction, 32, color, 2.5, true)
	draw_string(font, center + Vector2(-5, 5), hotkey, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, color)
	var title_size := 13 if size.x >= 130 else 11
	draw_string(font, Vector2(49, size.y * 0.5 - 6), title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, HudTheme.TEXT)
	draw_string(font, Vector2(49, size.y * 0.5 + 15), state, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, color)
	var track := Rect2(10, size.y - 8, size.x - 20, 3)
	draw_rect(track, HudTheme.BORDER.darkened(0.3))
	draw_rect(Rect2(track.position, Vector2(track.size.x * ready_fraction, 3)), color)

func update_state(cooldown: float, available: bool, team_color: Color) -> void:
	remaining = maxf(0, cooldown)
	disabled = not available or remaining > 0
	accent = team_color
	queue_redraw()
