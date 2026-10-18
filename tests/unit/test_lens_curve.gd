extends GutTest

const CAMERA: CameraRules = preload("res://data/rules/camera_rules.tres")


func test_the_lens_leaves_the_centre_alone_and_pulls_the_edges_in() -> void:
	var k: float = CAMERA.lens_k()
	assert_gt(k, 0.0, "the wide lens is on")
	assert_eq(LensCurve.source(Vector2.ZERO, k), Vector2.ZERO)
	assert_almost_eq(LensCurve.source(Vector2(1.0, 1.0), k).x, 1.0, 0.0001, "the frame edge still shows the flat edge")


func test_output_undoes_source() -> void:
	var k: float = CAMERA.lens_k()
	for flat: Vector2 in [Vector2(0.3, -0.5), Vector2(-0.8, 0.9), Vector2(0.0, 0.62)]:
		var back: Vector2 = LensCurve.output(LensCurve.source(flat, k), k)
		assert_almost_eq(back.x, flat.x, 0.001)
		assert_almost_eq(back.y, flat.y, 0.001)
