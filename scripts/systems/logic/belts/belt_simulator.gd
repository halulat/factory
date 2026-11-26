class_name BeltSimulator
extends RefCounted
# One simulation step for conveyor belts: first move every item, then let
# items that reached the exit transfer to the downstream belt.

# BeltSimulator reads BeltStore, BeltNetwork and the manager's active set;
# it owns no state besides the transfer snapshot array.

var _store: BeltStore
var _network: BeltNetwork
var _active_belts: DenseIdSet

# The occupied set must not be mutated while it is iterated, so the ids are
# snapshotted before the transfer phase.
var _transfer_ids: PackedInt32Array
# bit masks for eligible slots (the binary of the number tells which slot is taken
# | and & are bitwise comparisons, << moves the bits left
var _transfer_masks: PackedInt32Array


func _init(store: BeltStore, network: BeltNetwork, active_belts: DenseIdSet) -> void:
	_store = store
	_network = network
	_active_belts = active_belts


# TODO if needed update so that it can move more than one belt each tick
## advance the simulation by delta time
func tick(delta: float) -> void:
	for belt_id in _store.occupied.ids:
		move_items(belt_id, delta)
	_transfer_ids.clear()
	_transfer_masks.clear()

	for belt_id in _store.occupied.ids:
		var mask: int = 0

		for slot in range(BeltStore.MAX_ITEMS_PER_BELT):
			var index: int = _store.get_item_index(belt_id, slot)

			if _store.item_types[index] != BeltStore.EMPTY:
				if _store.item_positions[index] >= BeltStore.EXIT_POSITION:
					mask |= 1 << slot

		if mask != 0:
			_transfer_ids.append(belt_id)
			_transfer_masks.append(mask)

	for i in range(_transfer_ids.size()):
		transfer_items(_transfer_ids[i], _transfer_masks[i])


## Advance every item on one belt by speed * delta.
func move_items(belt_id: int, delta: float) -> void:
	var movement: float = float(_store.speeds[belt_id]) * delta
	for slot in range(BeltStore.MAX_ITEMS_PER_BELT):
		var index: int = _store.get_item_index(belt_id, slot)
		if _store.item_types[index] != BeltStore.EMPTY:
			_store.item_positions[index] += movement


## Move every item that reached the exit onto the downstream belt, when it has
## room. Item counts are updated once per belt, after all items moved.
func transfer_items(belt_id: int, mask: int) -> void:
	var next_belt: int = _network.next_indices[belt_id]
	var can_transfer: bool = (
		next_belt != BeltStore.EMPTY and next_belt != belt_id and _active_belts.contains(next_belt)
	)

	var transferred_count: int = 0
	for slot in range(BeltStore.MAX_ITEMS_PER_BELT):
		if (mask & (1 << slot)) == 0:
			continue
		var index: int = _store.get_item_index(belt_id, slot)
		if _store.item_types[index] == BeltStore.EMPTY:
			continue
		if _store.item_positions[index] < BeltStore.EXIT_POSITION:
			continue
		if not can_transfer:
			_store.item_positions[index] = BeltStore.EXIT_POSITION
			continue

		var item_type: int = _store.item_types[index]
		var new_position: float = _store.item_positions[index] - BeltStore.EXIT_POSITION
		var destination_slot: int = _store.find_free_slot(next_belt, new_position)
		if destination_slot == BeltStore.EMPTY:
			_store.item_positions[index] = BeltStore.EXIT_POSITION
			continue

		var item_id: int = _store.item_ids[index]
		_store.put_item(next_belt, destination_slot, item_type, new_position, item_id)
		_store.take_item(belt_id, slot)
		transferred_count += 1

	if transferred_count > 0:
		_store.change_item_count(belt_id, -transferred_count)
		_store.change_item_count(next_belt, transferred_count)
