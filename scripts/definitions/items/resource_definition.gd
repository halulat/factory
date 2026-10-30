class_name ResourceDefinition
extends Resource

@export_group("Identity")
@export var id: StringName
@export var display_name: String = ""
@export var max_stack: int = 100

@export_group("Visuals")
@export var icon: Texture2D
