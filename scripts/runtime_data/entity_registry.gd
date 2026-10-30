class_name BuildingRegistry
extends RefCounted

# mangaes all the instance ids
const INVALID_ID: int = -1

var _buildings: Array[BuildingInstance] = []
var _free_ids: Array[int] = []

var _active_count: int = 0


func register(building: BuildingInstance) -> int:
	var id: int

	if not _free_ids.is_empty():
		id = _free_ids.pop_back()
		_buildings[id] = building
	else:
		id = _buildings.size()
		_buildings.append(building)

	building.id = id
	_active_count += 1

	return id


func unregister(id: int) -> bool:
	if not contains(id):
		return false

	_buildings[id] = null
	_free_ids.append(id)
	_active_count -= 1

	return true


func get_building(id: int) -> BuildingInstance:
	if not contains(id):
		return null

	return _buildings[id]


func contains(id: int) -> bool:
	return (
		id >= 0
		and id < _buildings.size()
		and _buildings[id] != null
	)


func get_active_count() -> int:
	return _active_count
