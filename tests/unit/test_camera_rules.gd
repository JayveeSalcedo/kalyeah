extends GutTest

const CAMERA: CameraRules = preload("res://data/rules/camera_rules.tres")
const LAYOUT: MapLayout = preload("res://data/rules/map_layout.tres")
const PHONE: float = 720.0 / 1280.0


func test_a_fixed_low_angle_with_a_wide_perspective_lens() -> void:
	assert_eq(CAMERA.pitch_degrees, 40.0, "low behind-the-kid view, far up the street")
	assert_eq(CAMERA.vfov_degrees, 60.0, "wide vertical field of view")
	assert_eq(CameraRules.DESIGN_ASPECT, 9.0 / 16.0, "portrait 9:16")


func test_other_camera_numbers_come_from_data() -> void:
	assert_eq(CAMERA.visible_width, 12.0, "owner: closer")
	assert_eq(CAMERA.end_margin, 2.0)
	assert_eq(CAMERA.player_screen_y, 0.62)


func test_distance_shows_the_visible_width_on_any_phone() -> void:
	for aspect: float in [0.46, PHONE, 0.75]:
		var distance: float = CAMERA.distance(aspect)
		var width: float = 2.0 * distance * tan(deg_to_rad(CAMERA.vfov_degrees / 2.0)) * aspect
		assert_almost_eq(width, CAMERA.visible_width, 0.001, "aspect %.2f" % aspect)
	assert_almost_eq(CAMERA.distance(PHONE), 18.48, 0.05)


func test_the_camera_is_high_behind_the_hero() -> void:
	var offset: Vector3 = CAMERA.camera_offset(CAMERA.distance(PHONE), false)
	assert_almost_eq(offset.y, 11.88, 0.1, "about 12 m up")
	assert_almost_eq(offset.length(), CAMERA.distance(PHONE), 0.001)


func test_aspect_is_kept_in_a_sane_range() -> void:
	assert_eq(CAMERA.distance(0.05), CAMERA.distance(CAMERA.min_aspect))
	assert_eq(CAMERA.distance(5.0), CAMERA.distance(CAMERA.max_aspect))


func test_offset_sits_behind_and_above_the_target() -> void:
	var offset: Vector3 = CAMERA.camera_offset(20.0, false)
	assert_almost_eq(offset.y, 20.0 * sin(deg_to_rad(CAMERA.pitch_degrees)), 0.001)
	var back: float = 20.0 * cos(deg_to_rad(CAMERA.pitch_degrees))
	assert_almost_eq(Vector2(offset.x, offset.z).length(), back, 0.001)
	assert_gt(offset.z, 0.0, "own side: camera behind on +Z, looking toward -Z")
	assert_gte(offset.x, 0.0, "never to the left of the hero")
	assert_almost_eq(rad_to_deg(atan2(offset.x, offset.z)), CAMERA.yaw_offset_degrees, 0.001)


func test_other_team_view_is_mirrored() -> void:
	var own: Vector3 = CAMERA.camera_offset(20.0, false)
	var other: Vector3 = CAMERA.camera_offset(20.0, true)
	assert_almost_eq(other.z, -own.z, 0.0001)
	assert_almost_eq(other.x, -own.x, 0.0001)
	assert_almost_eq(other.y, own.y, 0.0001)
	assert_eq(CAMERA.yaw_degrees(false), CAMERA.yaw_offset_degrees)
	assert_eq(CAMERA.yaw_degrees(true), CAMERA.yaw_offset_degrees + 180.0)


func test_the_aim_point_is_far_enough_ahead_to_hold_the_hero_low_on_screen() -> void:
	var reach: float = CAMERA.distance(PHONE)
	var ahead: float = CAMERA.look_ahead(reach)
	assert_almost_eq(ahead, 3.42, 0.05, "about 3.4 m ahead")
	assert_eq(CAMERA.clamp_target(Vector2(0.0, 10.0), LAYOUT, false, reach), Vector2(0.0, 10.0 - ahead), "own side looks toward -Z")
	assert_eq(CAMERA.clamp_target(Vector2(0.0, -10.0), LAYOUT, true, reach), Vector2(0.0, -10.0 + ahead), "flipped looks toward +Z")


func test_the_view_stops_at_the_map_ends_and_the_hero_walks_on() -> void:
	var reach: float = CAMERA.distance(PHONE)
	var end: float = LAYOUT.lane_length / 2.0 + CAMERA.end_margin
	# at our own end, the bottom edge of the view sits on the end of the map
	var home: Vector2 = CAMERA.clamp_target(Vector2(0.0, LAYOUT.lane_length / 2.0 - 1.0), LAYOUT, false, reach)
	assert_almost_eq(home.y + CAMERA.ground_offset(reach, 1.0), end, 0.001)
	# walking further toward that end does not move the camera
	var further: Vector2 = CAMERA.clamp_target(Vector2(0.0, LAYOUT.lane_length / 2.0 - 0.2), LAYOUT, false, reach)
	assert_eq(further, home)
	# at the enemy end, the far end of the map sits just under the HUD at the top
	var away: Vector2 = CAMERA.clamp_target(Vector2(0.0, -LAYOUT.lane_length / 2.0 + 1.0), LAYOUT, false, reach)
	assert_almost_eq(away.y + CAMERA.ground_offset(reach, CAMERA.top_safe_y), -end, 0.001)
	# mirrored for the other team
	var their_home: Vector2 = CAMERA.clamp_target(Vector2(0.0, -LAYOUT.lane_length / 2.0 + 1.0), LAYOUT, true, reach)
	assert_almost_eq(their_home.y - CAMERA.ground_offset(reach, 1.0), -end, 0.001)


func test_ground_offsets_cover_the_whole_screen() -> void:
	var reach: float = CAMERA.distance(PHONE)
	assert_almost_eq(CAMERA.ground_offset(reach, 0.5), 0.0, 0.001, "the screen centre is the aim point")
	assert_gt(CAMERA.ground_offset(reach, 1.0), 0.0, "the bottom edge is behind the aim point")
	assert_lt(CAMERA.ground_offset(reach, 0.0), 0.0, "the top edge is ahead of it")


func test_camera_follows_sideways_but_never_far_past_the_curb() -> void:
	var half_visible: float = CAMERA.visible_width / 2.0
	var room: float = LAYOUT.lane_width / 2.0 + CAMERA.edge_margin - half_visible
	if room <= 0.0:
		# the wide lens shows the whole lane across the screen: no sideways follow needed
		assert_eq(CAMERA.clamp_target(Vector2(1.0, 0.0), LAYOUT).x, 0.0, "centred on the lane")
		assert_gte(half_visible, LAYOUT.lane_width / 2.0, "the curbs are on screen")
		return
	assert_eq(CAMERA.clamp_target(Vector2(1.0, 0.0), LAYOUT).x, 1.0, "follows the hero")
	for x: float in [LAYOUT.lane_width / 2.0, -LAYOUT.lane_width / 2.0]:
		var shift: float = CAMERA.clamp_target(Vector2(x, 0.0), LAYOUT).x
		assert_lte(absf(shift) + half_visible, LAYOUT.lane_width / 2.0 + CAMERA.edge_margin + 0.001)
		assert_gte(absf(shift) + half_visible, LAYOUT.lane_width / 2.0, "the curb is on screen")


func test_follow_weight_is_frame_rate_independent() -> void:
	var one_step: float = CAMERA.follow_weight(0.1)
	var two_steps: float = 1.0 - pow(1.0 - CAMERA.follow_weight(0.05), 2.0)
	assert_almost_eq(one_step, two_steps, 0.0001)
	assert_eq(CAMERA.follow_weight(0.0), 0.0)


func test_the_follow_camera_uses_keep_height_and_the_data_angle() -> void:
	var camera: FollowCamera = autofree(FollowCamera.new()) as FollowCamera
	camera.rules = CAMERA
	camera.layout = LAYOUT
	add_child(camera)
	assert_eq(camera.keep_aspect, Camera3D.KEEP_HEIGHT)
	assert_eq(camera.fov, CAMERA.vfov_degrees)
	camera.follow(Vector2.ZERO, false)
	assert_almost_eq(camera.rotation_degrees.x, -CAMERA.pitch_degrees, 0.001)
