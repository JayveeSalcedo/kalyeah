extends GutTest

const LAYOUT: MapLayout = preload("res://data/rules/map_layout.tres")
const MAP_SCENE: PackedScene = preload("res://scenes/map/street_map.tscn")


func test_the_playing_area_is_3_by_4() -> void:
	assert_eq(LAYOUT.lane_width, 30.0)
	assert_eq(LAYOUT.lane_length, 40.0)
	assert_almost_eq(LAYOUT.lane_width / LAYOUT.lane_length, 3.0 / 4.0, 0.001, "3:4 (width:length)")


func test_the_minimap_has_exactly_the_streets_ratio() -> void:
	assert_almost_eq(MatchHud.MINIMAP_SIZE.x / MatchHud.MINIMAP_SIZE.y, LAYOUT.lane_width / LAYOUT.lane_length, 0.0001)
	var minimap: LaneMinimap = autofree(LaneMinimap.new()) as LaneMinimap
	minimap.size = MatchHud.MINIMAP_SIZE
	minimap.setup(MatchSim.new(load("res://data/rules/game_rules.tres") as GameRules, LAYOUT, 1), 1, 0)
	var corner: Vector2 = minimap.to_map(LAYOUT.lane_rect().position)
	var far: Vector2 = minimap.to_map(LAYOUT.lane_rect().end)
	var drawn: Vector2 = (far - corner).abs()
	assert_almost_eq(drawn.x / drawn.y, 3.0 / 4.0, 0.0001, "the street drawn inside the frame is exactly 3:4")


func test_own_post_bottom_left_enemy_post_top_right() -> void:
	var own: Vector2 = LAYOUT.base_center(MapLayout.SIDE_OWN)
	var enemy: Vector2 = LAYOUT.base_center(MapLayout.SIDE_ENEMY)
	assert_lt(own.x, 0.0, "left")
	assert_gt(own.y, 0.0, "bottom (+Z is the own end)")
	assert_gt(enemy.x, 0.0, "right")
	assert_lt(enemy.y, 0.0, "top")
	assert_eq(enemy, -own, "the street is the same for both teams, turned round")
	assert_true(LAYOUT.lane_rect().has_point(own))


func test_tagged_boxes_own_top_left_enemy_bottom_right() -> void:
	var own: Rect2 = LAYOUT.jail_rect(MapLayout.SIDE_OWN)
	var enemy: Rect2 = LAYOUT.jail_rect(MapLayout.SIDE_ENEMY)
	assert_lt(own.get_center().x, 0.0, "your team's box: left")
	assert_lt(own.get_center().y, 0.0, "your team's box: top")
	assert_gt(enemy.get_center().x, 0.0, "their box: right")
	assert_gt(enemy.get_center().y, 0.0, "their box: bottom")
	assert_true(LAYOUT.lane_rect().encloses(own))
	assert_true(LAYOUT.lane_rect().encloses(enemy))
	for side: int in [MapLayout.SIDE_OWN, MapLayout.SIDE_ENEMY]:
		for other: int in [MapLayout.SIDE_OWN, MapLayout.SIDE_ENEMY]:
			assert_false(LAYOUT.in_base(other, LAYOUT.jail_rect(side).get_center()), "boxes are clear of the bases")


func test_jail_slots_stay_inside_the_box() -> void:
	for index: int in 6:
		assert_true(LAYOUT.jail_rect(MapLayout.SIDE_OWN).has_point(LAYOUT.jail_slot(MapLayout.SIDE_OWN, index)))
	assert_ne(LAYOUT.jail_slot(MapLayout.SIDE_OWN, 0), LAYOUT.jail_slot(MapLayout.SIDE_OWN, 1), "kids stand side by side")


func test_base_is_a_circle_round_the_post() -> void:
	var post: Vector2 = LAYOUT.base_center(MapLayout.SIDE_ENEMY)
	assert_true(LAYOUT.in_base(MapLayout.SIDE_ENEMY, post))
	assert_true(LAYOUT.in_base(MapLayout.SIDE_ENEMY, post + Vector2(0.0, LAYOUT.base_radius - 0.1)))
	assert_false(LAYOUT.in_base(MapLayout.SIDE_ENEMY, post + Vector2(0.0, LAYOUT.base_radius + 0.1)))
	assert_false(LAYOUT.in_base(MapLayout.SIDE_OWN, post))
	assert_true(LAYOUT.in_base(MapLayout.SIDE_OWN, LAYOUT.spawn_center(MapLayout.SIDE_OWN)), "players start at their post")


func test_fewer_obstacles_mirrored_for_both_halves() -> void:
	var rects: Array[Rect2] = LAYOUT.obstacle_rects()
	var count: int = LAYOUT.obstacles.size()
	assert_eq(rects.size(), count * 2)
	assert_lte(rects.size(), 6, "only a few cover pieces (owner: reduced twice)")
	for i: int in count:
		assert_true(rects[i + count].is_equal_approx(Rect2(-rects[i].end, rects[i].size)), "turned round the center")


func test_obstacles_inside_the_street_and_clear_of_bases_boxes_and_each_other() -> void:
	var rects: Array[Rect2] = LAYOUT.obstacle_rects()
	var street: Rect2 = LAYOUT.lane_rect()
	for i: int in rects.size():
		var rect: Rect2 = rects[i]
		assert_true(street.encloses(rect), "obstacle %d inside the street" % i)
		for side: int in [MapLayout.SIDE_OWN, MapLayout.SIDE_ENEMY]:
			assert_false(rect.intersects(LAYOUT.jail_rect(side).grow(1.0)), "obstacle %d clear of a box" % i)
			var post: Vector2 = LAYOUT.base_center(side)
			var closest: Vector2 = post.clamp(rect.position, rect.end)
			assert_gt(closest.distance_to(post), LAYOUT.base_radius, "obstacle %d clear of a base" % i)
		for j: int in range(i + 1, rects.size()):
			assert_false(rect.grow(0.8).intersects(rects[j]), "obstacles %d and %d leave room to pass" % [i, j])


func test_every_obstacle_is_a_cardboard_wall() -> void:
	for index: int in LAYOUT.obstacle_rects().size():
		assert_eq(LAYOUT.obstacle_prop(index), &"cardboard_wall", "inside the play area: cardboard walls only (owner)")


func test_boundary_walls_enclose_lane_without_overlapping_it() -> void:
	var lane: Rect2 = LAYOUT.lane_rect()
	var boundaries: Array[Rect2] = LAYOUT.boundary_rects()
	assert_eq(boundaries.size(), 4)
	for rect: Rect2 in boundaries:
		assert_false(rect.intersects(lane))


func test_street_scene_builds_bases_boxes_cover_and_dressing() -> void:
	var map: StreetMap = autofree(MAP_SCENE.instantiate()) as StreetMap
	add_child(map)
	var geometry: Node3D = map.get_node("%Geometry") as Node3D
	assert_gt(geometry.get_child_count(), 60, "street, cover, 2 bases, 2 boxes, houses and props")
	assert_eq(map.base_color(MapLayout.SIDE_OWN), StreetMap.OWN_COLOR)
	assert_eq(map.base_color(MapLayout.SIDE_ENEMY), StreetMap.ENEMY_COLOR)
	assert_eq(map.post_outline_color(MapLayout.SIDE_OWN), StreetMap.OWN_COLOR, "a blue outline round your post")
	assert_eq(map.post_outline_color(MapLayout.SIDE_ENEMY), StreetMap.ENEMY_COLOR, "a red one round theirs")
	map.set_own_side(MapLayout.SIDE_ENEMY)
	assert_eq(map.base_color(MapLayout.SIDE_ENEMY), StreetMap.OWN_COLOR, "your post is always blue")
	assert_eq(map.post_outline_color(MapLayout.SIDE_ENEMY), StreetMap.OWN_COLOR, "and so is its outline")


func test_props_stay_low_poly() -> void:
	var budgets: Dictionary = {
		"house": Props.house(0), "store": Props.sari_sari(), "crates_free": Props.umbrella(),
	}
	for name: String in budgets:
		var mesh: ArrayMesh = budgets[name]
		var vertices: int = mesh.surface_get_array_len(0)
		assert_lt(vertices, 3000, "%s has %d vertices" % [name, vertices])
		assert_eq(mesh.surface_get_material(0), LowPoly.material(), "%s uses the one shared material" % name)


func test_the_model_props_are_light_and_standing_on_the_ground() -> void:
	var limits: Dictionary = {"electric_pole": 1200, "cardboard_wall": 3200, "bench": 4200, "school_zone": 1400, "rooster_tent": 1300}
	for id: String in limits:
		var model: Node3D = autofree(PropModel.make(id)) as Node3D
		var mesh: MeshInstance3D = model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var vertices: int = mesh.mesh.surface_get_array_len(0)
		assert_lt(vertices, limits[id] * 3, "%s has %d vertices" % [id, vertices])
		var box: AABB = mesh.mesh.get_aabb()
		assert_almost_eq(box.position.y, 0.0, 0.01, "%s stands on the ground" % id)
		assert_almost_eq(box.position.x + box.size.x / 2.0, 0.0, 0.01, "%s is centred" % id)
		var material: StandardMaterial3D = mesh.get_surface_override_material(0) as StandardMaterial3D
		assert_eq(material.roughness, 1.0, "%s is matte" % id)


func test_cover_models_fill_their_footprint_and_stay_about_a_metre_high() -> void:
	for id: String in ["bench", "cardboard_wall", "school_zone", "rooster_tent"]:
		var footprint: Vector2 = Vector2(2.6, 0.6)
		var model: Node3D = autofree(PropModel.fit(id, footprint, 1.15)) as Node3D
		var mesh: MeshInstance3D = model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var box: AABB = mesh.mesh.get_aabb()
		assert_almost_eq(box.size.x * model.scale.x, footprint.x, 0.02, "%s fills the length" % id)
		assert_almost_eq(box.size.z * model.scale.z, footprint.y, 0.02, "%s fills the depth" % id)
		assert_lte(box.size.y * model.scale.y, 1.16, "%s is no taller than the cap" % id)
		assert_gt(box.size.y * model.scale.y, 0.5, "%s is tall enough to hide behind" % id)


func _post_front(map: StreetMap, side: int) -> float:
	var center: Vector2 = LAYOUT.base_center(side)
	for child: Node in map.get_node("%Geometry").get_children():
		var node: Node3D = child as Node3D
		if node != null and node.scene_file_path.ends_with("electric_pole.glb") and Vector2(node.position.x, node.position.z).is_equal_approx(center):
			var front: Vector3 = node.global_basis.z.normalized()
			return front.dot(Vector3(-center.x, 0.0, -center.y).normalized())
	fail_test("no post at base %d" % side)
	return 0.0


func test_the_enemy_post_faces_the_middle_and_your_own_is_turned_round() -> void:
	var map: StreetMap = autofree(MAP_SCENE.instantiate()) as StreetMap
	add_child(map)
	assert_gt(_post_front(map, MapLayout.SIDE_ENEMY), 0.99, "their flyers face the play area")
	assert_lt(_post_front(map, MapLayout.SIDE_OWN), -0.99, "your (blue) post is turned 180 degrees")
	map.set_own_side(MapLayout.SIDE_ENEMY)
	assert_lt(_post_front(map, MapLayout.SIDE_ENEMY), -0.99, "the other team: their own post is the turned one")
	assert_gt(_post_front(map, MapLayout.SIDE_OWN), 0.99)