class_name LaneMinimap
extends Control
## Minimap in the top left corner (docs/GDD.md "HUD", no frame): the whole playing area at
## exactly its own 1:2 shape, seen from above with your end at the bottom. Your base
## is the blue corner at the bottom left, theirs the red corner at the top right;
## the taped boxes are where tagged kids wait (yours top left, theirs bottom right).
## Obstacles are dark blocks; every player is the face of their character in a circle, with one
## thin ring in the team colour. The drawing (MinimapCanvas) is rendered at SUPERSAMPLE times the
## size in a SubViewport and shown scaled down, so every element is smooth, then cropped to rounded
## corners by a shader.

const ROAD: Color = Color(0.33, 0.33, 0.36, 0.95)
const OBSTACLE: Color = Color(0.16, 0.15, 0.18)
const OWN: Color = Color(0.3, 0.6, 1.0)
const ENEMY: Color = Color(1.0, 0.35, 0.35)
const BASE_ALPHA: float = 0.55
const JAIL_ALPHA: float = 0.75
## The street fills the whole minimap (no panel or frame round it). Everything drawn is cropped
## to rounded corners of this radius (px) by shaders/minimap_crop.gdshader, with a smooth edge.
const CORNER: float = 12.0
const CROP_SHADER: Shader = preload("res://shaders/minimap_crop.gdshader")
## A player's face circle: its radius, how thick the one team-colour ring on its edge is, and how
## much bigger you are than the others (px).
const FACE: float = 8.0
const RING: float = 1.2
const SELF_SCALE: float = 1.25
## The minimap is drawn this many times bigger and scaled down, which smooths every edge.
const SUPERSAMPLE: int = 3
const FACE_STEPS: int = 40
## A tagged kid's face is dimmed.
const TAGGED_DIM: float = 0.5
const BASE_STEPS: int = 48

var _sim: MatchSim
var _local_id: int = -1
var _local_team: int = 0
var _view: SubViewport
var _canvas: MinimapCanvas
var _shown: TextureRect


func setup(sim: MatchSim, local_id: int, local_team: int) -> void:
	_sim = sim
	_local_id = local_id
	_local_team = local_team
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# the drawing is rendered big in its own viewport (smooth: no pixelated edges) ...
	_view = SubViewport.new()
	_view.transparent_bg = true
	_view.disable_3d = true
	_view.gui_disable_input = true
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_view)
	_canvas = MinimapCanvas.new()
	_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_canvas.scale = Vector2.ONE * float(SUPERSAMPLE)
	_view.add_child(_canvas)
	_canvas.setup(self, sim, local_id, local_team)
	# ... and shown scaled down, cropped to rounded corners with a smooth edge
	_shown = TextureRect.new()
	_shown.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shown.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_shown.stretch_mode = TextureRect.STRETCH_SCALE
	_shown.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_shown.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shown.texture = _view.get_texture()
	var crop: ShaderMaterial = ShaderMaterial.new()
	crop.shader = CROP_SHADER
	crop.set_shader_parameter("radius", CORNER)
	_shown.material = crop
	add_child(_shown)
	resized.connect(_update_size)
	_update_size()


func _update_size() -> void:
	var pixels: Vector2i = Vector2i(maxi(1, ceili(size.x * SUPERSAMPLE)), maxi(1, ceili(size.y * SUPERSAMPLE)))
	_view.size = pixels
	_canvas.size = size
	(_shown.material as ShaderMaterial).set_shader_parameter("rect_size", size)


func _process(_delta: float) -> void:
	if _canvas != null:
		_canvas.queue_redraw()


## Street x/z to minimap pixels, turned so the local team's end is at the bottom.
func to_map(world: Vector2) -> Vector2:
	var layout: MapLayout = _sim.layout
	var view: Vector2 = world * float(_sim.side_for_team(_local_team))
	var inner: Rect2 = street_rect()
	return inner.get_center() + Vector2(
		view.x / layout.lane_width * inner.size.x, view.y / layout.lane_length * inner.size.y
	)


## The street's rectangle: as big as fits, at exactly the street's ratio.
func street_rect() -> Rect2:
	var room: Vector2 = size
	var ratio: float = _sim.layout.lane_width / _sim.layout.lane_length
	var fit: Vector2 = Vector2(room.y * ratio, room.y) if room.x / room.y > ratio else Vector2(room.x, room.x / ratio)
	return Rect2((size - fit) / 2.0, fit)


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
