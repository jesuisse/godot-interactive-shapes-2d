extends Node2D
## (c) 2025 by Pascal Schuppli
##
## AbstractEditor is an abstract base class for Node2D interactive editors. The
## editors are attached as a child of the Node2D and provide editing capability
## through visual editor controls. 
##
## The AbstractEditor provides the base class for control drag and drop, drawing
## etc.


## A list of control data dictionaries, which have the following keys:
##  pos : Vector2 (the position of the control)
##  draw : a callback function func(ctrl_idx : int)
##  collider: a callback function func(ctrl_idx, position: Vector2) -> bool
##  ondrag: a callback function func(ctrl_idx, state : DragSTate, global_pos : Vector2) -> bool
var controls = null

## the index of the currently focused control. -1 = no control is focused
var _focused_ctrl_idx := -1

## the shape this editor controls
var _shape
## the shape's bounding box, as returned by _shape.get_bounding_box()
var _shape_bbox : Rect2

# used for dragging
var _dragging_control := -1
var _dragging_last_pos : Vector2
enum DragState { START=0, DRAGGING=1, DROP=2}

## Override this function and create your controls in it.
func _init_controls():
	pass	

## Override this function and recalculate your control positions in it.
func _calculate_control_positions():
	pass
	
## Sets the focused control
func set_focused_ctrl(idx: int):
	_focused_ctrl_idx = idx
	queue_redraw()

## Checks if a given control (identified by its index) is currently focused
func is_focused_ctrl(idx: int) -> bool:
	return idx == _focused_ctrl_idx

## Returns a control's position
func get_ctrl_pos(idx) -> Vector2:
	return controls[idx].pos
	
## Returns true if we are currently dragging something
func _is_dragging():
	return _dragging_control != -1

func _draw_before_controls():
	pass

func _draw():
	if not _shape_bbox:
		return

	_draw_before_controls()

	var i := -1
	for control in controls:
		i += 1
		if control.has("draw"):
			control.draw.call(i)


func _input(event):
	_handle_editor_input(event)


func _handle_editor_input(event):
	if not is_visible_in_tree():
		return
		
	if event is InputEventMouseMotion:		
		var localpos = to_local(event.position)
		if _is_dragging():
			var ctrl = controls[_focused_ctrl_idx]			
			if ctrl.ondrag.call(event, DragState.DRAGGING, _dragging_last_pos):
				_dragging_last_pos = event.position
			#_dragging_last_pos = to_local(event.position)
					
		else:
			var i = -1
			var found = -1
			for ctrl in controls:
				i += 1
				if ctrl.collider.call(i, localpos):
					found = i
					break
			set_focused_ctrl(found)

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
			if _focused_ctrl_idx != -1:
				var ctrl = controls[_focused_ctrl_idx]
				if ctrl.has("ondrag"):
					_dragging_control = _focused_ctrl_idx
					#_dragging_last_pos = to_local(event.position)
					_dragging_last_pos = event.position
					ctrl.ondrag.call(event, DragState.START, _dragging_last_pos)
		if event.button_index == MOUSE_BUTTON_LEFT and event.is_released():
			if _is_dragging():
				var ctrl = controls[_focused_ctrl_idx]
				ctrl.ondrag.call(event, DragState.DROP, _dragging_last_pos)
				_dragging_control = -1


func _enter_tree():
	_shape = get_parent()
	_init_controls()
	_calculate_control_positions()
		

	
	
	
