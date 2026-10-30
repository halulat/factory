@tool
extends Node2D

@onready var ground: TileMapLayer = $Ground
@onready var preview: TileMapLayer = $Preview

enum Direction {LEFT, RIGHT, UP, DOWN}
enum MouseDirection {CLOCKWISE = 1, COUNTERCLOCKWISE = 0}
enum ConveyorStyle {DEFAULT, SIDE_INPUT, }
enum ConveyorDirection {
	LEFT = 0, 
	RIGHT = 1,
	LEFT_INPUT_UP = 2,
	UP_INPUT_RIGHT = 3,
	RIGHT_INPUT_UP = 4,
	UP_INPUT_LEFT = 5,
	DOWN_INPUT_RIGHT = 6,
	DOWN_INPUT_LEFT = 7
}
#tileset source id
var source_id : int
var selected_tile : Vector2i
#tracks snapped mouse position when mouse 1 is pressed
var m_pos_before : Vector2i
#tracks snapped mouse position when mouse 1 is released
var m_pos_after : Vector2i
var object_direction : Direction = Direction.RIGHT
var select_mode : bool = false
var placeable : bool:
	set(value):
		placeable = value
		if value == false:
			preview.modulate = Color.RED
		else:
			preview.modulate = Color("ffffff6f")
#for now, I think conveyor belts should overwrite themselves to easily change direction
var draggable : bool = true
#this variable pauses the auto belt direction when dragging until dragging again.
#use case: using mousewheel to set belt direction before placing belts in desired direction
var pause_direction_update : bool = false
var preview_tile: Vector2i:
	set(value):
		if preview_tile != value:
			pause_direction_update = false
		
		preview.erase_cell(preview_tile)
		preview_tile = value
		preview.set_cell(value, source_id, selected_tile, getDirectedConveyor(object_direction))
		#TODO!!! make conveyors unique here
		var atlas_tile : TileSetAtlasSource
		atlas_tile = preview.tile_set.get_source(source_id)
		var tile_size
		if atlas_tile:
			tile_size = atlas_tile.get_tile_size_in_atlas(selected_tile)
		placeable = true
		
		for j in range(tile_size.y):
			for i in range(tile_size.x):
				var tile = preview_tile + Vector2i(i, j)
				if tile in BuildingManager.used_tiles:
					placeable = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	source_id = 0
	pass # Replace with function body.

## Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta: float) -> void:
	#pass
 
# returns a position relative to the tiles in the tile map
func getSnappedPosition(global_pos: Vector2) -> Vector2i:
	var local_pos = ground.to_local(global_pos)
	var tile_pos = ground.local_to_map(local_pos)
	
	return tile_pos

func _physics_process(_delta):
	if select_mode:
		selected_tile = Vector2i(0, 0)
		preview_tile = getSnappedPosition(get_global_mouse_position())
		
		if draggable and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			drawPlaceObjectPreview(m_pos_before, preview_tile)
		elif draggable and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			drawRemoveObjectPreview(m_pos_before, preview_tile)

# updates BuildingManager tile data and places a tile the ground layer
func placeTile(tile_pos: Vector2i):
	ground.set_cell(tile_pos, source_id, selected_tile, getDirectedConveyor(object_direction))
	preview.erase_cell(tile_pos)
	BuildingManager.getTiles(ground, selected_tile, tile_pos)

# updates BuildingManager tile data and removes a tile the ground layer
func removeTile(tile_pos: Vector2i):
	BuildingManager.eraseTile(ground, tile_pos)
	ground.erase_cell(tile_pos)
	
func _input(event) -> void:
	if Input.is_action_pressed("rotate_placement_clockwise"):
		rotatePlacement(MouseDirection.CLOCKWISE)
	elif Input.is_action_pressed("rotate_placement_counterclockwise"):
		rotatePlacement(MouseDirection.COUNTERCLOCKWISE)
		
	if event is InputEventMouseButton:
		handlePlacement(event)
				
			
	if event is InputEventKey:
		if event.keycode == KEY_ESCAPE and event.pressed:
			select_mode = false
			preview.clear()
			return
		# Selects conveyor belts to place onto the map
		if event.keycode == KEY_1 and event.pressed:
			draggable = true
			select_mode = true
			source_id = 0
			#TODO PLACEHOLDER BELOW FOR OTHER OBJECTS
		if event.keycode == KEY_2 and event.pressed:
			pass

#TODO THIS IS TEMPORARY!!!!!
#returns the alternate conveyor tile corresponding to the tile set tiles
func getDirectedConveyor(direction: Direction) -> ConveyorDirection:
	match direction:
		Direction.LEFT:
			return ConveyorDirection.LEFT
		Direction.RIGHT:
			return ConveyorDirection.RIGHT
		Direction.UP:
			return ConveyorDirection.UP_INPUT_RIGHT
		_:
			return ConveyorDirection.DOWN_INPUT_RIGHT

#draws the preview for dragging objects before placing
func drawPlaceObjectPreview(first_pos, second_pos):
	if first_pos != second_pos and !pause_direction_update:
		object_direction = getDragDirection(first_pos, second_pos)
	selected_tile = Vector2i(0, 0)
	preview.clear()
	preview.modulate = Color("ffffff6f")
	var draw_logic = func draw_logic(cell):
		preview.set_cell(cell, source_id, selected_tile, getDirectedConveyor(object_direction))
	editTilesOrthogonally(first_pos, second_pos, draw_logic)
	
#draws the preview for removing objects
func drawRemoveObjectPreview(first_pos, second_pos):
	preview.clear()
	preview.modulate = Color("ff00006f")
	var draw_remove_box = func draw_remove_box(cell):
			preview.set_cell(cell, 0, Vector2i(0, 0), getDirectedConveyor(object_direction))
	editTilesInRange(first_pos, second_pos, draw_remove_box)
	
#gets the current Direction that is being dragged
func getDragDirection(first_pos: Vector2i, second_pos: Vector2i) -> Direction:
	var dist = abs(first_pos - second_pos)
	if dist.x > dist.y and second_pos.x > first_pos.x:
		return Direction.RIGHT
	elif dist.x > dist.y:
		return Direction.LEFT
	elif second_pos.y < first_pos.y:
		return Direction.UP
	else:
		return Direction.DOWN

func rotatePlacement(isClockwise):
	if isClockwise:
		match object_direction:
			Direction.LEFT:
				object_direction = Direction.UP
			Direction.RIGHT:
				object_direction = Direction.DOWN
			Direction.UP:
				object_direction = Direction.RIGHT
			_:
				object_direction = Direction.LEFT
	else:
		match object_direction:
			Direction.LEFT:
				object_direction = Direction.DOWN
			Direction.RIGHT:
				object_direction = Direction.UP
			Direction.UP:
				object_direction = Direction.LEFT
			_:
				object_direction = Direction.RIGHT
	pause_direction_update = true


func handlePlacement(event):
	if !(event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT):
		return
	if event.pressed:
		m_pos_before = getSnappedPosition(get_global_mouse_position())
	else:
		m_pos_after = getSnappedPosition(get_global_mouse_position())
			
	if event.button_index == MOUSE_BUTTON_LEFT and select_mode and !event.pressed and (placeable or draggable):
		if not draggable or m_pos_before == m_pos_after:
			selected_tile = Vector2i(0, 0)
			placeTile(m_pos_after)
			return
		else:
			placeDraggedObjects(m_pos_before, m_pos_after)
	elif event.button_index == MOUSE_BUTTON_RIGHT and select_mode and !event.pressed:
		if m_pos_before == m_pos_after:
			removeTile(preview_tile)
			return
		else:
			removeDraggedObjects(m_pos_before, m_pos_after)

#calls editTilesOrthogonally with a placement function
func placeDraggedObjects(first_pos, second_pos):
	selected_tile = Vector2i(0, 0)
	var place_function = func place_function(cell):
		placeTile(cell)
	editTilesOrthogonally(first_pos, second_pos, place_function)
	preview.clear()

#calls editTilesOrthogonally with a removal function
func removeDraggedObjects(first_pos, second_pos):
	selected_tile = Vector2i(0, 0)
	var remove_function = func remove_function(cell):
		if ground.get_cell_tile_data(cell):
			removeTile(cell)
	editTilesInRange(first_pos, second_pos, remove_function)
	preview.clear()

#calls function on every tile ORTHOGONALLY from first_pos to the direction
#indicated by placement_direction
func editTilesOrthogonally(first_pos, second_pos, function):
	var placement_direction = getDragDirection(first_pos, second_pos)
	if placement_direction == Direction.LEFT or placement_direction == Direction.RIGHT:
		for i in range(abs(second_pos.x - first_pos.x) + 1):
			var cell_location = Vector2i(min(first_pos.x, second_pos.x) + i, first_pos.y)
			function.call(cell_location)
	else:
		for i in range(abs(second_pos.y - first_pos.y) + 1):
			var cell_location = Vector2i(first_pos.x, min(first_pos.y, second_pos.y) + i)
			function.call(cell_location)
			
#calls function on every tile in the range between first_pos and second_pos
func editTilesInRange(first_pos, second_pos, function):
	for j in range(abs(second_pos.y - first_pos.y) + 1):
		for i in range(abs(second_pos.x - first_pos.x) + 1):
			var cell_location = Vector2i(min(first_pos.x, second_pos.x) + i, min(first_pos.y, second_pos.y) + j)
			function.call(cell_location)
	
