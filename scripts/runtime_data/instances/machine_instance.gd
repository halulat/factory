class_name MachineInstance
extends BuildingInstance

# An instance of a machine during the runtime
var definition: MachineDefinition
var recipe: RecipeDefinition

var inventory: Array[ItemAmount] = []
var progrss: float = 0.0

# needs to register with entity register after initialization
func _init(machine_def : MachineDefinition, pos :Vector2i, dir: Vector2i) -> void:
	super(pos, dir)
	
	definition = machine_def
	
# These instance types could be converted to SoA
# id -> ids[]
# pos -> pos[]
# However, SoA would need to update_belt(id) and mangage indexs & ids
