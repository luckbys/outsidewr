extends Node3D
## Orthographic inspection camera. Directions follow the screen, not world axes.

const DEFAULT_YAW := 45.0
const DEFAULT_ELEVATION := 55.0
const DEFAULT_SIZE := 96.0
const MIN_SIZE := 22.0
const MAX_SIZE := 110.0
const FOCUS_BOUNDS := Vector2(36, 26)

var yaw := DEFAULT_YAW
var elevation := DEFAULT_ELEVATION
var view_size := DEFAULT_SIZE
var focus := Vector3.ZERO
@onready var camera: Camera3D = $Camera3D

func _ready() -> void:
	apply_view()

func _process(delta: float) -> void:
	var direction := Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	if direction != Vector2.ZERO:
		pan(direction.normalized() * delta * view_size * 0.55)
	var rotation_axis := float(Input.is_physical_key_pressed(KEY_E)) - float(Input.is_physical_key_pressed(KEY_Q))
	if rotation_axis != 0:
		orbit(Vector2(rotation_axis * delta * 55, 0))

func pan(screen_delta: Vector2) -> void:
	var angle := deg_to_rad(yaw)
	var right := Vector3(cos(angle), 0, -sin(angle))
	var backward := Vector3(sin(angle), 0, cos(angle))
	focus += right * screen_delta.x + backward * screen_delta.y
	focus.x = clampf(focus.x, -FOCUS_BOUNDS.x, FOCUS_BOUNDS.x)
	focus.z = clampf(focus.z, -FOCUS_BOUNDS.y, FOCUS_BOUNDS.y)
	apply_view()

func orbit(amount: Vector2) -> void:
	yaw = wrapf(yaw + amount.x, -180, 180)
	elevation = clampf(elevation + amount.y, 35, 75)
	apply_view()

func zoom(steps: float) -> void:
	view_size = clampf(view_size * pow(0.9, steps), MIN_SIZE, MAX_SIZE)
	apply_view()

func frame_point(point: Vector3) -> void:
	focus = Vector3(clampf(point.x, -FOCUS_BOUNDS.x, FOCUS_BOUNDS.x), 0,
		clampf(point.z, -FOCUS_BOUNDS.y, FOCUS_BOUNDS.y))
	view_size = 30
	apply_view()

func reset_view() -> void:
	focus = Vector3.ZERO
	yaw = DEFAULT_YAW
	elevation = DEFAULT_ELEVATION
	view_size = DEFAULT_SIZE
	apply_view()

func apply_view() -> void:
	position = focus
	rotation_degrees = Vector3(-elevation, yaw, 0)
	if is_instance_valid(camera):
		camera.size = view_size

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom(1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom(-1)
	elif event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			orbit(Vector2(-event.relative.x, event.relative.y) * 0.25)
		elif Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
			var height := maxf(1, get_viewport().get_visible_rect().size.y)
			pan(-event.relative * view_size / height)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_HOME:
			reset_view()
