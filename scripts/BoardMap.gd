extends Control

const NODE_SIZE := Vector2(96, 58)
const NODE_SPACING := Vector2(126, 88)
const MAP_PADDING := Vector2(56, 42)

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
	var map_rect := Rect2(Vector2.ZERO, get_map_size())
	draw_rect(map_rect, Color("#171b24"))

	for space in _get_spaces():
		var from_space: Dictionary = space
		for next_id in _get_next_ids(from_space):
			var to_space := _get_space_by_id(next_id)
			if to_space.is_empty():
				continue
			var from_center := get_space_center(from_space)
			var to_center := get_space_center(to_space)
			var is_active := int(from_space.get("id", -1)) == current_space_id or route_option_ids.has(int(to_space.get("id", -1)))
			draw_line(from_center, to_center, Color("#11141b"), 14.0, true)
			draw_line(from_center, to_center, Color("#5c6577") if is_active else Color("#303846"), 6.0, true)
			if is_active:
				draw_line(from_center, to_center, Color("#f0c766"), 2.0, true)

	var start_space := _get_space_by_id(int(board_data.get("start_id", 0)))
	if not start_space.is_empty():
		draw_circle(get_space_center(start_space), 9.0, Color("#f0c766"))


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
