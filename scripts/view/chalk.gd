class_name Chalk
extends RefCounted
## Chalk and paint drawn flat on the street for the street games (Tumbang Preso's home line
## and can circle, Patintero's grid): unshaded, casting no shadow, just above the road.
## View only. An owner-made ground decal (a 2D image, docs/ART.md) can replace these later.

const COLOR: Color = Color(0.95, 0.94, 0.88)
const LINE_WIDTH: float = 0.18
## Just above the road (and the code-drawn cement) so nothing flickers.
const HEIGHT: float = 0.035


## A flat colour; see-through colours are drawn first so kids always stand on top of them.
static func material(color: Color) -> StandardMaterial3D:
	var paint: StandardMaterial3D = StandardMaterial3D.new()
	paint.albedo_color = color
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if color.a < 1.0:
		paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		paint.render_priority = -100
	return paint


## A flat rectangle (x, z) on the street at `height`.
static func add_rect(parent: Node3D, rect: Rect2, paint: StandardMaterial3D, height: float = HEIGHT) -> MeshInstance3D:
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(rect.size.x, 0.01, rect.size.y)
	box.material = paint
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.mesh = box
	var center: Vector2 = rect.get_center()
	mesh.position = Vector3(center.x, height, center.y)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)
	return mesh


## A straight line from `a` to `b` (x, z), `width` wide.
static func add_line(parent: Node3D, a: Vector2, b: Vector2, paint: StandardMaterial3D, width: float = LINE_WIDTH) -> MeshInstance3D:
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(width, 0.01, a.distance_to(b) + width)
	box.material = paint
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.mesh = box
	var middle: Vector2 = (a + b) / 2.0
	mesh.position = Vector3(middle.x, HEIGHT, middle.y)
	var along: Vector2 = b - a
	mesh.rotation.y = atan2(along.x, along.y)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)
	return mesh


## A ring of `radius` round `center` (x, z), `width` wide.
static func add_ring(parent: Node3D, center: Vector2, radius: float, paint: StandardMaterial3D, width: float = LINE_WIDTH) -> MeshInstance3D:
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = radius - width / 2.0
	torus.outer_radius = radius + width / 2.0
	torus.material = paint
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.mesh = torus
	mesh.scale = Vector3(1.0, 0.04, 1.0)
	mesh.position = Vector3(center.x, HEIGHT, center.y)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)
	return mesh
