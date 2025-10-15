extends PanelContainer

var fullscreen = false
	
	
const RectangleEditor = preload("res://rectangle_editor.gd")

func _input(event):
	if event.is_action_pressed("fullscreen_toggle"):
		fullscreen = not fullscreen
	toggle_fullscreen()
	if event.is_action_pressed("move_right"):
		$BlueRect.position += Vector2(10, 0)
	
func toggle_fullscreen():
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:		
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	
func _ready():	
	pass
	
		
	
