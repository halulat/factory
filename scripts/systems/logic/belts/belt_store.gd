class_name BeltStore
extends RefCounted
# storage for belts and the items on them.

# Holds the struct-of-arrays belt fields and the flattened item slots, plus the
# set of belts that currently carry at least one item.
# enforceable the item-count invariant  in one place.

const EMPTY: int = -1
const MAX_ITEMS_PER_BELT: int = 4
const MIN_ITEM_SPACING: float = 0.2

# An item may leave a belt only once it has reached this position.
const EXIT_POSITION: float = 1.0

# Number of belt IDs the arrays are sized for.
var capacity: int

# Belt data, indexed by belt ID.
var grid_indices: PackedInt32Array
var directions: PackedByteArray
var speeds: PackedByteArray
var item_counts: PackedByteArray

# Item data, indexed by get_item_index(belt_id, slot).
var item_types: PackedInt32Array
var item_positions: PackedFloat32Array

# Belts with at least one item. Maintained by change_item_count().
var occupied: DenseIdSet


func _init(belt_capacity: int) -> void:
	capacity = belt_capacity
	occupied = DenseIdSet.new(belt_capacity)
	reset()


func reset() -> void:
	grid_indices.resize(capacity)
	grid_indices.fill(EMPTY)
	directions.resize(capacity)
	directions.fill(0)
	speeds.resize(capacity)
	speeds.fill(0)
	item_counts.resize(capacity)
	item_counts.fill(0)

	item_types.resize(capacity * MAX_ITEMS_PER_BELT)
	item_types.fill(EMPTY)
	item_positions.resize(capacity * MAX_ITEMS_PER_BELT)
	item_positions.fill(0.0)

	occupied.clear()


# Clear every field and item slot for one belt ID, including its occupied flag.
func clear_belt(belt_id: int) -> void:
	grid_indices[belt_id] = EMPTY
	directions[belt_id] = 0
	speeds[belt_id] = 0
	for slot in range(MAX_ITEMS_PER_BELT):
		var index: int = get_item_index(belt_id, slot)
		item_types[index] = EMPTY
		item_positions[index] = 0.0
	item_counts[belt_id] = 0
	occupied.remove(belt_id)


# Flatten a belt ID and one of its item slots into an array index.
func get_item_index(belt_id: int, slot: int) -> int:
	return belt_id * MAX_ITEMS_PER_BELT + slot

# Return the first slot that can hold an item at [param position], or EMPTY.


# A slot is usable when it is empty and no existing item on the same belt sits
# closer than MIN_ITEM_SPACING to [param position].
func find_free_slot(belt_id: int, position: float) -> int:
	var empty_slot: int = EMPTY
	for slot in range(MAX_ITEMS_PER_BELT):
		var index: int = get_item_index(belt_id, slot)
		if item_types[index] == EMPTY:
			if empty_slot == EMPTY:
				empty_slot = slot
			continue
		if absf(item_positions[index] - position) < MIN_ITEM_SPACING:
			return EMPTY
	return empty_slot


# Write an item into a slot. Does not touch the item count.
func put_item(belt_id: int, slot: int, resource_id: int, position: float) -> void:
	var index: int = get_item_index(belt_id, slot)
	item_types[index] = resource_id
	item_positions[index] = position


# Clear one item slot. Does not touch the item count.
func take_item(belt_id: int, slot: int) -> void:
	var index: int = get_item_index(belt_id, slot)
	item_types[index] = EMPTY
	item_positions[index] = 0.0


# Move a belt between the empty and occupied sets when its count crosses zero.
func change_item_count(belt_id: int, change: int) -> void:
	var old_count: int = item_counts[belt_id]
	var new_count: int = old_count + change
	assert(new_count >= 0 and new_count <= MAX_ITEMS_PER_BELT)
	item_counts[belt_id] = new_count

	if old_count == 0 and new_count > 0:
		occupied.add(belt_id)
	elif old_count > 0 and new_count == 0:
		occupied.remove(belt_id)


func item_count(belt_id: int) -> int:
	return item_counts[belt_id]
