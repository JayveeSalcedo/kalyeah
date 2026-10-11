class_name LaneMinimap
extends Control
## Tall minimap in the top left corner (docs/GDD.md "HUD"): the whole street, as
## long as it is twice wide, seen from above with your end at the bottom. Your base
## is the blue corner at the bottom left, theirs the red corner at the top right;
## the taped boxes are where tagged kids wait (yours top left, theirs bottom right).
## Obstacles are dark blocks, players are dots (you are white-ringed).

const PANEL: Color = Color(0.1, 0.08, 0.14, 0.78)
const ROAD: Color = Color(0.33, 0.33, 0.36, 0.95)
const OBSTACLE: Color = Color(0.16, 0.15, 0.18)
const OWN: Color = Color(0.3, 0.6, 1.0)
const ENEMY: Color = Color(1.0, 0.35, 0.35)
const BASE_ALPHA: float = 0.55
const JAIL_ALPHA: float = 0.75
## Gold frame, like the skill buttons.
const FRAME: Color = Color(1.0, 0.8, 0.32)
const CORNER: float = 12.0
const FRAME_WIDTH: float = 4.0
const INSET: float = 7.0
const DOT: float = 4.5
const BASE_STEPS: int = 18

var _sim: MatchSim
var _local_id: int = -1
var _local_team: int = 0


func setup(sim: MatchSim, local_id: int, local_team: int) -> void:
	_sim = sim
	_local_id = local_id
	_local_team = local_team
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Street x/z to minimap pixels, turned so the local team's end is at the bottom.
func to_map(world: Vector2) -> Vector2:
	var layout: MapLayout = _sim.layout
	var view: Vector2 = world * float(_sim.side_for_team(_local_team))
	var inner: Rect2 = _inner()
	return inner.get_center() + Vector2(
		view.x / layout.lane_width * inner.size.x, view.y / layout.lane_length * inner.size.y
	)


func _inner() -> Rect2:
	return Rect2(Vector2(INSET, INSET), size - Vector2(INSET, INSET) * 2.0)


func _draw() -> void:
	if _sim == null:
		return
	var back: StyleBoxFlat = StyleBoxFlat.new()
	back.bg_color = PANEL
	back.set_corner_radius_all(int(CORNER))
	back.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	back.shadow_size = 4
	back.shadow_offset = Vector2(0, 3)
	draw_style_box(back, Rect2(Vector2.ZERO, size))
	var layout: MapLayout = _sim.layout
	_draw_world_rect(layout.lane_rect(), ROAD)
	var own_side: int = _sim.side_for_team(_local_team)
	for side: int in [MapLayout.SIDE_OWN, MapLayout.SIDE_ENEMY]:
		var color: Color = OWN if side == own_side else ENEMY
		_draw_base(side, Color(color, BASE_ALPHA))
		_draw_world_rect(layout.jail_rect(side), Color(color, JAIL_ALPHA))
	for rect: Rect2 in _sim.obstacles:
		_draw_world_rect(rect, OBSTACLE)
	for id: int in _sim.players:
		var state: PlayerState = _sim.players[id]
		var at: Vector2 = to_map(state.position)
		if id == _local_id:
			draw_circle(at, DOT + 2.0, Color.WHITE)
		var color: Color = OWN if state.team == _local_team else ENEMY
		draw_circle(at, DOT, color.darkened(0.35) if state.tagged else color)
	# the gold frame last
	var frame: StyleBoxFlat = StyleBoxFlat.new()
	frame.draw_center = false
	frame.set_corner_radius_all(int(CORNER))
	frame.border_color = FRAME
	frame.set_border_width_all(int(FRAME_WIDTH))
	draw_style_box(frame, Rect2(Vector2.ZERO, size))


func _draw_world_rect(rect: Rect2, color: Color) -> void:
	var a: Vector2 = to_map(rect.position)
	var b: Vector2 = to_map(rect.end)
	draw_rect(Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (b - a).abs()), color)


## The base circle, cut off where it meets the edges of the street.
func _draw_base(side: int, color: Color) -> void:
	var layout: MapLayout = _sim.layout
	var center: Vector2 = layout.base_center(side)
	var street: Rect2 = layout.lane_rect()
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in BASE_STEPS:
		var angle: float = TAU * float(i) / float(BASE_STEPS)
		var point: Vector2 = center + Vector2(cos(angle), sin(angle)) * layout.base_radius
		point = point.clamp(street.position, street.end)
		points.append(to_map(point))
	draw_colored_polygon(points, color)
