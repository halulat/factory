class_name FactoryManager
extends Node

const EMPTY = -1

# Grid size not pixels
const MAP_WIDTH: int = 1000
const MAP_HEIGHT: int = 1000
const MAP_SIZE: int = MAP_WIDTH * MAP_HEIGHT

const MAX_BELTS: int = 50000
const MAX_ITEMS_PER_BELT: int = BeltStore.MAX_ITEMS_PER_BELT
const MIN_ITEM_SPACING: float = BeltStore.MIN_ITEM_SPACING

const Direction = BeltNetwork.Direction

# MACHINES
# Machine capacity
const MAX_MACHINES: int = 50000
const MAX_MACHINE_SLOTS: int = MachineStore.MAX_MACHINE_SLOTS

const SIMULATION_UPDATES_PER_SECOND: float = 10.0 # UPS
const SIMULATION_INTERVAL: float = 1.0 / SIMULATION_UPDATES_PER_SECOND # Time inbetween updates (if simulating one frame exceeds this, the game will lag)

# Get catalog
var catalog = FactoryCatalog
var initialized: bool = false

var world: FactoryWorld = null
# BELT SUBSYSTEM
var belt_id_pool: IdPool = null
var active_belts: DenseIdSet = null
var belt_store: BeltStore = null
var belt_network: BeltNetwork = null
var belt_simulator: BeltSimulator = null
var machine_id_pool: IdPool = null
var active_machines: DenseIdSet = null
var machine_store: MachineStore = null
var simulation_accumulator: float = 0.0


# Initialization
func _init(factory_world: FactoryWorld = null) -> void:
	world = factory_world if factory_world != null else FactoryWorld.new(MAP_WIDTH, MAP_HEIGHT)


func _ready() -> void:
	initialize_factory() # Clear and create arrays
	#run_benchmark(10000, 100, 100, 4) comment out initialize_factory() if you want to run the benchmark test


func _process(delta: float) -> void:
	if not initialized:
		return

	simulation_accumulator += delta

	while simulation_accumulator >= SIMULATION_INTERVAL:
		tick(SIMULATION_INTERVAL)
		update_machines(SIMULATION_INTERVAL)
		simulation_accumulator -= SIMULATION_INTERVAL


func initialize_factory() -> void:
	initialize_machines(world.size)
	initialize_belts()

	initialized = true


func update_machines(delta: float) -> void:
	for machine_id in active_machines.ids:
		update_machine(machine_id, delta)


func update_machine(machine_id: int, delta: float) -> void:
	var recipe_id: int = machine_store.recipe_ids[machine_id]

	if recipe_id == EMPTY:
		return

	# TO DO


# True when the tile is out of bounds, already holds a belt or machine, or the
# world reports a building there. Belts and machines must not share a tile.
func is_tile_occupied(tile_index: int) -> bool:
	if tile_index < 0 or tile_index >= world.size:
		return true
	if belt_network != null and belt_network.belt_at[tile_index] != EMPTY:
		return true
	if machine_store != null and machine_store.machine_at[tile_index] != EMPTY:
		return true
	return not world.is_empty_index(tile_index)


# Advance the simulation by delta seconds.
func tick(delta: float) -> void:
	if not initialized:
		return
	belt_simulator.tick(delta)


# BELT COMMON API
# The manager owns the world, the id pool, the active set and the clock; belt
# and item storage lives in BeltStore, topology in BeltNetwork and one step in
# BeltSimulator.
func initialize_belts() -> void:
	simulation_accumulator = 0.0

	if belt_id_pool == null:
		belt_id_pool = IdPool.new(MAX_BELTS)
	else:
		belt_id_pool.reset()
	if active_belts == null:
		active_belts = DenseIdSet.new(MAX_BELTS)
	else:
		active_belts.clear()
	if belt_store == null:
		belt_store = BeltStore.new(MAX_BELTS)
	else:
		belt_store.reset()
	if belt_network == null:
		belt_network = BeltNetwork.new(world, belt_store)
	else:
		belt_network.reset()
	if belt_simulator == null:
		belt_simulator = BeltSimulator.new(belt_store, belt_network, active_belts)


func add_belt(tile_index: int, direction: int, speed: int) -> int:
	if not initialized:
		return EMPTY
	if tile_index < 0 or tile_index >= world.size:
		return EMPTY
	if direction < 0 or direction >= BeltNetwork.Direction.size():
		return EMPTY
	if speed < 0 or speed > 255:
		return EMPTY
	# The placement controller registers the global building after this call.
	if is_tile_occupied(tile_index):
		return EMPTY

	var belt_id: int = belt_id_pool.acquire()
	_reset_belt_data(belt_id)
	belt_store.grid_indices[belt_id] = tile_index
	belt_store.directions[belt_id] = direction
	belt_store.speeds[belt_id] = speed
	belt_network.register(belt_id, tile_index)
	active_belts.add(belt_id)
	belt_network.refresh_near(tile_index)
	return belt_id


func remove_belt(belt_id: int) -> void:
	if not _is_active_belt(belt_id):
		return

	var tile_index: int = belt_store.grid_indices[belt_id]
	belt_network.unregister(belt_id, tile_index)
	belt_store.clear_belt(belt_id)
	active_belts.remove(belt_id)
	belt_id_pool.release(belt_id)
	belt_network.refresh_near(tile_index)


func try_insert_belt_item(belt_id: int, resource_id: int) -> bool:
	if not _is_active_belt(belt_id) or resource_id < 0:
		return false
	var slot: int = belt_store.find_free_slot(belt_id, 0.0)
	if slot == EMPTY:
		return false
	belt_store.put_item(belt_id, slot, resource_id, 0.0)
	belt_store.change_item_count(belt_id, 1)
	return true


func try_take_belt_item(belt_id: int, resource_id: int) -> bool:
	if not _is_active_belt(belt_id):
		return false
	for slot in range(MAX_ITEMS_PER_BELT):
		var index: int = belt_store.get_item_index(belt_id, slot)
		if belt_store.item_types[index] != resource_id:
			continue
		if belt_store.item_positions[index] < BeltStore.EXIT_POSITION:
			continue
		belt_store.take_item(belt_id, slot)
		belt_store.change_item_count(belt_id, -1)
		return true
	return false


func belt_item_count(belt_id: int) -> int:
	if not _is_active_belt(belt_id):
		return 0
	return belt_store.item_count(belt_id)


# MACHINE COMMON API
# The manager owns machine IDs, the active set and the clock; machine storage
# lives in MachineStore. Behaviour moves to MachineSimulator next checkpoint.
func initialize_machines(map_size: int) -> void:
	if machine_id_pool == null:
		machine_id_pool = IdPool.new(MAX_MACHINES)
	else:
		machine_id_pool.reset()
	if active_machines == null:
		active_machines = DenseIdSet.new(MAX_MACHINES)
	else:
		active_machines.clear()
	if machine_store == null:
		machine_store = MachineStore.new(MAX_MACHINES, map_size)
	else:
		machine_store.reset()


func machine_slot(machine_id: int, slot: int) -> int:
	return machine_store.get_slot_index(machine_id, slot)


func add_machine(tile_index: int, machine_type: int, recipe_id: int = EMPTY) -> int:
	if not initialized:
		return EMPTY
	if is_tile_occupied(tile_index):
		return EMPTY

	var machine_id: int = machine_id_pool.acquire()

	if machine_id == IdPool.INVALID_ID:
		return EMPTY

	machine_store.set_machine(machine_id, tile_index, machine_type, recipe_id)
	active_machines.add(machine_id)
	return machine_id


func remove_machine(machine_id: int) -> void:
	if not _is_active_machine(machine_id):
		return

	machine_store.clear_machine(machine_id)
	active_machines.remove(machine_id)
	machine_id_pool.release(machine_id)


# Benchmark Test
func run_benchmark(
	belt_count: int,
	machine_count: int,
	occupied_percentage: float = 100.0,
	items_per_belt: int = 1,
) -> void:
	initialize_factory()

	var belts_added := 0
	var machines_added := 0
	var occupied_added := 0
	var items_added := 0

	# Add belts
	for tile_index in range(MAP_SIZE):
		if belts_added >= belt_count:
			break

		var belt_id := add_belt(tile_index, 1, 10)

		if belt_id != EMPTY:
			belts_added += 1

	# Add machines
	for tile_index in range(MAP_SIZE):
		if machines_added >= machine_count:
			break

		if belt_network.belt_at[tile_index] != EMPTY: # If there is already a belt at that tile index, skip it
			continue

		var machine_id := add_machine(tile_index, 0)

		if machine_id != EMPTY:
			machines_added += 1

	# Calculate how many belts should contain items
	var target_occupied := int(belts_added * clampf(occupied_percentage, 0.0, 100.0) / 100.0)

	# Populate belts
	for belt_id in active_belts.ids:
		if occupied_added >= target_occupied:
			break

		var added_to_belt := 0

		for i in range(items_per_belt):
			if try_insert_belt_item(belt_id, i):
				added_to_belt += 1
				items_added += 1
			else:
				break

		if added_to_belt > 0:
			occupied_added += 1

	print("Benchmark setup complete:")
	print("Belts: ", belts_added)
	print("Machines: ", machines_added)
	print("Occupied belts: ", occupied_added)
	print("Items: ", items_added)
	print("Occupied list size: ", belt_store.occupited.size())


func update_factory_performance(delta: float) -> void:
	var start_time := Time.get_ticks_usec()

	belt_simulator.tick(delta)

	var belt_time := Time.get_ticks_usec() - start_time

	start_time = Time.get_ticks_usec()

	update_machines(delta)

	var machine_time := Time.get_ticks_usec() - start_time

	print("Belts: ", belt_time / 1000.0, " ms | ", "Machines: ", machine_time / 1000.0, " ms")


func _is_active_belt(belt_id: int) -> bool:
	return belt_id >= 0 and belt_id < MAX_BELTS and active_belts.contains(belt_id)


func _reset_belt_data(belt_id: int) -> void:
	belt_store.clear_belt(belt_id)
	belt_network.clear_belt(belt_id)


func _is_active_machine(machine_id: int) -> bool:
	return machine_id >= 0 and machine_id < MAX_MACHINES and active_machines.contains(machine_id)
