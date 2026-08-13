extends Control

const NODE_SIZE := Vector2(104, 62)
const NODE_SPACING := Vector2(134, 90)
const MAP_PADDING := Vector2(72, 58)

var board_data: Dictionary = {}
var current_space_id := -1
var route_option_ids: Array[int] = []


func configure(data: Dictionary) -> void:
	board_data = data
	custom_minimum_size = get_map_size()
	size = custom_minimum_size
	queue_redraw()


func get_map_size() -> Vector2:
	return Vector2(
		int(board_data.get("width", 1)) * NODE_SPACING.x + MAP_PADDING.x * 2.0,
		int(board_data.get("height", 1)) * NODE_SPACING.y + MAP_PADDING.y * 2.0
	)


func get_space_position(space: Dictionary) -> Vector2:
	return MAP_PADDING + Vector2(
		int(space.get("x", 0)) * NODE_SPACING.x,
		int(space.get("y", 0)) * NODE_SPACING.y
	)


func get_space_center(space: Dictionary) -> Vector2:
	return get_space_position(space) + NODE_SIZE * 0.5


func set_focus_state(space_id: int, option_ids: Array) -> void:
	current_space_id = space_id
	route_option_ids.clear()
	for raw_id in option_ids:
		route_option_ids.append(int(raw_id))
	queue_redraw()


func _draw() -> void:
	var map_size := get_map_size()
	draw_rect(Rect2(Vector2.ZERO, map_size), Color("#0e121b"))

	var inner := Rect2(Vector2(18, 18), map_size - Vector2(36, 36))
	var band_steps := 20
	for i in range(band_steps):
		var t0: float = float(i) / float(band_steps)
		var t1: float = float(i + 1) / float(band_steps)
		var c := Color("#1c2436").lerp(Color("#141a27"), (t0 + t1) * 0.5)
		draw_rect(Rect2(inner.position.x, inner.position.y + inner.size.y * t0, inner.size.x, inner.size.y * (t1 - t0) + 1.0), c, true)
	draw_rect(inner, Color("#39465c"), false, 1.4)

	for i in range(90):
		var x := fposmod(float(i * 211), map_size.x - 120.0) + 60.0
		var y := fposmod(float(i * 97), map_size.y - 100.0) + 50.0
		var radius := 1.0 + float(i % 3) * 0.45
		draw_circle(Vector2(x, y), radius, Color(1, 1, 1, 0.045))

	for y in range(1, int(board_data.get("height", 1))):
		var line_y := MAP_PADDING.y + float(y) * NODE_SPACING.y + NODE_SIZE.y * 0.5
		draw_line(Vector2(34, line_y), Vector2(map_size.x - 34, line_y), Color(1, 1, 1, 0.018), 1.0)

	draw_string(get_theme_default_font(), Vector2(32, 36), "ROUTE MAP", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.18))

	for space in _get_spaces():
		var from_space: Dictionary = space
		for next_id in _get_next_ids(from_space):
			var to_space: Dictionary = _get_space_by_id(next_id)
			if to_space.is_empty():
				continue
			var from_center := get_space_center(from_space)
			var to_center := get_space_center(to_space)
			var is_active := int(from_space.get("id", -1)) == current_space_id or route_option_ids.has(int(to_space.get("id", -1)))
			draw_line(from_center + Vector2(0, 5), to_center + Vector2(0, 5), Color("#080b11"), 18.0, true)
			draw_line(from_center, to_center, Color("#384253") if is_active else Color("#252e3d"), 9.0, true)
			draw_line(from_center, to_center, Color("#f2ca69") if is_active else Color("#566173"), 3.0, true)
			if is_active:
				draw_line(from_center, to_center, Color(1.0, 0.88, 0.42, 0.35), 13.0, true)

	var current_space := _get_space_by_id(current_space_id)
	if not current_space.is_empty():
		var center := get_space_center(current_space)
		draw_circle(center, 42.0, Color(1.0, 0.78, 0.25, 0.10))
		draw_circle(center, 26.0, Color(1.0, 0.78, 0.25, 0.16))

	var start_space := _get_space_by_id(int(board_data.get("start_id", 0)))
	if not start_space.is_empty():
		draw_circle(get_space_center(start_space), 8.0, Color("#f2ca69"))


func _get_spaces() -> Array:
	return board_data.get("spaces", [])


func _get_space_by_id(space_id: int) -> Dictionary:
	for space in _get_spaces():
		if int(space.get("id", -1)) == space_id:
			return space
	return {}


func _get_next_ids(space: Dictionary) -> Array[int]:
	var ids: Array[int] = []
	for raw_id in space.get("next_ids", []):
		ids.append(int(raw_id))
	return ids
