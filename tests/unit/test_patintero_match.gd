extends GutTest
## The Patintero practice screen: your team of three (you and two bots) against three bots, the
## chalk grid, the stick, the prompt, the score card and the result card.

const PATINTERO_SCENE: PackedScene = preload("res://scenes/match/patintero.tscn")
const PAT: PatinteroRules = preload("res://data/rules/patintero_rules.tres")
const DT: float = 1.0 / 30.0


func _match() -> PatinteroMatch:
	var screen: PatinteroMatch = autofree(PATINTERO_SCENE.instantiate()) as PatinteroMatch
	add_child(screen)
	screen.skip_intro()
	return screen


func test_three_against_three_and_your_team_runs_first() -> void:
	var screen: PatinteroMatch = _match()
	assert_eq(screen.sim.players.size(), 6)
	assert_eq(screen.sim.attacking_team, PatinteroMatch.LOCAL_TEAM)
	assert_true(screen.sim.is_runner(PatinteroMatch.LOCAL_ID))
	screen.advance(DT)
	assert_true(screen.hud.joystick.visible)
	assert_eq(screen.hud.role_label.text, "YOUR TEAM RUNS")
	assert_eq(screen.hud.prompt_label.text, "CROSS THE LINES TO THE END!")
	assert_eq(screen.hud.score_label.text, "YOU 0 - 0 THEM")


func test_the_opening_show_names_the_game_and_hides_the_stick() -> void:
	var screen: PatinteroMatch = autofree(PATINTERO_SCENE.instantiate()) as PatinteroMatch
	add_child(screen)
	screen.advance(DT)
	assert_true(screen.hud.intro_bar.visible)
	assert_eq(screen.hud.intro_title.text, "PATINTERO!")
	assert_false(screen.hud.joystick.visible)


func test_the_stick_moves_you_up_the_grid() -> void:
	var screen: PatinteroMatch = _match()
	var me: PatinteroPlayer = screen.sim.players[PatinteroMatch.LOCAL_ID]
	var start: Vector2 = me.position
	screen.set_stick(Vector2(0.0, -1.0))
	screen.advance(DT * 6.0)
	assert_lt(me.position.y, start.y, "screen up is up the street")


func test_as_a_tagger_you_slide_along_your_line() -> void:
	var screen: PatinteroMatch = _match()
	var sim: PatinteroSim = screen.sim
	sim.runner_caught.emit(PatinteroMatch.ALLY_IDS[0], PatinteroMatch.ENEMY_IDS[0])
	sim._end_turn()
	sim._switch_sides()
	var me: PatinteroPlayer = sim.players[PatinteroMatch.LOCAL_ID]
	assert_eq(me.role, PatinteroPlayer.Role.LINE_GUARD)
	screen.set_stick(Vector2(0.6, -0.8))
	screen.advance(DT * 6.0)
	assert_eq(me.position.y, PAT.guard_lines[me.line_index], "stays on the line")
	assert_gt(me.position.x, 0.0)
	assert_eq(screen.hud.role_label.text, "YOUR TEAM TAGS")
	assert_eq(screen.hud.prompt_label.text, "SLIDE ON YOUR LINE - TAG THEM!")


func test_prompts_follow_the_trip() -> void:
	var screen: PatinteroMatch = _match()
	var sim: PatinteroSim = screen.sim
	var me: PatinteroPlayer = sim.players[PatinteroMatch.LOCAL_ID]
	me.reached_back = true
	assert_eq(PatinteroHud.prompt_for(sim, PatinteroMatch.LOCAL_ID), "NOW RUN BACK HOME!")


func test_the_result_card_shows_who_won() -> void:
	var screen: PatinteroMatch = _match()
	var sim: PatinteroSim = screen.sim
	sim.points = [3, 1]
	sim.winner = PatinteroMatch.LOCAL_TEAM
	sim.phase = PatinteroSim.Phase.MATCH_OVER
	screen.advance(DT)
	assert_true(screen.hud.result_card.visible)
	assert_eq(screen.hud.result_title.text, "YOU WIN!")
	assert_true(screen.hud.result_lines.text.begins_with("YOU 3 - 1 THEM"))
	assert_false(screen.hud.joystick.visible)


func test_the_street_keeps_its_props_but_no_base_markings() -> void:
	var screen: PatinteroMatch = _match()
	var map: StreetMap = screen.get_node("%Map") as StreetMap
	assert_false(map.tag_zones)
	assert_eq(map._posts.size(), 2, "the street keeps its posts")
	assert_true(map._base_materials.is_empty(), "but no base circles or rescue areas")


func test_without_input_you_stay_put() -> void:
	var screen: PatinteroMatch = _match()
	var me: PatinteroPlayer = screen.sim.players[PatinteroMatch.LOCAL_ID]
	var start: Vector2 = me.position
	for i: int in 90:
		screen.advance(DT)
	assert_eq(me.position, start)
