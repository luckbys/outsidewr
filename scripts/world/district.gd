extends Node2D
## Original procedural placeholder art; no external textures or asset downloads.

const BRICK := [Color("b36c4d"), Color("c48b62"), Color("a75c46"),
	Color("c5ac7b"), Color("62958b"), Color("ce9b6d"), Color("899b86")]
var buildings: Array[Dictionary] = []

func _ready() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 2026
	for row in [-340, -215, 215, 340]:
		for column in range(-550, 600, 122):
			# Reserve an actual football court and alleys between house blocks.
			if row == -340 and column > 100 and column < 400:
				continue
			var origin := Vector2(column + random.randf_range(-9, 9), row)
			buildings.append({"rect": Rect2(origin, Vector2(random.randf_range(67, 94),
				random.randf_range(58, 80))), "height": random.randf_range(42, 100),
				"color": BRICK[random.randi_range(0, BRICK.size() - 1)],
				"tank": random.randf() > 0.42})
	buildings.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.rect.end.x + a.rect.end.y < b.rect.end.x + b.rect.end.y)
	queue_redraw()

func _draw() -> void:
	# A terraced island silhouette makes the playable bounds easy to read.
	for i in range(3, 0, -1):
		var edge := Iso.diamond(Iso.MAP_RECT.grow(i * 7.0))
		for j in edge.size():
			edge[j].y += i * 10
		draw_colored_polygon(edge, Color("263b36").darkened(i * 0.12))
	flat(Iso.MAP_RECT, Color("66705a"))
	flat(Rect2(-650, -420, 1300, 840), Color("828369"))
	# Back alleys and footpaths.
	for row in [-400, -255, 160, 300]:
		flat(Rect2(-640, row, 1280, 19), Color("a79b78"))
	for column in [-420, -60, 420]:
		flat(Rect2(column, -420, 20, 840), Color("a39776"))
	# Single unobstructed lane, bordered by raised sidewalks.
	flat(Rect2(-650, -145, 1300, 290), Color("c2b595"))
	flat(Rect2(-650, -116, 1300, 232), Color("585f58"))
	flat(Rect2(-650, -108, 1300, 216), Color("64695f"))
	for x in range(-620, 650, 55):
		flat(Rect2(x, -2, 25, 4), Color("c7b88b"))
		line(Vector2(x, -141), Vector2(x, -119), Color("8d8c74"), 1)
		line(Vector2(x, 119), Vector2(x, 141), Color("8d8c74"), 1)
	for team in 2:
		var color := MatchRules.FACTIONS[team].color
		var x := -520.0 if team == 0 else 520.0
		flat(Rect2(x - 66, -95, 132, 190), Color(color, 0.16))
		for tower_x in [-290, -140] if team == 0 else [140, 290]:
			flat(Rect2(tower_x - 27, 23, 54, 54), Color("a79c7f"))
	# Football belongs to the neighborhood, outside the combat lane.
	flat(Rect2(128, -390, 230, 143), Color("4b8672"))
	draw_polyline(closed(Iso.diamond(Rect2(137, -382, 212, 127))), Color("d6d4ad"), 2, true)
	line(Vector2(243, -382), Vector2(243, -255), Color("d6d4ad"), 2)
	ring(Vector2(243, -318), 28, Color("d6d4ad"), 1.5)
	for x in [138, 332]:
		draw_polyline(closed(Iso.diamond(Rect2(x, -341, 16, 45))), Color("d6d4ad"), 1.5, true)
	# Houses are drawn back-to-front, with tanks, windows and exposed brickwork.
	for house in buildings:
		building(house)
	# Overhead utility lines, away from the playable road.
	for y in [-160, 166]:
		for x in range(-560, 590, 190):
			var foot := Iso.project(Vector2(x, y))
			draw_line(foot, foot - Vector2(0, 106), Color("454f42"), 4, true)
			draw_line(foot - Vector2(13, 95), foot + Vector2(13, -95), Color("454f42"), 3, true)
			if x < 390:
				var next := Iso.project(Vector2(x + 190, y))
				var points := PackedVector2Array()
				for step in 17:
					var t := step / 16.0
					points.append(foot.lerp(next, t) + Vector2(0, -100 + sin(t * PI) * 14))
				draw_polyline(points, Color("34483f"), 1.5, true)
	# Colorful laundry strung above a back alley.
	var start := Iso.project(Vector2(-370, -270)) - Vector2(0, 72)
	var end := Iso.project(Vector2(-160, -270)) - Vector2(0, 72)
	draw_line(start, end, Color("c3bea0"), 1, true)
	for i in 9:
		var point := start.lerp(end, (i + 1) / 10.0)
		draw_colored_polygon(PackedVector2Array([point, point + Vector2(12, 5),
			point + Vector2(11, 22), point + Vector2(0, 17)]), BRICK[i % BRICK.size()].lightened(0.15))
	var font := ThemeDB.fallback_font
	var sign_pos := Iso.project(Vector2(-440, 155))
	draw_style_box(sign_style(), Rect2(sign_pos - Vector2(5, 19), Vector2(171, 27)))
	draw_string(font, sign_pos, "MORRO DO SOL", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("e2d4aa"))

func flat(rect: Rect2, color: Color, height: float = 0.0) -> void:
	draw_colored_polygon(Iso.diamond(rect, height), color)

func line(from: Vector2, to: Vector2, color: Color, width: float) -> void:
	draw_line(Iso.project(from), Iso.project(to), color, width, true)

func ring(center: Vector2, radius: float, color: Color, width: float) -> void:
	var points := PackedVector2Array()
	for i in 49:
		points.append(Iso.project(center + Vector2.from_angle(TAU * i / 48.0) * radius))
	draw_polyline(points, color, width, true)

func building(data: Dictionary) -> void:
	var rect: Rect2 = data.rect
	var height: float = data.height
	var color: Color = data.color
	var roof := Iso.diamond(rect, height)
	var floor_points := Iso.diamond(rect)
	var shadow := floor_points.duplicate()
	for i in shadow.size():
		shadow[i] += Vector2(19, 9)
	draw_colored_polygon(shadow, Color(0.12, 0.19, 0.16, 0.24))
	draw_colored_polygon(PackedVector2Array([floor_points[1], floor_points[2], roof[2], roof[1]]), color.darkened(0.24))
	draw_colored_polygon(PackedVector2Array([floor_points[2], floor_points[3], roof[3], roof[2]]), color)
	draw_colored_polygon(roof, color.lightened(0.27))
	draw_polyline(closed(roof), color.lightened(0.4), 2, true)
	# Recessed windows on both visible walls.
	for side in [1, 3]:
		for column in [0.26, 0.68]:
			var lower: Vector2 = floor_points[2].lerp(floor_points[side], column)
			for level in range(1, int(height / 30.0) + 1):
				var point := lower - Vector2(0, level * 26)
				var shift := Vector2(9, -4.5 if side == 1 else 4.5)
				draw_colored_polygon(PackedVector2Array([point, point + shift,
					point + shift + Vector2(0, 12), point + Vector2(0, 12)]), Color("394f49"))
	for level in range(1, int(height / 14)):
		var offset := Vector2(0, level * 14)
		draw_line(floor_points[3] - offset, floor_points[2] - offset, Color(color.darkened(0.09), 0.6), 0.7)
	if data.tank:
		var center := Iso.project(rect.get_center()) - Vector2(0, height + 7)
		draw_style_box(tank_style(), Rect2(center - Vector2(13, 10), Vector2(26, 21)))
		draw_set_transform(center - Vector2(0, 9), 0, Vector2(1, 0.45))
		draw_circle(Vector2.ZERO, 13, Color("6c9eac"))
		draw_set_transform(Vector2.ZERO)
	else:
		var center := Iso.project(rect.get_center()) - Vector2(0, height)
		draw_line(center, center - Vector2(0, 25), Color("526154"), 1.5)
		draw_line(center - Vector2(9, 18), center + Vector2(9, -23), Color("526154"), 1.5)

func closed(points: PackedVector2Array) -> PackedVector2Array:
	var result := points.duplicate()
	result.append(points[0])
	return result

func tank_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("427387")
	style.corner_radius_top_left = 4
	style.corner_radius_bottom_right = 4
	return style

func sign_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("294c43")
	style.border_color = Color("cbbd91")
	style.set_border_width_all(1)
	return style
