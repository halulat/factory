class_name BeltManager
extends Node

const EMPTY: int = -1

const MAP_WIDTH: int = 1000
const MAP_HEIGHT: int = 1000
const MAP_SIZE: int = MAP_WIDTH * MAP_HEIGHT

const MAX_BELTS: int = 50000
const MAX_ITEMS_PER_BELT: int = 4
const MIN_ITEM_SPACING: float = 0.2

const SIMULATION_UPDATES_PER_SECOND: float = 10.0
const SIMULATION_INTERVAL: float = 1.0 / SIMULATION_UPDATES_PER_SECOND

const DIRECTION_OFFSETS: Array[Vector2i] = [
	Vector2i.UP,
	Vector2i.RIGHT,
	Vector2i.DOWN,
	Vector2i.LEFT,
]

enum Direction { UP, RIGHT, DOWN, LEFT }


# ID pools and dense lists. Reverse positions allow O(1) swap-removal.
var free_belt_ids: PackedInt32Array
var active_belt_ids: PackedInt32Array
var belt_active_position: PackedInt32Array
var occupied_belt_ids: PackedInt32Array
var belt_occupied_position: PackedInt32Array
var belt_transfer_ids: PackedInt32Array

# Belt data, indexed by belt ID.
var belt_grid_indices: PackedInt32Array
var belt_directions: PackedByteArray
var belt_speeds: PackedByteArray
var belt_next_indices: PackedInt32Array
var belt_item_counts: PackedByteArray

# Item data, indexed by beltSlot(belt_id, slot).
var belt_item_types: PackedInt32Array
var belt_item_positions: PackedFloat32Array

# Tile index -> belt ID; EMPTY means no belt.
var belt_at: PackedInt32Array

var _initialized: bool = false
var simulation_accumulator: float = 0.0

func _ready() -> void:
	initialize_factory(MAP_SIZE)

func initialize_factory(map_size: int) -> void:
	simulation_accumulator = 0.0
	initializeBelts(map_size)
	_initialized = true

func initializeBelts(map_size: int) -> void:
	# clear id fields
	free_belt_ids.clear()
	active_belt_ids.clear()
	occupied_belt_ids.clear()
	belt_transfer_ids.clear()
	
	# clear belt data fields
	belt_grid_indices.resize(MAX_BELTS)
	belt_grid_indices.fill(EMPTY)
	belt_directions.resize(MAX_BELTS)
	belt_directions.fill(0)
	belt_speeds.resize(MAX_BELTS)
	belt_speeds.fill(0)
	belt_next_indices.resize(MAX_BELTS)
	belt_next_indices.fill(EMPTY)
	belt_item_counts.resize(MAX_BELTS)
	belt_item_counts.fill(0)

	# clear belt position fields
	belt_active_position.resize(MAX_BELTS)
	belt_active_position.fill(EMPTY)
	belt_occupied_position.resize(MAX_BELTS)
	belt_occupied_position.fill(EMPTY)

	# clear belt items feilds
	belt_item_types.resize(MAX_BELTS * MAX_ITEMS_PER_BELT)
	belt_item_types.fill(EMPTY)
	belt_item_positions.resize(MAX_BELTS * MAX_ITEMS_PER_BELT)
	belt_item_positions.fill(0.0)

	belt_at.resize(map_size)
	belt_at.fill(EMPTY)

	# Pop from the end to assign IDs in ascending order (0, 1, 2...).
	for belt_id in range(MAX_BELTS - 1, -1, -1):
		free_belt_ids.append(belt_id)


# check if the belt with given id is active
func _is_active_belt(belt_id: int) -> bool:
	return belt_id >= 0 and belt_id < MAX_BELTS and belt_active_position[belt_id] != EMPTY
	
func _clear_belt_items(belt_id: int) -> void:
	for slot in range(MAX_ITEMS_PER_BELT):
		var index: int = beltSlot(belt_id, slot)
		belt_item_types[index] = EMPTY
		belt_item_positions[index] = 0.0
	belt_item_counts[belt_id] = 0
	
# Returns the index of the given belt id and item index
func beltSlot(belt_id: int, slot: int) -> int: 
	return belt_id * MAX_ITEMS_PER_BELT + slot 


# Recompute outgoing connections only for a changed tile and its four neighbors.
func _refresh_connections_near(tile_index: int) -> void:
	var center_id: int = belt_at[tile_index]
	if center_id != EMPTY:
		updateBeltConnetions(center_id)

	for direction in range(4):
		var neighbor_tile: int = getNeighbourTileIndex(tile_index, direction)
		if neighbor_tile == EMPTY:
			continue
		var neighbor_id: int = belt_at[neighbor_tile]
		if neighbor_id != EMPTY:
			updateBeltConnetions(neighbor_id)

func addBelt(tile_index: int, direction: int, speed: int) -> int:
	if not _initialized:
		return EMPTY
	# check if index in in the map
	if tile_index < 0 or tile_index >= belt_at.size(): 
		return EMPTY
	# check if belt data given is valid
	if direction < 0 or direction >= 4 or speed < 0 or speed > 255: 
		return EMPTY
	if belt_at[tile_index] != EMPTY or free_belt_ids.is_empty():
		return EMPTY
	
	# get last free id and remove from array
	var belt_id: int = free_belt_ids[free_belt_ids.size() - 1] 
	free_belt_ids.remove_at(free_belt_ids.size() - 1) 

	# Initialize data
	belt_grid_indices[belt_id] = tile_index
	belt_directions[belt_id] = direction
	belt_speeds[belt_id] = speed
	belt_next_indices[belt_id] = EMPTY
	_clear_belt_items(belt_id) # clear items from previous belts

	# Register belt
	belt_at[tile_index] = belt_id # Belt at tile_index is belt_id

	belt_at[tile_index] = belt_id
	belt_active_position[belt_id] = active_belt_ids.size()
	active_belt_ids.append(belt_id)

	_refresh_connections_near(tile_index)
	return belt_id

# deletes the belts id and corrisponding data with swap deleation

func removeBelt(belt_id: int) -> void: 
	if not _initialized or not _is_active_belt(belt_id):
		return

	var tile_index: int = belt_grid_indices[belt_id]
	var active_position: int = belt_active_position[belt_id]

	belt_at[tile_index] = EMPTY
	removeOccupiedBelt(belt_id)
	_clear_belt_items(belt_id)

	# Clear belt data
	belt_grid_indices[belt_id] = EMPTY
	belt_directions[belt_id] = 0
	belt_speeds[belt_id] = 0
	belt_next_indices[belt_id] = EMPTY

	# Swap and pop: no shifting the dense active list.
	var last_index: int = active_belt_ids.size() - 1
	if active_position != last_index:
		var last_id: int = active_belt_ids[last_index]
		active_belt_ids[active_position] = last_id
		belt_active_position[last_id] = active_position
	active_belt_ids.resize(last_index)
	belt_active_position[belt_id] = EMPTY
	free_belt_ids.append(belt_id)
	
	_refresh_connections_near(tile_index)

# gets the neighbouring tile in the given direction
func getNeighbourTileIndex(tile_index: int, direction: int) -> int:
	if direction < 0 or direction >= 4:
		return EMPTY
	if tile_index < 0 or tile_index >= belt_at.size():
		return EMPTY

	var x: int = tile_index % MAP_WIDTH
	var y: int = tile_index / MAP_WIDTH
	var neighbor: Vector2i = Vector2i(x, y) + DIRECTION_OFFSETS[direction]
	if neighbor.x < 0 or neighbor.x >= MAP_WIDTH:
		return EMPTY
	if neighbor.y < 0 or neighbor.y >= MAP_HEIGHT:
		return EMPTY

	var result: int = neighbor.y * MAP_WIDTH + neighbor.x
	if result >= belt_at.size():
		return EMPTY
	return result
	
func oppositeDirection(direction: int) -> int:
	return (direction + 2) % 4 # Returns the opposite direction (UP 0 turns to DOWN 2, LEFT 3 turns to RIGHT 1)
	
func updateBeltConnetions(belt_id: int) -> void: # Updates belt_next_indices when addBelt is called
	if not _is_active_belt(belt_id):
		return

	var output_tile: int = getNeighbourTileIndex(
		belt_grid_indices[belt_id], belt_directions[belt_id]
	)
	belt_next_indices[belt_id] = EMPTY if output_tile == EMPTY else belt_at[output_tile]

# adds a belt to the Occupied belt array
func addOccupiedBelt(belt_id: int) -> void:
	if belt_occupied_position[belt_id] != EMPTY:
		return
	belt_occupied_position[belt_id] = occupied_belt_ids.size()
	occupied_belt_ids.append(belt_id)

# removes a belt from the Occupied belt array
func removeOccupiedBelt(belt_id: int) -> void:
	var position: int = belt_occupied_position[belt_id]
	if position == EMPTY:
		return
	var last_index: int = occupied_belt_ids.size() - 1
	if position != last_index:
		var last_id: int = occupied_belt_ids[last_index]
		occupied_belt_ids[position] = last_id
		belt_occupied_position[last_id] = position
	occupied_belt_ids.resize(last_index)
	belt_occupied_position[belt_id] = EMPTY
	
func changeBeltItemCount(belt_id: int, change: int) -> void:
	var old_count: int = belt_item_counts[belt_id]
	var new_count: int = old_count + change
	assert(new_count >= 0 and new_count <= MAX_ITEMS_PER_BELT)
	belt_item_counts[belt_id] = new_count

	if old_count == 0 and new_count > 0:
		addOccupiedBelt(belt_id)
	elif old_count > 0 and new_count == 0:
		removeOccupiedBelt(belt_id)

func tryInsertItem(belt_id: int, resource_id: int) -> bool:
	# check validity
	if not _initialized or not _is_active_belt(belt_id) or resource_id < 0:
		return false
		
	var slot: int = findAvailableBeltSlot(belt_id, 0.0)
	if slot == EMPTY:
		return false

	var index: int = beltSlot(belt_id, slot)
	belt_item_types[index] = resource_id
	belt_item_positions[index] = 0.0
	changeBeltItemCount(belt_id, 1)
	return true

func tryRemoveItem(belt_id: int, resource_id: int) -> bool:
	if not _initialized or not _is_active_belt(belt_id):
		return false

	for slot in range(MAX_ITEMS_PER_BELT):
		var index: int = beltSlot(belt_id, slot)
		if belt_item_types[index] != resource_id:
			continue
		if belt_item_positions[index] < 1.0:
			continue

		belt_item_types[index] = EMPTY
		belt_item_positions[index] = 0.0
		changeBeltItemCount(belt_id, -1)
		return true
	return false

func findAvailableBeltSlot(belt_id: int, position: float) -> int:
	var empty_slot: int = EMPTY
	for slot in range(MAX_ITEMS_PER_BELT):
		var index: int = beltSlot(belt_id, slot)
		if belt_item_types[index] == EMPTY:
			if empty_slot == EMPTY:
				empty_slot = slot
			continue
		if absf(belt_item_positions[index] - position) < MIN_ITEM_SPACING:
			return EMPTY
	return empty_slot

func _process(delta: float) -> void:
	if not _initialized:
		return

	simulation_accumulator += delta
	while simulation_accumulator >= SIMULATION_INTERVAL:
		updateBelts(SIMULATION_INTERVAL)
		simulation_accumulator -= SIMULATION_INTERVAL


func updateBelts(delta: float) -> void:
	# Phase 1: all existing items move exactly once.
	for belt_id in occupied_belt_ids:
		moveBeltItems(belt_id, delta)

	# Phase 2: copy IDs because transfers mutate the occupied list.
	belt_transfer_ids.clear()
	belt_transfer_ids.append_array(occupied_belt_ids)
	for belt_id in belt_transfer_ids:
		if belt_occupied_position[belt_id] != EMPTY:
			transferBeltItems(belt_id)


func moveBeltItems(belt_id: int, delta: float) -> void:
	var movement: float = float(belt_speeds[belt_id]) * delta
	for slot in range(MAX_ITEMS_PER_BELT):
		var index: int = beltSlot(belt_id, slot)
		if belt_item_types[index] != EMPTY:
			belt_item_positions[index] += movement


func transferBeltItems(belt_id: int) -> void:
	# check destination
	var next_belt: int = belt_next_indices[belt_id]
	if not _is_active_belt(next_belt) or next_belt == belt_id:
		return
	
	var transferred_count: int = 0
	for slot in range(MAX_ITEMS_PER_BELT):
		var source_index: int = beltSlot(belt_id, slot)
		if belt_item_types[source_index] == EMPTY:
			continue
		if belt_item_positions[source_index] < 1.0:
			continue

		var new_position: float = belt_item_positions[source_index] - 1.0
		var destination_slot: int = findAvailableBeltSlot(next_belt, new_position)
		if destination_slot == EMPTY:
			continue

		var destination_index: int = beltSlot(next_belt, destination_slot)
		belt_item_types[destination_index] = belt_item_types[source_index]
		belt_item_positions[destination_index] = new_position
		belt_item_types[source_index] = EMPTY
		belt_item_positions[source_index] = 0.0
		transferred_count += 1

	if transferred_count > 0:
		changeBeltItemCount(belt_id, -transferred_count)
		changeBeltItemCount(next_belt, transferred_count)
