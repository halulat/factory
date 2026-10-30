class_name FactoryManager
extends Node

# Has grid system that stores where things are
#-> should move to own class

# Has regeristy for ids
# -> should be own class

# Stores Belt Inventories
# -> can be stored in runtime instance

# Simulates Belt logic
# ->  should be in own class

# Simulates machine logic
# -> should be in own class

# THIS CLASS should schedule the update ticks

# belt is combination of all belt arrays
# current architecture is SoA (struct of Array) should be AoS for prototype
# -> create building insatance class (RefCounted) let belt and machine inherit


# belt logic
# 1 move items internally
	# update item array from exit to enter
	# keep items sorted in array
#   
# 2 resolve transfers after moving all items
	#pending[]
	#reserved[]
	#
	#if can tansfer
		#add transfer to can tranfer
	#
	#for belt in can transfer
	#if null continue
	#if target has no space continue
	#if in reserved continue
	#
	#add to reserved
	#add to pending
# 3 commit changes
# 	apply transfers in pending

# ISSUES 
# magic numbers -1 -> EMPTY = -1

# ID registery should be own class

# Position info should be own class

# current internal item update doesn't prevent overlapping could have a min dist
# from front object





# Get catalog
@onready var catalog: FactoryCatalog = get_node("../FactoryCatalog")

const EMPTY = -1
var initialized: bool = false

# Grid size not pixels
const MAP_WIDTH: int = 1000
const MAP_HEIGHT: int = 1000
const MAP_SIZE: int = MAP_WIDTH * MAP_HEIGHT

# BELTS
# Belt capacity
const MAX_BELTS: int = 50000
const MAX_ITEMS_PER_BELT: int = 4
const MIN_ITEM_SPACING: float = 0.2

# Belt management
var free_belt_ids: PackedInt32Array # Contains all belt IDs that aren't currently being used
var active_belt_ids: PackedInt32Array # Contains every belt currently existing in your factory
var belt_active_position: PackedInt32Array # This is a reverse lookup array. Shows where a belt ID is located inside active_belt_ids
var occupied_belt_ids: PackedInt32Array # Contains only belts that currently have at least one item
var belt_occupied_position: PackedInt32Array # A temporary array used during belt transfers instead of occupied_belt_ids since occupied_belt_ids can change mid transfer
var belt_transfer_ids: PackedInt32Array # A temporary array used during belt transfers instead of occupied_belt_ids since occupied_belt_ids can change mid transfer

# Belt data
var belt_tile_indices: PackedInt32Array # Which tile the belt occupies
var belt_directions: PackedByteArray 
var belt_speeds: PackedByteArray
var belt_next_indices: PackedInt32Array # Which belt is recieving from this belt

# Inventory
var belt_item_types: PackedInt32Array # Resource IDs
var belt_item_positions: PackedFloat32Array # How far along each item is on the belt (0.0 to 1.0)
var belt_item_counts: PackedByteArray # Number of items on the belt (used to avoid checking all slots if the belt only has one item)

# Tile index. -1 means no belt
var belt_at: PackedInt32Array # Maps a tile index to a belt ID (belt_at[100] = 5 means tile 100 contains belt 5)

# Belt Directions
enum Direction {
	UP,
	RIGHT,
	DOWN,
	LEFT
}

#
const DIRECTION_OFFSETS: Array[Vector2i] = [
	Vector2i(0, -1), # Up
	Vector2i(1, 0),  # Right
	Vector2i(0, 1),  # Down
	Vector2i(-1, 0)  # Left
]

# MACHINES
# Machine capacity
const MAX_MACHINES: int = 50000
const MAX_MACHINE_SLOTS: int = 8 # Max eight different items per machine

# Machine management
var free_machine_ids: PackedInt32Array # Same as free_belt_ids
var active_machine_ids: PackedInt32Array # Same as active_belt_ids
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
func _ready() -> void:
	catalog.initialize() # Fill catalog with all definitions
	initialize_factory(MAP_SIZE) # Clear and create arrays
	#run_benchmark(10000, 100, 100, 4) comment out initialize_factory(MAP_SIZE) if you want to run the benchmark test

func initialize_factory(map_size: int) -> void:
	free_belt_ids.clear()
	active_belt_ids.clear()
	
	free_machine_ids.clear()
	active_machine_ids.clear()
	
	initializeBelts(map_size)
	initializeMachines(map_size)
	
	initialized = true

func initializeBelts(map_size: int) -> void:
	belt_tile_indices.resize(MAX_BELTS)
	belt_directions.resize(MAX_BELTS)
	belt_speeds.resize(MAX_BELTS)
	belt_next_indices.resize(MAX_BELTS)

	belt_item_types.resize(
		MAX_BELTS * MAX_ITEMS_PER_BELT
	)
	belt_item_positions.resize(
		MAX_BELTS * MAX_ITEMS_PER_BELT
	)
	
	belt_item_types.fill(EMPTY) # In case we have Resource ID 0
	
	belt_item_counts.resize(MAX_BELTS)
	belt_item_counts.fill(0)

	belt_at.resize(map_size)
	belt_at.fill(EMPTY) # belt_at of an empty tile will return EMPTY

	belt_next_indices.fill(EMPTY) # By default every belt will feed nowhere
	
	belt_active_position.resize(MAX_BELTS)
	belt_active_position.fill(EMPTY) 
	
	occupied_belt_ids.clear()
	belt_transfer_ids.clear()

	belt_occupied_position.resize(MAX_BELTS)
	belt_occupied_position.fill(EMPTY)

	for i in range(MAX_BELTS - 1, EMPTY, EMPTY):
		free_belt_ids.append(i) # By default all belt IDs are available


func beltSlot(belt_id: int, slot: int) -> int: # Turns a Belt ID and a slot in a belt (1 to 4) into a single index
	return belt_id * MAX_ITEMS_PER_BELT + slot # If each belt can have a max of 4 items, then Belt ID 20 and slot 3 would give index 83

func machineSlot(machine_id: int, slot: int) -> int: # Same as beltSlot
	return machine_id * MAX_MACHINE_SLOTS + slot


func initializeMachines(map_size: int) -> void: # Same as initializeBelts
	machine_tile_indices.resize(MAX_MACHINES)
	machine_types.resize(MAX_MACHINES)
	machine_recipe_ids.resize(MAX_MACHINES)

	machine_progress.resize(MAX_MACHINES)
	machine_status.resize(MAX_MACHINES)

	machine_item_types.resize(
		MAX_MACHINES * MAX_MACHINE_SLOTS
	)
	machine_item_amounts.resize(
		MAX_MACHINES * MAX_MACHINE_SLOTS
	)
	
	machine_item_types.fill(EMPTY)

	machine_at.resize(map_size)
	machine_at.fill(EMPTY)

	machine_recipe_ids.fill(EMPTY)
	
	machine_active_position.resize(MAX_MACHINES)
	machine_active_position.fill(EMPTY)

	for i in range(MAX_MACHINES - 1, EMPTY, EMPTY):
		free_machine_ids.append(i)

func addBelt(tile_index: int, direction: int, speed: int) -> int:
	if tile_index < 0 or tile_index >= belt_at.size(): # Is tile inside map
		return EMPTY

	if belt_at[tile_index] != EMPTY: # Is tile already occupied
		return EMPTY

	if free_belt_ids.is_empty(): # Are there any free belt IDs (if not that means they already exceeded the maximum belt limit)
		return EMPTY

	var belt_id: int = free_belt_ids[free_belt_ids.size() - 1] # Last available ID
	free_belt_ids.remove_at(free_belt_ids.size() - 1) # Remove that ID from the list of free belt IDs

	# Initialize data
	belt_tile_indices[belt_id] = tile_index
	belt_directions[belt_id] = direction
	belt_speeds[belt_id] = speed
	belt_next_indices[belt_id] = EMPTY

	# Clear inventory
	for slot in range(MAX_ITEMS_PER_BELT):
		var index: int = beltSlot(belt_id, slot)
		belt_item_types[index] = EMPTY
		belt_item_positions[index] = 0.0
	
	belt_item_counts[belt_id] = 0

	# Register belt
	belt_at[tile_index] = belt_id # Belt at tile_index is belt_id

	belt_active_position[belt_id] = active_belt_ids.size()
	active_belt_ids.append(belt_id)
	
	updateBeltConnetions(belt_id) # Update belt_next_indices

	# Update neighbouring belts' connections
	for dir in range(4):
		var neighbour_tile: int = getNeighbourTileIndex(
			tile_index,
			dir
		)

		if neighbour_tile == EMPTY: # Empty
			continue

		var neighbour_id: int = belt_at[neighbour_tile] # Look up belt ID using the neighbouring tile

		if neighbour_id != EMPTY:
			updateBeltConnetions(neighbour_id)

	return belt_id
	
func removeBelt(belt_id: int) -> void: # Instead of shifting every belt in the array, swap the last belt with the one being removed and shrink the array (swap and pop method)
	if belt_id < 0 or belt_id >= MAX_BELTS:
		return

	var active_position: int = belt_active_position[belt_id]

	if active_position == EMPTY:
		return

	var tile_index: int = belt_tile_indices[belt_id]

	# Remove grid lookup
	if belt_at[tile_index] == belt_id:
		belt_at[tile_index] = EMPTY

	# Disconnect incoming belts
	for other_id in active_belt_ids:
		if belt_next_indices[other_id] == belt_id:
			belt_next_indices[other_id] = EMPTY
			
	removeOccupiedBelt(belt_id) # Remove this belt ID from occupied belts array

	# Clear inventory
	for slot in range(MAX_ITEMS_PER_BELT):
		var index: int = beltSlot(belt_id, slot)

		belt_item_types[index] = EMPTY
		belt_item_positions[index] = 0.0
		
	belt_item_counts[belt_id] = 0

	# Clear belt data
	belt_tile_indices[belt_id] = EMPTY
	belt_directions[belt_id] = 0
	belt_speeds[belt_id] = 0
	belt_next_indices[belt_id] = EMPTY

	# Swap and pop
	var last_index: int = active_belt_ids.size() - 1

	if active_position != last_index:
		var last_id: int = active_belt_ids[last_index]

		active_belt_ids[active_position] = last_id
		belt_active_position[last_id] = active_position

	active_belt_ids.resize(last_index)

	# Mark inactive and recycle ID
	belt_active_position[belt_id] = EMPTY
	free_belt_ids.append(belt_id)
	
func addMachine(tile_index: int, machine_type: int, recipe_id: int = EMPTY) -> int: # Same as addBelt

	if tile_index < 0 or tile_index >= machine_at.size():
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
		var index: int = machineSlot(machine_id, slot)

		machine_item_types[index] = EMPTY
		machine_item_amounts[index] = 0

	# Register machine
	machine_at[tile_index] = machine_id

	machine_active_position[machine_id] = active_machine_ids.size()
	active_machine_ids.append(machine_id)

	return machine_id
	
func removeMachine(machine_id: int) -> void: # Same as removeBelt
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
		var index: int = machineSlot(machine_id, slot)

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
	
func getNeighbourTileIndex(tile_index: int, direction: int) -> int: # Returns the tile index immediately next to a given tile in x direction
	if direction < 0 or direction > 3:
		return EMPTY

	# Index = y * MAP_WIDTH + x
	# This reverses that by taking an index and producing x and y
	var x: int = tile_index % MAP_WIDTH
	var y: int = tile_index / MAP_WIDTH

	var offset: Vector2i = DIRECTION_OFFSETS[direction]

	var nx: int = x + offset.x
	var ny: int = y + offset.y

	if nx < 0 or nx >= MAP_WIDTH:
		return EMPTY

	if ny < 0 or ny >= MAP_HEIGHT:
		return EMPTY

	return ny * MAP_WIDTH + nx
	
func oppositeDirection(direction: int) -> int:
	return (direction + 2) % 4 # Returns the opposite direction (UP 0 turns to DOWN 2, LEFT 3 turns to RIGHT 1)
	
func updateBeltConnetions(belt_id: int) -> void: # Updates belt_next_indices when addBelt is called
	if belt_active_position[belt_id] == EMPTY:
		return

	var tile_index: int = belt_tile_indices[belt_id]
	var direction: int = belt_directions[belt_id]

	# Find the belt this belt outputs into
	var output_tile: int = getNeighbourTileIndex(
		tile_index,
		direction
	)

	if output_tile != EMPTY: # If tile isn't empty
		var output_belt: int = belt_at[output_tile] # Get belt ID from tile index

		if output_belt != EMPTY: # If belt exists
			belt_next_indices[belt_id] = output_belt # Save the Belt ID
		else:
			belt_next_indices[belt_id] = EMPTY # This belt feeds into no other belt
	else:
		belt_next_indices[belt_id] = EMPTY # This belt feeds into no other belt

	# Find neighbouring belts that output into this belt
	for dir in range(4):
		var neighbour_tile: int = getNeighbourTileIndex(
			tile_index,
			dir
		)

		if neighbour_tile == EMPTY:
			continue

		var neighbour_id: int = belt_at[neighbour_tile]

		if neighbour_id == EMPTY:
			continue

		var neighbor_direction: int = belt_directions[neighbour_id]

		# Does this neighbouring belt point towards this belt
		if neighbor_direction == oppositeDirection(dir):
			belt_next_indices[neighbour_id] = belt_id # Update the neighbouring belt's belt_next_indices with this belt's ID

# The two functions below (addOccupiedBelt and removeOccupiedBelt) update the occupied belt array which is used for optimization (_process ignores empty belts)
func addOccupiedBelt(belt_id: int) -> void:
	if belt_occupied_position[belt_id] != EMPTY:
		return

	belt_occupied_position[belt_id] = occupied_belt_ids.size()
	occupied_belt_ids.append(belt_id)

func removeOccupiedBelt(belt_id: int) -> void:
	var position: int = belt_occupied_position[belt_id]

	if position == EMPTY:
		return
	
	# Swap and Pop
	var last_index: int = occupied_belt_ids.size() - 1

	if position != last_index:
		var last_id: int = occupied_belt_ids[last_index]

		occupied_belt_ids[position] = last_id
		belt_occupied_position[last_id] = position

	occupied_belt_ids.resize(last_index)
	belt_occupied_position[belt_id] = EMPTY
	
func changeBeltItemCount(belt_id: int, change: int) -> void: 
	# This is called during item transfers between belts
	# If a belt becomes empty or becomes no longer empty, remove/add it to the occupied belt list
	var old_count := belt_item_counts[belt_id]
	var new_count := old_count + change

	belt_item_counts[belt_id] = new_count

	if old_count == 0 and new_count > 0:
		addOccupiedBelt(belt_id)
	elif old_count > 0 and new_count == 0:
		removeOccupiedBelt(belt_id)

func tryInsertItem(belt_id: int, resource_id: int) -> bool: # Used by machines to add items to belts
	if belt_id < 0 or belt_id >= MAX_BELTS:
		return false

	if belt_active_position[belt_id] == EMPTY:
		return false

	if resource_id < 0:
		return false

	var entry_position := 0.0

	var slot := findAvailableBeltSlot(
		belt_id,
		entry_position
	)

	if slot == EMPTY:
		return false

	var index := beltSlot(belt_id, slot)

	belt_item_types[index] = resource_id
	belt_item_positions[index] = entry_position

	changeBeltItemCount(belt_id, 1)

	return true

func tryRemoveItem( # Used by machines to remove items from belts
	belt_id: int,
	resource_id: int
) -> bool:
	if belt_id < 0 or belt_id >= MAX_BELTS:
		return false

	if belt_active_position[belt_id] == EMPTY:
		return false

	for slot in range(MAX_ITEMS_PER_BELT):
		var index: int = beltSlot(belt_id, slot)

		if belt_item_types[index] != resource_id:
			continue

		if belt_item_positions[index] < 1.0:
			continue

		belt_item_types[index] = EMPTY
		belt_item_positions[index] = 0.0
		
		changeBeltItemCount(belt_id, EMPTY)

		return true
	return false

func findAvailableBeltSlot(belt_id: int, position: float) -> int: # Find the first available slot on a belt when adding items (since belts have a max item limit)
	var empty_slot := EMPTY

	for slot in range(MAX_ITEMS_PER_BELT):
		var index := beltSlot(belt_id, slot)

		if belt_item_types[index] == EMPTY:
			if empty_slot == EMPTY:
				empty_slot = slot
			continue

		if abs(belt_item_positions[index] - position) < MIN_ITEM_SPACING:
			return EMPTY
	return empty_slot


# PROTOTYPE (If we use this, move constants and _process to top of file)

const SIMULATION_UPDATES_PER_SECOND: float = 10.0 # UPS
const SIMULATION_INTERVAL: float = 1.0 / SIMULATION_UPDATES_PER_SECOND # Time inbetween updates (if simulating one frame exceeds this, the game will lag)

var simulation_accumulator: float = 0.0

func _process(delta: float) -> void:
	if not initialized:
		return

	simulation_accumulator += delta

	while simulation_accumulator >= SIMULATION_INTERVAL:
		updateBelts(SIMULATION_INTERVAL)
		updateMachines(SIMULATION_INTERVAL)
		#update_factory_performance(SIMULATION_INTERVAL) comment out updateBelts(SIMULATION_INTERVAL) and updateMachines(SIMULATION_INTERVAL) if you wish to run the benchmark test

		simulation_accumulator -= SIMULATION_INTERVAL

func updateBelts(delta: float) -> void:
	# Move items only on occupied belts
	for belt_id in occupied_belt_ids:
		moveBeltItems(belt_id, delta) # Move items internally for each belt

	belt_transfer_ids.clear()
	belt_transfer_ids.append_array(occupied_belt_ids) # Temporary array since occupied_belt_ids may change mid update

	for belt_id in belt_transfer_ids:
		if belt_occupied_position[belt_id] == EMPTY:
			continue
			
		transferBeltItems(belt_id) # Move items between belts

func moveBeltItems(belt_id: int, delta: float) -> void:
	var speed: float = float(belt_speeds[belt_id])
	
	for slot in range(MAX_ITEMS_PER_BELT):
		var item_index: int = beltSlot(belt_id, slot)
		
		if belt_item_types[item_index] == EMPTY:
			continue
			
		belt_item_positions[item_index] += speed * delta # belt_item_positions is from 0.0 to 1.0

func transferBeltItems(belt_id: int) -> void:
	var next_belt: int = belt_next_indices[belt_id] # Belt that this belt feeds into
	
	if next_belt < 0 or next_belt >= MAX_BELTS: # If this belt feeds nowhere
		return
		
	if belt_active_position[next_belt] == EMPTY:
		return
		
	if next_belt == belt_id: # If this belt feeds into itself somehow :/
		return
		
	var transferred := false
	
	for slot in range(MAX_ITEMS_PER_BELT):
		var source_index: int = beltSlot(belt_id, slot)
		
		if belt_item_types[source_index] == EMPTY: # Skip empty items
			continue
			
		if belt_item_positions[source_index] < 1.0: # Skip items that aren't at the end of the belt
			continue
			
		var new_position: float = belt_item_positions[source_index] - 1.0 # If the position on the previous belt was 1.1, new position would be 0.1 (this is to make it smooth)
		
		var destination_slot := findAvailableBeltSlot(
			next_belt,
			new_position
		)

		if destination_slot == EMPTY:
			continue

		var destination_index: int = beltSlot(
			next_belt,
			destination_slot
		)

		belt_item_types[destination_index] = belt_item_types[source_index]
		belt_item_positions[destination_index] = new_position

		belt_item_types[source_index] = EMPTY
		belt_item_positions[source_index] = 0.0

		transferred = true

	if transferred:
		changeBeltItemCount(belt_id, EMPTY) # Update to check if this belt needs to be removed from the occupied list
		changeBeltItemCount(next_belt, 1) # Update to check if the next belt needs to be added to the occupied list

func updateMachines(delta: float) -> void:
	for machine_id in active_machine_ids:
		updateMachine(machine_id, delta)
		
func updateMachine(machine_id: int, delta: float) -> void:
	var recipe_id: int = machine_recipe_ids[machine_id]

	if recipe_id == EMPTY:
		return
		
	# TO DO


# Benchmark Test
func run_benchmark(
	belt_count: int,
	machine_count: int,
	occupied_percentage: float = 100.0,
	items_per_belt: int = 1
) -> void:
	initialize_factory(MAP_SIZE)

	var belts_added := 0
	var machines_added := 0
	var occupied_added := 0
	var items_added := 0

	# Add belts
	for tile_index in range(MAP_SIZE):
		if belts_added >= belt_count:
			break

		var belt_id := addBelt(tile_index, 1, 10)

		if belt_id != EMPTY:
			belts_added += 1

	# Add machines
	for tile_index in range(MAP_SIZE):
		if machines_added >= machine_count:
			break

		if belt_at[tile_index] != EMPTY: # If there is already a belt at that tile index, skip it
			continue

		var machine_id := addMachine(tile_index, 0)

		if machine_id != EMPTY:
			machines_added += 1

	# Calculate how many belts should contain items
	var target_occupied := int(
		belts_added * clampf(occupied_percentage, 0.0, 100.0) / 100.0
	)

	# Populate belts
	for belt_id in active_belt_ids:
		if occupied_added >= target_occupied:
			break

		var added_to_belt := 0

		for i in range(items_per_belt):
			if tryInsertItem(belt_id, i):
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
	print("Occupied list size: ", occupied_belt_ids.size())

func update_factory_performance(delta: float) -> void:
	var start_time := Time.get_ticks_usec()

	updateBelts(delta)

	var belt_time := Time.get_ticks_usec() - start_time

	start_time = Time.get_ticks_usec()

	updateMachines(delta)

	var machine_time := Time.get_ticks_usec() - start_time

	print(
		"Belts: ", belt_time / 1000.0, " ms | ",
		"Machines: ", machine_time / 1000.0, " ms"
	)
