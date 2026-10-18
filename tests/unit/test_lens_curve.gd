extends GutTest

const CAMERA: CameraRules = preload("res://data/rules/camera_rules.tres")


func test_the_lens_leaves_the_centre_alone_and_pulls_the_edges_in() -> void:
	var k: float = CAMERA.lens_k()
	assert_gt(k, 0.0, "the wide lens is on")
	assert_eq(LensCurve.source(Vector2(0.5, 0.5), k), Vector2(0.5, 0.5))
	assert_almost_eq(LensCurve.source(Vector2(1.0, 0.5), k).x, 1.0, 0.0001, "the middle of each frame edge still shows the flat edge")
	assert_lt(LensCurve.source(Vector2(0.9, 0.5), k).x, 0.9, "the edges show less of the flat picture's rim: pulled in")


func test_output_undoes_source() -> void:
	var k: float = CAMERA.lens_k()
	for flat: Vector2 in [Vector2(0.3, 0.2), Vector2(0.1, 0.9), Vector2(0.5, 0.62)]:
		var back: Vector2 = LensCurve.output(LensCurve.source(flat, k), k)
		assert_almost_eq(back.x, flat.x, 0.001)
		assert_almost_eq(back.y, flat.y, 0.001)
