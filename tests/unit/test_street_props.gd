extends GutTest
## The owner's street models: the nanay outside the play area and the five new barrier things
## (tricycle, e-bike, sacks, sewing machine, NO ID NO ENTRY sign) across both ends.

const MAP_SCENE: PackedScene = preload("res://scenes/map/street_map.tscn")
const NEW_BARRIERS: Array[String] = ["tricycle", "ebike", "sacks", "sewing_machine", "no_id_no_entry"]


func _map() -> StreetMap:
	var map: StreetMap = autofree(MAP_SCENE.instantiate()) as StreetMap
	add_child(map)
	return map


func test_every_new_model_exists_light_and_whole() -> void:
	for id: String in NEW_BARRIERS + ["nanay"]:
		var path: String = PropModel.PATH % id
		assert_true(ResourceLoader.exists(path), "%s is there" % id)
		var counts: Vector2i = MeshAudit.open_edges_and_triangles(path)
		assert_between(counts.y, 2000, 6500, "%s is light for phones" % id)
		assert_lt(float(counts.x) / float(counts.y), 0.35, "%s is a whole surface" % id)


func test_the_new_things_are_in_the_barrier_rows_at_both_ends() -> void:
	var map: StreetMap = _map()
	assert_eq(map.barrier_rows.size(), 2, "a row at each end")
	var seen: Dictionary = {}
	for row: Array in map.barrier_rows:
		assert_gt(row.size(), 5, "a full row")
		for id: Variant in row:
			seen[id] = true
	for id: String in NEW_BARRIERS:
		assert_true(StreetMap.BARRIER_HEIGHTS.has(id), "%s has a height" % id)
		assert_true(seen.has(id), "%s stands in a row" % id)


func test_the_rows_still_fit_the_street_at_true_size() -> void:
	var map: StreetMap = _map()
	for row: Array in map.barrier_rows:
		var used: float = 0.0
		for id: Variant in row:
			var natural: Vector3 = PropModel.size_of(id as String)
			var side: float = natural.z if StreetMap.BARRIER_TURNED.has(id) else natural.x
			used += side * StreetMap.BARRIER_HEIGHTS[id] / natural.y + StreetMap.BARRIER_GAP
		assert_lt(used - StreetMap.BARRIER_GAP, map.layout.lane_width + 0.001, "the row fits the street")


func test_the_nanay_stands_on_the_sidewalk_outside_the_play_area_facing_the_street() -> void:
	var map: StreetMap = _map()
	var nanay: Node3D = map.find_child("Nanay", true, false) as Node3D
	assert_not_null(nanay)
	assert_gt(absf(nanay.position.x), map.layout.lane_width / 2.0 + map.layout.boundary_thickness, "outside the play area")
	assert_almost_eq(nanay.position.y, StreetMap.CURB_HEIGHT, 0.001, "on the sidewalk")
	assert_lt(nanay.position.x, 0.0)
	assert_almost_eq(nanay.rotation.y, PI / 2.0, 0.1, "turned toward the street")
	var mesh: MeshInstance3D = nanay.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	assert_almost_eq(mesh.get_aabb().size.y * nanay.scale.y, StreetMap.NANAY_HEIGHT, 0.01)


func test_the_nanay_sways_a_little() -> void:
	var map: StreetMap = _map()
	var nanay: Node3D = map.find_child("Nanay", true, false) as Node3D
	var start: float = nanay.rotation.y
	await wait_seconds(1.0)
	assert_ne(nanay.rotation.y, start)
	assert_lt(absf(nanay.rotation.y - PI / 2.0), deg_to_rad(StreetMap.NANAY_SWAY_DEGREES) + 0.01)


func test_the_main_screen_model_has_no_nanay_or_barriers() -> void:
	var map: StreetMap = autofree(MAP_SCENE.instantiate()) as StreetMap
	map.layout = load("res://data/rules/map_layout.tres") as MapLayout
	map.diorama = true
	map.show_overview_camera = false
	add_child(map)
	assert_null(map.find_child("Nanay", true, false))
	assert_eq(map.barrier_rows.size(), 0)
