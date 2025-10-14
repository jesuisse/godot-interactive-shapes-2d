extends PopupPanel
## A popup toolbar which can contain other nodes (but designed with buttons displaying
## image textures in mind), useful for quick context menus etc.
##
## The PopupToolbar comes preconfigured with 3 star buttons so you can preview it's
## appearance in the Godot Editor. These are cleared automatically.


## Emitted when a toolbar button is pressed. ìd identifies which one.
signal button_pressed(id)

## Stores the individual items. You may read from this, but should not change it directly. Use
## add_item and remove_item instead.
var items : Array[Dictionary] = []

const normal_stylebox = preload("res://addons/PopupToolbar/resources/ButtonNormalStylebox.tres")
const pressed_stylebox = preload("res://addons/PopupToolbar/resources/ButtonPressedStylebox.tres")
const focused_stylebox = preload("res://addons/PopupToolbar/resources/ButtonFocusStylebox.tres")

@onready var item_container = $HBoxContainer

## Adds an item to the toolbar.	The item is defined by it's icon and an id
##	which is opaque to the toolbar, but should be capable of being converted
##	to a string.
##	
##	toggle_mode also accepts a ButtonGroup object apart from true/false, in
##	case you want to create groups of buttons where only one can be toggled at
##	at any given time.
func add_item(icon, id, toggle_mode = false):
	var button = _create_button(icon, toggle_mode)
	items.append({&'icon': icon, &'id': id, &'node': button})
	item_container.add_child(button)	
	button.pressed.connect(func(): _on_button_pressed(id))


## Removes a specific item (identified by its id) from the toolbar
func remove_item(id):	
	for i in items.size():
		var item : Dictionary = items[i]
		if item.id == id:
			items.remove_at(i)
			item_container.remove_child(item.node)
			# TODO: Figure out if we need to manually disconnect the signal
			return


## Removes all items from the toolbar
func clear_items():
	# TODO: Figure out whether we need to disconnect signals
	items = []
	for child : Button in item_container.get_children():
		item_container.remove_child(child)

	
## Sets the toggle state of the item identified by the given id
func set_item_toggle_state(id, state : bool):
	for item in items:
		if item.id == id:
			if item.node is Button:		
				item.node.button_pressed = state
			else:
				push_warning("Item with id " + str(id) + " is not a button!")
			return
	push_warning("Item with id " + str(id) + " not found")
	

# Helper function to create buttons from the icon
func _create_button(icon, toggle_mode):
	var button = Button.new()
	button.custom_minimum_size = Vector2(32, 0)
	button.icon = icon
	button.flat = false
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER	
	if toggle_mode is ButtonGroup:
		button.toggle_mode = true
		button.button_group = toggle_mode
	elif typeof(toggle_mode) == TYPE_BOOL:
		button.toggle_mode = toggle_mode
	else:
		push_warning("You've passed an invalid value for toggle_mode. Must be either bool or ButtonGroup.")
		button.toggle_mode = false
	
	button.add_theme_stylebox_override(&"normal", normal_stylebox)
	button.add_theme_stylebox_override(&"pressed", pressed_stylebox)
	button.add_theme_stylebox_override(&"focus", focused_stylebox)
	return button

		
func _input(event):
	if event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_RIGHT:
		visible = false


func _ready():	
	# remove the placeholder children and make it invisible
	clear_items()
	hide()


func _on_button_pressed(id=null):
	hide()
	button_pressed.emit(id)
