class_name VirtualJoystick
extends Control
## On-screen joystick: two fixed outlined rings (no fill) and a knob that follows the
## finger. Inside the inner ring it is a normal stick. Drag the knob so most of it is past
## the inner ring and the outer ring lights up: let go there and the kid keeps running that
## way on his own (auto-run). Let go inside and he stops. A touch in the stick's area
## always grabs the knob at once, auto-run or not. Put it over the area it should listen
## in. Handles real touches (multi-touch safe) and the real mouse; ignores mouse events
## emulated from touch.

signal changed(value: Vector2)

const MAX_RADIUS: float = 90.0
## The outer ring: the knob can be dragged out to it; past MAX_RADIUS (the knob's centre
## over the inner ring, so most of the knob outside it) a release locks the run.
const OUTER_RADIUS: float = 125.0
const DEADZONE: float = 0.1
const THUMB_RADIUS: float = 38.0
const NO_POINTER: int = -1
const MOUSE_POINTER: int = -2
const RING_COLOR: Color = Color(1.0, 1.0, 1.0, 0.6)
const RING_WIDTH: float = 4.0
const THUMB_COLOR: Color = Color(0.86, 0.87, 0.9, 0.4)
## The ring that is not "active" is the same white, dimmer: the outer one until it lights
## up (auto-run armed), then the inner one.
const DIM_RING_COLOR: Color = Color(1.0, 1.0, 1.0, 0.25)
## While the outer ring is lit, the band between the two rings is tinted too.
const BAND_COLOR: Color = Color(1.0, 1.0, 1.0, 0.16)

var value: Vector2 = Vector2.ZERO
## Resting spot of the stick inside the zone (0..1 of its size).
var rest_fraction: Vector2 = Vector2(0.42, 0.72)

## Running on its own after a release past the inner ring (value stays at full speed).
var auto_run: bool = false

var _pointer: int = NO_POINTER
var _armed: bool = false  # the knob is past the inner ring: a release locks the run
var _origin: Vector2 = Vector2.ZERO
var _thumb: Vector2 = Vector2.ZERO


## Offset from the stick origin to a normalized stick vector (length <= 1, with deadzone).
static func stick_from_offset(offset: Vector2, radius: float, deadzone: float) -> Vector2:
	var stick: Vector2 = (offset / radius).limit_length(1.0)
	if stick.length() < deadzone:
		return Vector2.ZERO
	return stick


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		if touch.pressed:
			if _pointer == NO_POINTER and _in_zone(touch.position):
				_begin(touch.index, touch.position)
		elif touch.index == _pointer:
			_end()
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event as InputEventScreenDrag
		if drag.index == _pointer:
			_update(drag.position)
	elif event is InputEventMouseButton:
		var click: InputEventMouseButton = event as InputEventMouseButton
		if click.device == InputEvent.DEVICE_ID_EMULATION or click.button_index != MOUSE_BUTTON_LEFT:
			return
		if click.pressed:
			if _pointer == NO_POINTER and _in_zone(click.position):
				_begin(MOUSE_POINTER, click.position)
		elif _pointer == MOUSE_POINTER:
			_end()
	elif event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		if motion.device != InputEvent.DEVICE_ID_EMULATION and _pointer == MOUSE_POINTER:
			_update(motion.position)


## Stops the stick dead: lets go of a drag and ends auto-run (the controls were hidden,
## or a new round began).
func release() -> void:
	var moving: bool = _pointer != NO_POINTER or auto_run or value != Vector2.ZERO
	_pointer = NO_POINTER
	_armed = false
	auto_run = false
	value = Vector2.ZERO
	if moving:
		changed.emit(value)
	queue_redraw()


## The outer ring is lit: letting go now (or already let go) keeps running.
func outer_lit() -> bool:
	return auto_run or (_pointer != NO_POINTER and _armed)


## [inner ring, outer ring] colours: both white and as thick; the lit one is the brighter.
func ring_colors() -> Array[Color]:
	if outer_lit():
		return [DIM_RING_COLOR, RING_COLOR]
	return [RING_COLOR, DIM_RING_COLOR]


## Where the stick rests when nobody touches it (MOBA style: always visible).
func rest_position() -> Vector2:
	return size * rest_fraction


func _draw() -> void:
	# an outline that never moves (no tint over the street), and the knob that follows the finger
	var origin: Vector2 = rest_position()
	var thumb: Vector2 = _thumb if _pointer != NO_POINTER or auto_run else origin
	var colors: Array[Color] = ring_colors()
	if outer_lit():
		var band: float = OUTER_RADIUS - MAX_RADIUS
		draw_arc(origin, MAX_RADIUS + band / 2.0, 0.0, TAU, 72, BAND_COLOR, band, true)
	draw_arc(origin, MAX_RADIUS, 0.0, TAU, 64, colors[0], RING_WIDTH, true)
	draw_arc(origin, OUTER_RADIUS, 0.0, TAU, 72, colors[1], RING_WIDTH, true)
	draw_circle(thumb, THUMB_RADIUS, THUMB_COLOR)


func _to_local(viewport_position: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * viewport_position


func _in_zone(viewport_position: Vector2) -> bool:
	return Rect2(Vector2.ZERO, size).has_point(_to_local(viewport_position))


func _begin(pointer: int, viewport_position: Vector2) -> void:
	# grabs at once, also out of auto-run: the finger takes over on this very touch
	auto_run = false
	_pointer = pointer
	_origin = rest_position()
	_update(viewport_position)


func _update(viewport_position: Vector2) -> void:
	var offset: Vector2 = _to_local(viewport_position) - _origin
	value = stick_from_offset(offset, MAX_RADIUS, DEADZONE)
	_thumb = _origin + offset.limit_length(OUTER_RADIUS)
	_armed = offset.length() > MAX_RADIUS
	changed.emit(value)
	queue_redraw()


func _end() -> void:
	_pointer = NO_POINTER
	if _armed and value != Vector2.ZERO:
		# let go past the inner ring: keep running that way at full speed
		auto_run = true
		value = value.normalized()
		_thumb = _origin + value * OUTER_RADIUS
	else:
		auto_run = false
		value = Vector2.ZERO
	_armed = false
	changed.emit(value)
	queue_redraw()
