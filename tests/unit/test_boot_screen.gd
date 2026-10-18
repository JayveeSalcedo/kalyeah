extends GutTest

const BOOT_SCENE: PackedScene = preload("res://scenes/ui/boot_screen.tscn")


func _boot() -> BootScreen:
	var root: Control = autofree(Control.new()) as Control
	root.size = Vector2(720.0, 1280.0)
	add_child(root)
	var boot: BootScreen = BOOT_SCENE.instantiate() as BootScreen
	root.add_child(boot)
	boot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	boot.set_process(false)
	return boot


func test_the_fill_runs_from_the_left_end_to_the_right_end() -> void:
	assert_almost_eq(BootScreen.fill_width(0.0, 1000.0), 1000.0 * BootScreen.BAR_INSET, 0.01)
	assert_almost_eq(BootScreen.fill_width(1.0, 1000.0), 1000.0 * (1.0 - BootScreen.BAR_INSET), 0.01)
	assert_gt(BootScreen.fill_width(0.6, 1000.0), BootScreen.fill_width(0.3, 1000.0))


func test_black_is_the_base_layer_and_the_bar_sits_in_a_black_band_under_the_art() -> void:
	var boot: BootScreen = _boot()
	boot._layout()
	var black: ColorRect = boot.find_child("Black", false, false) as ColorRect
	assert_eq(black.color, Color.BLACK, "black underneath everything")
	assert_lt(black.get_index(), boot._art.get_index(), "under the art")
	assert_lt(black.get_index(), boot._track_rect.get_index(), "and under the bar")
	var band_top: float = 1280.0 - boot.band_height()
	assert_almost_eq(boot._art.position.y + boot._art.size.y, band_top, 0.5, "the art stops where the black band starts")
	var track: TextureRect = boot._track_rect
	assert_gte(track.position.y, band_top, "the bar is in the band")
	assert_lte(track.position.y + track.size.y, 1280.0)
	assert_gt(track.size.x, 720.0 * 0.9, "nearly edge to edge")
	boot.queue_free()


func test_the_percentage_is_dagsen_text_in_the_middle_of_the_bar_instead_of_the_k() -> void:
	var boot: BootScreen = _boot()
	boot.progress = 0.5
	boot._layout()
	assert_eq(boot._percent.text, "50%")
	assert_eq(boot._percent.get_theme_font("font"), KalyeahTheme.ACTION_FONT, "the Dagsen font")
	assert_almost_eq(boot._percent.get_global_rect().get_center().x, 360.0, 1.0, "centred on the bar")
	assert_almost_eq(boot._percent.get_global_rect().get_center().y, boot._track_rect.get_global_rect().get_center().y, 1.0)
	boot.progress = 1.0
	boot._apply_progress()
	assert_eq(boot._percent.text, "100%")
	assert_null(boot.get("_icon_rect"), "no K! riding the bar")
	boot.queue_free()


func test_a_tip_floats_just_above_the_bar_and_fits_the_screen() -> void:
	var boot: BootScreen = _boot()
	boot._layout()
	assert_true(BootScreen.TIPS.has(boot._tip.text), "one of the tips")
	var tip: Rect2 = boot._tip.get_global_rect()
	assert_lte(tip.end.y, 1280.0 - boot.band_height() + 1.0, "above the black band")
	assert_gte(tip.position.x, 0.0)
	assert_lte(tip.end.x, 720.0)
	assert_eq(boot._tip.horizontal_alignment, HORIZONTAL_ALIGNMENT_CENTER)
	for line: String in BootScreen.TIPS:
		assert_lt(line.length(), 80, "short enough for two lines")
	boot.queue_free()


func test_every_scene_it_warms_up_exists() -> void:
	for path: String in BootScreen.WARM_SCENES:
		assert_true(ResourceLoader.exists(path), path)
