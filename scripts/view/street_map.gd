class_name StreetMap
extends Node3D
## The barangay street the game is played on (view only; reads MapLayout, holds no
## rules). The play area is one flat, dark grey cement slab (no tiles or
## markings) with curbs and sidewalks, house fronts, a sari-sari store with an
## umbrella and bunting around it; the few cover
## pieces kids hide behind (cardboard walls); each team's electric post in its corner with a chalk base
## circle; and the taped box where each team's tagged kids wait.

const OWN_COLOR: Color = Palette.TEAM_OWN
const ENEMY_COLOR: Color = Palette.TEAM_ENEMY
const SKY_COLOR: Color = Color(0.74, 0.8, 0.9)
# cinematic morning (see make_environment)
const SUN_ANGLES: Vector3 = Vector3(-30.0, 52.0, 0.0)
const SUN_COLOR: Color = Color(1.0, 0.88, 0.7)
const SUN_ENERGY: float = 1.15
const SHADOW_OPACITY: float = 0.62
const SHADOW_BLUR: float = 1.6
const FILL_ANGLES: Vector3 = Vector3(-30.0, 258.0, 0.0)
const FILL_COLOR: Color = Color(0.58, 0.7, 1.0)
const FILL_ENERGY: float = 0.38
const AMBIENT_COLOR: Color = Color(0.78, 0.86, 1.0)
const AMBIENT_ENERGY: float = 0.82
const EXPOSURE: float = 0.94
const TONEMAP_WHITE: float = 4.0
const GLOW_INTENSITY: float = 0.18
const GLOW_BLOOM: float = 0.03
const GLOW_THRESHOLD: float = 1.1
const SATURATION: float = 0.9
const CONTRAST: float = 0.97
const BRIGHTNESS: float = 0.97
const HAZE_COLOR: Color = Color(1.0, 0.9, 0.8)
const HAZE_DENSITY: float = 0.002
const RING_HEIGHT: float = 0.03
## The base chalk and the box tape are tinted toward a soft grey so they are calm, not neon.
const SOFT_GREY: Color = Color(0.62, 0.64, 0.7)
const BASE_SOFTEN: float = 0.3
const BASE_ALPHA: float = 0.5
const JAIL_FILL_ALPHA: float = 0.22
const TAPE_WIDTH: float = 0.16
const CHALK: Color = Color(0.96, 0.95, 0.9)
const CHALK_WIDTH: float = 0.12
const BASE_STEPS: int = 36
const CURB_HEIGHT: float = 0.18
const SIDEWALK_WIDTH: float = 2.4
## The street goes on past both ends of the play area (behind a barricade).
const END_REACH: float = 16.0
const HOUSE_SPACING: float = 6.4
const BUNTING_HEIGHT: float = 6.0
const SHADOW_DISTANCE: float = 75.0
## Painted ground sits just above the coloured road and sidewalk boxes.
const PAVER_TILE: float = 2.4
## The play area is one flat, dark grey cement slab (owner): no repeating tiles.
const CEMENT: Color = Color(0.3, 0.3, 0.31)
## Optional realistic cement art (owner-made 2D image, see docs/ART.md): when this
## file exists it is laid ONCE over the whole play area (stretched, never tiled).
const CEMENT_ART: String = "res://assets/textures/cement.png"
const CEMENT_LIFT: float = 0.004
const SIDEWALK_TINT: Color = Color(0.8, 0.76, 0.7)
## Paving around the whole map, so the street never ends in sky.
const OUTER_MARGIN: float = 40.0
const OUTER_DROP: float = -0.12
const OUTER_TINT: Color = Color(0.62, 0.58, 0.54)
const SARI_SIGN_HEIGHT: float = 1.15
## Which model each cover piece (MapLayout.obstacle_props) is drawn as.
const OBSTACLE_MODELS: Dictionary[StringName, String] = {
	&"bench": "bench", &"cardboard_wall": "cardboard_wall", &"school_zone": "school_zone", &"tent": "rooster_tent",
}
const COVER_HEIGHT: float = 1.15
const POST_HEIGHT: float = 6.0
const BARRICADE_COUNT: int = 9
const BARRICADE_MODELS: Array[String] = ["bench", "school_zone", "rooster_tent"]
const BARRICADE_DEPTH: float = 0.7
const BARRICADE_HEIGHT: float = 1.1

@export var layout: MapLayout
## Off when a match scene supplies its own (follow) camera.
@export var show_overview_camera: bool = true
## side -> [post band, base chalk, box tape, box fill] materials (recoloured per viewer).
var _base_materials: Dictionary[int, Array] = {}

@onready var _geometry: Node3D = %Geometry
@onready var _camera: Camera3D = %Camera
@onready var _sun: DirectionalLight3D = %Sun
@onready var _back_button: Button = %BackButton


func _ready() -> void:
	_build_map()
	if show_overview_camera:
		_setup_camera()
	_light_scene(self, _sun)
	_back_button.pressed.connect(_on_back_pressed)


## Cinematic morning: a low golden sun (long soft shadows), a cool blue fill from
## the other side and a soft lavender ambient so the shadows stay blue against the
## warm light, a gentle bloom on the highlights and a golden morning mist into the
## distance.
static func make_environment() -> Environment:
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = SKY_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = AMBIENT_COLOR
	env.ambient_light_energy = AMBIENT_ENERGY
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = EXPOSURE
	env.tonemap_white = TONEMAP_WHITE
	env.glow_enabled = true
	env.glow_intensity = GLOW_INTENSITY
	env.glow_bloom = GLOW_BLOOM
	env.glow_hdr_threshold = GLOW_THRESHOLD
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.adjustment_enabled = true
	env.adjustment_saturation = SATURATION
	env.adjustment_contrast = CONTRAST
	env.adjustment_brightness = BRIGHTNESS
	env.fog_enabled = true
	env.fog_light_color = HAZE_COLOR
	env.fog_density = HAZE_DENSITY
	env.fog_sky_affect = 0.0
	return env


## The key sun and the sky fill for a scene (`sun` is reused; the fill is added).
static func _light_scene(parent: Node, sun: DirectionalLight3D) -> void:
	sun.rotation_degrees = SUN_ANGLES
	sun.light_color = SUN_COLOR
	sun.light_energy = SUN_ENERGY
	# real shadows give the toy-town depth; one cheap orthogonal map
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = SHADOW_DISTANCE
	sun.shadow_opacity = SHADOW_OPACITY
	sun.shadow_blur = SHADOW_BLUR
	var fill: DirectionalLight3D = DirectionalLight3D.new()
	fill.name = "SkyFill"
	fill.rotation_degrees = FILL_ANGLES
	fill.light_color = FILL_COLOR
	fill.light_energy = FILL_ENERGY
	fill.shadow_enabled = false
	parent.add_child(fill)


## Colors the bases and boxes for the viewer: `own_side` is blue, the other red
## (teams switch ends every set).
func set_own_side(own_side: int) -> void:
	for side: int in _base_materials:
		var tint: Color = OWN_COLOR if side == own_side else ENEMY_COLOR
		for material: StandardMaterial3D in _base_materials[side]:
			var color: Color = tint
			if material != _base_materials[side][0]:
				color = tint.lerp(SOFT_GREY, BASE_SOFTEN)
			color.a = material.albedo_color.a
			material.albedo_color = color


func base_color(side: int) -> Color:
	var materials: Array = _base_materials[side]
	return (materials[0] as StandardMaterial3D).albedo_color


func _build_map() -> void:
	_add(_street(), Vector3.ZERO)
	_add_ground_textures()
	for index: int in layout.obstacle_rects().size():
		_add_obstacle(index)
	for side: int in [MapLayout.SIDE_OWN, MapLayout.SIDE_ENEMY]:
		var color: Color = OWN_COLOR if side == MapLayout.SIDE_OWN else ENEMY_COLOR
		var center: Vector2 = layout.base_center(side)
		var post: Node3D = _add_prop(PropModel.by_height("electric_pole", POST_HEIGHT), Vector3(center.x, 0.0, center.y))
		# a team-coloured band on the post so you can tell bases apart from afar
		var band: StandardMaterial3D = _add_band(post, color)
		var chalk: StandardMaterial3D = _add_base_chalk(side, color)
		var jail: Array[StandardMaterial3D] = _add_jail(side, color)
		_base_materials[side] = [band, chalk, jail[0], jail[1]]
	_add_barricades()
	_add_houses()
	_add_details()


## The cement street (past both ends of the play area), curbs and sidewalks.
func _street() -> ArrayMesh:
	var kit: LowPoly = LowPoly.new()
	var half_w: float = layout.lane_width / 2.0
	var length: float = layout.lane_length + END_REACH * 2.0
	kit.box(Vector3(0.0, -0.05, 0.0), Vector3(layout.lane_width, 0.1, length), CEMENT, CEMENT)
	for side: float in [-1.0, 1.0]:
		kit.box(Vector3(side * (half_w + layout.boundary_thickness / 2.0), CURB_HEIGHT / 2.0, 0.0), Vector3(layout.boundary_thickness, CURB_HEIGHT, length), Palette.CURB, Palette.CURB)
		var walk_x: float = side * (half_w + layout.boundary_thickness + SIDEWALK_WIDTH / 2.0)
		kit.box(Vector3(walk_x, CURB_HEIGHT / 2.0 - 0.02, 0.0), Vector3(SIDEWALK_WIDTH, CURB_HEIGHT, length), Palette.SIDEWALK, Palette.SIDEWALK)
	return kit.commit()


## The cement art if there is one, pavers on the sidewalks and paving all around.
func _add_ground_textures() -> void:
	var half_w: float = layout.lane_width / 2.0
	var length: float = layout.lane_length + END_REACH * 2.0
	_add_cement_art()
	for side: float in [-1.0, 1.0]:
		var walk: MeshInstance3D = StreetArt.ground("pavers", Vector2(SIDEWALK_WIDTH, length), PAVER_TILE, SIDEWALK_TINT)
		walk.position = Vector3(side * (half_w + layout.boundary_thickness + SIDEWALK_WIDTH / 2.0), CURB_HEIGHT - 0.015, 0.0)
		_geometry.add_child(walk)
	var outer: MeshInstance3D = StreetArt.ground("pavers", Vector2(layout.lane_width + OUTER_MARGIN * 2.0, length + OUTER_MARGIN * 2.0), PAVER_TILE, OUTER_TINT)
	outer.position = Vector3(0.0, OUTER_DROP, 0.0)
	_geometry.add_child(outer)


## Lays the owner's cement image once across the play area (no tiling), if present.
func _add_cement_art() -> void:
	if not ResourceLoader.exists(CEMENT_ART):
		return
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(layout.lane_width, layout.lane_length)
	var material: StandardMaterial3D = StreetArt.material("cement", Vector2.ONE)
	plane.material = material
	var art: MeshInstance3D = MeshInstance3D.new()
	art.name = "CementArt"
	art.mesh = plane
	art.position.y = CEMENT_LIFT
	art.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_geometry.add_child(art)


## The cover piece `index` (MapLayout.obstacle_rects order), drawn as its prop.
func _add_obstacle(index: int) -> void:
	var rect: Rect2 = layout.obstacle_rects()[index]
	var center: Vector2 = rect.get_center()
	var at: Vector3 = Vector3(center.x, 0.0, center.y)
	# the long side lies along X; a rect that is longer in Z turns the model a quarter
	var turned: bool = rect.size.y > rect.size.x
	var footprint: Vector2 = Vector2(maxf(rect.size.x, rect.size.y), minf(rect.size.x, rect.size.y))
	var id: String = String(OBSTACLE_MODELS.get(layout.obstacle_prop(index), "cardboard_wall"))
	_add_prop(PropModel.fit(id, footprint, COVER_HEIGHT), at, PI / 2.0 if turned else 0.0)


## The base: a chalk-coloured circle round the post, cut off by the street edges,
## with a chalk line on its rim. Returns the fill material (recoloured per viewer).
func _add_base_chalk(side: int, color: Color) -> StandardMaterial3D:
	var center: Vector2 = layout.base_center(side)
	var street: Rect2 = layout.lane_rect()
	var rim: Array[Vector2] = []
	for i: int in BASE_STEPS:
		var angle: float = TAU * float(i) / float(BASE_STEPS)
		rim.append((center + Vector2(cos(angle), sin(angle)) * layout.base_radius).clamp(street.position, street.end))
	var tool: SurfaceTool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_normal(Vector3.UP)
	for i: int in rim.size():
		var a: Vector2 = rim[i]
		var b: Vector2 = rim[(i + 1) % rim.size()]
		for point: Vector2 in [center, b, a]:
			tool.add_vertex(Vector3(point.x, RING_HEIGHT, point.y))
	var material: StandardMaterial3D = StandardMaterial3D.new()
	var soft: Color = color.lerp(SOFT_GREY, BASE_SOFTEN)
	material.albedo_color = Color(soft.r, soft.g, soft.b, BASE_ALPHA)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	# drawn first, so the kids and everything else stand on top of the tint, never under it
	material.render_priority = -100
	var mesh: ArrayMesh = tool.commit()
	mesh.surface_set_material(0, material)
	var fill: MeshInstance3D = _add(mesh, Vector3.ZERO)
	fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# the chalk line along the curved rim (not along the street edges)
	var kit: LowPoly = LowPoly.new()
	for i: int in rim.size():
		var a: Vector2 = rim[i]
		var b: Vector2 = rim[(i + 1) % rim.size()]
		if absf(a.distance_to(center) - layout.base_radius) > 0.01 or absf(b.distance_to(center) - layout.base_radius) > 0.01:
			continue
		var mid: Vector2 = (a + b) / 2.0
		kit.set_transform(Transform3D(Basis(Vector3.UP, -(b - a).angle()), Vector3(mid.x, RING_HEIGHT + 0.004, mid.y)))
		kit.box(Vector3.ZERO, Vector3(a.distance_to(b) + 0.04, 0.01, CHALK_WIDTH), CHALK)
	kit.reset_transform()
	_add(kit.commit(), Vector3.ZERO).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return material


## The taped box where a team's tagged kids wait: team-coloured tape on the road
## and a faint fill. Returns [tape, fill] materials (recoloured per viewer).
func _add_jail(side: int, color: Color) -> Array[StandardMaterial3D]:
	var box: Rect2 = layout.jail_rect(side)
	var center: Vector2 = box.get_center()
	var fill_mesh: BoxMesh = BoxMesh.new()
	fill_mesh.size = Vector3(box.size.x, 0.01, box.size.y)
	var fill: StandardMaterial3D = StandardMaterial3D.new()
	var soft: Color = color.lerp(SOFT_GREY, BASE_SOFTEN)
	fill.albedo_color = Color(soft.r, soft.g, soft.b, JAIL_FILL_ALPHA)
	fill.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fill.render_priority = -100
	fill_mesh.material = fill
	_add(fill_mesh, Vector3(center.x, RING_HEIGHT, center.y)).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var tape: StandardMaterial3D = StandardMaterial3D.new()
	tape.albedo_color = soft
	var pieces: Array[Rect2] = [
		Rect2(box.position.x, box.position.y, box.size.x, TAPE_WIDTH),
		Rect2(box.position.x, box.end.y - TAPE_WIDTH, box.size.x, TAPE_WIDTH),
		Rect2(box.position.x, box.position.y, TAPE_WIDTH, box.size.y),
		Rect2(box.end.x - TAPE_WIDTH, box.position.y, TAPE_WIDTH, box.size.y),
	]
	for piece: Rect2 in pieces:
		var strip: BoxMesh = BoxMesh.new()
		strip.size = Vector3(piece.size.x, 0.012, piece.size.y)
		strip.material = tape
		var at: Vector2 = piece.get_center()
		_add(strip, Vector3(at.x, RING_HEIGHT + 0.006, at.y)).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return [tape, fill]


## The ends of the play area are walled off by a row of street things, the bench, the
## SLOW DOWN SCHOOL ZONE sign and the wooden A-frame taking turns (the other end starts
## one further along, so the two rows differ).
func _add_barricades() -> void:
	var piece: float = layout.lane_width / BARRICADE_COUNT
	for end_index: int in 2:
		var end: float = -1.0 if end_index == 0 else 1.0
		for i: int in BARRICADE_COUNT:
			var x: float = -layout.lane_width / 2.0 + piece * (i + 0.5)
			var id: String = BARRICADE_MODELS[(i + end_index) % BARRICADE_MODELS.size()]
			var model: Node3D = PropModel.fit(id, Vector2(piece * 0.92, BARRICADE_DEPTH), BARRICADE_HEIGHT)
			_add_prop(model, Vector3(x, 0.0, end * (layout.lane_length / 2.0 + 0.45)))


## House fronts along both sides, a sari-sari store, and houses across both far ends.
func _add_houses() -> void:
	var half_w: float = layout.lane_width / 2.0
	var half_l: float = layout.lane_length / 2.0 + END_REACH
	var front: float = half_w + layout.boundary_thickness + SIDEWALK_WIDTH
	var store_z: float = -layout.lane_length * 0.18
	var variant: int = 0
	for side: float in [-1.0, 1.0]:
		var z: float = -half_l + HOUSE_SPACING / 2.0
		while z < half_l:
			var yaw: float = 0.0 if side < 0.0 else PI
			if side < 0.0 and absf(z - store_z) < HOUSE_SPACING / 2.0:
				_add(Props.sari_sari(), Vector3(side * (front + 1.8), 0.0, store_z))
				_add_sign("sari_sign", SARI_SIGN_HEIGHT, Vector3(side * (front + 0.4), 3.3, store_z))
			else:
				var tall: bool = variant % 3 == 1
				var depth: float = 4.4 if tall else 4.0
				var mesh: ArrayMesh = Props.house_tall(variant) if tall else Props.house(variant)
				_add(mesh, Vector3(side * (front + depth / 2.0 + 0.2), 0.0, z), yaw)
				if variant % 4 == 2:
					_add(Props.tarpaulin(variant), Vector3(side * (front + 0.1), 2.6, z + 1.4), yaw)
			variant += 1
			z += HOUSE_SPACING
	# the street ends in more houses, facing back up the street
	for end: float in [-1.0, 1.0]:
		var x: float = -half_w - 2.0
		while x < half_w + 3.0:
			_add(Props.house(variant), Vector3(x, 0.0, end * (half_l + 2.2)), end * PI / 2.0)
			variant += 1
			x += HOUSE_SPACING


## Life around the street (no power poles along the sides, owner): bunting,
## laundry, the store's umbrella and bench, drums and trees. The play area itself
## stays plain cement.
func _add_details() -> void:
	var half_w: float = layout.lane_width / 2.0
	var half_l: float = layout.lane_length / 2.0
	var span: float = layout.lane_width + 2.0 * (layout.boundary_thickness + SIDEWALK_WIDTH)
	var bunting_index: int = 0
	for bz: float in [-half_l * 0.55, half_l * 0.05, half_l * 0.6]:
		_add(Props.banderitas(span, bunting_index), Vector3(0.0, BUNTING_HEIGHT, bz))
		bunting_index += 1
	var walk_x: float = half_w + layout.boundary_thickness + SIDEWALK_WIDTH / 2.0
	var store_z: float = -layout.lane_length * 0.18
	_add(Props.umbrella(), Vector3(-walk_x, CURB_HEIGHT, store_z + 1.6))
	_add_prop(PropModel.fit("bench", Vector2(2.0, 0.7), 1.0), Vector3(-walk_x - 0.3, CURB_HEIGHT, store_z - 1.0), PI / 2.0)
	for lz: float in [-half_l * 0.7, half_l * 0.3]:
		_add(Props.laundry_line(4.0), Vector3(-walk_x - 0.6, CURB_HEIGHT, lz))
	for lz: float in [-half_l * 0.25, half_l * 0.75]:
		_add(Props.laundry_line(3.0), Vector3(walk_x + 0.6, CURB_HEIGHT, lz))
	for spot: Vector3 in [Vector3(walk_x, CURB_HEIGHT, 6.0), Vector3(-walk_x, CURB_HEIGHT, 15.0), Vector3(walk_x, CURB_HEIGHT, -20.0)]:
		_add(Props.drum(), spot)
	for pz: float in [-half_l * 0.85, half_l * 0.5]:
		_add(Props.potted_plant(), Vector3(walk_x + 0.5, CURB_HEIGHT, pz))
		_add(Props.potted_plant(), Vector3(-walk_x - 0.5, CURB_HEIGHT, -pz))
	var tree_x: float = half_w + layout.boundary_thickness + SIDEWALK_WIDTH + 7.0
	for tz: float in [-30.0, -14.0, 4.0, 22.0]:
		_add(Props.mango_tree(), Vector3(-tree_x - 1.0, 0.0, tz))
		_add(Props.banana_plant(), Vector3(tree_x, 0.0, tz + 6.0))


func _add_sign(texture_name: String, height: float, at: Vector3) -> void:
	var sign: Sprite3D = StreetArt.billboard(texture_name, height)
	sign.position = at
	_geometry.add_child(sign)


func _add(mesh: Mesh, at: Vector3, yaw: float = 0.0) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	instance.rotation.y = yaw
	_geometry.add_child(instance)
	return instance


func _add_prop(model: Node3D, at: Vector3, yaw: float = 0.0) -> Node3D:
	model.position = at
	model.rotation.y = yaw
	_geometry.add_child(model)
	return model


func _add_band(post: Node3D, color: Color) -> StandardMaterial3D:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = 0.44
	mesh.bottom_radius = 0.45
	mesh.height = 0.35
	mesh.radial_segments = 8
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	mesh.material = material
	var band: MeshInstance3D = MeshInstance3D.new()
	band.mesh = mesh
	band.position.y = 3.2
	post.add_child(band)
	return material


func _setup_camera() -> void:
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_camera.size = layout.overview_size
	_camera.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	_camera.position = Vector3(0.0, layout.overview_height, 0.0)
	_camera.environment = make_environment()


## The map's own Exit button (map preview); a match uses its settings menu instead.
func show_back_button(visible_now: bool) -> void:
	_back_button.visible = visible_now


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn")
