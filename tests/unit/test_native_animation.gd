extends GutTest
## Junjun plays the animation clips of his own 3D model at their own speed (CharacterDef
## .native_animation); the other kids keep the game's pacing. And the practice menu has buttons
## that play the animations a skill hit causes (stunned, airborne, knocked down).

const PRACTICE_SCENE: PackedScene = preload("res://scenes/match/practice.tscn")
const DT: float = 1.0 / 30.0


func _def(id: StringName) -> CharacterDef:
	for def: CharacterDef in (load("res://data/rules/game_rules.tres") as GameRules).characters:
		if def.id == id:
			return def
	return null


func _kid(id: StringName) -> KidModel:
	var kid: KidModel = autofree(KidModel.new()) as KidModel
	kid.setup(_def(id), Palette.TEAM_OWN, 0.4)
	add_child(kid)
	return kid


func _run(kid: KidModel, speed: float) -> void:
	var state: PlayerState = PlayerState.new()
	for i: int in 12:
		kid.animate(DT, speed, state)


func test_only_junjun_is_marked_native() -> void:
	assert_true(_def(&"junjun").native_animation)
	for id: StringName in [&"toni", &"ligaya", &"migo", &"popoy", &"inday"]:
		assert_false(_def(id).native_animation, "%s keeps the game's pacing" % id)


func test_junjun_runs_at_his_own_clip_speed_whatever_the_ground_speed() -> void:
	var kid: KidModel = _kid(&"junjun")
	for speed: float in [2.0, 5.0, 9.0]:
		_run(kid, speed)
		assert_eq(kid.current_animation(), "run")
		assert_almost_eq(kid._player.speed_scale, 1.0, 0.0001, "his run clip plays at its own speed at %.0f m/s" % speed)


func test_the_other_kids_run_is_still_paced_to_the_ground() -> void:
	var kid: KidModel = _kid(&"toni")
	_run(kid, 2.0)
	var slow: float = kid._player.speed_scale
	_run(kid, 7.0)
	assert_gt(kid._player.speed_scale, slow, "the faster they go the faster the cycle")


func test_a_cast_shows_his_clip_at_its_own_speed_and_for_its_own_length() -> void:
	var kid: KidModel = _kid(&"junjun")
	var state: PlayerState = PlayerState.new()
	kid.play_cast(0.38, false)
	kid.animate(DT, 0.0, state)
	assert_eq(kid.pose, "cast")
	assert_almost_eq(kid._player.speed_scale, 1.0, 0.0001, "not squeezed into the 0.38 s cast time")
	assert_almost_eq(kid._cast_total, kid._clip_length("cast"), 0.001, "the cast shows for the clip's own length")
	assert_gt(kid._cast_total, 1.0, "his throw is a real, long clip")
	var toni: KidModel = _kid(&"toni")
	toni.play_cast(0.38, false)
	toni.animate(DT, 0.0, state)
	assert_gt(toni._player.speed_scale, 1.5, "the others are still squeezed into the cast time")


func test_a_spell_starts_at_the_beginning_of_his_clip() -> void:
	var kid: KidModel = _kid(&"junjun")
	assert_eq(kid._clip_start("spell"), 0.0)
	assert_gt(_kid(&"toni")._clip_start("spell"), 0.0, "the others skip their charge-up")


func test_his_footsteps_follow_his_run_clip() -> void:
	var kid: KidModel = _kid(&"junjun")
	var steps: Array[int] = [0]
	kid.footstep.connect(func() -> void: steps[0] += 1)
	var state: PlayerState = PlayerState.new()
	var seconds: float = kid._clip_length("run") * 4.0
	for i: int in int(seconds / DT):
		kid.animate(DT, 6.0, state)
	assert_between(steps[0], 6, 9, "two steps per cycle of his run clip, four cycles")


# ---- the practice menu: play the animations a skill hit causes ---------------------------

func _practice() -> PracticeMatch:
	var practice: PracticeMatch = autofree(PRACTICE_SCENE.instantiate()) as PracticeMatch
	add_child(practice)
	practice.finish_pick()
	practice.skip_intro()
	return practice


func test_the_practice_menu_has_the_hit_animation_buttons() -> void:
	var practice: PracticeMatch = _practice()
	var menu: MatchMenu = practice.hud.menu
	assert_eq(menu.status_buttons.size(), 3)
	for type: int in [StatusEffects.Type.STUN, StatusEffects.Type.AIRBORNE, StatusEffects.Type.KNOCKOUT]:
		assert_true(menu.status_buttons.has(type))
		assert_true(menu.status_buttons[type].visible, "shown in practice")
		assert_gte(menu.status_buttons[type].custom_minimum_size.y, 60.0, "easy to tap")


func test_each_button_plays_its_animation_on_your_kid_and_closes_the_menu() -> void:
	var practice: PracticeMatch = _practice()
	var player: PlayerState = practice.sim.players[PracticeMatch.LOCAL_ID]
	var expect: Dictionary = {
		StatusEffects.Type.STUN: "stunned", StatusEffects.Type.AIRBORNE: "airborne", StatusEffects.Type.KNOCKOUT: "ko",
	}
	for type: int in expect:
		player.effects.clear() if player.effects.has_method("clear") else null
		practice.hud.menu.open()
		practice.hud.menu.status_buttons[type].pressed.emit()
		assert_false(practice.hud.menu.visible, "the menu closes so you can watch")
		assert_true(player.effects.has(type as StatusEffects.Type), "the status is on")
		for i: int in 3:
			practice.advance(DT)
		var view: KidModel = practice._views[PracticeMatch.LOCAL_ID] as KidModel
		assert_eq(view.pose, expect[type], "the kid plays the %s animation" % expect[type])
		for i: int in int(PracticeMatch.STATUS_TEST_TIME * 30.0) + 60:
			practice.advance(DT)
		assert_false(player.effects.has(type as StatusEffects.Type), "it wears off")
