extends GutTest

# this file checks if the common API behaves as agreed

var world: FactoryWorld
var manager: FactoryManager

const TILE_A := Vector2i(5, 5)
const TILE_B := Vector2i(6, 5)
const TILE_C := Vector2i(7, 5)


func before_each() -> void:
	world = FactoryWorld.new(1000, 1000)
	manager = add_child_autofree(FactoryManager.new(world)) as FactoryManager
	manager.set_process(false)


func _index(tile: Vector2i) -> int:
	return world.pos_to_index(tile)


func test_empty_tile_is_not_occupied() -> void:
	assert_false(manager.is_tile_occupied(_index(TILE_A)))
	assert_true(manager.is_tile_occupied(-1))
	assert_true(manager.is_tile_occupied(world.size))


func test_belt_marks_tile_occupied() -> void:
	var belt_id: int = manager.add_belt(_index(TILE_A), FactoryManager.Direction.RIGHT, 1)

	assert_true(belt_id >= 0)
	assert_true(manager.is_tile_occupied(_index(TILE_A)))

	manager.remove_belt(belt_id)
	assert_false(manager.is_tile_occupied(_index(TILE_A)))


func test_machine_marks_tile_occupied() -> void:
	var machine_id: int = manager.add_machine(_index(TILE_A), 0)

	assert_true(machine_id >= 0)
	assert_true(manager.is_tile_occupied(_index(TILE_A)))

	manager.remove_machine(machine_id)
	assert_false(manager.is_tile_occupied(_index(TILE_A)))


func test_belt_and_machine_cannot_share_a_tile() -> void:
	var belt_id: int = manager.add_belt(_index(TILE_A), FactoryManager.Direction.RIGHT, 1)

	assert_true(belt_id >= 0)
	assert_eq(manager.add_machine(_index(TILE_A), 0), FactoryManager.EMPTY)

	var machine_id: int = manager.add_machine(_index(TILE_B), 0)

	assert_true(machine_id >= 0)
	assert_eq(
		manager.add_belt(_index(TILE_B), FactoryManager.Direction.RIGHT, 1),
		FactoryManager.EMPTY,
	)


func test_world_building_blocks_both() -> void:
	var tile: int = _index(TILE_A)

	world.place_building_at_index(7, tile)

	assert_true(manager.is_tile_occupied(tile))
	assert_eq(manager.add_belt(tile, FactoryManager.Direction.RIGHT, 1), FactoryManager.EMPTY)
	assert_eq(manager.add_machine(tile, 0), FactoryManager.EMPTY)


func test_freed_belt_id_is_reused() -> void:
	var first: int = manager.add_belt(_index(TILE_A), FactoryManager.Direction.RIGHT, 1)
	var second: int = manager.add_belt(_index(TILE_B), FactoryManager.Direction.RIGHT, 1)

	manager.remove_belt(first)

	assert_eq(manager.add_belt(_index(TILE_C), FactoryManager.Direction.RIGHT, 1), first)
	assert_ne(second, first)


func test_tick_advances_belts_without_process() -> void:
	var belt_id: int = manager.add_belt(_index(TILE_A), FactoryManager.Direction.RIGHT, 2)

	assert_true(manager.try_insert_belt_item(belt_id, 1))

	manager.tick(0.1)

	var slot: int = manager.belt_store.get_item_index(belt_id, 0)

	assert_almost_eq(manager.belt_store.item_positions[slot], 0.2, 0.00001)


func test_initialize_factory_resets_both_subsystems() -> void:
	var belt_id: int = manager.add_belt(_index(TILE_A), FactoryManager.Direction.RIGHT, 1)
	var machine_id: int = manager.add_machine(_index(TILE_B), 0)

	assert_true(belt_id >= 0)
	assert_true(machine_id >= 0)
	assert_true(manager.try_insert_belt_item(belt_id, 3))

	manager.initialize_factory()

	assert_eq(manager.active_belts.size(), 0)
	assert_eq(manager.active_machine_ids.size(), 0)
	assert_eq(manager.belt_store.item_count(belt_id), 0)
	assert_eq(manager.machine_at[_index(TILE_B)], FactoryManager.EMPTY)
	assert_false(manager.is_tile_occupied(_index(TILE_A)))


# check if API is broken
const FROZEN_PUBLIC_API: Array[String] = [
	"add_belt",
	"add_machine",
	"belt_item_count",
	"initialize_belts",
	"initialize_factory",
	"initialize_machines",
	"is_tile_occupied",
	"machine_slot",
	"remove_belt",
	"remove_machine",
	"run_benchmark",
	"tick",
	"try_insert_belt_item",
	"try_take_belt_item",
	"update_factory_performance",
	"update_machine",
	"update_machines",
]


func _public_methods() -> Array[String]:
	var script: Script = load("uid://dqremj44s4uon")
	var names: Array[String] = []

	for method in script.get_script_method_list():
		var method_name: String = method["name"]

		if not method_name.begins_with("_"):
			names.append(method_name)

	names.sort()
	return names


func test_public_api_is_frozen() -> void:
	assert_eq(
		_public_methods(),
		FROZEN_PUBLIC_API.duplicate(),
		"FactoryManager's public API changed: update FROZEN_PUBLIC_API only if the change is intended",
	)
