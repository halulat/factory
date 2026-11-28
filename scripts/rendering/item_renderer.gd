class_name ItemRenderer
extends Node2D


@export var sprite_sheet: CompressedTexture2D = preload("res://assets/resource_spritesheet.png")
@export var factory_manager: FactoryManager
const TILE_SIZE: int = 64
var rs = RenderingServer
var timer = 1
var _sprite_instances : Dictionary

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass

func create_item_render(item_id: int, pos: Vector2i, texture: AtlasTexture):
	var new_sprite_instance = rs.canvas_item_create()
	var trans = Transform2D(0, pos * TILE_SIZE)
	rs.canvas_item_set_transform(new_sprite_instance, trans)
	rs.canvas_item_set_draw_index(new_sprite_instance, item_id)
	rs.canvas_item_set_default_texture_filter(new_sprite_instance, RenderingServer.CANVAS_ITEM_TEXTURE_FILTER_NEAREST)
	rs.canvas_item_set_parent(new_sprite_instance, get_canvas_item())
	rs.canvas_item_add_texture_rect_region(new_sprite_instance, Rect2(0, 0, TILE_SIZE, TILE_SIZE), texture, texture.region)
	_sprite_instances.get_or_add(item_id, new_sprite_instance)
	
func delete_item_render(item_id: int):
	var instance_id = _sprite_instances.get(item_id)
	if instance_id == null:
		return
	rs.canvas_item_clear(instance_id)
	rs.free_rid(instance_id)
	_sprite_instances.erase(item_id)
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	#rs.canvas_item_clear(sprite_instance)
	for belt_id in factory_manager.belt_store.occupied.ids:
	
		var belt_pos: Vector2i = FactoryManager.tile_index_to_vector(factory_manager.belt_store.grid_indices[belt_id])
		var direction = factory_manager.belt_store.directions[belt_id]
		
		for item_slot in range(factory_manager.belt_store.MAX_ITEMS_PER_BELT):
			var item_idx = factory_manager.belt_store.get_item_index(belt_id, item_slot)
			if (factory_manager.belt_store.item_types[item_idx] == factory_manager.belt_store.EMPTY):
				continue
				
			var sprite_instance = _sprite_instances.get(factory_manager.belt_store.item_ids[item_idx])
			assert(sprite_instance != null)
				
			var item_pos = factory_manager.belt_store.item_positions[item_idx]
			var offset = Vector2.ZERO
			match direction:
				factory_manager.belt_network.Direction.UP:
					offset.y -= item_pos
				factory_manager.belt_network.Direction.DOWN:
					offset.y += item_pos
				factory_manager.belt_network.Direction.RIGHT:
					offset.x += item_pos
				factory_manager.belt_network.Direction.LEFT:
					offset.x -= item_pos 
					
			var trans = Transform2D(0, Vector2(belt_pos.x * 64 + offset.x * 64.0, belt_pos.y * 64 + offset.y * 64.0))
			rs.canvas_item_set_transform(sprite_instance, trans)
