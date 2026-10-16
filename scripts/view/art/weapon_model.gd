class_name WeaponModel
extends RefCounted
## The thrown and placed skill objects that are real 3D models (assets/models/weapons/<id>.glb,
## made by tools/blender/build_prop_model.py from the owner's models): the slipper (tsinelas),
## the can (lata), the marble (bola), the crumpled paper (papel trap) and the paper sheet
## (papel shield). Each has its base centre on the origin and the matte look from ModelLook.
## Weapons without a model here keep their code-drawn object (Props.weapon_object).

const PATH: String = "res://assets/models/weapons/%s.glb"
## Weapon id -> [model, longest side in metres]. The slippers keep the old boxes' length.
const OBJECTS: Dictionary[StringName, Array] = {
	&"tsinelas_light": ["slipper", 0.8],
	&"tsinelas_heavy": ["slipper", 1.5],
	&"lata": ["can", 0.7],
	&"bola": ["marble", 0.8],
	&"papel_trap": ["crumpled_paper", 0.7],
}
## The paper wall's model.
const SHIELD: String = "paper"
const GAIN: float = 0.85

static var _scenes: Dictionary[String, PackedScene] = {}
static var _sizes: Dictionary[String, Vector3] = {}


static func has_model(weapon_id: StringName) -> bool:
	return OBJECTS.has(weapon_id)


## The thrown / placed object of `weapon_id`, its middle on the origin when `centered` (a
## projectile in flight) or standing on the ground (a placed trap).
static func make(weapon_id: StringName, centered: bool) -> Node3D:
	var spec: Array = OBJECTS[weapon_id]
	var id: String = spec[0] as String
	var natural: Vector3 = size_of(id)
	var scale: float = (spec[1] as float) / maxf(natural.x, maxf(natural.y, natural.z))
	var holder: Node3D = Node3D.new()
	var model: Node3D = _instance(id)
	model.scale = Vector3.ONE * scale
	if centered:
		model.position.y = -natural.y * scale / 2.0
	holder.add_child(model)
	return holder


## The paper wall: `width` metres wide, `height` tall and `thickness` deep (the model is a thin
## sheet standing up, so it is stretched to the wall's size).
static func shield(width: float, height: float, thickness: float) -> Node3D:
	var natural: Vector3 = size_of(SHIELD)
	var holder: Node3D = Node3D.new()
	var model: Node3D = _instance(SHIELD)
	model.scale = Vector3(width / natural.x, height / natural.y, thickness / natural.z)
	holder.add_child(model)
	return holder


## The size (x, y, z) the model was made at.
static func size_of(id: String) -> Vector3:
	if not _sizes.has(id):
		var probe: Node3D = _scene(id).instantiate() as Node3D
		var mesh: MeshInstance3D = probe.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		_sizes[id] = mesh.mesh.get_aabb().size
		probe.free()
	return _sizes[id]


static func _scene(id: String) -> PackedScene:
	if not _scenes.has(id):
		_scenes[id] = load(PATH % id) as PackedScene
	return _scenes[id]


static func _instance(id: String) -> Node3D:
	var root: Node3D = _scene(id).instantiate() as Node3D
	ModelLook.apply(root, GAIN)
	return root
