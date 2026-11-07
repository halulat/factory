class_name FactoryManager
extends Node

# Get catalog
var catalog = FactoryCatalog

const EMPTY = -1
var initialized: bool = false

var world: FactoryWorld = null
# BELT SUBSYSTEM
var belt_id_pool: IdPool = null
var active_belts: DenseIdSet = null
var belt_store: BeltStore = null
var belt_network: BeltNetwork = null
var belt_simulator: BeltSimulator = null


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
const MAX_MACHINE_SLOTS: int = 8 # Max eight different items per machine

# Machine management
var free_machine_ids: PackedInt32Array # Same as free_belt_ids
var active_machine_ids: PackedInt32Array # Same as active_belts.ids
var machine_active_position: PackedInt32Array # Same as belt_active_position

# Machine data
var machine_tile_indices: PackedInt32Array # Tile location
var machine_types: PackedInt32Array # Machine type ID
var machine_recipe_ids: PackedInt32Array # Current assigned recipes

# Runtime state
var machine_progress: PackedFloat32Array # Tracks how far the machine has progressed through its recipe | NOT USED YET
var machine_status: PackedByteArray # IDLE, RUNNING, NO_INPUT, etc. Can be used for optimization | NOT USED YET

# Inventory
var machine_item_types: PackedInt32Array # Resource IDs
var machine_item_amounts: PackedInt32Array # Amount of resources (just values unlike belts which need individual items)

# Tile index
var machine_at: PackedInt32Array # Maps a tile index to a machine ID (machine_at[100] = 5 means tile 100 contains machine 5)


# Initialization
func _init(factory_world: FactoryWorld = null) -> void:
	world = factory_world if factory_world != null else FactoryWorld.new(MAP_WIDTH, MAP_HEIGHT)


func _ready() -> void:
	initialize_factory() # Clear and create arrays
	#run_benchmark(10000, 100, 100, 4) comment out initialize_factory() if you want to run the benchmark test


func initialize_factory() -> void:
	free_machine_ids.clear()
	active_machine_ids.clear()

	initialize_machines(world.size)
	initialize_belts()

	initialized = true


func machine_slot(machine_id: int, slot: int) -> int: # Same as beltSlot
	return machine_id * MAX_MACHINE_SLOTS + slot


func initialize_machines(map_size: int) -> void: # Same as initializeBelts
	machine_tile_indices.resize(MAX_MACHINES)
	machine_types.resize(MAX_MACHINES)
	machine_recipe_ids.resize(MAX_MACHINES)

	machine_progress.resize(MAX_MACHINES)
	machine_status.resize(MAX_MACHINES)

	machine_item_types.resize(MAX_MACHINES * MAX_MACHINE_SLOTS)
	machine_item_amounts.resize(MAX_MACHINES * MAX_MACHINE_SLOTS)

	machine_item_types.fill(EMPTY)

	machine_at.resize(map_size)
	machine_at.fill(EMPTY)

	machine_recipe_ids.fill(EMPTY)

	machine_active_position.resize(MAX_MACHINES)
	machine_active_position.fill(EMPTY)

	for i in range(MAX_MACHINES - 1, EMPTY, EMPTY):
		free_machine_ids.append(i)


func add_machine(
	tile_index: int,
	machine_type: int,
	recipe_id: int = EMPTY,
) -> int: # Same as add_belt
	if not initialized:
		return EMPTY
	if is_tile_occupied(tile_index):
		return EMPTY
	if machine_at[tile_index] != EMPTY:
		return EMPTY

	if free_machine_ids.is_empty():
		return EMPTY

	var machine_id: int = free_machine_ids[free_machine_ids.size() - 1]
	free_machine_ids.remove_at(free_machine_ids.size() - 1)

	# Initialize machine
	machine_tile_indices[machine_id] = tile_index
	machine_types[machine_id] = machine_type
	machine_recipe_ids[machine_id] = recipe_id

	machine_progress[machine_id] = 0.0
	machine_status[machine_id] = 0

	# Clear inventory
	for slot in range(MAX_MACHINE_SLOTS):
		var index: int = machine_slot(machine_id, slot)

		machine_item_types[index] = EMPTY
		machine_item_amounts[index] = 0

	# Register machine
	machine_at[tile_index] = machine_id

	machine_active_position[machine_id] = active_machine_ids.size()
	active_machine_ids.append(machine_id)

	return machine_id


func remove_machine(machine_id: int) -> void: # Same as removeBelt
	if machine_id < 0 or machine_id >= MAX_MACHINES:
		return

	var active_position: int = machine_active_position[machine_id]

	if active_position == EMPTY:
		return

	var tile_index: int = machine_tile_indices[machine_id]

	# Remove grid lookup
	if machine_at[tile_index] == machine_id:
		machine_at[tile_index] = EMPTY

	# Clear inventory
	for slot in range(MAX_MACHINE_SLOTS):
		var index: int = machine_slot(machine_id, slot)

		machine_item_types[index] = EMPTY
		machine_item_amounts[index] = 0

	# Clear machine data
	machine_tile_indices[machine_id] = EMPTY
	machine_types[machine_id] = EMPTY
	machine_recipe_ids[machine_id] = EMPTY

	machine_progress[machine_id] = 0.0
	machine_status[machine_id] = 0

	# Swap and pop
	var last_index: int = active_machine_ids.size() - 1

	if active_position != last_index:
		var last_id: int = active_machine_ids[last_index]

		active_machine_ids[active_position] = last_id
		machine_active_position[last_id] = active_position

	active_machine_ids.resize(last_index)

	# Mark inactive and recycle ID
	machine_active_position[machine_id] = EMPTY
	free_machine_ids.append(machine_id)


const SIMULATION_UPDATES_PER_SECOND: float = 10.0 # UPS
const SIMULATION_INTERVAL: float = 1.0 / SIMULATION_UPDATES_PER_SECOND # Time inbetween updates (if simulating one frame exceeds this, the game will lag)
var simulation_accumulator: float = 0.0


func _process(delta: float) -> void:
	if not initialized:
		return

	simulation_accumulator += delta

	while simulation_accumulator >= SIMULATION_INTERVAL:
		tick(SIMULATION_INTERVAL)
		update_machines(SIMULATION_INTERVAL)
		#update_factory_performance(SIMULATION_INTERVAL) comment out updateBelts(SIMULATION_INTERVAL) and update_machines(SIMULATION_INTERVAL) if you wish to run the benchmark test
		simulation_accumulator -= SIMULATION_INTERVAL


func update_machines(delta: float) -> void:
	for machine_id in active_machine_ids:
		update_machine(machine_id, delta)


func update_machine(machine_id: int, delta: float) -> void:
	var recipe_id: int = machine_recipe_ids[machine_id]

	if recipe_id == EMPTY:
		return

	# TO DO


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


# True when the tile is out of bounds, already holds a belt or machine, or the
# world reports a building there. Belts and machines must not share a tile.
func is_tile_occupied(tile_index: int) -> bool:
	if tile_index < 0 or tile_index >= world.size:
		return true
	if belt_network != null and belt_network.belt_at[tile_index] != EMPTY:
		return true
	if machine_at[tile_index] != EMPTY:
		return true
	return not world.is_empty_index(tile_index)

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


func _is_active_belt(belt_id: int) -> bool:
	return belt_id >= 0 and belt_id < MAX_BELTS and active_belts.contains(belt_id)


func _reset_belt_data(belt_id: int) -> void:
	belt_store.clear_belt(belt_id)
	belt_network.clear_belt(belt_id)


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


# Advance the simulation by [param delta] seconds. Kept public so tests (and
# later the machine system) can drive one step without the Node process.
func tick(delta: float) -> void:
	if not initialized:
		return
	belt_simulator.tick(delta)
