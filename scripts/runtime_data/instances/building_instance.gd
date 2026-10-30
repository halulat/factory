class_name BuildingInstance
extends RefCounted

# An instance of a building during the runtime
var instance_id : int =-1
var direction : Vector2i # could use int
var position : Vector2i 

# needs to register with entity register after initialization
func _init(pos: Vector2i, dir: Vector2i) -> void:
	position = pos
	direction = dir
