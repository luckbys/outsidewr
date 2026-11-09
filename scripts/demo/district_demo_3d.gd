extends Node3D

const CREAM := Color("efe7d2")
const MUTED := Color("adbcad")
@onready var rig: Node3D = $CameraRig
@onready var district: Node3D = $District
var navigation_button: Button
var last_label_scale := -1.0

func _ready() -> void:
	create_interface()
	update_label_sizes()

func _process(_delta: float) -> void:
	update_label_sizes()

func update_label_sizes() -> void:
	var height := maxf(1, get_viewport().get_visible_rect().size.y)
	var label_scale: float = rig.camera.size / height * 0.42
	if is_equal_approx(label_scale, last_label_scale):
		return
	last_label_scale = label_scale
	for point in district.get_node("PointsOfInterest").get_children():
		if point.has_node("Label"):
			point.get_node("Label").pixel_size = label_scale
	for unit in district.get_node("Units").get_children():
		unit.get_node("Character/Nameplate").pixel_size = label_scale

func create_interface() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Interface"
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	var top := PanelContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 24
	top.offset_right = -24
	top.offset_top = 20
	top.offset_bottom = 102
	top.add_theme_stylebox_override("panel", panel_style())
	root.add_child(top)
	var title_box := VBoxContainer.new()
	title_box.add_theme_constant_override("separation", 5)
	top.add_child(title_box)
	label(title_box, "MORRO DO SOL / AMBIENTE 3D", 25, CREAM)
	label(title_box, "Casas e lajes | Rota central | Azul e coral | Escala: 1 unidade = 1 metro", 13, MUTED)
	var bottom := PanelContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 24
	bottom.offset_right = -24
	bottom.offset_top = -119
	bottom.offset_bottom = -20
	bottom.add_theme_stylebox_override("panel", panel_style())
	root.add_child(bottom)
	var bottom_box := VBoxContainer.new()
	bottom_box.add_theme_constant_override("separation", 12)
	bottom.add_child(bottom_box)
	label(bottom_box, "WASD: mover | Q/E ou mouse direito: girar | Roda: zoom | Mouse do meio: arrastar | Home: restaurar", 13, CREAM)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	bottom_box.add_child(actions)
	button(actions, "Vista geral", rig.reset_view)
	button(actions, "Central Azul", func() -> void:
		rig.frame_point(district.get_node("PointsOfInterest/PoliceCore").global_position))
	button(actions, "Central Coral", func() -> void:
		rig.frame_point(district.get_node("PointsOfInterest/TrafficCore").global_position))
	navigation_button = button(actions, "Ver navegação", toggle_navigation)
	navigation_button.toggle_mode = true
	button(actions, "Abrir jogo 2D", func() -> void:
		get_tree().change_scene_to_file("res://scenes/main.tscn"))
	button(actions, "Personagens", func() -> void:
		rig.frame_point(Vector3(0, 0, -1.5), 14))
	button(actions, "Barricadas", func() -> void:
		rig.frame_point(district.get_node("PointsOfInterest/PoliceBarricade2").global_position, 12))

func toggle_navigation() -> void:
	district.get_node("Navigation/Preview").visible = navigation_button.button_pressed

func label(parent: Node, value: String, font_size: int, color: Color) -> void:
	var control := Label.new()
	control.text = value
	control.add_theme_font_size_override("font_size", font_size)
	control.add_theme_color_override("font_color", color)
	parent.add_child(control)

func button(parent: Node, value: String, action: Callable) -> Button:
	var control := Button.new()
	control.text = value
	control.custom_minimum_size = Vector2(150, 35)
	control.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	control.add_theme_font_size_override("font_size", 14)
	control.add_theme_color_override("font_color", CREAM)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("35554c")
	normal.set_corner_radius_all(4)
	control.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("4d7464")
	control.add_theme_stylebox_override("hover", hover)
	control.pressed.connect(action)
	parent.add_child(control)
	return control

func panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.13, 0.13, 0.95)
	style.border_color = Color("456354")
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style
