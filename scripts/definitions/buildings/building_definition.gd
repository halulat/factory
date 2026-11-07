class_name BuildingDefinition
extends DataDefinition

@export_group("Identity")
@export var id: StringName
@export var display_name: String
@export_multiline var description: String


@export_group("Visuals")
@export var scene: PackedScene 

@export_group("Placement")
@export var size: Vector2i = Vector2i.ONE
