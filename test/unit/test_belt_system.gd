extends GutTest

var belts: BeltManager


func before_each() -> void:
	belts = add_child_autofree(BeltManager.new())
	belts.set_process(false)


func _add(tile: int, direction: int = BeltManager.Direction.RIGHT, speed: int = 1) -> int:
	return belts.addBelt(tile, direction, speed)


func _item_index(belt_id: int, slot: int = 0) -> int:
	return belts.beltSlot(belt_id, slot)


func test_initialization_sets_empty_grid_and_free_pool() -> void:
	assert_eq(belts.active_belt_ids.size(), 0)
	assert_eq(belts.occupied_belt_ids.size(), 0)
	assert_eq(belts.free_belt_ids.size(), BeltManager.MAX_BELTS)
	assert_eq(belts.belt_at[1001], BeltManager.EMPTY)
	assert_eq(belts.belt_next_indices[0], BeltManager.EMPTY)


func test_add_belt_registers_grid_and_active_id() -> void:
	var id := _add(1001)
	assert_eq(id, 0)
	assert_eq(belts.belt_at[1001], id)
	assert_eq(belts.belt_grid_indices[id], 1001)
	assert_eq(belts.belt_directions[id], BeltManager.Direction.RIGHT)
	assert_eq(belts.active_belt_ids.size(), 1)
	assert_eq(belts.belt_active_position[id], 0)


func test_add_rejects_out_of_bounds_tiles() -> void:
	assert_eq(_add(-1), BeltManager.EMPTY)
	assert_eq(_add(belts.belt_at.size()), BeltManager.EMPTY)
	assert_eq(belts.active_belt_ids.size(), 0)


func test_add_rejects_duplicate_tile() -> void:
	var id := _add(1001)
	assert_eq(_add(1001), BeltManager.EMPTY)
	assert_eq(belts.belt_at[1001], id)
	assert_eq(belts.active_belt_ids.size(), 1)


func test_add_rejects_invalid_direction_and_speed() -> void:
	assert_eq(_add(1001, -1), BeltManager.EMPTY)
	assert_eq(_add(1001, 4), BeltManager.EMPTY)
	assert_eq(_add(1001, BeltManager.Direction.RIGHT, -1), BeltManager.EMPTY)
	assert_eq(_add(1001, BeltManager.Direction.RIGHT, 256), BeltManager.EMPTY)


func test_remove_belt_clears_grid_and_recycles_id() -> void:
	var id := _add(1001)
	belts.removeBelt(id)
	assert_eq(belts.belt_at[1001], BeltManager.EMPTY)
	assert_eq(belts.belt_active_position[id], BeltManager.EMPTY)
	assert_eq(belts.active_belt_ids.size(), 0)
	assert_eq(_add(1002), id)


func test_swap_remove_keeps_reverse_positions_consistent() -> void:
	var a := _add(1001)
	var b := _add(1002)
	var c := _add(1003)
	belts.removeBelt(b)
	assert_eq(belts.active_belt_ids.size(), 2)
	assert_eq(belts.belt_active_position[a], 0)
	assert_eq(belts.belt_active_position[b], BeltManager.EMPTY)
	assert_eq(belts.active_belt_ids[1], c)
	assert_eq(belts.belt_active_position[c], 1)


func test_remove_invalid_or_inactive_id_is_safe() -> void:
	belts.removeBelt(-1)
	belts.removeBelt(BeltManager.MAX_BELTS)
	belts.removeBelt(0)
	assert_eq(belts.active_belt_ids.size(), 0)


func test_neighbors_do_not_wrap_across_rows() -> void:
	assert_eq(belts.getNeighbourTileIndex(999, BeltManager.Direction.RIGHT), BeltManager.EMPTY)
	assert_eq(belts.getNeighbourTileIndex(1000, BeltManager.Direction.LEFT), BeltManager.EMPTY)
	assert_eq(belts.getNeighbourTileIndex(0, BeltManager.Direction.UP), BeltManager.EMPTY)
	assert_eq(belts.getNeighbourTileIndex(0, BeltManager.Direction.LEFT), BeltManager.EMPTY)
	assert_eq(belts.getNeighbourTileIndex(1001, BeltManager.Direction.RIGHT), 1002)


func test_connects_to_belt_placed_later() -> void:
	var source := _add(1001)
	assert_eq(belts.belt_next_indices[source], BeltManager.EMPTY)
	var destination := _add(1002)
	assert_eq(belts.belt_next_indices[source], destination)


func test_connects_to_belt_placed_earlier() -> void:
	var destination := _add(1002)
	var source := _add(1001)
	assert_eq(belts.belt_next_indices[source], destination)


func test_ignores_adjacent_belt_when_not_pointing_at_it() -> void:
	var source := _add(1001, BeltManager.Direction.UP)
	_add(1002)
	assert_eq(belts.belt_next_indices[source], BeltManager.EMPTY)


func test_removing_destination_disconnects_source() -> void:
	var source := _add(1001)
	var destination := _add(1002)
	belts.removeBelt(destination)
	assert_eq(belts.belt_next_indices[source], BeltManager.EMPTY)


func test_insert_marks_belt_occupied() -> void:
	var id := _add(1001)
	assert_true(belts.tryInsertItem(id, 42))
	assert_eq(belts.belt_item_counts[id], 1)
	assert_eq(belts.belt_item_types[_item_index(id)], 42)
	assert_eq(belts.occupied_belt_ids.size(), 1)
	assert_eq(belts.belt_occupied_position[id], 0)


func test_insert_rejects_invalid_id_and_resource() -> void:
	var id := _add(1001)
	assert_false(belts.tryInsertItem(-1, 42))
	assert_false(belts.tryInsertItem(BeltManager.MAX_BELTS, 42))
	assert_false(belts.tryInsertItem(id, -1))
	assert_eq(belts.belt_item_counts[id], 0)


func test_insert_rejects_item_too_close_to_entrance() -> void:
	var id := _add(1001)
	assert_true(belts.tryInsertItem(id, 42))
	assert_false(belts.tryInsertItem(id, 43))
	assert_eq(belts.belt_item_counts[id], 1)


func test_insert_rejects_full_belt() -> void:
	var id := _add(1001)
	for slot in range(BeltManager.MAX_ITEMS_PER_BELT):
		var index := _item_index(id, slot)
		belts.belt_item_types[index] = 100 + slot
		belts.belt_item_positions[index] = float(slot) * 0.2
	belts.changeBeltItemCount(id, BeltManager.MAX_ITEMS_PER_BELT)
	assert_false(belts.tryInsertItem(id, 999))
	assert_eq(belts.belt_item_counts[id], BeltManager.MAX_ITEMS_PER_BELT)


func test_remove_item_only_when_at_exit() -> void:
	var id := _add(1001)
	assert_true(belts.tryInsertItem(id, 42))
	assert_false(belts.tryRemoveItem(id, 42))
	belts.belt_item_positions[_item_index(id)] = 1.0
	assert_false(belts.tryRemoveItem(id, 99))
	assert_true(belts.tryRemoveItem(id, 42))
	assert_eq(belts.belt_item_counts[id], 0)
	assert_eq(belts.occupied_belt_ids.size(), 0)
	assert_eq(belts.belt_occupied_position[id], BeltManager.EMPTY)


func test_move_items_uses_speed_times_delta() -> void:
	var id := _add(1001, BeltManager.Direction.RIGHT, 2)
	assert_true(belts.tryInsertItem(id, 42))
	belts.moveBeltItems(id, 0.1)
	assert_almost_eq(belts.belt_item_positions[_item_index(id)], 0.2, 0.00001)


func test_transfer_moves_item_and_updates_occupied_lists() -> void:
	var source := _add(1001)
	var destination := _add(1002)
	assert_true(belts.tryInsertItem(source, 42))
	belts.belt_item_positions[_item_index(source)] = 1.1
	belts.updateBelts(0.0)
	assert_eq(belts.belt_item_counts[source], 0)
	assert_eq(belts.belt_item_counts[destination], 1)
	assert_eq(belts.belt_item_types[_item_index(destination)], 42)
	assert_almost_eq(belts.belt_item_positions[_item_index(destination)], 0.1, 0.00001)
	assert_eq(belts.occupied_belt_ids.size(), 1)
	assert_eq(belts.occupied_belt_ids[0], destination)


func test_transfer_two_items_updates_count_by_two() -> void:
	# Regression: earlier implementation only incremented/decremented counts by 1.
	var source := _add(1001)
	var destination := _add(1002)
	for slot in range(2):
		var index := _item_index(source, slot)
		belts.belt_item_types[index] = 50 + slot
		belts.belt_item_positions[index] = 1.0 + float(slot) * 0.25
	belts.changeBeltItemCount(source, 2)
	belts.updateBelts(0.0)
	assert_eq(belts.belt_item_counts[source], 0)
	assert_eq(belts.belt_item_counts[destination], 2)
	assert_eq(belts.occupied_belt_ids.size(), 1)


func test_blocked_destination_keeps_item_on_source() -> void:
	var source := _add(1001)
	var destination := _add(1002)
	assert_true(belts.tryInsertItem(source, 42))
	assert_true(belts.tryInsertItem(destination, 99))
	belts.belt_item_positions[_item_index(source)] = 1.0
	belts.transferBeltItems(source)
	assert_eq(belts.belt_item_counts[source], 1)
	assert_eq(belts.belt_item_counts[destination], 1)
	assert_eq(belts.belt_item_types[_item_index(source)], 42)


func test_remove_occupied_belt_clears_items_and_occupancy() -> void:
	var id := _add(1001)
	assert_true(belts.tryInsertItem(id, 42))
	belts.removeBelt(id)
	assert_eq(belts.belt_item_counts[id], 0)
	assert_eq(belts.belt_item_types[_item_index(id)], BeltManager.EMPTY)
	assert_eq(belts.belt_occupied_position[id], BeltManager.EMPTY)
	assert_eq(belts.occupied_belt_ids.size(), 0)


func test_reinitialize_clears_all_belts_and_items() -> void:
	var id := _add(1001)
	assert_true(belts.tryInsertItem(id, 42))
	belts.initialize_factory(BeltManager.MAP_SIZE)
	assert_eq(belts.active_belt_ids.size(), 0)
	assert_eq(belts.occupied_belt_ids.size(), 0)
	assert_eq(belts.free_belt_ids.size(), BeltManager.MAX_BELTS)
	assert_eq(belts.belt_at[1001], BeltManager.EMPTY)
	assert_eq(belts.belt_item_types[_item_index(id)], BeltManager.EMPTY)
	assert_eq(belts.belt_item_counts[id], 0)
