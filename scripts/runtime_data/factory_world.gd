class_name FactoryWorld
extends RefCounted

# Represents the occupancy of the game world
# cell 0, 0 must be at the top left corner of the map

# TODO add support for size
const EMPTY := -1

var width: int
var height: int
var size : int



# stores the occupancy of the game world
# stored in x * y sized array 
# where pos(x, y) => index x + width * y
var cells: PackedInt32Array = []

# Building ID -> Tile index
var building_positions: Dictionary = {}

func _init(w: int = 500, h: int = 500) -> void:
	assert(w > 0 and h > 0)
	width = w
	height = h
	size = width * height
	
	cells.resize(size)
	cells.fill(EMPTY)

#---------------------
# Coordinate Helpers
#--------------------
func pos_to_index(pos: Vector2i) -> int:
	return pos.x + pos.y * width
	
func index_to_pos(index: int) -> Vector2i:
	return Vector2i(
		index % width, 
		int(index / width))

func is_valid_pos(pos: Vector2i) -> bool:
	return (
		pos.x >= 0 
		and pos.x < width 
		and pos.y >= 0 
		and pos.y < height
	)
	
func is_valid_index(index: int) -> bool:
	return index >= 0 and index < size	
# -----------------------
# queries
# ------------------------
# gets the id of the item in the 
func get_cell(pos: Vector2i) -> int:
	if not is_valid_pos(pos):
		return EMPTY
		
	return cells[pos_to_index(pos)]

func get_cell_by_index(index: int) -> int:
	if not is_valid_index(index):
		return EMPTY

	return cells[index]


func is_empty(pos: Vector2i) -> bool:
	return (
		is_valid_pos(pos)
		and cells[pos_to_index(pos)] == EMPTY
		)


func has_building(building_id: int) -> bool:
	return building_positions.has(building_id)


func get_building_position(building_id: int) -> Vector2i:
	if not has_building(building_id):
		return Vector2i(-1, -1)

	return index_to_pos(building_positions[building_id])
# ---------------------------------
# Building placement
# ---------------------------------

func place_building(building_id: int, pos: Vector2i) -> bool:
	if building_id < 0:
		return false

	if not is_empty(pos):
		return false

	if has_building(building_id):
		return false

	var index := pos_to_index(pos)

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
	var building_id := get_cell(pos)

	if building_id == EMPTY:
		return false

	return remove_building(building_id)
