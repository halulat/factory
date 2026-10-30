extends Node2D

# This is the array that stores the tile positions
var used_tiles = []

# Gets a tile from the tile map layer and puts them into used_tiles if not already included 
func getTiles(layer: TileMapLayer, selected_tile: Vector2i, tile_pos: Vector2i):
	var source_id = layer.get_cell_source_id(tile_pos)
	var atlas_tile: TileSetAtlasSource
	var tile_size
	
	if source_id != -1:
		atlas_tile = layer.tile_set.get_source(source_id)
	else:
		return
	tile_size = atlas_tile.get_tile_size_in_atlas(selected_tile)
		
	for i in range(tile_size.y):
		for j in range(tile_size.x):
			var tile = tile_pos + Vector2i(i, j)
			if tile not in used_tiles:
				used_tiles.append(tile)

# Erases a tile from used_tiles
func eraseTile(layer: TileMapLayer, tile_pos: Vector2i):
	var source_id = layer.get_cell_source_id(tile_pos)
	var atlas_tile: TileSetAtlasSource
	var tile_size
	
	if source_id != -1:
		atlas_tile = layer.tile_set.get_source(source_id)
	else:
		return
	var tile_sprite = layer.get_cell_atlas_coords(tile_pos)
	tile_size = atlas_tile.get_tile_size_in_atlas(tile_sprite)
	
	for i in range(tile_size.y):
		for j in range(tile_size.x):
			var tile = tile_pos + Vector2i(i, j)
			if tile in used_tiles:
				used_tiles.erase(tile)

func _ready() -> void:
	pass # Replace with function body.


## Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta: float) -> void:
	#pass
#
##linkage to logic implementation
#func updateTileData(tile: Vector2i):
	##TODO
	#pass
