extends GutTest
## The street props must be whole surfaces. When the Meshy models were decimated without first
## welding their split vertices they were torn into open pieces: thousands of open edges (cracks,
## holes, seams) on a few thousand triangles. Now only a few percent of the edges are open.

const PROPS: Array[String] = [
	"basketball_pole", "bench", "cardboard_wall", "crates", "electric_pole",
	"fishball_cart", "ironing_board", "rooster_tent", "school_zone", "truck_wheels",
]
## Open edges as a fraction of the triangles: the torn models were 0.9 to 1.3; whole ones are under 0.3.
const MAX_OPEN_FRACTION: float = 0.35
## The electric pole's dangling cables are thin flat ribbons, which are open strips by nature.
const MAX_OPEN_FRACTION_POLE: float = 0.6
const WELD: float = 1000.0  # positions are compared to the millimetre of a 1 m model


func _open_edges_and_triangles(id: String) -> Vector2i:
	var scene: PackedScene = load("res://assets/models/props/%s.glb" % id) as PackedScene
	var root: Node = scene.instantiate()
	var uses: Dictionary = {}
	var triangles: int = 0
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (node as MeshInstance3D).mesh
		for surface: int in mesh.get_surface_count():
			var arrays: Array = mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var welded: Dictionary = {}
			var ids: PackedInt32Array = PackedInt32Array()
			for vertex: Vector3 in vertices:
				var key: Vector3i = Vector3i((vertex * WELD).round())
				if not welded.has(key):
					welded[key] = welded.size()
				ids.append(int(welded[key]))
			for i: int in range(0, indices.size(), 3):
				triangles += 1
				for k: int in 3:
					var a: int = ids[indices[i + k]]
					var b: int = ids[indices[i + (k + 1) % 3]]
					var edge: Vector2i = Vector2i(mini(a, b), maxi(a, b))
					uses[edge] = int(uses.get(edge, 0)) + 1
	root.free()
	var open: int = 0
	for edge: Vector2i in uses:
		if int(uses[edge]) == 1:
			open += 1
	return Vector2i(open, triangles)


func test_the_street_props_are_whole_surfaces_not_torn_into_pieces() -> void:
	for id: String in PROPS:
		var counts: Vector2i = _open_edges_and_triangles(id)
		assert_gt(counts.y, 500, "%s has its triangles" % id)
		var limit: float = MAX_OPEN_FRACTION_POLE if id == "electric_pole" else MAX_OPEN_FRACTION
		assert_lt(float(counts.x) / float(counts.y), limit, "%s: %d open edges on %d triangles" % [id, counts.x, counts.y])
