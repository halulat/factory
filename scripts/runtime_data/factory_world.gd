class_name FactoryWorld
extends RefCounted

# Single-tile world occupancy. (0, 0) is the top-left tile.
# Each occupied cell stores a global building ID, not a system-local belt ID.
const EMPTY: int = -1
const INVALID_POS: Vector2i = Vector2i(-1, -1)

var width: int
var height: int
var size: int

# Tile index -> building ID
var cells: PackedInt32Array = PackedInt32Array()
# Building ID -> tile index
var building_positions: Dictionary[int, int] = {}


func _init(w: int = 500, h: int = 500) -> void:
	assert(w > 0 and h > 0)
	width = w
	height = h
	size = width * height
	cells.resize(size)
	cells.fill(EMPTY)


# ---------------------------------
# Coordinate helpers
# ---------------------------------
func is_valid_pos(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < width and pos.y >= 0 and pos.y < height


func is_valid_index(index: int) -> bool:
	return index >= 0 and index < size


# Caller should pass a valid position.
func pos_to_index(pos: Vector2i) -> int:
	return pos.x + pos.y * width


# Caller should pass a valid index.
func index_to_pos(index: int) -> Vector2i:
	return Vector2i(index % width, index / width)


func get_neighbor_index(index: int, direction: Vector2i) -> int:
	if not is_valid_index(index):
		return EMPTY

	var neighbor: Vector2i = index_to_pos(index) + direction
	if not is_valid_pos(neighbor):
		return EMPTY
	return pos_to_index(neighbor)


# ---------------------------------
# Queries
# ---------------------------------
func get_cell(pos: Vector2i) -> int:
	if not is_valid_pos(pos):
		return EMPTY
	return cells[pos_to_index(pos)]


func get_cell_by_index(index: int) -> int:
	if not is_valid_index(index):
		return EMPTY
	return cells[index]


func is_empty(pos: Vector2i) -> bool:
	return is_valid_pos(pos) and cells[pos_to_index(pos)] == EMPTY


func is_empty_index(index: int) -> bool:
	return is_valid_index(index) and cells[index] == EMPTY


func has_building(building_id: int) -> bool:
	return building_positions.has(building_id)


func get_building_position(building_id: int) -> Vector2i:
	if not has_building(building_id):
		return INVALID_POS
	return index_to_pos(building_positions[building_id])


func get_building_index(building_id: int) -> int:
	if not has_building(building_id):
		return EMPTY
	return building_positions[building_id]


# ---------------------------------
# Placement and removal
# ---------------------------------
func place_building(building_id: int, pos: Vector2i) -> bool:
	if not is_valid_pos(pos):
		return false
	return place_building_at_index(building_id, pos_to_index(pos))


func place_building_at_index(building_id: int, index: int) -> bool:
	if building_id < 0 or not is_empty_index(index) or has_building(building_id):
		return false

	cells[index] = building_id
	building_positions[building_id] = index
	return true


func remove_building(building_id: int) -> bool:
	if not has_building(building_id):
		return false

	var index: int = building_positions[building_id]
	cells[index] = EMPTY
	building_positions.erase(building_id)
	return true


func remove_building_at(pos: Vector2i) -> bool:
	return remove_building(get_cell(pos))


func remove_building_at_index(index: int) -> bool:
	return remove_building(get_cell_by_index(index))


# Reset world occupancy; calling code must reset building/simulation systems too.
func reset() -> void:
	cells.fill(EMPTY)
	building_positions.clear()
