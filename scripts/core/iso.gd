class_name Iso
extends RefCounted
## Gameplay uses a flat logical plane. Only presentation uses isometric coordinates.

const AXIS := Vector2(0.86, 0.43)
const MAP_RECT := Rect2(-660, -430, 1320, 860)
const WALK_RECT := Rect2(-585, -112, 1170, 224)

static func project(point: Vector2) -> Vector2:
	return Vector2((point.x - point.y) * AXIS.x, (point.x + point.y) * AXIS.y)

static func unproject(point: Vector2) -> Vector2:
	return Vector2((point.x / AXIS.x + point.y / AXIS.y) * 0.5,
		(point.y / AXIS.y - point.x / AXIS.x) * 0.5)

static func clamp_to_lane(point: Vector2) -> Vector2:
	return Vector2(clampf(point.x, WALK_RECT.position.x, WALK_RECT.end.x),
		clampf(point.y, WALK_RECT.position.y, WALK_RECT.end.y))

static func diamond(rect: Rect2, height: float = 0.0) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in [rect.position, Vector2(rect.end.x, rect.position.y),
			rect.end, Vector2(rect.position.x, rect.end.y)]:
		result.append(project(point) - Vector2(0, height))
	return result
