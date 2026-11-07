class_name RecipeDefinition
extends DataDefinition

@export_group("Identity")
@export var id: StringName
@export var display_name: String = ""

@export_group("Recipe")
@export var inputs: Array[ItemAmount] = []
@export var outputs: Array[ItemAmount] = []
@export var duration: float = 1.0
