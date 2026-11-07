class_name BeltNetwork
extends RefCounted
# Topology of the belt graph: which belt occupies which tile, and which belt
# each belt outputs into. It reads position and direction from BeltStore

enum Direction {
	UP,
	RIGHT,
	DOWN,
	LEFT,
}

const DIRECTION_OFFSETS: Array[Vector2i] = [
	Vector2i.UP,
	Vector2i.RIGHT,
	Vector2i.DOWN,
	Vector2i.LEFT,
]

const EMPTY: int = BeltStore.EMPTY

var world: FactoryWorld

# Tile index -> belt ID.
var belt_at: PackedInt32Array
# Belt ID -> downstream belt ID, or EMPTY when nothing can receive items.
var next_indices: PackedInt32Array

var _store: BeltStore


func _init(factory_world: FactoryWorld, store: BeltStore) -> void:
	world = factory_world
	_store = store
	reset()


func reset() -> void:
	belt_at.resize(world.size)
	belt_at.fill(EMPTY)
	next_indices.resize(_store.capacity)
	next_indices.fill(EMPTY)


# Forget the output connection of one belt slot.
func clear_belt(belt_id: int) -> void:
	next_indices[belt_id] = EMPTY


# Claim [param tile_index] for [param belt_id]. The caller owns validation.
func register(belt_id: int, tile_index: int) -> void:
	belt_at[tile_index] = belt_id


# Drop the tile claim and the output connection of one belt.
func unregister(belt_id: int, tile_index: int) -> void:
	if tile_index >= 0 and tile_index < belt_at.size() and belt_at[tile_index] == belt_id:
		belt_at[tile_index] = EMPTY
	clear_belt(belt_id)


# Tile index in front of [param tile_index], or EMPTY at the map border.
func neighbor_tile(tile_index: int, direction: int) -> int:
	if direction < 0 or direction >= Direction.size():
		return EMPTY
	return world.get_neighbor_index(tile_index, DIRECTION_OFFSETS[direction])


# Recompute which belt one belt outputs into.
func link(belt_id: int) -> void:
	var tile_index: int = _store.grid_indices[belt_id]
	if tile_index == EMPTY:
		clear_belt(belt_id)
		return

	var output_tile: int = neighbor_tile(tile_index, _store.directions[belt_id])
	next_indices[belt_id] = EMPTY if output_tile == EMPTY else belt_at[output_tile]


# Recompute the connections around a tile whose occupancy just changed: the
# belt on that tile plus the four belts that could feed into it.
func refresh_near(tile_index: int) -> void:
	var center_id: int = belt_at[tile_index]
	if center_id != EMPTY:
		link(center_id)

	for direction in range(Direction.size()):
		var neighbor: int = neighbor_tile(tile_index, direction)
		if neighbor == EMPTY:
			continue
		var neighbor_id: int = belt_at[neighbor]
		if neighbor_id != EMPTY:
			link(neighbor_id)
