## Utility class used to manage the insertion and removal of ids of
## paired id & position arrays. Allows O(1) insertion and removal
class_name DenseIdSet
extends RefCounted

const INVALID: int = -1

# Dense IDs and their reverse positions allow O(1) swap-removal.
var ids: PackedInt32Array = PackedInt32Array()
var positions: PackedInt32Array = PackedInt32Array()


func _init(capacity: int) -> void:
	assert(capacity > 0, "DenseIdSet capacity must be positive")
	positions.resize(capacity)
	positions.fill(INVALID)


func contains(id: int) -> bool:
	return id >= 0 and id < positions.size() and positions[id] != INVALID


func add(id: int) -> bool:
	if id < 0 or id >= positions.size() or contains(id):
		return false

	positions[id] = ids.size()
	ids.append(id)
	return true


func remove(id: int) -> bool:
	if not contains(id):
		return false

	var position: int = positions[id]
	var last_index: int = ids.size() - 1
	var last_id: int = ids[last_index]

	if position != last_index:
		ids[position] = last_id
		positions[last_id] = position

	ids.resize(last_index)
	positions[id] = INVALID
	return true


func clear() -> void:
	ids.clear()
	positions.fill(INVALID)


func size() -> int:
	return ids.size()
