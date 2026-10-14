class_name LaneMinimap
extends Control
## Minimap in the top left corner (docs/GDD.md "HUD", no frame): the whole playing area at
## exactly its own 1:2 shape, seen from above with your end at the bottom. Your base
## is the blue corner at the bottom left, theirs the red corner at the top right;
## the taped boxes are where tagged kids wait (yours top left, theirs bottom right).
## Obstacles are dark blocks; every player is the face of their character in a circle, with a
## ring in the team colour (you are white-ringed).

const PANEL: Color = Color(0.1, 0.08, 0.14, 0.78)
const ROAD: Color = Color(0.33, 0.33, 0.36, 0.95)
const OBSTACLE: Color = Color(0.16, 0.15, 0.18)
const OWN: Color = Color(0.3, 0.6, 1.0)
const ENEMY: Color = Color(1.0, 0.35, 0.35)
const BASE_ALPHA: float = 0.55
const JAIL_ALPHA: float = 0.75
const CORNER: float = 12.0
const INSET: float = 7.0
## A player's face circle: radius, the team ring round it and the white ring for you (px).
const FACE: float = 8.0
const RING: float = 1.8
const SELF_RING: float = 1.8
const FACE_STEPS: int = 20
## A tagged kid's face is dimmed.
const TAGGED_DIM: float = 0.5
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


## The street's rectangle inside the frame: as big as fits, at exactly the street's ratio.
func _inner() -> Rect2:
	var room: Vector2 = size - Vector2(INSET, INSET) * 2.0
	var ratio: float = _sim.layout.lane_width / _sim.layout.lane_length
	var fit: Vector2 = Vector2(room.y * ratio, room.y) if room.x / room.y > ratio else Vector2(room.x, room.x / ratio)
	return Rect2((size - fit) / 2.0, fit)


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
	# the local player last, so you are never covered by another face
	var ids: Array = _sim.players.keys()
	ids.erase(_local_id)
	ids.append(_local_id)
	for id: int in ids:
		if _sim.players.has(id):
			_draw_player(_sim.players[id] as PlayerState)


## One player: their face (cropped from the boot screen art; the top of the portrait without one) cut to a circle, in a ring of the
## team colour. Tagged kids, and enemies hiding in their box, are dimmed and ringed darker.
func _draw_player(state: PlayerState) -> void:
	var at: Vector2 = to_map(state.position)
	var dim: bool = state.tagged or _sim.hides_in_box(state, _local_team)
	var team_color: Color = OWN if state.team == _local_team else ENEMY
	if state.id == _local_id:
		draw_circle(at, FACE + RING + SELF_RING, Color.WHITE)
	draw_circle(at, FACE + RING, team_color.darkened(0.35) if dim else team_color)
	var texture: Texture2D = KidModel.minimap_face(state.character_id)
	if texture == null:
		texture = KidModel.portrait(state.character_id)
	draw_colored_polygon(face_points(at, FACE), Color.WHITE.darkened(TAGGED_DIM) if dim else Color.WHITE, face_uvs(texture), texture)


## The corners of a circle of `radius` round `center`.
static func face_points(center: Vector2, radius: float) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in FACE_STEPS:
		var angle: float = TAU * float(i) / float(FACE_STEPS)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points


## The texture coordinates for those corners: a square face fills the circle; for a tall
## portrait it is the square at the top (the face and shoulders).
static func face_uvs(texture: Texture2D) -> PackedVector2Array:
	var height: float = minf(1.0, float(texture.get_width()) / float(texture.get_height()))
	var uvs: PackedVector2Array = PackedVector2Array()
	for i: int in FACE_STEPS:
		var angle: float = TAU * float(i) / float(FACE_STEPS)
		uvs.append(Vector2(0.5 + 0.5 * cos(angle), height * (0.5 + 0.5 * sin(angle))))
	return uvs


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
