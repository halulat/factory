extends Camera2D

@export var zoom_speed: float = 10
@export var pan_speed: float = 1000

var zoom_target: Vector2
var drag_start_mouse_pos: Vector2
var drag_start_camera_pos: Vector2
var dragging: bool = false
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	zoom_target = zoom
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float):
	zoomCamera(delta)
	key_pan(delta)
	drag_pan()

func zoomCamera(delta: float):
	if Input.is_key_pressed(KEY_CTRL):
		return
	if Input.is_action_just_pressed("camera_zoom_in"):
		zoom_target *= 1.1
	
	if Input.is_action_just_pressed("camera_zoom_out"):
		zoom_target *= 0.9
	
	zoom = zoom.slerp(zoom_target, zoom_speed * delta)

# pans using WASD keys
func key_pan(delta: float):
	var move_amount = Vector2.ZERO
	if Input.is_action_pressed("camera_move_left"):
		move_amount.x -= 1
	
	if Input.is_action_pressed("camera_move_right"):
		move_amount.x += 1
	
	if Input.is_action_pressed("camera_move_up"):
		move_amount.y -= 1
	
	if Input.is_action_pressed("camera_move_down"):
		move_amount.y += 1
		
	move_amount	= move_amount.normalized()
	position += move_amount * delta * pan_speed * (1/zoom.x)

# pans using the mouse buttons
func drag_pan():
	if !dragging and !Input.is_key_pressed(KEY_CTRL) and Input.is_action_just_pressed("camera_pan"):
		drag_start_mouse_pos = get_viewport().get_mouse_position()
		drag_start_camera_pos = position
		dragging = true
		
	if dragging and !Input.is_key_pressed(KEY_CTRL) and Input.is_action_just_released("camera_pan"):
		dragging = false
		
	if dragging:
		var move_vector = get_viewport().get_mouse_position() - drag_start_mouse_pos
		position = drag_start_camera_pos - move_vector * (1/zoom.x)
		
