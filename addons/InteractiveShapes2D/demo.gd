## (c) Pascal Schuppli 2025-present. This code is licensed to you under the MIT
## license. See LICENSE.md for details.
##
## Interactive Curve Demonstration
##
## Note: The Blue curve has a shared Curve2D object. It's NOT a good
## idea to do this; here it is used only to demonstrate the InterActiveCurve2D's 
## signals and the current limitations pertaining to their use.
## 
## Whenever one of the interactive curves is updated, the other interactive 
## curve will be notified and redraw itself. This is implemented here using
## the curve_updated and curve_updated_and_stable signals. The difference in 
## these signals is that curve_updated_and_stable is only emitted once all 
## dragging has ceased.
##
## Curve synchronization using these signals fails, however, when the first 
## point of one of the interactive curves gets moved, as the other curve won't 
## be able to copy the change of origin. This is currently a limitation of the 
## interactive curve's signaling ability. In a later version, the plan is for 
## curves to pass information about what exactly has changed, which will also
## enable undo functionality etc, which is currently impossible to do 
## efficiently.
##
## Another failure point is when you change the constraint for one of the
## control tangent handles. Since only the actual Curve2D is shared, such a 
## change won't be picked up by the other curve. While this is mostly a nuisance, 
## there is another failure which crashes the demo: If you add a new point in 
## one of the curves and then try to change the constraint on the very last 
## point of the curve, you'll get an index out of bounds error because the list
## stat stores the control constraints in the other interactive curve was not 
## resized. This gets progressively worse the more points you add to the curve.
## 
## Please do not file bug reports about these limitations. ;-)

extends PanelContainer

var fullscreen = false

func _input(event):
	if event.is_action_pressed("fullscreen_toggle"):
		fullscreen = not fullscreen
	toggle_fullscreen()
	
func toggle_fullscreen():
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:		
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _on_blue_curve_updated(_empty_change_data):
	$InteractiveCurveShared.queue_redraw()

func _on_shared_curve_updated_and_stable(_empty_change_data):
	$InteractiveCurveBlue.queue_redraw()

func _ready():
	$InteractiveCurveBlue.curve_updated.connect(_on_blue_curve_updated)
	$InteractiveCurveShared.curve_updated_and_stable.connect(_on_shared_curve_updated_and_stable)
	
