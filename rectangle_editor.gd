extends "res://abstract_editor.gd"
## RectangleEditor is an editor which provides resizing and moving capabilities
## for rectangular Node2D objects. They need to provide the following interface
## in order to work with the editor:
##
## size : Vector2
## get_bounding_box() -> Rect2
## get_minimum_size() -> Vector2
## origin_offset -> Vector2

@export var control_color : Color = Color.DARK_GRAY:
	set(x):
		control_color = x
		queue_redraw()

var control_focused_color := Color.RED

func _init_controls():	
	if controls != null:
		# already initialized
		return		
	controls = [
		{ collider=corner_ctrl_collide, draw=_draw_corner_ctrl, ondrag=_corner_ctrl_drag0},
		{ collider=corner_ctrl_collide, draw=_draw_corner_ctrl, ondrag=_corner_ctrl_drag1},		
		{ collider=corner_ctrl_collide, draw=_draw_corner_ctrl, ondrag=_corner_ctrl_drag2},
		{ collider=corner_ctrl_collide, draw=_draw_corner_ctrl, ondrag=_corner_ctrl_drag3},
		{ collider=rotation_ctrl_collide, draw=_draw_rotation_ctrl},
		{ collider=drag_ctrl_collide, ondrag=_drag_ctrl_drag}
	]

# Recalculates the position of each control
func _calculate_control_positions():	
	_shape_bbox = _shape.get_bounding_box()
	var bbox = _shape_bbox
	bbox = bbox.grow(2)
	var ctrl_tl = bbox.position
	var ctrl_tr = bbox.position + Vector2(bbox.size.x, 0)
	var ctrl_bl = bbox.position + Vector2(0, bbox.size.y)
	var ctrl_br = bbox.position + bbox.size

	#var ctrl_rotation = _shape_bbox.position + _shape_bbox.size/2 + Vector2(50, 0)
	var ctrl_rotation = Vector2(bbox.position.x, 0) + Vector2(bbox.size.x+20, 0)
	
	var ctrl_drag = _shape_bbox.position + _shape_bbox.size/2
		
	controls[0].pos = ctrl_tl
	controls[1].pos = ctrl_tr
	controls[2].pos = ctrl_bl
	controls[3].pos = ctrl_br
	controls[4].pos = ctrl_rotation
	controls[5].pos = ctrl_drag


func corner_ctrl_collide(idx : int, pointer_position : Vector2) -> bool:
	var pos = get_ctrl_pos(idx)
	return Rect2(pos.x-3, pos.y-3, 7, 7).has_point(pointer_position)


func rotation_ctrl_collide(idx: int, pointer_position: Vector2) -> bool:
	var pos = get_ctrl_pos(idx)
	return pointer_position.distance_squared_to(pos) < 25


func drag_ctrl_collide(idx: int, pointer_position: Vector2) -> bool:
	var pos = get_ctrl_pos(idx)
	return Rect2(Vector2(pos.x-_shape_bbox.size.x/2, pos.y-_shape_bbox.size.y/2), _shape_bbox.size).has_point(pointer_position)


func _draw_corner_ctrl(idx):
	var pos = get_ctrl_pos(idx)

	if is_focused_ctrl(idx):
		draw_rect(Rect2(pos.x-3, pos.y-3, 7, 7), control_focused_color, true, -1, true)
	else:
		draw_rect(Rect2(pos.x-3, pos.y-3, 7, 7), control_color, false, 1, true)


func _draw_rotation_ctrl(idx):
	var pos = get_ctrl_pos(idx)	
	#var center = _shape_bbox.position + _shape_bbox.size/2	
	var start := Vector2(0, 0) #+ Vector2(_shape_bbox.size.x/2, 0)
	draw_dashed_line(start, pos+Vector2(-5, 0), control_color, 0.75, 4, true, true)
	if is_focused_ctrl(idx):
		draw_circle(pos, 5, control_focused_color, true, -1, true)
	else:
		draw_circle(pos, 5, control_color, false, 0.75, true)


func _draw_before_controls():
	var tl = get_ctrl_pos(0)
	var tpr = get_ctrl_pos(1)
	var bl = get_ctrl_pos(2)
	var br = get_ctrl_pos(3)	
	var bh = Vector2(4, 0)
	var bv = Vector2(0, 4)
	var h = Vector2(20, 0)
	var v = Vector2(0, 20)

	draw_line(tl+bh, tl+h, control_color, 1, true)
	draw_line(tl+bv, tl+v, control_color, 1, true)

	draw_line(tpr-bh, tpr-h, control_color, 1, true)
	draw_line(tpr+bv, tpr+v, control_color, 1, true)

	draw_line(bl+bh, bl+h, control_color, 1, true)
	draw_line(bl-bv, bl-v, control_color, 1, true)
	
	draw_line(br-bh, br-h, control_color, 1, true)
	draw_line(br-bv, br-v, control_color, 1, true)


# called when the drag ctrl is dragged
func _drag_ctrl_drag(event, _state, last_global_pos):
	var deltapos = event.position - last_global_pos	
	_shape.position += deltapos
	return true


func _resize_shape(posdelta : Vector2, sizedelta: Vector2) -> bool:
	var minsize = _shape.get_minimum_size()
	if sizedelta.x + _shape.size.x > minsize.x and sizedelta.y + _shape.size.y > minsize.y:	
		_shape.position += _shape.transform.basis_xform(posdelta)
		_shape.size += sizedelta
		_shape.queue_redraw() # most likely unnecessary, but let's err on the side of caution
		_calculate_control_positions()
		queue_redraw()
		return true
	else:
		# do not update last drag position because the control can't follow the pointer
		return false


# called when the left top corner ctrl is dragged
func _corner_ctrl_drag0(event, _state, last_global_pos) -> bool:	
	var deltapos : Vector2 = to_local(event.position) - to_local(last_global_pos)
	var diff = Vector2((1 - _shape.origin_offset.x) * deltapos.x, (1-_shape.origin_offset.y) * deltapos.y)
	return _resize_shape(diff, -deltapos)


# called when the right top corner ctrl is dragged
func _corner_ctrl_drag1(event, _state, last_global_pos):	
	var deltapos : Vector2 = to_local(event.position) - to_local(last_global_pos)
	var sizedelta = Vector2(deltapos.x, -deltapos.y)		
	var diff = Vector2(sizedelta.x * _shape.origin_offset.x, sizedelta.y * _shape.origin_offset.y + deltapos.y)
	return _resize_shape(diff, sizedelta)

	
# called when the left bottom ctrl is dragged
func _corner_ctrl_drag2(event, _state, last_global_pos):	
	var deltapos : Vector2 = to_local(event.position) - to_local(last_global_pos)
	var sizedelta = Vector2(-deltapos.x, deltapos.y)
	var diff = Vector2(sizedelta.x * _shape.origin_offset.x + deltapos.x, sizedelta.y * _shape.origin_offset.y)
	return _resize_shape(diff, sizedelta)

# called when the right bottom ctrl is dragged
func _corner_ctrl_drag3(event, _state, last_global_pos):	
	var deltapos : Vector2 = to_local(event.position) - to_local(last_global_pos)
	var diff = Vector2(deltapos.x * _shape.origin_offset.x, deltapos.y * _shape.origin_offset.y)
	return _resize_shape(diff, deltapos)
		
