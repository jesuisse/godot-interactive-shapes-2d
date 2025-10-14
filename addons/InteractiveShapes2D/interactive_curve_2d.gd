# (c) 2025 by Pascal Schuppli. This code is provided under the MIT license.
@tool
@icon("res://addons/InteractiveShapes2D/resources/Curve2D.svg")

class_name InteractiveCurve2D
extends Node2D

## The InteractiveCurve2D node lets you display and interactively edit Curve2D objects inside
## your running application. It's main purpose is the interactive handling of Bézier curves.
##
## Note: This is *not* a tool for use directly in the Godot Editor. The Godot Editor
## already has an interface for manipulating curves via the Path2D nodes. The script is marked
## as a @tool only so you can get a visual display of the curve in the editor.

## Emitted whenever the curve is changed. The parameter is currently unused (always null)
signal curve_updated(unimplemented_change_information)
## Emitted whenever the curve was changed and all _dragging has ceased (parameter currently null)
signal curve_updated_and_stable(Unimplemented_changeset_information)

const CurvePopup = preload("res://addons/PopupToolbar/PopupToolbar.tscn")

const curve_delete_icon = preload("res://addons/InteractiveShapes2D/resources/CurveDelete.svg")
const bezier_handles_free_icon = preload("res://addons/InteractiveShapes2D/resources/BezierHandlesFree.svg")
const bezier_handles_balanced_icon = preload("res://addons/InteractiveShapes2D/resources/BezierHandlesBalanced.svg")
const bezier_handles_mirror_icon = preload("res://addons/InteractiveShapes2D/resources/BezierHandlesMirror.svg")

# Line cap
enum LineCap { SQUARED, ROUNDED}

# Allowed Edit Operations on the curve
enum EditFlags { ALLOW_ADD_REMOVE = 1, ALLOW_MOVE_ENDPOINTS = 2, CONSTRAIN_TO_BALANCED = 4, CONSTRAIN_TO_MIRRORED = 8 }

# Constraints for how the control point handles move 
enum HandleType { FREE = 0,  BALANCED = 1, MIRRORED = 2 }

## Toolbar Actions
enum CurveEditAction {	
	FREE = HandleType.FREE,
	BALANCED = HandleType.BALANCED,
	MIRRORED = HandleType.MIRRORED,
	DELETE_POINT = 3,
}

## The Curve2D object we want do display and interact with. 
@export var curve: Curve2D:
	set(x):
		curve = x
		control_handle_constraints = []
		for i in curve.point_count:
			control_handle_constraints.append(control_handle_default)
		if curve.point_count >= 1:
			enforce_control_handle_constraints(0, curve.get_point_out(0))
		if curve.point_count >= 2:
			enforce_control_handle_constraints(curve.point_count-1, curve.get_point_in(curve.point_count-1))
		queue_redraw()
			
## Width of the curve
@export_range(0.5, 50, 0.1) var width: float = 3.0:
	set(x):
		width = x
		queue_redraw()

## Curve color		
@export var color: Color = Color.DARK_GRAY:	
	set(x):
		color = x
		queue_redraw()

## Control point color
@export var control_points_color: Color = Color.DIM_GRAY:
	set(x):
		control_points_color = x
		queue_redraw()

## Radius of the control points
@export_range(2, 20, 0.1) var control_point_size: float = 5.0:
	set(x):
		control_point_size = x
		queue_redraw()

## Set this to false to disable interactive editing		
@export var editable: bool = true:
	set(x):
		editable = x
		queue_redraw()

## Set this to false to hide the control points
@export var show_controls: bool = true:
	set(x):
		show_controls = x
		queue_redraw()

## This determines whether the curve always starts at the coordinate origin. If enabled,
## when you move the first point of the curve, the origin is adjusted so that the first 
## point always stays at the local coordinate origin (0, 0). 
## You may turn this off if you want the node's origin to remain fixed. 
@export var origin_at_curve_start: bool = true:
	set(x):
		origin_at_curve_start = x
		if x and curve:
			rebase_curve_to_origin()


## The two "handles" (off-curve control points) of an on-curve control point 
## can be constrained to the same direction (BALANCED - this keeps edges from forming at
## the control point) or to mirror each other (MIRRORED, which ensures a symmetric curvature).
## To move both handles independently, set this to FREE. The default can be changed later
## (even interactively) for each control point.
@export var control_handle_default: HandleType = HandleType.MIRRORED:
	set(x):
		control_handle_default = x
		queue_redraw()	

## This is a combination of Flags defined in the EditFlags enum and determines whether the user
## can add and remove points and how constrained the movement of the off-curve control points
## is.[br]
## ALLOW_ADD_REMOVE allows the creation and removal of on_curve control points.[br]
## ALLOW_MOVE_ENDPOINTS allows the endpoints to be moved.[br]
## CONSTRAIN_TO_BALANCED constrains off-curve control handles to be balanced (on the same line).[br]
## CONSTRAIN_TO_MIRRORED constrains off-curve control handles to mirror each other.[br]
@export_flags("allow adding/removing points", "allow moving endpoints", "constrain to balanced", "constrain to mirrored") var edit_flags : int = EditFlags.ALLOW_ADD_REMOVE + EditFlags.ALLOW_MOVE_ENDPOINTS:
	set(x):
		edit_flags = x
		_set_toolbar_actions()

		
@export var antialiasing: bool = true:
	set(x):
		antialiasing = x
		queue_redraw()

## Controls whether the curve endpoints have rounded caps or not.
@export var caps: LineCap = LineCap.ROUNDED:
	set(x):
		caps = x
		queue_redraw()

# stores the currently focused control point (may be both on or off curve). "Focused"
# means "mouse currently hovers over it" in this class. We might have to rethink this
# term when we think about keyboard interaction or selecting multiple points.
var _focused_ctrl_idx := -1
var _focused_ctrl_position : Vector2

# we use this for indicating where to subdivide a curve segment when adding a point
var _candidate_on_curve : Vector2 = Vector2.ZERO

var _dragging = false
var _drag_last_pos : Vector2

## Stores the control handle restrictions for each point. Save to directly change
## from the outside, but be advised the array will shrink or grow when points are 
## removed or added.
var control_handle_constraints : Array[HandleType] = []

# The context menu popup toolbar
var curve_popup 

# This is left in the code purely for future debugging purposes. 
var _dbg_data = {}
enum DebugDraw { OFF, BBOX=1, SEGMENT_BBOX=2 }
## You can set a combination of DebugDraw constants here
var debug = DebugDraw.OFF  # DebugDraw.BBOX + DebugDraw.SEGMENT_BBOX



func _input(event):
	if editable and not Engine.is_editor_hint():
		_handle_mouse_input(event)	

func _handle_mouse_input(event):
	if not event is InputEventMouseMotion and not event is InputEventMouseButton:
		return
	# leave this in case someone overrides _input and forgets the editable check
	if not editable:
		return	
	var local_pos = to_local(event.position)
	
	if event is InputEventMouseMotion:
		if _dragging:
			_drag(local_pos, _focused_ctrl_idx)
		else:
			_locate_control_points(local_pos)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
			focus_nearby_control_point(local_pos)
			if has_focused_control_point():
				_discard_candidate_on_curve()
				# handle start of control point _dragging operation
				if is_endpoint_movement_allowed() or not is_endpoint_focused() :
					_dragging = true
					_drag_last_pos = local_pos
			else:
				# handle click on the curve to add a point / subdivide the curve segment
				if has_candidate_on_curve() and (edit_flags & EditFlags.ALLOW_ADD_REMOVE):
					subdivide_curve_segment(_candidate_on_curve)
					_discard_candidate_on_curve()
					curve_updated.emit(null)
					curve_updated_and_stable.emit(null)
			
		elif event.button_index == MOUSE_BUTTON_LEFT and event.is_released():
			_drag_finished()
			
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.is_pressed() and has_focused_control_point():
			_show_context_toolbar(event.position)


func _discard_candidate_on_curve():
	if has_candidate_on_curve():
		queue_redraw()
		_candidate_on_curve = Vector2.ZERO


func _locate_control_points(local_position):
	var old_idx = _focused_ctrl_idx
	focus_nearby_control_point(local_position)
	if _focused_ctrl_idx != -1 or old_idx != -1:
		queue_redraw()
	if edit_flags & EditFlags.ALLOW_ADD_REMOVE:
		_identify_new_point_candidate_on_curve(local_position)


func _show_context_toolbar(position):
		var offset := Vector2(-curve_popup.size.x / 2.0, -curve_popup.size.y-6)
		curve_popup.set_item_toggle_state(control_handle_constraints[_focused_ctrl_idx], true)
		curve_popup.popup(Rect2(position + offset, curve_popup.size))


func _drag_finished():
	if origin_at_curve_start and _dragging and is_endpoint_focused() and _focused_ctrl_idx == 0:		
		rebase_curve_to_origin()
		queue_redraw()
	_dragging = false
	curve_updated_and_stable.emit(null)	


func _drag(local_pos : Vector2, idx):
	var relative = local_pos - _drag_last_pos
	_drag_last_pos = local_pos
	var base = curve.get_point_position(idx)
	var ctrl_in = curve.get_point_in(idx)
	var ctrl_out = curve.get_point_out(idx)
	# note: it's important that we check the in and out control points first, 
	# because if we do it the other way around, we might drag the in or out point
	# to the base, which would then become the active control point. This can't 
	# happen with the in and out points, as when we drag the base point, they move
	# with it.
	if is_focused_point(idx, base + ctrl_in):
		var new_in = ctrl_in + relative
		curve.set_point_in(idx, new_in)
		_focused_ctrl_position = base + new_in
		enforce_control_handle_constraints(idx, new_in)
		
	elif is_focused_point(idx, base + ctrl_out):
		var new_out = ctrl_out + relative
		curve.set_point_out(idx, new_out)		
		_focused_ctrl_position = base + new_out
		enforce_control_handle_constraints(idx, new_out)
		
	elif is_focused_point(idx, base):
		curve.set_point_position(idx, base + relative)
		_focused_ctrl_position += relative

	curve_updated.emit(null)
	queue_redraw()


## This enforces the constraints set for the tangent control points at a given
## curve index. dominant_handle is the tangent control point that will guide
## the change in the opposite tangent control point.
func enforce_control_handle_constraints(idx: int, dominant_handle : Vector2):
	var ctrl_in = curve.get_point_in(idx)
	var ctrl_out = curve.get_point_out(idx)
	match control_handle_constraints[idx]:
		HandleType.BALANCED:
			if dominant_handle == ctrl_in:
				curve.set_point_out(idx, -ctrl_in.normalized() * ctrl_out.length())
			else:
				curve.set_point_in(idx, -ctrl_out.normalized() * ctrl_in.length())			
		HandleType.MIRRORED:
			if dominant_handle == ctrl_in:
				curve.set_point_out(idx, -ctrl_in)
			else:
				curve.set_point_in(idx, -ctrl_out)

func _enforce_focused_constraint():
	if _focused_ctrl_idx == -1:
		return
	var base = curve.get_point_position(_focused_ctrl_idx)
	var ctrl_in = curve.get_point_in(_focused_ctrl_idx)
	var ctrl_out = curve.get_point_out(_focused_ctrl_idx)
	
	if is_focused_point(_focused_ctrl_idx, base+ctrl_in):		
		enforce_control_handle_constraints(_focused_ctrl_idx, ctrl_in)
	elif is_focused_point(_focused_ctrl_idx, base+ctrl_out):	
		enforce_control_handle_constraints(_focused_ctrl_idx, ctrl_out)
	

	
# Identifies a possible candidate for creating a new point on the curve
# The point parameter gives the position where we would want the point to be
# if we weren't limited by the curve (e.g. the mouse position)
func _identify_new_point_candidate_on_curve(point: Vector2):
	
	var closest_on_curve = curve.get_closest_point(point)
	
	# check if closest point is too far off the curve
	if closest_on_curve.distance_squared_to(point) > 9*(width/2)**2:
		if _candidate_on_curve != Vector2.ZERO:
			queue_redraw()
		_candidate_on_curve = Vector2.ZERO
		return
	
	# now check if the point on the curve is too close to existing control points
	for i in curve.point_count:
		var pos = curve.get_point_position(i)
		if pos.distance_squared_to(closest_on_curve) < 9*control_point_size**2:			
			# too close!
			if _candidate_on_curve != Vector2.ZERO:
				queue_redraw()
			_candidate_on_curve = Vector2.ZERO
			return
	
	# found a new candidate point on the curve!
	_candidate_on_curve = closest_on_curve
	queue_redraw()


## Given a poinnt in local coordinate space and a distance, this focuses
## a control point which lies closer than that distance, or removes
## focus if no such control point exists.
## Note 1: The order in which control points are checked is relevant 
## here: For each curve index, we look first at the off-curve in tangent
## control, then the off-curve out tangent control and last at the on-curve
## control point. 
## Note 2: There is no guarantee that this finds focuses control point 
## *closest* to the given point.
func focus_nearby_control_point(point : Vector2, distance: float = 0.0):
	if distance == 0.0:
		distance = control_point_size
	distance = distance ** 2
	for i in curve.point_count:
		var base = curve.get_point_position(i)
		# the order is relevant: we check for the base control point last so that we
		# can drag the in and out points away from it if they lie on top of it.
		for pos in [base+curve.get_point_in(i), base+curve.get_point_out(i), base]:
			if pos.distance_squared_to(point) < distance:
				_focused_ctrl_idx = i
				_focused_ctrl_position = pos
				return
	# -1 signifies there is no focused control point						
	_focused_ctrl_idx = -1

## Returns true either an on-curve or an off-curve control point of the curve
## is currently focused.
func has_focused_control_point():
	return _focused_ctrl_idx != -1

## Returns true if either the first or the last control point on the curve is
## currently focused, false if not.
func is_endpoint_focused() -> bool:	
	if _focused_ctrl_idx > 0 and _focused_ctrl_idx < curve.point_count-1:
		return false
	elif _focused_ctrl_idx == -1:
		return false	
	var base = curve.get_point_position(_focused_ctrl_idx)
	return is_focused_point(_focused_ctrl_idx, base)

## Returns true if the point is focused. TODO: Remove the idx parameter, which seems 
## unnecessary given that we're checking against the position of a point. It only helps
## to distinguish two control points at different indices which have the exact same location.
func is_focused_point(idx: int, point: Vector2) -> bool:
	return editable and _focused_ctrl_idx != -1 and _focused_ctrl_idx == idx and _focused_ctrl_position == point

## Returns true if there is a point on the curve that is singled out as a candidate
## for spline segment subdivision (and making the candidate an additional control point)
func has_candidate_on_curve() -> bool:
	return _candidate_on_curve != Vector2.ZERO

## Returns true if moving endpoints is allowed
func is_endpoint_movement_allowed() -> bool:
	return (edit_flags & EditFlags.ALLOW_MOVE_ENDPOINTS)

## Given a point on the curve, this finds the index of the closest on-curve
## control point that comes *before* the given point.
func find_curve_segment_start_of(point_on_curve: Vector2) -> int:
	var subdiv_offset : float = curve.get_closest_offset(point_on_curve)
	var start_idx := -1	
	for i in curve.point_count:
		var point = curve.get_point_position(i)
		var point_offset = curve.get_closest_offset(point)		
		if point_offset < subdiv_offset:
			start_idx = i
		else:
			return start_idx
	return -1

## Returns the bounding box of the spline segment starting at control point idx
func get_segment_bounding_box(start_idx: int, ignore_curve_width=false) -> Rect2:
	# For an explanation of what we calculate here, see
	# Freya Holmér, https://www.youtube.com/watch?v=aVwxzDHniEw
	# The following code is adapted from cuixping,  
	# https://stackoverflow.com/questions/24809978/calculating-the-bounding-box-of-cubic-bezier-curve
	
	var p0 : Vector2 = curve.get_point_position(start_idx)
	var p1 : Vector2 = p0 + curve.get_point_out(start_idx)
	var p3 : Vector2 = curve.get_point_position(start_idx+1)
	var p2 : Vector2 = p3 + curve.get_point_in(start_idx+1)
	
	var tArr = []
	var xArr = [p0.x, p3.x]
	var yArr = [p0.y, p3.y]
	var a : float
	var b : float
	var c : float
	var t: float
	for i in 2:
		if i == 0:
			b = 6*p0.x - 12 * p1.x + 6 * p2.x
			a = -3 * p0.x + 9 * p1.x - 9 * p2.x + 3 * p3.x
			c = 3 * p1.x - 3 * p0.x
		else:
			b = 6 * p0.y - 12 * p1.y + 6 * p2.y
			a = -3 * p0.y + 9 * p1.y - 9 * p2.y + 3 * p3.y
			c = 3 * p1.y - 3 * p0.y
		if abs(a) < 1e-12:
			if abs(b) < 1e-12:
				continue
			t = -c / b
			if 0 < t and t < 1:
				tArr.append(t)
		var b2ac = b**2 - 4*a*c
		if b2ac < 0:
			if abs(b2ac) < 1e-12:
				t = -b / (2*a)
				if 0 < t and t < 1:
					tArr.append(t)
			continue
		var sqrt_b2ac := sqrt(b2ac)
		var t1 = (-b + sqrt_b2ac) / (2 * a)
		if 0 < t1 and t1 < 1:
			tArr.append(t1)
		var t2 = (-b - sqrt_b2ac) / (2 * a)
		if 0 < t2 and t2 < 1:
			tArr.append(t2)
		
	var j := tArr.size()
	var mt : float
	while j>0:
		j=j-1
		t = tArr[j]
		mt = 1 - t
		xArr.append(mt ** 3 * p0.x + 3 * mt**2 * t * p1.x + 3 * mt * t**2 * p2.x + t**3 * p3.x)
		yArr.append(mt ** 3 * p0.y + 3 * mt**2 * t * p1.y + 3 * mt * t**2 * p2.y + t**3 * p3.y)
			
	var minx = xArr.min()
	var miny = yArr.min()
	var expand := 0.0
	if not ignore_curve_width:
		expand = width / 2
		if antialiasing:
			expand += 1	
	return Rect2(minx-expand, miny-expand, xArr.max()-minx+expand*2, yArr.max()-miny+expand*2)
		

## Calculates and returns the bounding box of the entire curve. 
## The calculation takes the width of the curve into account so that the bounding box will 
## contain all the pixels of the curve. If you want the (slightly smaller) bounding box of the 
## mathematical curve shape instead, set ignore_curve_width to true. 
## The bounding box does NOT contain the curve's UI controls.
func get_bounding_box(ignore_curve_width := false) -> Rect2:
	var bbox := get_segment_bounding_box(0, true)	
	for i in curve.point_count-2:
		var seg_bbox := get_segment_bounding_box(i+1, true)			
		var max_x := max(seg_bbox.position.x + seg_bbox.size.x, bbox.position.x + bbox.size.x)
		var max_y := max(seg_bbox.position.y + seg_bbox.size.y, bbox.position.y + bbox.size.y)
		bbox.position.x = min(seg_bbox.position.x, bbox.position.x)
		bbox.position.y = min(seg_bbox.position.y, bbox.position.y)
		bbox.size.x = max_x - bbox.position.x
		bbox.size.y = max_y - bbox.position.y	
	if not ignore_curve_width:
		var expand = width / 2
		if antialiasing:
			expand += 1
		bbox = bbox.grow(expand)
	return bbox
		

# Subdivides the curve at the given point (which must lie on the curve for the math to work out!)
func subdivide_curve_segment(subdivision_point: Vector2):
		
	var start_idx = find_curve_segment_start_of(subdivision_point)	
	var end_idx = start_idx + 1
	if start_idx == -1:
		# This should actually not happen because find_curve_segment will work even
		# when we use a point that does *not* lie on the curve, but better be safe...
		push_warning("Provided point does not lie on the curve")
		return	
	var p0 = curve.get_point_position(start_idx)
	var p1 = p0 + curve.get_point_out(start_idx)	
	var p3 = curve.get_point_position(end_idx)
	var p2 = p3 + curve.get_point_in(end_idx)
	var start_offset : float = curve.get_closest_offset(p0)
	var end_offset : float = curve.get_closest_offset(p3)
	# This won't be exact, but it's usually close enough. We would need to solve
	# iteratively for better values of t.
	var subdiv_offset : float = curve.get_closest_offset(subdivision_point)
	var t := (subdiv_offset - start_offset) / (end_offset - start_offset)
		
	var m0 = p0 + (p1-p0)*t
	var m1 = p1 + (p2-p1)*t
	var m2 = p2 + (p3-p2)*t	
	var q0 = m0 + (m1-m0)*t
	var q1 = m1 + (m2-m1)*t
			
	var start_out = m0 - p0
	var subdiv_in = q0 - subdivision_point
	var subdiv_out = q1 - subdivision_point
	var end_in = m2 - p3
	
	"""
	# left in the code on purpose. Debug data for curve splitting
	_dbg_data.subdiv = {
		't': t, 
		'p0': p0, 'p1': p1, 'p2': p2, 'p3': p3,
		'm0': m0, 'm1': m1, 'm2': m2, 'q0': q0, 'q1': q1
	}
	"""
	
	curve.set_point_out(start_idx, start_out)
	curve.set_point_in(end_idx, end_in)
	# relax constraints of start and end points of the segment if necessary
	if control_handle_constraints[start_idx] == HandleType.MIRRORED:
		control_handle_constraints[start_idx] = HandleType.BALANCED
	if control_handle_constraints[end_idx] == HandleType.MIRRORED:
		control_handle_constraints[end_idx] = HandleType.BALANCED
	
	curve.add_point(subdivision_point, subdiv_in, subdiv_out, end_idx)
	control_handle_constraints.insert(end_idx, HandleType.BALANCED)
	
	queue_redraw()	

## Moves the coordinate origin so that the first control point of the curve
## ist at (0,0). 
## If origin_at_curve_start is true, there is no need to call this manually,
## as rebasing is handled automatically when necessary.
## Note: To keep the curve's on-screen position stable, this changes the 
## node's transform, e.g. the node's position is adjusted.
func rebase_curve_to_origin():
	var delta : Vector2 = curve.get_point_position(0)
			
	position += Vector2(delta.x*scale.x, delta.y*scale.y)
	for i in curve.point_count:
		curve.set_point_position(i, curve.get_point_position(i)-delta)
	# make sure we're really at the origin (possible floating point errors...)
	curve.set_point_position(0, Vector2.ZERO)
	if _focused_ctrl_idx != -1:
		_focused_ctrl_position = curve.get_point_position(_focused_ctrl_idx)
		

func _set_toolbar_actions():
	if not curve_popup:
		return
	curve_popup.clear_items()
	if edit_flags & EditFlags.ALLOW_ADD_REMOVE:
		curve_popup.add_item(curve_delete_icon, CurveEditAction.DELETE_POINT)
	var buttongroup = ButtonGroup.new()			
	if edit_flags & (EditFlags.CONSTRAIN_TO_BALANCED + EditFlags.CONSTRAIN_TO_MIRRORED) == 0:
		curve_popup.add_item(bezier_handles_free_icon, CurveEditAction.FREE, buttongroup)
		curve_popup.add_item(bezier_handles_balanced_icon, CurveEditAction.BALANCED, buttongroup)
		curve_popup.add_item(bezier_handles_mirror_icon, CurveEditAction.MIRRORED, buttongroup)	
	elif (edit_flags & EditFlags.CONSTRAIN_TO_MIRRORED == 0) or (edit_flags & EditFlags.ALLOW_ADD_REMOVE):
		curve_popup.add_item(bezier_handles_balanced_icon, CurveEditAction.BALANCED, buttongroup)
		curve_popup.add_item(bezier_handles_mirror_icon, CurveEditAction.MIRRORED, buttongroup)	
	
func _dbg_draw_segment():
	for i in curve.point_count-1:
		var bounding_box = get_segment_bounding_box(i)
		draw_rect(bounding_box, Color(0.129, 0.129, 0.133, 0.671), true, -1, false)

func _dbg_draw_subdiv():
	if _dbg_data.has("subdiv"):
		var subdiv = _dbg_data.subdiv
		draw_line(subdiv.p0, subdiv.p1, Color.SEA_GREEN, 1, true)
		draw_line(subdiv.p1, subdiv.p2, Color.SEA_GREEN, 1, true)
		draw_line(subdiv.p2, subdiv.p3, Color.SEA_GREEN, 1, true)
		draw_line(subdiv.m0, subdiv.m1, Color.TURQUOISE, 1, true)
		draw_line(subdiv.m1, subdiv.m2, Color.TURQUOISE, 1, true)
		draw_line(subdiv.q0, subdiv.q1, Color.DARK_TURQUOISE, 1, true)
		var p = subdiv.q0 + (subdiv.q1-subdiv.q0)*subdiv.t
		draw_circle(p, 5, Color.MEDIUM_TURQUOISE, false, -1, true)
	
		
func _draw_control_lines():
	for i in curve.point_count:
		var pos = curve.get_point_position(i)
		var ctrl_in = curve.get_point_in(i)
		var ctrl_out = curve.get_point_out(i)		
		if i > 0:
			draw_line(pos, pos + ctrl_in, Color.DIM_GRAY, 1.0,antialiasing)
		if i < curve.point_count-1:
			draw_line(pos, pos + ctrl_out, Color.DIM_GRAY, 1.0, antialiasing)

			
func _draw_control_points():
	var control_color : Color 
	var radius = max(2, control_point_size)
	
	if _candidate_on_curve != Vector2.ZERO:
		draw_circle(_candidate_on_curve, radius, control_points_color, true, -1.0, antialiasing)
	
	for i in curve.point_count:
		var pos = curve.get_point_position(i)
		var ctrl_in = pos + curve.get_point_in(i)
		var ctrl_out = pos + curve.get_point_out(i)
		var j := -1
		for p in [pos, ctrl_in, ctrl_out]:
			j += 1
			if i == 0 and j == 1:
				continue
			if i == curve.point_count-1 and j == 2:
				continue			
			if is_focused_point(i, p):
				control_color = Color.RED
			else:
				control_color = control_points_color
			if j == 0:
				draw_circle(p, radius, control_color, true, -1.0, antialiasing)	
			else:
				draw_circle(p, radius, control_color, false, 1.0, antialiasing)
			


func _draw_line_caps():
	if curve.point_count < 2:
		return	
	var radius := width / 2 #- 0.5
	# TODO: This is ugly when antialiasing is true because we draw a full
	# circle instead of just the necessary cap, which creates visual 
	# artefacts due to the circle border interacting visibly with the 
	# line border. Fix this by actually drawing the correct half circles.
	var start = curve.get_point_position(0)
	var end = curve.get_point_position(curve.point_count-1)
	draw_circle(start, radius, color, true, -1.0, antialiasing)  
	draw_circle(end, radius, color, true, -1.0, antialiasing)


func _draw():	
	if curve == null:
		return
	
	if debug & DebugDraw.BBOX:
		var bounding_box = get_bounding_box()
		draw_rect(bounding_box, Color(0.149, 0.149, 0.153, 0.58), true, -1, false)
	if debug & DebugDraw.SEGMENT_BBOX:
		_dbg_draw_segment()
		
	if show_controls and not Engine.is_editor_hint():
		_draw_control_lines()
	
	var points = curve.get_baked_points()
	draw_polyline(points, color, width, antialiasing)
	
	# Draw circles at the start and end of the line 
	if caps == LineCap.ROUNDED:
		_draw_line_caps()
		
	if show_controls and not Engine.is_editor_hint():
		_draw_control_points()

		
func _on_toolbar_button_pressed(id):
	match id:
		CurveEditAction.FREE:
			control_handle_constraints[_focused_ctrl_idx] = HandleType.FREE
		CurveEditAction.BALANCED:
			control_handle_constraints[_focused_ctrl_idx] = HandleType.BALANCED
			_enforce_focused_constraint()
			queue_redraw()
			curve_updated.emit(null)
			curve_updated_and_stable.emit(null)			
		CurveEditAction.MIRRORED:
			control_handle_constraints[_focused_ctrl_idx] = HandleType.MIRRORED
			_enforce_focused_constraint()
			queue_redraw()
			curve_updated.emit(null)
			curve_updated_and_stable.emit(null)
		CurveEditAction.DELETE_POINT:
			if is_endpoint_focused() and not (edit_flags & EditFlags.ALLOW_MOVE_ENDPOINTS):
				# cannot delete endpoints if we can't move them				
				pass
			elif curve.point_count > 2 and (edit_flags & EditFlags.ALLOW_ADD_REMOVE):
				curve.remove_point(_focused_ctrl_idx)
				control_handle_constraints.remove_at(_focused_ctrl_idx)
				if _focused_ctrl_idx == 0 and origin_at_curve_start:
					rebase_curve_to_origin()
					
				queue_redraw()
				curve_updated.emit(null)
				curve_updated_and_stable.emit(null)


func _ready():
	if curve == null:
		curve = Curve2D.new()
		
	# Create a default curve if there are no points so there's something to 
	# start with		
	if curve.point_count == 0:	
		curve.add_point(Vector2(0, 0), Vector2(-50, 140), Vector2(50, -140))
		curve.add_point(Vector2(200, 0), Vector2(-50, -140), Vector2(50, 140))
		control_handle_constraints = [ control_handle_default, control_handle_default]
		queue_redraw()		
	else:
		if control_handle_constraints.size() == 0:
			for i in curve.point_count:
				control_handle_constraints.append(control_handle_default)
	
	if not Engine.is_editor_hint():
		# Create popup toolbar if we're in game. There's no sense in doing this
		# in the Godot Editor as we're restricting ourselves to displaying the
		# curve in the editor, so no popup toolbar is needed.
		curve_popup = CurvePopup.instantiate()
		add_child(curve_popup)		
		curve_popup.button_pressed.connect(_on_toolbar_button_pressed)
		_set_toolbar_actions()
		
