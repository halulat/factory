class_name FactoryWorld
extends RefCounted

# Represents the occupancy of the game world
# cell 0, 0 must be at the top left corner of the map

# TODO add support for size
const EMPTY := -1

var width: int
var height: int
var size : int



# Grid: array of runtime ids
# stored in x * y sized array 
# where pos(x, y) => index x + width * y
var cells: PackedInt32Array = []


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
		
# -----------------------
# queries
# ------------------------
# gets the id of the item in the 
func get_cell(pos: Vector2i) -> int:
	if not is_valid_pos(pos):
		return EMPTY
		
	return cells[pos_to_index(pos)]

# Returns a cell at given displacement of origin
# Use pos + Vector2i.UP/LEFT/DOWN/RIGHT to get neighbours 
func get_cell_displaced(pos: Vector2i, direction: Vector2i) -> int:
	return get_cell(pos + direction)
	
func is_empty(pos : Vector2i) -> bool:
	return (is_valid_pos(pos) and get_cell(pos) == EMPTY)
	
#------------------------
# Building Lifetime
#-------------------------

# takes an instance_id and places it in the given position and direction
func place_building(instance_id: int, pos :Vector2i, direction :Vector2i):
	if not is_empty(pos):
		return null
	cells[pos_to_index(pos)] = instance_id
	
func remove_building(instance_id: int) -> bool:
	if instance_id == EMPTY:
		return false
		
	cells[instance_id] = EMPTY
	return true
	
func remove_building_at(pos: Vector2i) -> bool:
	var id := get_cell(pos)
	if id == EMPTY:
		return false
		
	cells[pos_to_index(pos)] = EMPTY
	return true
	
