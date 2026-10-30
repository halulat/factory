class_name  BeltInstance
extends BuildingInstance

# An instance of a belt during the runtime
const MAX_ITEMS := 4
const MIN_SPACING := 0.2

var definition: BeltDefinition

var item_types: PackedInt32Array =[]
var item_positions: PackedFloat32Array = []

# could use Building instance, but would need to implement common interface
# can_accept try_insert
var next_belt : BeltInstance = null 


# needs to register with entity register after initialization
func _init(belt_def : BeltDefinition, pos :Vector2i, dir: Vector2i) -> void:
	super(pos, dir)
	
	definition = belt_def
	
