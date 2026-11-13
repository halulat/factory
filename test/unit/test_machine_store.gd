extends GutTest

var store: MachineStore


func before_each() -> void:
	store = MachineStore.new(16, 1000)


func test_new_store_is_empty() -> void:
	assert_eq(store.machine_at[100], MachineStore.EMPTY)
	assert_eq(store.tile_indices[0], MachineStore.EMPTY)
	assert_eq(store.types[0], MachineStore.EMPTY)
	assert_eq(store.recipe_ids[0], MachineStore.EMPTY)
	assert_eq(store.item_types[0], MachineStore.EMPTY)
	assert_eq(store.item_amounts[0], 0)


func test_set_machine_registers_tile_and_fields() -> void:
	store.set_machine(0, 123, 4, 7)

	assert_eq(store.tile_index(0), 123)
	assert_eq(store.types[0], 4)
	assert_eq(store.recipe_ids[0], 7)
	assert_eq(store.progress[0], 0.0)
	assert_eq(store.status[0], 0)
	assert_eq(store.machine_at[123], 0)


func test_clear_machine_removes_tile_and_data() -> void:
	store.set_machine(0, 123, 4, 7)
	store.clear_machine(0)

	assert_eq(store.machine_at[123], MachineStore.EMPTY)
	assert_eq(store.tile_indices[0], MachineStore.EMPTY)
	assert_eq(store.types[0], MachineStore.EMPTY)
	assert_eq(store.recipe_ids[0], MachineStore.EMPTY)


func test_clear_machine_does_not_clear_other_machines_tile() -> void:
	store.set_machine(0, 100, 1, MachineStore.EMPTY)
	store.set_machine(1, 200, 2, MachineStore.EMPTY)

	store.clear_machine(0)

	assert_eq(store.machine_at[100], MachineStore.EMPTY)
	assert_eq(store.machine_at[200], 1)
	assert_eq(store.tile_index(1), 200)


func test_slot_index_is_machine_times_slots() -> void:
	assert_eq(store.get_slot_index(2, 3), 2 * MachineStore.MAX_MACHINE_SLOTS + 3)
	assert_eq(store.get_slot_index(0, 0), 0)


func test_set_item_round_trip() -> void:
	store.set_item(0, 5, 42, 9)

	assert_eq(store.item_type(0, 5), 42)
	assert_eq(store.item_amount(0, 5), 9)
	assert_eq(store.item_types[store.get_slot_index(0, 5)], 42)
	assert_eq(store.item_types[store.get_slot_index(1, 5)], MachineStore.EMPTY)


func test_clear_machine_clears_inventory() -> void:
	store.set_machine(0, 123, 4, MachineStore.EMPTY)
	store.set_item(0, 0, 42, 9)

	store.clear_machine(0)

	assert_eq(store.item_type(0, 0), MachineStore.EMPTY)
	assert_eq(store.item_amount(0, 0), 0)


func test_reset_clears_everything() -> void:
	store.set_machine(0, 123, 4, 7)
	store.set_item(0, 0, 42, 9)
	store.set_machine(1, 456, 2, MachineStore.EMPTY)

	store.reset()

	assert_eq(store.machine_at[123], MachineStore.EMPTY)
	assert_eq(store.machine_at[456], MachineStore.EMPTY)
	assert_eq(store.tile_indices[0], MachineStore.EMPTY)
	assert_eq(store.types[0], MachineStore.EMPTY)
	assert_eq(store.item_type(0, 0), MachineStore.EMPTY)
	assert_eq(store.item_amount(0, 0), 0)
