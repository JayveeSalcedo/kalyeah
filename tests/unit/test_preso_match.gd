extends GutTest
## The Tumbang Preso practice screen: you and three bots on the street with the can, your
## slipper button, the prompt, the tally board and the result card.

const PRESO_SCENE: PackedScene = preload("res://scenes/match/preso.tscn")
const PRESO: PresoRules = preload("res://data/rules/preso_rules.tres")
const DT: float = 1.0 / 30.0


func _match() -> PresoMatch:
	var screen: PresoMatch = autofree(PRESO_SCENE.instantiate()) as PresoMatch
	add_child(screen)
	screen.skip_intro()
	return screen


func _me(screen: PresoMatch) -> PresoPlayer:
	return screen.sim.players[PresoMatch.LOCAL_ID]


func test_you_start_behind_the_line_with_your_slipper_and_a_bot_is_the_taya() -> void:
	var screen: PresoMatch = _match()
	assert_eq(screen.sim.players.size(), 4)
	assert_true(PresoMatch.BOT_IDS.has(screen.sim.taya_id), "you learn to throw first")
	assert_true(screen.sim.can_throw(_me(screen)))
	screen.advance(DT)
	assert_true(screen.hud.throw_button.visible)
	assert_true(screen.hud.prompt_label.text.begins_with("THROW AT THE CAN!"))


func test_the_opening_show_names_the_game_and_hides_the_controls() -> void:
	var screen: PresoMatch = autofree(PRESO_SCENE.instantiate()) as PresoMatch
	add_child(screen)
	screen.advance(DT)
	assert_true(screen.hud.intro_bar.visible)
	assert_eq(screen.hud.intro_title.text, "TUMBANG PRESO!")
	assert_false(screen.hud.throw_button.visible)


func test_releasing_the_slipper_button_throws_your_slipper() -> void:
	var screen: PresoMatch = _match()
	screen.aim_started()
	screen.advance(DT * 2.0)
	screen.aim_released(Vector2(0.0, -1.0), false)
	screen.advance(DT * 3.0)
	assert_false(_me(screen).has_slipper)
	assert_true(screen.sim.slippers.has(PresoMatch.LOCAL_ID))


func test_a_cancelled_throw_keeps_your_slipper() -> void:
	var screen: PresoMatch = _match()
	screen.aim_started()
	screen.advance(DT * 2.0)
	screen.aim_released(Vector2(0.0, -1.0), true)
	screen.advance(DT * 3.0)
	assert_true(_me(screen).has_slipper)


func test_the_taya_has_no_slipper_button_and_is_told_to_tag() -> void:
	var screen: PresoMatch = _match()
	screen.sim.taya_id = PresoMatch.LOCAL_ID
	screen.advance(DT)
	assert_false(screen.hud.throw_button.visible)
	assert_eq(screen.hud.prompt_label.text, "TAG A KID OUTSIDE THE LINE!")


func test_the_board_lists_everyone_with_their_tags_and_marks_the_taya() -> void:
	var screen: PresoMatch = _match()
	screen.advance(DT)
	var lines: PackedStringArray = PresoHud.board_lines(screen.sim, screen.names)
	assert_eq(lines.size(), 4)
	var taya_lines: int = 0
	for line: String in lines:
		if line.ends_with("TAYA"):
			taya_lines += 1
	assert_eq(taya_lines, 1)
	assert_true("\n".join(lines).contains("YOU"))


func test_the_result_card_shows_at_the_end() -> void:
	var screen: PresoMatch = _match()
	for id: int in PresoMatch.BOT_IDS:
		screen.sim.players[id].times_tagged = 3
	screen.sim.match_time = PRESO.match_length
	screen.sim.phase = PresoSim.Phase.MATCH_OVER
	screen.advance(DT)
	assert_true(screen.hud.result_card.visible)
	assert_eq(screen.hud.result_title.text, "YOU WIN!")
	assert_false(screen.hud.joystick.visible)


func test_prompts_follow_the_slipper_and_the_can() -> void:
	var screen: PresoMatch = _match()
	var sim: PresoSim = screen.sim
	var me: PresoPlayer = _me(screen)
	sim.throw(me, Vector2(-0.6, -1.0))
	for i: int in 30:
		sim.step(DT)
	assert_true(PresoHud.prompt_for(sim, PresoMatch.LOCAL_ID).begins_with("GET YOUR SLIPPER!"))
	me.position = Vector2(8.0, 0.0)
	assert_eq(PresoHud.prompt_for(sim, PresoMatch.LOCAL_ID), "GET YOUR SLIPPER - WATCH THE TAYA!")
	sim.can_state = PresoSim.CanState.DOWN
	assert_eq(PresoHud.prompt_for(sim, PresoMatch.LOCAL_ID), "THE CAN IS DOWN - GET YOUR SLIPPER!")


func test_the_street_keeps_its_props_but_no_base_markings() -> void:
	var screen: PresoMatch = _match()
	var map: StreetMap = screen.get_node("%Map") as StreetMap
	assert_false(map.tag_zones)
	assert_eq(map._posts.size(), 2, "the street keeps its posts")
	assert_true(map._base_materials.is_empty(), "but no base circles or rescue areas")
