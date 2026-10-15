class_name MenuDiorama
extends SubViewportContainer
## The main screen's map model: a small, compact copy of the playground street (same bases, boxes,
## cover walls, posts and props as the real map) standing on a stone base, with three kids idling
## on it. It lives in its own 3D world inside a transparent SubViewport, so it floats over the
## screen background, and it slowly turns left and right so it never looks like a still picture.

const LANE_LENGTH: float = 26.0
const KIDS: Array[StringName] = [&"toni", &"popoy", &"ligaya"]
## The kids are bigger than life: the map model is small and they are its stars.
const KID_SCALE: float = 2.6
const CAMERA_FOV: float = 34.0
const CAMERA_PITCH: float = 38.0
## How much of the frame the model may fill (1 = touching the edges).
const FRAME_FILL: float = 0.97
## How far the model turns each way (degrees) and how long one swing takes (s).
const TURN_DEGREES: float = 13.0
const TURN_SECONDS: float = 7.0

var viewport: SubViewport
var pivot: Node3D
var camera: Camera3D
var map: StreetMap
var kids: Array[KidModel] = []

var _time: float = 0.0
var _idle: PlayerState = PlayerState.new()


func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.handle_input_locally = false
	viewport.gui_disable_input = true
	add_child(viewport)
	pivot = Node3D.new()
	pivot.name = "Pivot"
	viewport.add_child(pivot)
	_build_map()
	_build_kids()
	_build_camera()


## The street, cut short and without its surroundings (StreetMap.diorama).
func _build_map() -> void:
	var layout: MapLayout = (load("res://data/rules/map_layout.tres") as MapLayout).duplicate() as MapLayout
	layout.lane_length = LANE_LENGTH
	# the two cover walls belong to the long street: on the short model they would sit inside the bases
	layout.obstacles = []
	layout.obstacle_props = []
	map = (load("res://scenes/map/street_map.tscn") as PackedScene).instantiate() as StreetMap
	map.layout = layout
	map.diorama = true
	map.show_overview_camera = false
	map.get_node("Hud").queue_free()
	pivot.add_child(map)


func _build_kids() -> void:
	var rules: GameRules = load("res://data/rules/game_rules.tres") as GameRules
	var by_id: Dictionary[StringName, CharacterDef] = {}
	for def: CharacterDef in rules.characters:
		by_id[def.id] = def
	var spots: Array[Vector3] = [Vector3(-3.4, 0.0, 1.3), Vector3(0.0, 0.0, 0.2), Vector3(3.4, 0.0, 1.3)]
	for i: int in KIDS.size():
		var kid: KidModel = KidModel.new()
		kid.setup(by_id[KIDS[i]], Palette.TEAM_OWN if i != 1 else Palette.TEAM_ALLY, rules.player_radius)
		kid.position = spots[i]
		kid.scale = Vector3.ONE * KID_SCALE
		kid.rotation.y = PI + (-0.35 if i == 0 else (0.0 if i == 1 else 0.35))
		pivot.add_child(kid)
		kids.append(kid)


## A transparent camera over the model, looking down at it from the front.
func _build_camera() -> void:
	camera = Camera3D.new()
	camera.fov = CAMERA_FOV
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	var env: Environment = StreetMap.make_environment()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.glow_enabled = false
	env.fog_enabled = false
	camera.environment = env
	camera.near = 1.0
	camera.far = 400.0
	viewport.add_child(camera)
	camera.make_current()
	frame()
	resized.connect(frame)


## Places the camera so every corner of the model (street, sidewalks and stone base) fits the
## viewport with a margin, looking at its middle from the front.
func frame() -> void:
	if camera == null or map == null:
		return
	var pitch: float = deg_to_rad(CAMERA_PITCH)
	var half_x: float = map.layout.lane_width / 2.0 + map.layout.boundary_thickness + StreetMap.SIDEWALK_WIDTH + 0.4
	var half_z: float = map.layout.lane_length / 2.0 + StreetMap.DIORAMA_REACH + 0.4
	var aspect: float = maxf(0.2, size.x / maxf(size.y, 1.0))
	var tan_h: float = tan(deg_to_rad(CAMERA_FOV) / 2.0)
	var tan_v: float = tan_h / aspect
	var forward: Vector3 = Vector3(0.0, -sin(pitch), -cos(pitch))
	var right: Vector3 = Vector3.RIGHT
	var up: Vector3 = right.cross(forward).normalized()
	var distance: float = 10.0
	# the smallest distance at which all eight corners are inside the frame (with a margin)
	for step: int in 60:
		var eye: Vector3 = -forward * distance
		var fits: bool = true
		# at rest and at both ends of the swing (the model turns left and right)
		for yaw: float in [-TURN_DEGREES, 0.0, TURN_DEGREES]:
			for cx: float in [-half_x, half_x]:
				for cy: float in [-StreetMap.PLINTH_HEIGHT - 0.1, StreetMap.CURB_HEIGHT]:
					for cz: float in [-half_z, half_z]:
						var corner: Vector3 = Vector3(cx, cy, cz).rotated(Vector3.UP, deg_to_rad(yaw))
						var rel: Vector3 = corner - eye
						var depth: float = rel.dot(forward)
						if absf(rel.dot(right)) > depth * tan_h * FRAME_FILL or absf(rel.dot(up)) > depth * tan_v * FRAME_FILL:
							fits = false
		if fits:
			break
		distance *= 1.06
	camera.position = -forward * distance
	camera.rotation_degrees = Vector3(-CAMERA_PITCH, 0.0, 0.0)


func _process(delta: float) -> void:
	if pivot == null:
		return
	_time += delta
	pivot.rotation_degrees.y = sin(_time * TAU / TURN_SECONDS) * TURN_DEGREES
	for kid: KidModel in kids:
		kid.animate(delta, 0.0, _idle)
