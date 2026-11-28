@tool
class_name TilePlacement
extends Node2D

# TODO for testing, remove later
var belt_id_test = 0

# rendering layer for belts
@onready var ground: TileMapLayer = $Ground
# rendering layer for previewing placement
@onready var preview: TileMapLayer = $Preview

@export var factory_manager: FactoryManager

const Direction = factory_manager.Direction
enum MouseDirection {CLOCKWISE = 1, COUNTERCLOCKWISE = 0}

# TODO not used properly as of now, intended for rendering correct belt connections
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

#currently selected building to place in the world
var selected_building : BuildingDefinition
#placement direction
var object_direction : Direction = Direction.RIGHT

#tileset source id
var source_id : int
#tileset tile selected
var selected_tile : Vector2i

#tracks snapped mouse position when mouse 1 is pressed
var pressed_mouse_pos : Vector2i
#tracks snapped mouse position when mouse 1 is released
var released_mouse_pos : Vector2i
#true if placement is enabled, false otherwise
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
var conveyor_held : bool = false

#used for cases where M1 is still held while a "cancelling" action is pressed
var deny_placement_action : bool = false

#this variable pauses the auto belt direction when dragging until dragging again.
#use case: using mousewheel to set belt direction before placing belts in desired direction
var pause_direction_update : bool = false

#draws the preview tile to the screen when placement is enabled
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
		
		if (!factory_manager.is_pos_in_bounds(preview_tile)):
			placeable = false
			return
		
		for j in range(tile_size.y):
			for i in range(tile_size.x):
				var tile_idx = FactoryManager.flatten_tile_index(preview_tile + Vector2i(i, j))
				if factory_manager.is_tile_occupied(tile_idx):
					placeable = false
					break

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	
	# TODO Temporary: renders the map area
	var rs = RenderingServer
	var map_bound_render = rs.canvas_item_create()
	var trans = Transform2D(0, Vector2.ZERO)
	rs.canvas_item_set_transform(map_bound_render, trans)
	rs.canvas_item_set_draw_index(map_bound_render, -5)
	rs.canvas_item_set_default_texture_filter(map_bound_render, RenderingServer.CANVAS_ITEM_TEXTURE_FILTER_NEAREST)
	rs.canvas_item_set_parent(map_bound_render, get_canvas_item())
	rs.canvas_item_add_rect(map_bound_render, 
							Rect2(0, 0, (FactoryManager.MAP_WIDTH * ItemRenderer.TILE_SIZE) / scale.x, 
							(FactoryManager.MAP_HEIGHT  * ItemRenderer.TILE_SIZE) / scale.y), 
							Color.hex(0x444444ff))
							
	source_id = 0


## returns position relative to the tiles in the tile map
func getSnappedPosition(global_pos: Vector2) -> Vector2i:
	var local_pos = ground.to_local(global_pos)
	var tile_pos = ground.local_to_map(local_pos)
	
	return tile_pos
	
func _physics_process(_delta):
	if !select_mode:
		return
		
	selected_tile = Vector2i(0, 0)
	preview_tile = getSnappedPosition(get_global_mouse_position())

	if draggable and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and !deny_placement_action:
		drawPlaceObjectPreview(pressed_mouse_pos, preview_tile)
	elif draggable and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and !deny_placement_action:
		drawRemoveObjectPreview(pressed_mouse_pos, preview_tile)

## places tile into the world and draws its sprite to the canvas
func placeTile(tile_pos: Vector2i):
	if (!factory_manager.is_pos_in_bounds(tile_pos)):
		print("INVALID TILE POS")
		return
	
	
	if conveyor_held:
		var belt: BeltDefinition = selected_building
		var added = factory_manager.add_belt(FactoryManager.flatten_tile_index(tile_pos), object_direction, int(belt.items_per_second))
		if added == -1:
			print("called replace")
			factory_manager.replace_existing_belt(factory_manager.belt_network.belt_at[FactoryManager.flatten_tile_index(tile_pos)], object_direction, int(belt.items_per_second))
	else:
		# TODO change later, only belts exist right now
		return
	
	ground.set_cell(tile_pos, source_id, selected_tile, getDirectedConveyor(object_direction))
	preview.erase_cell(tile_pos)
	
## removes tile from the world and derenders its sprite
func removeTile(tile_pos: Vector2i):
	if (!factory_manager.is_pos_in_bounds(tile_pos)):
		print("INVALID TILE POS")
		return
	ground.erase_cell(tile_pos)
	
	# (Belt removal)
	var belt_id = factory_manager.belt_network.belt_at[FactoryManager.flatten_tile_index(tile_pos)]
	if belt_id != BeltNetwork.EMPTY:
		factory_manager.remove_belt(belt_id)
		
	# TODO machine removal unimplemented
	
func _input(event) -> void:
	if Input.is_action_pressed("rotate_placement_clockwise", true):
		rotatePlacement(MouseDirection.CLOCKWISE)
		return
	elif Input.is_action_pressed("rotate_placement_counterclockwise", true):
		rotatePlacement(MouseDirection.COUNTERCLOCKWISE)
		return
			
	if event is InputEventMouseButton:
		handlePlacement(event)
		return
	
		# TODO REMOVE LATER TEST PURPOSES
	if Input.is_action_pressed("test_input"):
		if (!factory_manager.active_belts.contains(belt_id_test)):
			return
		if factory_manager.belt_store.item_count(belt_id_test) >= factory_manager.belt_store.MAX_ITEMS_PER_BELT - 1:
			return
		factory_manager.try_insert_belt_item(belt_id_test, randi_range(0, 3))
		
# TODO THIS IS TEMPORARY!!!!!
## returns the alternate conveyor tile corresponding to the tile set tiles
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

## draws the preview for dragging objects before placing
func drawPlaceObjectPreview(first_pos, second_pos):
	if first_pos != second_pos and !pause_direction_update:
		object_direction = getDragDirection(first_pos, second_pos)
	selected_tile = Vector2i(0, 0)
	preview.clear()
	if (!factory_manager.is_pos_in_bounds(first_pos) or !factory_manager.is_pos_in_bounds(second_pos)):
		preview.modulate = Color.RED
	else:
		preview.modulate = Color("ffffff6f")
	var draw_logic = func draw_logic(cell):
		preview.set_cell(cell, source_id, selected_tile, getDirectedConveyor(object_direction))
	editTilesOrthogonally(first_pos, second_pos, draw_logic)
	
## draws the preview for removing objects
func drawRemoveObjectPreview(first_pos, second_pos):
	preview.clear()
	preview.modulate = Color("ff00006f")
	var draw_remove_box = func draw_remove_box(cell):
			preview.set_cell(cell, 0, Vector2i(0, 0), getDirectedConveyor(object_direction))
	editTilesInRange(first_pos, second_pos, draw_remove_box)
	
## gets the current Direction that is being dragged
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

## handles the placement and removal of tiles on the tilemap
func handlePlacement(event: InputEventMouseButton):
	if !(event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT):
		return
	if event.pressed:
		deny_placement_action = false
		pressed_mouse_pos = getSnappedPosition(get_global_mouse_position())
		
		# if opposite action pressed, then clear the preview and prevent the action
		if (event.button_index == MOUSE_BUTTON_LEFT and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)) or \
			(event.button_index == MOUSE_BUTTON_RIGHT and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)):
			deny_placement_action = true
			preview.clear()
	else:
		released_mouse_pos = getSnappedPosition(get_global_mouse_position())
		
	# handle placing tiles
	if event.button_index == MOUSE_BUTTON_LEFT and \
							!deny_placement_action and \
									select_mode and \
								!event.pressed and \
							(placeable or draggable):
										
		if (!factory_manager.is_pos_in_bounds(pressed_mouse_pos) or !factory_manager.is_pos_in_bounds(released_mouse_pos)):
			print("INVALID TILE POS")
			preview.clear()
			return
			
		if not draggable or pressed_mouse_pos == released_mouse_pos:
			selected_tile = Vector2i(0, 0)
			placeTile(released_mouse_pos)
			return
		else:
			placeDraggedObjects(pressed_mouse_pos, released_mouse_pos)
	
	# handle removing tiles
	elif event.button_index == MOUSE_BUTTON_RIGHT and \
								!deny_placement_action and \
										select_mode and \
										!event.pressed:
		if pressed_mouse_pos == released_mouse_pos:
			removeTile(preview_tile)
			return
		else:
			removeDraggedObjects(pressed_mouse_pos, released_mouse_pos)

## calls editTilesOrthogonally with a placement function
func placeDraggedObjects(first_pos, second_pos):
	selected_tile = Vector2i(0, 0)
	var place_function = func place_function(cell):
		placeTile(cell)
	editTilesOrthogonally(first_pos, second_pos, place_function)
	preview.clear()

## calls editTilesOrthogonally with a removal function
func removeDraggedObjects(first_pos, second_pos):
	selected_tile = Vector2i(0, 0)
	var remove_function = func remove_function(cell):
		if ground.get_cell_tile_data(cell):
			removeTile(cell)
	editTilesInRange(first_pos, second_pos, remove_function)
	preview.clear()

## calls function on every tile ORTHOGONALLY from first_pos to the direction indicated by placement_direction
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
			
## calls function on every tile in the range between first_pos and second_pos
func editTilesInRange(first_pos, second_pos, function):
	for j in range(abs(second_pos.y - first_pos.y) + 1):
		for i in range(abs(second_pos.x - first_pos.x) + 1):
			var cell_location = Vector2i(min(first_pos.x, second_pos.x) + i, min(first_pos.y, second_pos.y) + j)
			function.call(cell_location)


# selects the current building to place from hotbar
func _on_hotbar_slot_selected(_index: int, building: BuildingDefinition) -> void:
	if !building:
			select_mode = false
			selected_building = null
			preview.clear()
			return
			
	selected_building = building
	select_mode = true
	conveyor_held = false
	
	if selected_building is BeltDefinition:
		print("BELT SELECTED")
		draggable = true
		conveyor_held = true
		source_id = 0
		return
	else:
		print("BUILDING SELECTED")
		source_id = 0
		return
		
		
	
