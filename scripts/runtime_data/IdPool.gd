class_name IdPool
extends RefCounted

# mangaes all the instance ids
const INVALID_ID: int = -1


var capacity: int
var free_ids: PackedInt32Array = PackedInt32Array()
var allocated: PackedByteArray = PackedByteArray()


func _init(max_ids: int) -> void:
	assert(max_ids > 0, "IdPool capacity must be positive")
	capacity = max_ids
	free_ids.resize(capacity)
	allocated.resize(capacity)
	reset()


func reset() -> void:
	allocated.fill(0)
	# IDs are popped from the end, so the first acquired ID is 0.
	free_ids.resize(capacity)
	for i in range(capacity):
		free_ids[i] = capacity - 1 - i


func acquire() -> int:
	if free_ids.is_empty():
		return INVALID_ID

	var last_index: int = free_ids.size() - 1
	var id: int = free_ids[last_index]
	free_ids.resize(last_index)
	allocated[id] = 1
	return id


func release(id: int) -> bool:
	if not is_allocated(id):
		return false

	allocated[id] = 0
	free_ids.append(id)
	return true


func is_allocated(id: int) -> bool:
	return id >= 0 and id < capacity and allocated[id] == 1


func available_count() -> int:
	return free_ids.size()


func active_count() -> int:
	return capacity - free_ids.size()


func is_full() -> bool:
	return free_ids.is_empty()
