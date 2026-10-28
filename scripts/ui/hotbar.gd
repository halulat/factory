extends CanvasLayer

signal slot_selected(index: int, building : BuildingDefinition)
const MAX_SLOTS : int = 10

@onready var slot_container : HBoxContainer = $Control/MarginContainer/PanelContainer/HBoxContainer

@export var _num_slots : int = 0

@export var selected_style : StyleBoxFlat
#@export var normal_style : StyleBoxFlat#
# index i maps to slot i+1
# 0-9             1-10
var selected_slot : int = -1

var buttons : Array[Button] = []

var items: Array[BuildingDefinition] = []


func _ready() -> void:
	_num_slots =  slot_container.get_child_count()
	if _num_slots > MAX_SLOTS:
		push_error("building hotbar has more slots than num keys")
	
	items.resize(_num_slots)
	
	_configure_buttons()
		
	
	# for testing
	#var test : BeltDefinition = load("res://assets/placeholders/hotbar_test.tres")
	#var test_2 = test as BuildingDefinition
	#set_index_to_building(1, test_2)
	
	update_hotbar()
	
func _configure_buttons():
	# get all buttons in Horizontal Box container
	for  i in range(_num_slots):
		# get button
		var button : Button = slot_container.get_child(i)
		if button == null:
			push_error("Hotbar slot is not a Button")
			break
			
		# connect signal
		buttons.append(button)
		button.pressed.connect(select_index.bind(i))
		
		# add number lable
		var label = buttons[i].get_node("Label")
		label.text = str(i + 1)
		
		# configure style
		
		# configure icons
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		
	
# check for keyboard input and change slots if hotkeys are pressed
func _unhandled_key_input(event: InputEvent) -> void:
	# san check
	if not event is InputEventKey:
		return
	
	# ignore if key is held down
	if not event.is_pressed() or event.is_echo():
		return
	
	
	if event.keycode >= KEY_1 and event.keycode <= KEY_9:
		select_index(event.keycode - KEY_1) # adjust for 0 indexing
	elif event.keycode == KEY_0:
		select_index(9)
		

# slects the slot of given index in array
func select_index(index : int) -> void:
	if index < 0 or index >= items.size():
		return
	 
	if selected_slot == index:
		selected_slot = -1
	else:
		selected_slot = index
		
	update_hotbar()
	
	if selected_slot == -1:
		print("hotbar deselected")
		slot_selected.emit(-1, null)
	else:
		print("slot " + str(index + 1) + " is selected")
		slot_selected.emit(index, items[index])

# highlight and update hotbar visuals
func update_hotbar() -> void:
	for i in range(buttons.size()):
		var button: Button = buttons[i]
		var building: BuildingDefinition = items[i]

		# Update the icon
		if building != null:
			button.icon = building.icon
		else:
			button.icon = null
			
		# Make the icon fit inside the button
		button.expand_icon = true
		
			# Highlight the selected slot
		if i == selected_slot:
			button.modulate = Color(1.0, 0.9, 0.5)
		else:
			button.modulate = Color.WHITE
			
		if i == selected_slot:
			button.add_theme_stylebox_override("normal", selected_style)
			button.add_theme_stylebox_override("hover", selected_style)
			button.add_theme_stylebox_override("pressed", selected_style)
		else:
			button.remove_theme_stylebox_override("normal")
			button.remove_theme_stylebox_override("hover")
			button.remove_theme_stylebox_override("pressed")

func set_index_to_building(index : int, building : BuildingDefinition) -> void:
	if (index < 0 or index > items.size()):
		push_error("index " + str(index) + " out of bounds when setting hotbar slot")
		return
	
	items[index] = building
	var button = buttons[index]
	update_hotbar()
	
	
		
