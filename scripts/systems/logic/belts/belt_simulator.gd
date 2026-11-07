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


func _init(store: BeltStore, network: BeltNetwork, active_belts: DenseIdSet) -> void:
	_store = store
	_network = network
	_active_belts = active_belts


func tick(delta: float) -> void:
	for belt_id in _store.occupied.ids:
		move_items(belt_id, delta)

	_transfer_ids.clear()
	_transfer_ids.append_array(_store.occupied.ids)
	for belt_id in _transfer_ids:
		if _store.occupied.contains(belt_id):
			transfer_items(belt_id)


# Advance every item on one belt by speed * delta.
func move_items(belt_id: int, delta: float) -> void:
	var movement: float = float(_store.speeds[belt_id]) * delta
	for slot in range(BeltStore.MAX_ITEMS_PER_BELT):
		var index: int = _store.get_item_index(belt_id, slot)
		if _store.item_types[index] != BeltStore.EMPTY:
			_store.item_positions[index] += movement


# Move every item that reached the exit onto the downstream belt, when it has
# room. Item counts are updated once per belt, after all items moved.
func transfer_items(belt_id: int) -> void:
	var next_belt: int = _network.next_indices[belt_id]
	if not _active_belts.contains(next_belt) or next_belt == belt_id:
		return

	var transferred_count: int = 0
	for slot in range(BeltStore.MAX_ITEMS_PER_BELT):
		var index: int = _store.get_item_index(belt_id, slot)
		if _store.item_types[index] == BeltStore.EMPTY:
			continue
		if _store.item_positions[index] < BeltStore.EXIT_POSITION:
			continue

		var item_type: int = _store.item_types[index]
		var new_position: float = _store.item_positions[index] - BeltStore.EXIT_POSITION
		var destination_slot: int = _store.find_free_slot(next_belt, new_position)
		if destination_slot == BeltStore.EMPTY:
			continue

		_store.put_item(next_belt, destination_slot, item_type, new_position)
		_store.take_item(belt_id, slot)
		transferred_count += 1

	if transferred_count > 0:
		_store.change_item_count(belt_id, -transferred_count)
		_store.change_item_count(next_belt, transferred_count)
