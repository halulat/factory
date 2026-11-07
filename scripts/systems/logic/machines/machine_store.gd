class_name MachineStore
extends RefCounted

# Structure-of-arrays storage for machines and their small item inventories.

# The store owns the data only: creating, recycling and scheduling machine
# IDs stays in FactoryManager, and per-tick behaviour will live in
# MachineSimulator. `machine_at` mirrors BeltNetwork's tile lookup so the
# manager has one occupancy rule.

const EMPTY: int = -1
const MAX_MACHINE_SLOTS: int = 8

var capacity: int
var world_size: int

var tile_indices: PackedInt32Array
var types: PackedInt32Array
var recipe_ids: PackedInt32Array
var progress: PackedFloat32Array
var status: PackedByteArray

var item_types: PackedInt32Array
var item_amounts: PackedInt32Array

# Tile index. -1 means no machine
var machine_at: PackedInt32Array


func _init(machine_capacity: int, map_size: int) -> void:
	capacity = machine_capacity
	world_size = map_size

	tile_indices = PackedInt32Array()
	tile_indices.resize(capacity)
	tile_indices.fill(EMPTY)

	types = PackedInt32Array()
	types.resize(capacity)
	types.fill(EMPTY)

	recipe_ids = PackedInt32Array()
	recipe_ids.resize(capacity)
	recipe_ids.fill(EMPTY)

	progress = PackedFloat32Array()
	progress.resize(capacity)
	progress.fill(0.0)

	status = PackedByteArray()
	status.resize(capacity)
	status.fill(0)

	item_types = PackedInt32Array()
	item_types.resize(capacity * MAX_MACHINE_SLOTS)
	item_types.fill(EMPTY)

	item_amounts = PackedInt32Array()
	item_amounts.resize(capacity * MAX_MACHINE_SLOTS)
	item_amounts.fill(0)

	machine_at = PackedInt32Array()
	machine_at.resize(world_size)
	machine_at.fill(EMPTY)


func reset() -> void:
	tile_indices.fill(EMPTY)
	types.fill(EMPTY)
	recipe_ids.fill(EMPTY)
	progress.fill(0.0)
	status.fill(0)
	item_types.fill(EMPTY)
	item_amounts.fill(0)
	machine_at.fill(EMPTY)


func get_slot_index(machine_id: int, slot: int) -> int:
	assert(machine_id >= 0 and machine_id < capacity)
	assert(slot >= 0 and slot < MAX_MACHINE_SLOTS)
	return machine_id * MAX_MACHINE_SLOTS + slot


func set_machine(machine_id: int, tile_index: int, machine_type: int, recipe_id: int) -> void:
	assert(machine_id >= 0 and machine_id < capacity)
	assert(tile_index >= 0 and tile_index < world_size)

	tile_indices[machine_id] = tile_index
	types[machine_id] = machine_type
	recipe_ids[machine_id] = recipe_id
	progress[machine_id] = 0.0
	status[machine_id] = 0

	for slot in range(MAX_MACHINE_SLOTS):
		var index: int = get_slot_index(machine_id, slot)

		item_types[index] = EMPTY
		item_amounts[index] = 0

	machine_at[tile_index] = machine_id


func clear_machine(machine_id: int) -> void:
	assert(machine_id >= 0 and machine_id < capacity)

	var tile_index: int = tile_indices[machine_id]

	if tile_index != EMPTY and machine_at[tile_index] == machine_id:
		machine_at[tile_index] = EMPTY

	tile_indices[machine_id] = EMPTY
	types[machine_id] = EMPTY
	recipe_ids[machine_id] = EMPTY
	progress[machine_id] = 0.0
	status[machine_id] = 0

	for slot in range(MAX_MACHINE_SLOTS):
		var index: int = get_slot_index(machine_id, slot)

		item_types[index] = EMPTY
		item_amounts[index] = 0


func tile_index(machine_id: int) -> int:
	assert(machine_id >= 0 and machine_id < capacity)
	return tile_indices[machine_id]


func set_item(machine_id: int, slot: int, item_type: int, amount: int) -> void:
	var index: int = get_slot_index(machine_id, slot)

	item_types[index] = item_type
	item_amounts[index] = amount


func item_type(machine_id: int, slot: int) -> int:
	return item_types[get_slot_index(machine_id, slot)]


func item_amount(machine_id: int, slot: int) -> int:
	return item_amounts[get_slot_index(machine_id, slot)]
