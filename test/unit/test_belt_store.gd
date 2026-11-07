extends GutTest

const CAPACITY: int = 16

var store: BeltStore


func before_each() -> void:
	store = BeltStore.new(CAPACITY)


func test_reset_initializes_clean_state() -> void:
	assert_eq(store.capacity, CAPACITY)
	assert_eq(store.grid_indices.size(), CAPACITY)
	assert_eq(store.item_types.size(), CAPACITY * BeltStore.MAX_ITEMS_PER_BELT)
	assert_eq(store.item_positions.size(), CAPACITY * BeltStore.MAX_ITEMS_PER_BELT)
	assert_eq(store.grid_indices[0], BeltStore.EMPTY)
	assert_eq(store.item_counts[0], 0)
	assert_eq(store.occupied.size(), 0)


func test_get_item_index_flattens_belt_and_slot() -> void:
	assert_eq(store.get_item_index(0, 0), 0)
	assert_eq(store.get_item_index(2, 3), 2 * BeltStore.MAX_ITEMS_PER_BELT + 3)


func test_find_free_slot_returns_first_empty_slot() -> void:
	assert_eq(store.find_free_slot(0, 0.0), 0)


func test_find_free_slot_skips_occupied_slots() -> void:
	store.put_item(0, 1, 7, 0.5)
	assert_eq(store.find_free_slot(0, 0.0), 0)


func test_find_free_slot_rejects_position_too_close_to_an_item() -> void:
	store.put_item(0, 0, 42, 0.0)
	assert_eq(store.find_free_slot(0, 0.1), BeltStore.EMPTY)


func test_find_free_slot_accepts_position_at_min_spacing() -> void:
	store.put_item(0, 0, 42, 0.0)
	assert_eq(store.find_free_slot(0, BeltStore.MIN_ITEM_SPACING), 1)


func test_find_free_slot_returns_empty_when_full() -> void:
	for slot in range(BeltStore.MAX_ITEMS_PER_BELT):
		store.put_item(0, slot, 100 + slot, float(slot) * 0.25)
	assert_eq(store.find_free_slot(0, 1.0), BeltStore.EMPTY)


func test_put_and_take_item_roundtrip() -> void:
	store.put_item(3, 2, 42, 0.75)
	var index: int = store.get_item_index(3, 2)
	assert_eq(store.item_types[index], 42)
	assert_almost_eq(store.item_positions[index], 0.75, 0.00001)

	store.take_item(3, 2)
	assert_eq(store.item_types[index], BeltStore.EMPTY)
	assert_almost_eq(store.item_positions[index], 0.0, 0.00001)


func test_change_item_count_marks_belt_occupied() -> void:
	store.change_item_count(5, 1)
	assert_eq(store.item_counts[5], 1)
	assert_eq(store.item_count(5), 1)
	assert_true(store.occupied.contains(5))

	store.change_item_count(5, 1)
	assert_eq(store.item_counts[5], 2)
	assert_true(store.occupied.contains(5))


func test_change_item_count_clears_occupancy_at_zero() -> void:
	store.change_item_count(5, 2)
	store.change_item_count(5, -2)
	assert_eq(store.item_counts[5], 0)
	assert_false(store.occupied.contains(5))
	assert_eq(store.occupied.size(), 0)


func test_clear_belt_resets_fields_items_and_occupancy() -> void:
	store.grid_indices[5] = 10
	store.directions[5] = 2
	store.speeds[5] = 3
	store.put_item(5, 0, 42, 1.0)
	store.change_item_count(5, 1)

	store.clear_belt(5)

	assert_eq(store.grid_indices[5], BeltStore.EMPTY)
	assert_eq(store.directions[5], 0)
	assert_eq(store.speeds[5], 0)
	assert_eq(store.item_counts[5], 0)
	assert_eq(store.item_types[store.get_item_index(5, 0)], BeltStore.EMPTY)
	assert_almost_eq(store.item_positions[store.get_item_index(5, 0)], 0.0, 0.00001)
	assert_false(store.occupied.contains(5))


func test_reset_clears_previously_written_state() -> void:
	store.grid_indices[1] = 99
	store.directions[1] = 1
	store.speeds[1] = 4
	store.put_item(1, 0, 42, 0.5)
	store.change_item_count(1, 1)

	store.reset()

	assert_eq(store.grid_indices[1], BeltStore.EMPTY)
	assert_eq(store.directions[1], 0)
	assert_eq(store.speeds[1], 0)
	assert_eq(store.item_counts[1], 0)
	assert_eq(store.item_types[store.get_item_index(1, 0)], BeltStore.EMPTY)
	assert_eq(store.occupied.size(), 0)
