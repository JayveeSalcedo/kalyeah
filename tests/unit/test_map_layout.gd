extends GutTest

const LAYOUT: MapLayout = preload("res://data/rules/map_layout.tres")
const MAP_SCENE: PackedScene = preload("res://scenes/map/street_map.tscn")


func test_the_street_is_twice_as_long_as_it_is_wide() -> void:
	assert_eq(LAYOUT.lane_width, 24.0)
	assert_eq(LAYOUT.lane_length, 48.0)
	assert_almost_eq(LAYOUT.lane_length / LAYOUT.lane_width, 2.0, 0.001, "the same 1:2 street as the minimap")


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
	assert_lte(rects.size(), 12, "a handful of cover pieces, not a maze")
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


func test_every_obstacle_has_a_prop() -> void:
	for index: int in LAYOUT.obstacle_rects().size():
		assert_true(LAYOUT.obstacle_prop(index) in [&"bench", &"crates", &"sawhorse", &"no_entry"])


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
	map.set_own_side(MapLayout.SIDE_ENEMY)
	assert_eq(map.base_color(MapLayout.SIDE_ENEMY), StreetMap.OWN_COLOR, "your post is always blue")


func test_props_stay_low_poly() -> void:
	var budgets: Dictionary = {
		"house": Props.house(0), "store": Props.sari_sari(), "post": Props.electric_post(),
		"crates": Props.crates(Vector2(1.4, 1.4)), "bench": Props.street_bench(Vector2(3.0, 0.7)),
		"sawhorse": Props.sawhorse(Vector2(2.6, 0.6)), "board": Props.sign_board(Vector2(2.4, 0.5)),
		"umbrella": Props.umbrella(),
	}
	for name: String in budgets:
		var mesh: ArrayMesh = budgets[name]
		var vertices: int = mesh.surface_get_array_len(0)
		assert_lt(vertices, 3000, "%s has %d vertices" % [name, vertices])
		assert_eq(mesh.surface_get_material(0), LowPoly.material(), "%s uses the one shared material" % name)


func test_cover_props_fill_their_footprint() -> void:
	var size: Vector2 = Vector2(0.7, 3.0)
	var bench: AABB = Props.street_bench(size).get_aabb()
	assert_almost_eq(bench.size.x, size.x, 0.25, "a bench along Z is turned to fit")
	assert_almost_eq(bench.size.z, size.y, 0.25)
	assert_between(Props.crates(Vector2(1.4, 1.4)).get_aabb().size.y, 0.8, 1.3, "kids hide behind about a metre of crates")
