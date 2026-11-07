extends GutTest

const CAPACITY: int = 16

var world: FactoryWorld
var store: BeltStore
var network: BeltNetwork


func before_each() -> void:
	world = FactoryWorld.new(1000, 1000)
	store = BeltStore.new(CAPACITY)
	network = BeltNetwork.new(world, store)


func _place(belt_id: int, tile: int, direction: int) -> void:
	store.grid_indices[belt_id] = tile
	store.directions[belt_id] = direction
	network.register(belt_id, tile)
	network.refresh_near(tile)


func test_reset_initializes_empty_topology() -> void:
	assert_eq(network.belt_at.size(), world.size)
	assert_eq(network.next_indices.size(), CAPACITY)
	assert_eq(network.belt_at[1001], BeltNetwork.EMPTY)
	assert_eq(network.next_indices[0], BeltNetwork.EMPTY)


func test_register_and_unregister_own_a_tile() -> void:
	_place(0, 1001, BeltNetwork.Direction.RIGHT)
	assert_eq(network.belt_at[1001], 0)

	network.unregister(0, 1001)
	assert_eq(network.belt_at[1001], BeltNetwork.EMPTY)
	assert_eq(network.next_indices[0], BeltNetwork.EMPTY)


func test_neighbor_tile_never_wraps_rows_and_rejects_borders() -> void:
	assert_eq(network.neighbor_tile(1001, BeltNetwork.Direction.RIGHT), 1002)
	assert_eq(network.neighbor_tile(1001, BeltNetwork.Direction.DOWN), 2001)
	assert_eq(network.neighbor_tile(1001, BeltNetwork.Direction.LEFT), 1000)
	assert_eq(network.neighbor_tile(1001, BeltNetwork.Direction.UP), 1)
	# x=999 is the last column: moving right leaves the row.
	assert_eq(network.neighbor_tile(999, BeltNetwork.Direction.RIGHT), BeltNetwork.EMPTY)
	assert_eq(network.neighbor_tile(1001, BeltNetwork.Direction.LEFT), 1000)
	# x=0 is the first column: moving left leaves the row.
	assert_eq(network.neighbor_tile(1000, BeltNetwork.Direction.LEFT), BeltNetwork.EMPTY)
	assert_eq(network.neighbor_tile(0, BeltNetwork.Direction.UP), BeltNetwork.EMPTY)
	assert_eq(network.neighbor_tile(0, BeltNetwork.Direction.LEFT), BeltNetwork.EMPTY)
	assert_eq(network.neighbor_tile(-1, BeltNetwork.Direction.RIGHT), BeltNetwork.EMPTY)
	assert_eq(network.neighbor_tile(1001, 4), BeltNetwork.EMPTY)


func test_links_to_belt_in_front() -> void:
	_place(0, 1001, BeltNetwork.Direction.RIGHT)
	_place(1, 1002, BeltNetwork.Direction.RIGHT)
	assert_eq(network.next_indices[0], 1)


func test_ignores_belts_that_are_not_in_front() -> void:
	_place(0, 1001, BeltNetwork.Direction.RIGHT)
	_place(1, 1000, BeltNetwork.Direction.RIGHT) # left of source
	_place(2, 2001, BeltNetwork.Direction.RIGHT) # below source
	assert_eq(network.next_indices[0], BeltNetwork.EMPTY)


func test_links_belt_placed_later() -> void:
	_place(0, 1001, BeltNetwork.Direction.RIGHT)
	assert_eq(network.next_indices[0], BeltNetwork.EMPTY)

	_place(1, 1002, BeltNetwork.Direction.RIGHT)
	assert_eq(network.next_indices[0], 1)


func test_removing_destination_disconnects_source() -> void:
	_place(0, 1001, BeltNetwork.Direction.RIGHT)
	_place(1, 1002, BeltNetwork.Direction.RIGHT)

	network.unregister(1, 1002)
	store.clear_belt(1)
	network.refresh_near(1001)
	assert_eq(network.next_indices[0], BeltNetwork.EMPTY)


func test_clear_belt_forgets_only_the_connection() -> void:
	_place(0, 1001, BeltNetwork.Direction.RIGHT)
	_place(1, 1002, BeltNetwork.Direction.RIGHT)

	network.clear_belt(0)
	assert_eq(network.next_indices[0], BeltNetwork.EMPTY)
	assert_eq(network.belt_at[1001], 0)


func test_belt_at_map_border_has_no_output() -> void:
	_place(0, 999, BeltNetwork.Direction.RIGHT)
	assert_eq(network.next_indices[0], BeltNetwork.EMPTY)


func test_unregister_wrong_tile_does_not_steal_another_belt() -> void:
	_place(0, 1001, BeltNetwork.Direction.RIGHT)
	network.unregister(1, 1001)
	assert_eq(network.belt_at[1001], 0)
