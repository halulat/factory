class_name  BeltInstance
extends BuildingInstance

const MAX_ITEMS := 4
const MIN_SPACING := 0.2

var definition: BeltDefinition

var item_types: PackedInt32Array =[]
var item_positions: PackedFloat32Array = []

var next_belt : BeltInstance = null
# needs to register with entity register after initialization
func _init(belt_def : BeltDefinition, pos :Vector2i, dir: Vector2i) -> void:
	super(pos, dir)
	
	definition = belt_def
	
