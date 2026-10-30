extends Node
class_name FactoryCatalog

# Added in Editor 
# In the editor make sure to add any resources,recipes,etc that we create
@export var resource_resources: Array[ResourceDefinition] = []
@export var belt_resources: Array[BeltDefinition] = []
@export var machine_resources: Array[MachineDefinition] = []
@export var recipe_resources: Array[RecipeDefinition] = []

# Static definitions copied from resourses
var resources: Array[ResourceDefinition] = []
var belts: Array[BeltDefinition] = []
var machines: Array[MachineDefinition] = []
var recipes: Array[RecipeDefinition] = []

# String ID -> integer ID
var resource_ids: Dictionary = {}
var belt_ids: Dictionary = {}
var machine_ids: Dictionary = {}
var recipe_ids: Dictionary = {}

func initialize() -> void:
	# clear data on reinitialization
	clear_fields()
	
	for definition in resource_resources:
		registerResource(definition)

	for definition in belt_resources:
		registerBelt(definition)

	for definition in machine_resources:
		registerMachine(definition)

	for definition in recipe_resources:
		registerRecipe(definition)


func _regeister(
	definition: DataDefinition,
	definitions: Array,
	ids: Dictionary,
	type_name : String
)-> int:
	# check if def is null
	if definition == null:
		push_error("Null " + type_name + " definition")
		return -1
	
	var string_id: StringName = definition.get("id")
	
	# check if StringName id is empty
	if string_id == &"":
		push_error("Empty " + type_name + " ID")
		return -1
		
	# check if has duplicate
	if ids.has(string_id):
		push_error("Duplicate " + type_name + " ID: " + str(string_id))
		return -1
		
	# register item
	var integer_id := definitions.size()
	definitions.append(definition)
	ids[string_id] = integer_id
	
	return integer_id

func registerResource(definition: ResourceDefinition) -> int:
	return _regeister(definition, resources, resource_ids, "resourse")

func registerBelt(definition: BeltDefinition) -> int:
	return _regeister(definition, belts, belt_ids, "belt")

func registerMachine(definition: MachineDefinition) -> int:
	return _regeister(definition, machines, machine_ids, "machine")

func registerRecipe(definition: RecipeDefinition) -> int:
	return _regeister(definition, recipes, recipe_ids, "recipes")

# Turns string id into int so they can be stored in PackedInt32Array
func getResourceID(id: StringName) -> int:
	return resource_ids.get(id, -1)

func getBeltID(id: StringName) -> int:
	return belt_ids.get(id, -1)

func getMachineID(id: StringName) -> int:
	return machine_ids.get(id, -1)

func getRecipeID(id: StringName) -> int:
	return recipe_ids.get(id, -1)

func clear_fields() -> void:
	resources.clear()
	belts.clear()
	machines.clear()
	recipes.clear()
	resource_ids.clear()
	belt_ids.clear()
	machine_ids.clear()
	recipe_ids.clear()
# TODO add int to stringName id look up
