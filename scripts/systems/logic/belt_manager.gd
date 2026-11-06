class_name BeltManager
extends Node

const EMPTY: int = -1

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

enum Direction {
	UP,
	RIGHT,
	DOWN,
	LEFT,
}

# the occupancy of the world
var world: FactoryWorld

# ID pool and dense membership sets.
var id_pool: IdPool
var active_belts: DenseIdSet
var occupied_belts: DenseIdSet
var belt_transfer_ids: PackedInt32Array

# Belt data, indexed by belt ID.
var belt_grid_indices: PackedInt32Array
var belt_directions: PackedByteArray
var belt_speeds: PackedByteArray
var belt_next_indices: PackedInt32Array
var belt_item_counts: PackedByteArray

# Item data, indexed by _get_item_index(belt_id, slot).
var belt_item_types: PackedInt32Array
var belt_item_positions: PackedFloat32Array

# Tile index -> belt ID; EMPTY means no belt.
var belt_at: PackedInt32Array

var _initialized: bool = false
var simulation_accumulator: float = 0.0


func _init(factory_world: FactoryWorld) -> void:
	world = factory_world
	initialize_belts()


func initialize_belts() -> void:
	_initialized = false
	simulation_accumulator = 0.0
	# Reset the ID pool.
	if id_pool == null:
		id_pool = IdPool.new(MAX_BELTS)
	else:
		id_pool.reset()

	# Reset active and occupied belt membership.
	if active_belts == null:
		active_belts = DenseIdSet.new(MAX_BELTS)
	else:
		active_belts.clear()
	if occupied_belts == null:
		occupied_belts = DenseIdSet.new(MAX_BELTS)
	else:
		occupied_belts.clear()
	belt_transfer_ids.clear()

	# Clear belt data fields.
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

	# Clear item storage.
	belt_item_types.resize(MAX_BELTS * MAX_ITEMS_PER_BELT)
	belt_item_types.fill(EMPTY)
	belt_item_positions.resize(MAX_BELTS * MAX_ITEMS_PER_BELT)
	belt_item_positions.fill(0.0)

	belt_at.resize(world.size)
	belt_at.fill(EMPTY)
	_initialized = true


# Check whether a belt ID is currently active.
func _is_active_belt(belt_id: int) -> bool:
	return belt_id >= 0 and belt_id < MAX_BELTS and active_belts.contains(belt_id)


# Clear all local data for an ID after removing it from occupancy sets.
# Also safe for a freshly acquired ID before configuring its fields.
func _reset_belt_data(belt_id: int) -> void:
	belt_grid_indices[belt_id] = EMPTY
	belt_directions[belt_id] = 0
	belt_speeds[belt_id] = 0
	belt_next_indices[belt_id] = EMPTY
	_clear_belt_items(belt_id)


func _clear_belt_items(belt_id: int) -> void:
	for slot in range(MAX_ITEMS_PER_BELT):
		var index: int = _get_item_index(belt_id, slot)
		belt_item_types[index] = EMPTY
		belt_item_positions[index] = 0.0
	belt_item_counts[belt_id] = 0


# Return the flattened array index for an item slot.
func _get_item_index(belt_id: int, slot: int) -> int:
	return belt_id * MAX_ITEMS_PER_BELT + slot


# Recompute outgoing connections only for a changed tile and its four neighbors.
func _refresh_connections_near(tile_index: int) -> void:
	var center_id: int = belt_at[tile_index]
	if center_id != EMPTY:
		_update_belt_connections(center_id)

	for direction in range(Direction.size()):
		var neighbor_tile: int = _get_neighbor_tile_index(tile_index, direction)
		if neighbor_tile == EMPTY:
			continue
		var neighbor_id: int = belt_at[neighbor_tile]
		if neighbor_id != EMPTY:
			_update_belt_connections(neighbor_id)


func add_belt(tile_index: int, direction: int, speed: int) -> int:
	if not _initialized:
		return EMPTY
	# Validate tile index.
	if tile_index < 0 or tile_index >= belt_at.size():
		return EMPTY
	# Validate direction and speed.
	if direction < 0 or direction >= Direction.size() or speed < 0 or speed > 255:
		return EMPTY
	# Belt-local occupancy and global building occupancy must both be clear.
	# The placement controller registers the global building AFTER this call.
	if belt_at[tile_index] != EMPTY or not world.is_empty_index(tile_index):
		return EMPTY

	# Acquire a free belt ID.
	var belt_id: int = id_pool.acquire()

	if belt_id == IdPool.INVALID_ID:
		return EMPTY

	# Initialize reused ID before assigning the new belt fields.
	_reset_belt_data(belt_id)
	belt_grid_indices[belt_id] = tile_index
	belt_directions[belt_id] = direction
	belt_speeds[belt_id] = speed

	# Register belt.
	belt_at[tile_index] = belt_id
	active_belts.add(belt_id)

	_refresh_connections_near(tile_index)
	return belt_id


func remove_belt(belt_id: int) -> void:
	if not _initialized or not _is_active_belt(belt_id):
		return

	var tile_index: int = belt_grid_indices[belt_id]

	belt_at[tile_index] = EMPTY
	occupied_belts.remove(belt_id)
	_reset_belt_data(belt_id)

	active_belts.remove(belt_id)
	id_pool.release(belt_id)

	_refresh_connections_near(tile_index)


# Return the neighboring tile in the given direction.
func _get_neighbor_tile_index(tile_index: int, direction: int) -> int:
	if direction < 0 or direction >= Direction.size():
		return FactoryWorld.EMPTY
	return world.get_neighbor_index(tile_index, DIRECTION_OFFSETS[direction])


func _update_belt_connections(
	belt_id: int
) -> void: # Updates belt_next_indices when add_belt is called
	if not _is_active_belt(belt_id):
		return

	var output_tile: int = _get_neighbor_tile_index(
		belt_grid_indices[belt_id],
		belt_directions[belt_id],
	)
	belt_next_indices[belt_id] = EMPTY if output_tile == EMPTY else belt_at[output_tile]


func _change_belt_item_count(belt_id: int, change: int) -> void:
	var old_count: int = belt_item_counts[belt_id]
	var new_count: int = old_count + change
	assert(new_count >= 0 and new_count <= MAX_ITEMS_PER_BELT)
	belt_item_counts[belt_id] = new_count

	if old_count == 0 and new_count > 0:
		occupied_belts.add(belt_id)
	elif old_count > 0 and new_count == 0:
		occupied_belts.remove(belt_id)


func try_insert_item(belt_id: int, resource_id: int) -> bool:
	# Validate insertion request.
	if not _initialized or not _is_active_belt(belt_id) or resource_id < 0:
		return false

	var slot: int = _find_available_item_slot(belt_id, 0.0)
	if slot == EMPTY:
		return false

	var index: int = _get_item_index(belt_id, slot)
	belt_item_types[index] = resource_id
	belt_item_positions[index] = 0.0
	_change_belt_item_count(belt_id, 1)
	return true


func try_remove_item(belt_id: int, resource_id: int) -> bool:
	if not _initialized or not _is_active_belt(belt_id):
		return false

	for slot in range(MAX_ITEMS_PER_BELT):
		var index: int = _get_item_index(belt_id, slot)
		if belt_item_types[index] != resource_id:
			continue
		if belt_item_positions[index] < 1.0:
			continue

		belt_item_types[index] = EMPTY
		belt_item_positions[index] = 0.0
		_change_belt_item_count(belt_id, -1)
		return true
	return false


func _find_available_item_slot(belt_id: int, position: float) -> int:
	var empty_slot: int = EMPTY
	for slot in range(MAX_ITEMS_PER_BELT):
		var index: int = _get_item_index(belt_id, slot)
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
		_update_belts(SIMULATION_INTERVAL)
		simulation_accumulator -= SIMULATION_INTERVAL


func _update_belts(delta: float) -> void:
	# Phase 1: all existing items move exactly once.
	for belt_id in occupied_belts.ids:
		_move_belt_items(belt_id, delta)

	# Phase 2: copy IDs because transfers mutate the occupied list.
	belt_transfer_ids.clear()
	belt_transfer_ids.append_array(occupied_belts.ids)
	for belt_id in belt_transfer_ids:
		if occupied_belts.contains(belt_id):
			_transfer_belt_items(belt_id)


func _move_belt_items(belt_id: int, delta: float) -> void:
	var movement: float = float(belt_speeds[belt_id]) * delta
	for slot in range(MAX_ITEMS_PER_BELT):
		var index: int = _get_item_index(belt_id, slot)
		if belt_item_types[index] != EMPTY:
			belt_item_positions[index] += movement


func _transfer_belt_items(belt_id: int) -> void:
	# Check destination.
	var next_belt: int = belt_next_indices[belt_id]
	if not _is_active_belt(next_belt) or next_belt == belt_id:
		return

	var transferred_count: int = 0
	for slot in range(MAX_ITEMS_PER_BELT):
		var source_index: int = _get_item_index(belt_id, slot)
		if belt_item_types[source_index] == EMPTY:
			continue
		if belt_item_positions[source_index] < 1.0:
			continue

		var new_position: float = belt_item_positions[source_index] - 1.0
		var destination_slot: int = _find_available_item_slot(next_belt, new_position)
		if destination_slot == EMPTY:
			continue

		var destination_index: int = _get_item_index(next_belt, destination_slot)
		belt_item_types[destination_index] = belt_item_types[source_index]
		belt_item_positions[destination_index] = new_position
		belt_item_types[source_index] = EMPTY
		belt_item_positions[source_index] = 0.0
		transferred_count += 1

	if transferred_count > 0:
		_change_belt_item_count(belt_id, -transferred_count)
		_change_belt_item_count(next_belt, transferred_count)
