class_name MachineInstance
extends BuildingInstance

var definition: MachineDefinition
var recipe: RecipeDefinition

var inventory: Array[ItemAmount] = []
var progrss: float = 0.0

# needs to register with entity register after initialization
func _init(machine_def : MachineDefinition, pos :Vector2i, dir: Vector2i) -> void:
	super(pos, dir)
	
	definition = machine_def
	
