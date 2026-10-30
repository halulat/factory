class_name PlacementManager
extends Node2D
const CELL_SIZE := 32

# holds information about what and where things are placed
# grabs user input and places buildings
@export var machine_scene: PackedScene
@export var belt_scene: PackedScene

signal building_placed(builiding : BuildingDefinition)

# TODO make it so it takes a building_data and places the scene
# in the grid

# TODO add rotation 

# TODO allow swiching the current building

# TODO add support for nxm sized buildings (use type, origin, size)

# TODO Support removing buildings

var occupied_cells: Dictionary[Vector2i, StringName] = {}
var selected_building : StringName = "belt"

# the grid returns 
func world_to_grid(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		floori(world_pos.x / CELL_SIZE),
		floori(world_pos.y / CELL_SIZE))

func grid_to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell) * CELL_SIZE + Vector2.ONE * 16

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			place_building(get_global_mouse_position())

func set_selected_as(building: BuildingDefinition) -> void:
	selected_building = building.id

func place_building(world_pos: Vector2) -> void:
	var cell := world_to_grid(world_pos)
	print(cell)
	
	occupied_cells.set(cell, selected_building)
	
	# TODO place scene(visual) in world
	emit_signal("building_placed", [BuildingDefinition])
	
