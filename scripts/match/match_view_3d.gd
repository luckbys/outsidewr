extends Control
## Render the existing logical match with real meshes; never simulate combat here.

const METERS := 0.05
const Character = preload("res://scenes/actors/character_visual_3d.tscn")
const Barricade = preload("res://scenes/world/modules/barricade_3d.tscn")
const Landmark = preload("res://scenes/world/modules/landmark_3d.tscn")
var arena: Node
var enabled := true
var viewport: SubViewport
var container: SubViewportContainer
var camera: Camera3D
var district: Node3D
var actors: Node3D
var ruins: Node3D
var views: Dictionary = {}

func bind_match(match_node: Node) -> void:
	arena = match_node
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var backdrop := Control.new()
	backdrop.set_script(preload("res://scripts/world/city_backdrop_3d.gd"))
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	container = SubViewportContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.handle_input_locally = false
	viewport.gui_disable_input = true
	viewport.msaa_3d = Viewport.MSAA_2X
	viewport.positional_shadow_atlas_size = 0
	container.add_child(viewport)
	district = preload("res://scenes/world/district_3d.tscn").instantiate()
	viewport.add_child(district)
	# Preview units and objective placeholders are replaced by live match actors.
	district.get_node("Units").free()
	district.get_node("PointsOfInterest").visible = false
	district.get_node("Navigation").process_mode = Node.PROCESS_MODE_DISABLED
	var environment: Environment = district.get_node("Lighting/Environment").environment.duplicate()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	district.get_node("Lighting/Environment").environment = environment
	bake_static_world()
	actors = Node3D.new()
	actors.name = "LiveActors"
	viewport.add_child(actors)
	ruins = Node3D.new()
	ruins.name = "Ruins"
	viewport.add_child(ruins)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.far = 400
	camera.position = Vector3(100, 81.64966, 100)
	viewport.add_child(camera)
	camera.look_at(Vector3.ZERO)
	camera.current = true
	var overlay := Control.new()
	overlay.set_script(preload("res://scripts/ui/match_world_overlay.gd"))
	overlay.view = self
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	resized.connect(fit_camera)
	fit_camera()
	set_enabled(true)

func bake_static_world() -> void:
	# The inspection scene stays editable. Only this gameplay instance is baked,
	# greatly reducing WebGL draw calls while retaining the static collisions.
	var batch := MorroMeshBatch.new()
	for instance: MeshInstance3D in district.find_children("*", "MeshInstance3D", true, false):
		if instance.is_visible_in_tree() and instance.mesh != null:
			batch.append_instance(instance)
			instance.hide()
	var geometry := Node3D.new()
	geometry.name = "StaticGeometry"
	district.add_child(geometry)
	batch.finish(geometry)

func world_point(point: Vector2, height: float = 0.0) -> Vector3:
	return Vector3(point.x * METERS, height, point.y * METERS)

func project(point: Vector2, height: float = 0.0) -> Vector2:
	return camera.unproject_position(world_point(point, height))

func fit_camera() -> void:
	if camera == null or arena == null:
		return
	# A 30-degree camera and these offsets exactly match Iso.project(), so
	# world clicks, aim, minimap, range rings and WASD retain their coordinates.
	var pixels_per_meter: float = arena.world.scale.x * Iso.AXIS.x * sqrt(2.0) / METERS
	camera.size = maxf(1, size.y / maxf(0.1, pixels_per_meter))
	camera.v_offset = 30.0 / maxf(0.1, pixels_per_meter)

func set_enabled(value: bool) -> void:
	enabled = value
	visible = value
	arena.world.get_node("District").visible = not value
	arena.actor_root.visible = not value
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if value else SubViewport.UPDATE_DISABLED

func reset_units() -> void:
	for entry in views.values():
		entry.root.free()
	views.clear()
	for rubble in ruins.get_children():
		rubble.free()

func _process(_delta: float) -> void:
	if enabled and arena != null:
		sync_units()

func sync_units() -> void:
	var present: Dictionary = {}
	for unit in arena.units:
		var id: int = unit.get_instance_id()
		present[id] = true
		if not views.has(id):
			views[id] = create_actor(unit)
		var entry: Dictionary = views[id]
		var model: Node3D = entry.root
		model.visible = unit.alive
		model.position = world_point(unit.world_position, 0.1)
		entry.last_hp = unit.hp
		if unit.role in [UnitActor.Role.HERO, UnitActor.Role.TROOP]:
			model.walking = unit.moving
			model.apply_pose(unit.animation_time * (8.5 if unit.moving else 1.8))
			var direction: Vector2 = unit.destination - unit.world_position
			if is_instance_valid(unit.attack_target) and unit.attack_target.alive:
				direction = unit.attack_target.world_position - unit.world_position
			if direction.length_squared() > 1:
				model.rotation.y = atan2(-direction.x, -direction.y)
		if entry.has("smoke"):
			entry.smoke.emitting = unit.alive and unit.hp < unit.max_hp * 0.6
			entry.smoke.speed_scale = 0 if arena.paused else 1
	for id in views.keys():
		if not present.has(id):
			var entry: Dictionary = views[id]
			if entry.role in [UnitActor.Role.BARRICADE, UnitActor.Role.CORE] and entry.last_hp <= 0:
				create_rubble(entry.root.position)
			entry.root.free()
			views.erase(id)

func create_actor(unit: UnitActor) -> Dictionary:
	var model: Node3D
	if unit.role in [UnitActor.Role.HERO, UnitActor.Role.TROOP]:
		model = Character.instantiate()
		model.team = unit.team
		model.hero = unit.role == UnitActor.Role.HERO
		model.variation = unit.visual_variant
		actors.add_child(model)
		model.set_process(false)
		model.get_node("Nameplate").hide()
		model.get_node("Selection").hide()
	else:
		model = (Barricade if unit.role == UnitActor.Role.BARRICADE else Landmark).instantiate()
		model.accent = MatchRules.FACTIONS[unit.team].color
		actors.add_child(model)
		model.get_node("Label").hide()
		if unit.role == UnitActor.Role.BARRICADE:
			model.rotation.y = PI * 0.5
		else:
			model.column_height = 1.2
	var entry := {"root": model, "role": unit.role, "last_hp": unit.hp}
	unit.died.connect(func(_unit: UnitActor, _attacker: UnitActor) -> void: entry.last_hp = 0)
	if unit.role in [UnitActor.Role.BARRICADE, UnitActor.Role.CORE]:
		entry.smoke = create_smoke(model)
	return entry

func create_smoke(parent: Node3D) -> CPUParticles3D:
	var smoke := CPUParticles3D.new()
	smoke.position.y = 0.7
	smoke.amount = 10
	smoke.lifetime = 2.7
	smoke.emitting = false
	smoke.direction = Vector3(0.2, 1, 0.1)
	smoke.spread = 25
	smoke.gravity = Vector3(0.08, 0.12, 0)
	smoke.initial_velocity_min = 0.35
	smoke.initial_velocity_max = 0.7
	smoke.scale_amount_min = 0.4
	smoke.scale_amount_max = 1.2
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.47, 0.42, 0.35, 0.34))
	gradient.set_color(1, Color(0.62, 0.57, 0.48, 0))
	smoke.color_ramp = gradient
	var mesh := QuadMesh.new()
	mesh.size = Vector2(1.5, 1.5)
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = smoke_texture()
	mesh.material = material
	smoke.mesh = mesh
	smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(smoke)
	return smoke

static var puff: ImageTexture
func smoke_texture() -> ImageTexture:
	if puff == null:
		var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
		for y in 32:
			for x in 32:
				var radius := Vector2(x - 15.5, y - 15.5).length() / 15.5
				image.set_pixel(x, y, Color(1, 1, 1, pow(maxf(0, 1 - radius), 1.5)))
		puff = ImageTexture.create_from_image(image)
	return puff

func create_rubble(point: Vector3) -> void:
	var rubble := Node3D.new()
	rubble.position = point
	ruins.add_child(rubble)
	var batch := MorroMeshBatch.new()
	var concrete := MorroMaterials.surface("concrete", Color("8d8778"))
	for i in 9:
		var angle := i * 2.4
		batch.box(Vector3(sin(angle) * 0.7, 0.13, cos(angle) * 1.4), Vector3(0.4, 0.3, 0.55),
			concrete, Vector3(0.1, angle, 0.2))
	batch.finish(rubble)
