class_name BeltManager
extends Node

const EMPTY: int = BeltStore.EMPTY

const MAX_BELTS: int = 50000
const MAX_ITEMS_PER_BELT: int = BeltStore.MAX_ITEMS_PER_BELT
const MIN_ITEM_SPACING: float = BeltStore.MIN_ITEM_SPACING

const SIMULATION_UPDATES_PER_SECOND: float = 10.0
const SIMULATION_INTERVAL: float = 1.0 / SIMULATION_UPDATES_PER_SECOND

# enum of dir
const Direction = BeltNetwork.Direction

var world: FactoryWorld # posisions
var id_pool: IdPool # ids
var active_belts: DenseIdSet # optimizaton
var store: BeltStore # data
var network: BeltNetwork # connections

# Items must not be changed when interating
# ids for transfer phase of items
var belt_transfer_ids: PackedInt32Array

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
	if store == null:
		store = BeltStore.new(MAX_BELTS)
	else:
		store.reset()
	if network == null:
		network = BeltNetwork.new(world, store)
	else:
		network.reset()
	belt_transfer_ids.clear()

	_initialized = true


# Check whether a belt ID is currently active.
func _is_active_belt(belt_id: int) -> bool:
	return belt_id >= 0 and belt_id < MAX_BELTS and active_belts.contains(belt_id)


# clear data of the given belt id
func _reset_belt_data(belt_id: int) -> void:
	store.clear_belt(belt_id)
	network.clear_belt(belt_id)


func add_belt(tile_index: int, direction: int, speed: int) -> int:
	if not _initialized:
		return EMPTY
	# Validate tile index, direction and speed
	if tile_index < 0 or tile_index >= world.size:
		return EMPTY
	if direction < 0 or direction >= Direction.size():
		return EMPTY
	if speed < 0 or speed > 255:
		return EMPTY

	# The placement controller registers the global building AFTER this call.
	if network.belt_at[tile_index] != EMPTY or not world.is_empty_index(tile_index):
		return EMPTY

	var belt_id: int = id_pool.acquire()

	# store data
	store.grid_indices[belt_id] = tile_index
	store.directions[belt_id] = direction
	store.speeds[belt_id] = speed

	network.register(belt_id, tile_index)
	active_belts.add(belt_id)

	network.refresh_near(tile_index)
	return belt_id


func remove_belt(belt_id: int) -> void:
	if not _initialized or not _is_active_belt(belt_id):
		return

	var tile_index: int = store.grid_indices[belt_id]

	network.unregister(belt_id, tile_index)

	store.clear_belt(belt_id)
	active_belts.remove(belt_id)
	id_pool.release(belt_id)
	network.refresh_near(tile_index)


func try_insert_item(belt_id: int, resource_id: int) -> bool:
	# Validate insertion request.
	if not _initialized or not _is_active_belt(belt_id) or resource_id < 0:
		return false

	var slot: int = store.find_free_slot(belt_id, 0.0)
	if slot == EMPTY:
		return false

	store.put_item(belt_id, slot, resource_id, 0.0)
	store.change_item_count(belt_id, 1)
	return true


func try_remove_item(belt_id: int, resource_id: int) -> bool:
	if not _initialized or not _is_active_belt(belt_id):
		return false

	for slot in range(MAX_ITEMS_PER_BELT):
		var index: int = store.get_item_index(belt_id, slot)
		if store.item_types[index] != resource_id:
			continue
		if store.item_positions[index] < BeltStore.EXIT_POSITION:
			continue

		store.take_item(belt_id, slot)
		store.change_item_count(belt_id, -1)
		return true
	return false


func _process(delta: float) -> void:
	if not _initialized:
		return
	simulation_accumulator += delta
	while simulation_accumulator >= SIMULATION_INTERVAL:
		simulation_accumulator -= SIMULATION_INTERVAL
		_update_belts(SIMULATION_INTERVAL)


func _update_belts(delta: float) -> void:
	# Phase 1: all existing items move exactly once.
	for belt_id in store.occupied.ids:
		_move_belt_items(belt_id, delta)

	# Phase 2: copy IDs because transfers mutate the occupied list.
	belt_transfer_ids.clear()
	belt_transfer_ids.append_array(store.occupied.ids)
	for belt_id in belt_transfer_ids:
		if store.occupied.contains(belt_id):
			_transfer_belt_items(belt_id)


func _move_belt_items(belt_id: int, delta: float) -> void:
	var movement: float = float(store.speeds[belt_id]) * delta
	for slot in range(MAX_ITEMS_PER_BELT):
		var index: int = store.get_item_index(belt_id, slot)
		if store.item_types[index] != EMPTY:
			store.item_positions[index] += movement


func _transfer_belt_items(belt_id: int) -> void:
	# Check destination.
	var next_belt: int = network.next_indices[belt_id]
	if not _is_active_belt(next_belt) or next_belt == belt_id:
		return

	var transferred_count: int = 0
	for slot in range(MAX_ITEMS_PER_BELT):
		var index: int = store.get_item_index(belt_id, slot)
		if store.item_positions[index] == EMPTY:
			continue
		if store.item_positions[index] < 1.0:
			continue

		var item_type: int = store.item_types[index]
		var new_position: float = store.item_positions[index] - BeltStore.EXIT_POSITION
		var destination_slot: int = store.find_free_slot(next_belt, new_position)
		if destination_slot == EMPTY:
			continue

		store.put_item(next_belt, destination_slot, item_type, new_position)
		store.take_item(belt_id, slot)
		transferred_count += 1

	if transferred_count > 0:
		store.change_item_count(belt_id, -transferred_count)
		store.change_item_count(next_belt, transferred_count)
