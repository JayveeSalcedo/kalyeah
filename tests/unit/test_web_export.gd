extends GutTest
## The web build's browser-tab icon (see export_presets.cfg).


func _web_head_include() -> String:
	var cfg: ConfigFile = ConfigFile.new()
	assert_eq(cfg.load("res://export_presets.cfg"), OK)
	for section: String in cfg.get_sections():
		if cfg.get_value(section, "name", "") == "Web":
			return String(cfg.get_value(section + ".options", "html/head_include", ""))
	fail_test("no Web preset")
	return ""


func test_web_export_ships_the_page_icon() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.load("res://export_presets.cfg")
	for section: String in cfg.get_sections():
		if cfg.get_value(section, "name", "") == "Web":
			assert_true(cfg.get_value(section + ".options", "html/export_icon", false), "index.icon.png is exported")
	assert_true(String(ProjectSettings.get_setting("application/config/icon")).begins_with("res://assets/app_icon/"))


func test_the_game_cannot_swap_the_tab_icon_for_a_blob() -> void:
	# at boot the engine replaces the tab icon with a blob: URL, which Safari (and so
	# every iPhone browser) does not show; the page puts the real file back
	var head: String = _web_head_include()
	assert_string_contains(head, "-gd-engine-icon")
	assert_string_contains(head, "MutationObserver")
	assert_string_contains(head, "blob:")
	assert_string_contains(head, "index.icon.png?v=")
