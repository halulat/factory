extends GutTest
# Focused tests for BeltSimulator: move-then-transfer ordering, blocked
# destinations, the one-free-slot race between two sources, and item-count
# conservation over a long soak.

const CAPACITY: int = 16

var world: FactoryWorld
var store: BeltStore
var network: BeltNetwork
var active: DenseIdSet
var simulator: BeltSimulator


func before_each() -> void:
	world = FactoryWorld.new(1000, 1000)
	store = BeltStore.new(CAPACITY)
	network = BeltNetwork.new(world, store)
	active = DenseIdSet.new(CAPACITY)
	simulator = BeltSimulator.new(store, network, active)


func _place(belt_id: int, tile: int, direction: int, speed: int = 1) -> void:
	store.grid_indices[belt_id] = tile
	store.directions[belt_id] = direction
	store.speeds[belt_id] = speed
	network.register(belt_id, tile)
	active.add(belt_id)
	network.refresh_near(tile)


func _add_item(belt_id: int, slot: int, item_type: int, position: float) -> void:
	store.put_item(belt_id, slot, item_type, position)
	store.change_item_count(belt_id, 1)


func _position(belt_id: int, slot: int) -> float:
	return store.item_positions[store.get_item_index(belt_id, slot)]


func _total_items() -> int:
	var total: int = 0
	for belt_id in store.occupied.ids:
		total += store.item_counts[belt_id]
	return total


func test_move_items_advances_by_speed_times_delta() -> void:
	_place(0, 1001, BeltNetwork.Direction.RIGHT, 2)
	_add_item(0, 0, 42, 0.1)

	simulator.move_items(0, 0.1)

	assert_almost_eq(_position(0, 0), 0.3, 0.00001)


func test_zero_speed_belt_does_not_move_items() -> void:
	_place(0, 1001, BeltNetwork.Direction.RIGHT, 0)
	_add_item(0, 0, 42, 0.5)

	simulator.tick(1.0)

	assert_almost_eq(_position(0, 0), 0.5, 0.00001)


func test_tick_transfers_item_at_exit() -> void:
	_place(0, 1001, BeltNetwork.Direction.RIGHT)
	_place(1, 1002, BeltNetwork.Direction.RIGHT)
	_add_item(0, 0, 42, 1.1)

	simulator.tick(0.0)

	assert_eq(store.item_counts[0], 0)
	assert_eq(store.item_counts[1], 1)
	assert_almost_eq(_position(1, 0), 0.1, 0.00001)


func test_tick_moves_before_transferring() -> void:
	_place(0, 1001, BeltNetwork.Direction.RIGHT)
	_place(1, 1002, BeltNetwork.Direction.RIGHT)
	_add_item(0, 0, 42, 0.95)

	simulator.tick(0.1)

	# 0.95 + 0.1 crosses the exit in the same tick, so it transfers at 0.05.
	assert_eq(store.item_counts[0], 0)
	assert_eq(store.item_counts[1], 1)
	assert_almost_eq(_position(1, 0), 0.05, 0.00001)


func test_blocked_destination_keeps_item_on_source() -> void:
	_place(0, 1001, BeltNetwork.Direction.RIGHT)
	_place(1, 1002, BeltNetwork.Direction.RIGHT)
	for slot in range(BeltStore.MAX_ITEMS_PER_BELT):
		_add_item(1, slot, 100 + slot, float(slot) * 0.25)
	_add_item(0, 0, 42, 1.0)

	simulator.tick(0.0)

	assert_eq(store.item_counts[1], BeltStore.MAX_ITEMS_PER_BELT)
	assert_eq(store.item_counts[0], 1)
	assert_eq(_total_items(), BeltStore.MAX_ITEMS_PER_BELT + 1)


func test_two_sources_to_one_free_slot_transfers_exactly_one() -> void:
	# dest at 1002 has one free slot; both 1001 and 2 point into it.
	_place(1, 1002, BeltNetwork.Direction.RIGHT)
	for slot in range(BeltStore.MAX_ITEMS_PER_BELT - 1):
		_add_item(1, slot, 100 + slot, 0.5 + float(slot) * 0.25)
	_place(0, 1001, BeltNetwork.Direction.RIGHT)
	_place(3, 2, BeltNetwork.Direction.DOWN)
	_add_item(0, 0, 42, 1.0)
	_add_item(3, 0, 43, 1.0)

	simulator.tick(0.0)

	assert_eq(store.item_counts[1], BeltStore.MAX_ITEMS_PER_BELT)
	assert_eq(_total_items(), BeltStore.MAX_ITEMS_PER_BELT + 1)
	var source_counts: Array = [store.item_counts[0], store.item_counts[3]]
	assert_eq(source_counts.count(0), 1, "exactly one source item transferred")
	assert_eq(source_counts.count(1), 1, "the other source item stayed put")


func test_transfer_requires_active_destination() -> void:
	_place(0, 1001, BeltNetwork.Direction.RIGHT)
	# Claim the downstream tile without joining the active set.
	store.grid_indices[1] = 1002
	network.register(1, 1002)
	network.refresh_near(1001)
	_add_item(0, 0, 42, 1.0)

	simulator.tick(0.0)

	assert_eq(store.item_counts[0], 1)
	assert_eq(store.item_counts[1], 0)


func test_thousand_tick_soak_conserves_items() -> void:
	_place(0, 1001, BeltNetwork.Direction.RIGHT)
	_place(1, 1002, BeltNetwork.Direction.RIGHT)
	_add_item(0, 0, 42, 0.1)
	_add_item(0, 1, 43, 0.5)
	assert_eq(_total_items(), 2)

	for _tick in range(1000):
		simulator.tick(0.1)
		if _total_items() != 2:
			fail_test("item count changed to %d on tick %d" % [_total_items(), _tick])
			return

	assert_eq(store.item_counts[0], 0)
	assert_eq(store.item_counts[1], 2)
