class_name MeshAudit
extends RefCounted
## Counts the open edges of imported models (edges with a triangle on one side only): the cracks and
## holes of a mesh that was torn apart. Positions are welded to a millimetre first.

const WELD: float = 1000.0


## Vector2i(open edges, triangles) of every mesh under the scene `path`.
static func open_edges_and_triangles(path: String) -> Vector2i:
	var root: Node = (load(path) as PackedScene).instantiate()
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
