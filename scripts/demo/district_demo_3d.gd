extends Node3D

const CREAM := HudTheme.TEXT
const MUTED := HudTheme.MUTED
@onready var rig: Node3D = $CameraRig
@onready var district: Node3D = $District
var navigation_button: Button
var last_label_scale := -1.0
var ui_root: Control
var header: PanelContainer
var toolbar: PanelContainer
var action_flow: HFlowContainer
var help_panel: PanelContainer
var status_label: Label
var subtitle: Label
var view_buttons: Array[Button] = []
var view_name := "Vista geral"

func _ready() -> void:
	create_interface()
	update_label_sizes()
	layout_hud()
	select_view(0)

func _process(_delta: float) -> void:
	update_label_sizes()
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_Q) or Input.is_physical_key_pressed(KEY_E):
		mark_free_view()
	var zoom: float = 96.0 / rig.camera.size
	status_label.text = ("%s  /  %.1fx" % [view_name, zoom]) if ui_root.size.x >= 650 else "%.1fx" % zoom

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
	ui_root = Control.new()
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui_root)
	header = PanelContainer.new()
	header.add_theme_stylebox_override("panel", padded_style())
	ui_root.add_child(header)
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 14)
	header.add_child(header_row)
	var brand := VBoxContainer.new()
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brand.add_theme_constant_override("separation", 3)
	header_row.add_child(brand)
	label(brand, "MORRO DO SOL", 20, CREAM)
	subtitle = label(brand, "EXPLORAÇÃO 3D  /  %d HERÓIS  /  %d MINIONS" % [get_tree().get_nodes_in_group("hero_previews").size(), get_tree().get_nodes_in_group("minion_previews").size()], 11, MUTED)
	status_label = label(header_row, "Vista geral / 1.0x", 13, HudTheme.GOLD)
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var help_button := button(header_row, "?", toggle_help)
	help_button.custom_minimum_size = Vector2(36, 36)
	help_button.tooltip_text = "Mostrar controles da câmera / H"
	toolbar = PanelContainer.new()
	toolbar.add_theme_stylebox_override("panel", padded_style())
	ui_root.add_child(toolbar)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	toolbar.add_child(content)
	action_flow = HFlowContainer.new()
	action_flow.add_theme_constant_override("h_separation", 8)
	action_flow.add_theme_constant_override("v_separation", 8)
	content.add_child(action_flow)
	var names := ["Vista geral", "Central Azul", "Central Coral", "Personagens", "Barricadas"]
	for i in names.size():
		var index := i
		var control := button(action_flow, names[i], func() -> void: select_view(index))
		control.toggle_mode = true
		control.tooltip_text = "%s / tecla %d" % [names[i], i + 1]
		view_buttons.append(control)
	navigation_button = button(action_flow, "Navegação [N]", toggle_navigation)
	navigation_button.toggle_mode = true
	navigation_button.tooltip_text = "Mostrar ou ocultar a faixa navegável"
	var game_button := button(action_flow, "Jogar 2D", func() -> void:
		get_tree().change_scene_to_file("res://scenes/main.tscn"))
	game_button.tooltip_text = "Abrir a partida contra bot"
	label(content, "1-5: vistas  |  N: navegação  |  H: controles", 11, MUTED)
	help_panel = PanelContainer.new()
	help_panel.add_theme_stylebox_override("panel", padded_style())
	ui_root.add_child(help_panel)
	var help_content := VBoxContainer.new()
	help_content.add_theme_constant_override("separation", 10)
	help_panel.add_child(help_content)
	label(help_content, "CONTROLES DA CÂMERA", 15, HudTheme.GOLD)
	label(help_content, "WASD: deslocar a vista\nQ/E: girar\nMouse direito: girar e inclinar\nMouse do meio: arrastar\nRoda: aproximar / afastar\nHome ou 1: vista geral\nH: fechar esta ajuda", 14, CREAM)
	help_panel.hide()
	ui_root.resized.connect(layout_hud)

func layout_hud() -> void:
	if toolbar == null:
		return
	var size := ui_root.size
	header.position = Vector2(16, 16)
	header.size = Vector2(size.x - 32, 68)
	subtitle.visible = size.x >= 650
	var width := minf(size.x - 32, 1120)
	var inner_width := width - 28
	var row_width := 0.0
	var rows := 1
	for control in action_flow.get_children():
		var item_width: float = control.get_combined_minimum_size().x
		if row_width > 0 and row_width + 8 + item_width > inner_width:
			rows += 1
			row_width = 0
		row_width += item_width + (8 if row_width > 0 else 0)
	var height := 24 + rows * 38 + (rows - 1) * 8 + 26
	toolbar.position = Vector2((size.x - width) * 0.5, size.y - 16 - height)
	toolbar.size = Vector2(width, height)
	help_panel.position = Vector2(maxf(16, size.x - 376), 98)
	help_panel.size = Vector2(minf(360, size.x - 32), 225)

func select_view(index: int) -> void:
	match index:
		0: rig.reset_view()
		1: rig.frame_point(district.get_node("PointsOfInterest/PoliceCore").global_position)
		2: rig.frame_point(district.get_node("PointsOfInterest/TrafficCore").global_position)
		3: rig.frame_point(Vector3(0, 0, -1.5), 14)
		4: rig.frame_point(district.get_node("PointsOfInterest/PoliceBarricade2").global_position, 12)
	view_name = ["Vista geral", "Central Azul", "Central Coral", "Personagens", "Barricadas"][index]
	for i in view_buttons.size():
		view_buttons[i].set_pressed_no_signal(i == index)

func mark_free_view() -> void:
	view_name = "Vista livre"
	for control in view_buttons:
		control.set_pressed_no_signal(false)

func toggle_navigation() -> void:
	district.get_node("Navigation/Preview").visible = navigation_button.button_pressed

func toggle_help() -> void:
	help_panel.visible = not help_panel.visible

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode >= KEY_1 and event.physical_keycode <= KEY_5:
			select_view(event.physical_keycode - KEY_1)
		elif event.physical_keycode == KEY_HOME:
			select_view(0)
		elif event.physical_keycode == KEY_H:
			toggle_help()
		elif event.physical_keycode == KEY_N:
			navigation_button.set_pressed_no_signal(not navigation_button.button_pressed)
			toggle_navigation()
	elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		mark_free_view()
	elif event is InputEventMouseMotion and (Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE)):
		mark_free_view()

func label(parent: Node, value: String, font_size: int, color: Color) -> Label:
	var control := Label.new()
	control.text = value
	control.add_theme_font_size_override("font_size", font_size)
	control.add_theme_color_override("font_color", color)
	parent.add_child(control)
	return control

func button(parent: Node, value: String, action: Callable) -> Button:
	var control := Button.new()
	control.text = value
	control.focus_mode = Control.FOCUS_NONE
	control.custom_minimum_size = Vector2(124, 38)
	HudTheme.button(control)
	control.pressed.connect(action)
	parent.add_child(control)
	return control

func padded_style() -> StyleBoxFlat:
	var style := HudTheme.panel().duplicate() as StyleBoxFlat
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style
