@tool
extends Node2D


@export var size : Vector2 = Vector2(200.0, 100.0):
	set(x):
		size = x
		_calculate_shape()
		queue_redraw()

@export_range(0, 50, 0.1) var border_radius : float = 5.0:
	set(x):
		border_radius = x
		_calculate_shape()
		queue_redraw()

@export_range(0.1, 50, 0.1)  var width : float = 3:
	set(x):
		width = x
		queue_redraw()

@export var stroke_color : Color = Color.BLACK:
	set(x):
		stroke_color = x
		queue_redraw()

@export var fill_color : Color = Color.DARK_GRAY:
	set(x):
		fill_color = x
		queue_redraw()

## This defines where the local coordinate origin lies in relation to the 
## shape. (0.5, 0.5) means the origin is at it's center, while (0, 0) means
## the origin sits at the top left corner and (1, 1) is at the bottom right.
@export var origin_offset : Vector2 = Vector2(0.5, 0.5):
	set(x):
		origin_offset = x
		_calculate_shape()
		queue_redraw()

var _points: PackedVector2Array


## Returns the bounding box of this shape
func get_bounding_box():
	var w = width / 2.0
	return Rect2(Vector2(-origin_offset.x*size.x-w, -origin_offset.y*size.y-w), Vector2(size.x+2*w, size.y+2*w))
		
func get_minimum_size() -> Vector2:	
	var m = (border_radius + width*0.5) * 2
	return Vector2(m, m)
		
func _arc_coordinates(radius, start, end, count, center):
	"""
	Calculates count points on the arc from start to end
	with the start and end point excluded
	"""
	var points = PackedVector2Array()
	var arcstep = (end - start) / (count+1)
	for i in range(1, count+1):
		points.append(Vector2(center.x + radius * cos(start+i*arcstep), center.y + radius * sin(start+i*arcstep)))
	return points

	
func _calculate_shape():
	_points = PackedVector2Array([Vector2.ZERO, Vector2(0, size.y), Vector2(size.x, size.y), Vector2(size.x, 0), Vector2.ZERO])
	
	_points = PackedVector2Array()

	var b = Vector2(-origin_offset.x*size.x, -origin_offset.y*size.y)
	var radius = min(border_radius, min(size.x, size.y)/4)	
	var scale_factor = max(scale.x, scale.y)
	var npoints = int(radius / PI * scale_factor)
		
	_points.append(Vector2(b.x, b.y+radius))
	_points.append_array(_arc_coordinates(radius, PI, PI+PI/2, npoints, Vector2(b.x+radius, b.y+radius)))
	_points.append(Vector2(b.x+radius, b.y))
	_points.append(Vector2(b.x+size.x-radius, b.y))
	_points.append_array(_arc_coordinates(radius, PI+PI/2, 2*PI, npoints, Vector2(b.x+size.x-radius, b.y+radius)))
	_points.append(Vector2(b.x+size.x, b.y+radius))
	_points.append(Vector2(b.x+size.x, b.y + size.y - radius))
	_points.append_array(_arc_coordinates(radius, 0, PI/2, npoints, Vector2(b.x+size.x-radius, b.y+size.y-radius)))
	_points.append(Vector2(b.x+size.x-radius, b.y+size.y))
	_points.append(Vector2(b.x+radius, b.y+size.y))
	_points.append_array(_arc_coordinates(radius, PI/2, PI, npoints, Vector2(b.x+radius, b.y+size.y-radius)))
	_points.append(Vector2(b.x, b.y+size.y-radius))
	

	
func _draw():
	if not _points:
		_calculate_shape()
	
	var scale_factor = max(scale.x, scale.y)
	
	draw_colored_polygon(_points, fill_color)	
	_points.append(_points[0])
	draw_polyline(_points, stroke_color, width/scale_factor, true)
	_points.remove_at(_points.size()-1)
	
		
func _ready():
	pass

	
