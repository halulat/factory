extends CanvasLayer

signal slot_selected(index: int, building : BuildingDefinition)
const MAX_SLOTS : int = 10

@onready var slot_container : HBoxContainer = $Control/MarginContainer/PanelContainer/HBoxContainer

var _num_slots : int = 0

var selected_slot : int = 0

var buttons : Array[Button] = []

var items: Array[BuildingDefinition] = []

func _ready() -> void:
	_num_slots =  slot_container.get_child_count()
	if _num_slots > MAX_SLOTS:
		push_error("building hotbar has more slots than num keys")
		
	# get all buttons in Horizontal Box container
	for  i in range(_num_slots):
		var button : Button = slot_container.get_child(i)
		buttons.append(button)
		button.pressed.connect(select_slot.bind(i))
		
	update_hotbar()

# check for keyboard input and change slots if hotkeys are pressed
func _unhandled_key_input(event: InputEvent) -> void:
	# san check
	if not event is InputEventKey:
		return
	
	# ignore if key is held down
	if not event.is_pressed() or event.is_echo():
		return
		
	if event.keycode >= KEY_1 and event.keycode <= KEY_9:
		select_slot(event.keycode - KEY_1) # adjust for 0 indexing
	elif event.keycode == KEY_0:
		select_slot(9)
	
func select_slot(index : int) -> void:
	selected_slot = index
	update_hotbar()
	print("slot " + str(index + 1) + " is selected")
	slot_selected.emit(index)

# highlight and update hotbar visuals
func update_hotbar() -> void:
	pass
