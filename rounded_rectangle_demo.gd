extends PanelContainer

var fullscreen = false
	
	
const RectangleEditor = preload("res://rectangle_editor.gd")

func _input(event):
	if event.is_action_pressed("fullscreen_toggle"):
		fullscreen = not fullscreen
	toggle_fullscreen()
	if event.is_action_pressed("move_right"):
		$BlueRect.position += $BlueRect.transform.x * 10
	
	if event is InputEventMouseButton:
		var diff = event.position - $BlueRect.transform.origin
		var rot = diff.rotated(-$BlueRect.rotation)
		print(diff, " rot:", rot, " tolocal:", $BlueRect.to_local(event.position))
	
func toggle_fullscreen():
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:		
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	
func _ready():	
	pass
	
		
	
