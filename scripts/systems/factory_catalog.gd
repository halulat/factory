extends Node
class_name FactoryCatalog

# In the editor make sure to add any resources,recipes,etc that we create
@export var resource_resources: Array[ResourceDefinition] = []
@export var belt_resources: Array[BeltDefinition] = []
@export var machine_resources: Array[MachineDefinition] = []
@export var recipe_resources: Array[RecipeDefinition] = []

# Static definitions
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
	for definition in resource_resources:
		registerResource(definition)

	for definition in belt_resources:
		registerBelt(definition)

	for definition in machine_resources:
		registerMachine(definition)

	for definition in recipe_resources:
		registerRecipe(definition)

func registerResource(definition: ResourceDefinition) -> int:
	if resource_ids.has(definition.id):
		push_error("Duplicate resource ID: " + str(definition.id))
		return -1

	var id := resources.size()
	resources.append(definition)
	resource_ids[definition.id] = id
	return id

func registerBelt(definition: BeltDefinition) -> int:
	if belt_ids.has(definition.id):
		push_error("Duplicate belt ID: " + str(definition.id))
		return -1

	var id := belts.size()
	belts.append(definition)
	belt_ids[definition.id] = id
	return id

func registerMachine(definition: MachineDefinition) -> int:
	if machine_ids.has(definition.id):
		push_error("Duplicate machine ID: " + str(definition.id))
		return -1

	var id := machines.size()
	machines.append(definition)
	machine_ids[definition.id] = id
	return id

func registerRecipe(definition: RecipeDefinition) -> int:
	if recipe_ids.has(definition.id):
		push_error("Duplicate recipe ID: " + str(definition.id))
		return -1

	var id := recipes.size()
	recipes.append(definition)
	recipe_ids[definition.id] = id
	return id

# Turns string id into int so they can be stored in PackedInt32Array
func getResourceID(id: StringName) -> int:
	return resource_ids.get(id, -1)

func getBeltID(id: StringName) -> int:
	return belt_ids.get(id, -1)

func getMachineID(id: StringName) -> int:
	return machine_ids.get(id, -1)

func getRecipeID(id: StringName) -> int:
	return recipe_ids.get(id, -1)
