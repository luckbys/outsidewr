class_name HudTheme
extends RefCounted
## Shared palette and cached panel styles for the match and 3D inspection HUDs.

const SURFACE := Color("122429")
const RAISED := Color("1e363a")
const BORDER := Color("3b5355")
const TEXT := Color("eee8d9")
const MUTED := Color("a3b5b3")
const GOLD := Color("dfbd7b")
const DANGER := Color("f19279")
static var panels: Dictionary = {}

static func panel(fill: Color = SURFACE, stroke: Color = BORDER, radius: int = 7, border_width: int = 1) -> StyleBoxFlat:
	var key := "%s/%s/%d/%d" % [fill.to_html(), stroke.to_html(), radius, border_width]
	if not panels.has(key):
		var style := StyleBoxFlat.new()
		style.bg_color = fill
		style.border_color = stroke
		style.set_corner_radius_all(radius)
		style.set_border_width_all(border_width)
		panels[key] = style
	return panels[key]

static func button(control: Button, fill: Color = RAISED, text: Color = TEXT) -> void:
	control.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	control.add_theme_font_size_override("font_size", 14)
	control.add_theme_color_override("font_color", text)
	control.add_theme_color_override("font_hover_color", text)
	control.add_theme_color_override("font_pressed_color", text)
	control.add_theme_color_override("font_disabled_color", MUTED.darkened(0.2))
	control.add_theme_stylebox_override("normal", panel(fill))
	control.add_theme_stylebox_override("hover", panel(fill.lightened(0.08), GOLD))
	control.add_theme_stylebox_override("pressed", panel(fill.darkened(0.08), GOLD, 7, 2))
	control.add_theme_stylebox_override("disabled", panel(SURFACE, BORDER.darkened(0.15)))
	control.add_theme_stylebox_override("focus", panel(Color.TRANSPARENT, GOLD, 7, 2))
	control.add_theme_constant_override("outline_size", 0)
