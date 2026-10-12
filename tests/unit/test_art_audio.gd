extends GutTest

var RULES: GameRules = load("res://data/rules/game_rules.tres") as GameRules
const LAYOUT: MapLayout = preload("res://data/rules/map_layout.tres")


func _kid(index: int) -> KidModel:
	var kid: KidModel = autofree(KidModel.new()) as KidModel
	kid.setup(RULES.characters[index], Palette.TEAM_OWN, RULES.player_radius)
	add_child(kid)
	return kid


func test_each_kid_has_their_own_outfit() -> void:
	var seen: Dictionary = {}
	for i: int in RULES.characters.size():
		var def: CharacterDef = RULES.characters[i]
		var key: String = "%d-%d-%d-%d" % [def.hair, def.top, def.bottom, def.extra]
		assert_false(seen.has(key), "%s looks different from the others" % def.display_name)
		seen[key] = true
	var inday: CharacterDef = RULES.characters[5]
	assert_lt(inday.skin.get_luminance(), RULES.characters[1].skin.get_luminance(), "varied Filipino skin tones")


func test_kid_turns_into_a_can_and_greys_out() -> void:
	var kid: KidModel = _kid(0)
	var state: PlayerState = PlayerState.new()
	state.effects.apply(StatusEffects.Type.POLYMORPH, 1.0)
	kid.animate(0.1, 0.0, state)
	assert_true(kid.is_can())
	state.effects.clear()
	state.tagged = true
	kid.animate(0.1, 0.0, state)
	assert_false(kid.is_can())
	assert_true(kid.is_ghost(), "tagged kids wait greyed out in the box")


func test_kid_faces_its_movement() -> void:
	var kid: KidModel = _kid(1)
	kid.face(Vector2(1.0, 0.0))
	var forward: Vector3 = -kid.global_transform.basis.z
	assert_almost_eq(forward.x, 1.0, 0.001)


func test_every_sound_is_built_and_not_silent() -> void:
	for id: StringName in SoundBank.ids():
		var stream: AudioStreamWAV = SoundBank.get_sound(id)
		assert_gt(stream.data.size(), 400, String(id))
		var loudest: int = 0
		for i: int in range(0, stream.data.size(), 64):
			loudest = maxi(loudest, absi(stream.data.decode_s16(i)))
		assert_gt(loudest, 1000, "%s is audible" % id)


func test_music_renders_in_chunks_and_loops() -> void:
	var renderer: SoundBank.MusicRenderer = SoundBank.MusicRenderer.new()
	var chunks: int = 0
	while not renderer.step(20000):
		chunks += 1
	assert_gt(chunks, 3, "built over several frames, not one")
	var stream: AudioStreamWAV = renderer.stream()
	assert_eq(stream.loop_mode, AudioStreamWAV.LOOP_FORWARD)
	assert_almost_eq(float(stream.data.size()) / 2.0 / stream.mix_rate, 8.0 * 4.0 * 60.0 / SoundBank.TEMPO, 0.05)


func test_match_audio_follows_sim_events() -> void:
	var sim: MatchSim = MatchSim.new(RULES, LAYOUT, 1)
	var audio: MatchAudio = autofree(MatchAudio.new()) as MatchAudio
	add_child(audio)
	audio.watch(sim, 0)
	sim.point_scored.emit(0, MatchSim.CaptureKind.BASE)
	sim.point_scored.emit(1, MatchSim.CaptureKind.ALL_TAGGED)
	sim.player_tagged.emit(3)
	sim.player_rescued.emit(3, 4)
	assert_eq(audio.played, [&"point", &"lose_point", &"ko", &"revive"] as Array[StringName])


func test_the_ui_theme_is_applied_everywhere() -> void:
	var button: Button = autofree(Button.new()) as Button
	add_child(button)
	var box: StyleBoxTexture = button.get_theme_stylebox("normal") as StyleBoxTexture
	assert_not_null(box, "every button gets the painted, bevelled style")
	assert_not_null(box.texture)
	assert_eq(box.texture.resource_path, "res://assets/ui/button_orange.png")


func _animation_after(kid: KidModel, state: PlayerState, speed: float = 0.0) -> String:
	kid.animate(0.05, speed, state)
	return kid.current_animation()


func test_each_state_plays_its_own_animation() -> void:
	var kid: KidModel = _kid(2)
	var state: PlayerState = PlayerState.new()
	for i: int in 10:
		kid.animate(0.05, 5.0, state)
	assert_eq(kid.pose, "run")
	assert_eq(kid.current_animation(), "run")
	kid.play_cast()
	assert_eq(_animation_after(kid, state), "cast")
	state = PlayerState.new()
	state.effects.apply(StatusEffects.Type.STUN, 2.0)
	assert_eq(_animation_after(kid, state), "stun", "stars")
	state = PlayerState.new()
	state.effects.apply(StatusEffects.Type.AIRBORNE, 2.0)
	assert_eq(_animation_after(kid, state), "stun", "every status uses the stars")
	state = PlayerState.new()
	state.tagged = true
	assert_eq(_animation_after(kid, state), "idle", "tagged kids stand in the box")


func test_a_knockout_falls_then_lies() -> void:
	var kid: KidModel = _kid(1)
	var state: PlayerState = PlayerState.new()
	state.effects.apply(StatusEffects.Type.KNOCKOUT, 3.0)
	assert_eq(_animation_after(kid, state), "ko_stagger")
	kid.animate(KidModel.KO_FALL_TIME, 0.0, state)
	assert_eq(kid.current_animation(), "ko_lying")
	assert_eq(kid.pose, "ko")
	state.effects.clear()
	assert_eq(_animation_after(kid, state), "idle", "gets back up")


func test_every_weapon_has_its_own_cast_sound() -> void:
	for i: int in RULES.weapons.size():
		var id: StringName = RULES.weapons[i].id
		assert_ne(SoundBank.cast_id(id), &"cast", "%s has a specific cast sound" % id)
		assert_gt(SoundBank.get_sound(SoundBank.cast_id(id)).data.size(), 200)
	assert_eq(SoundBank.cast_id(&"mystery"), &"cast", "unknown weapons fall back")


func test_match_audio_has_sounds_for_casts_heals_effects_and_the_result() -> void:
	var sim: MatchSim = MatchSim.new(RULES, LAYOUT, 1)
	var audio: MatchAudio = autofree(MatchAudio.new()) as MatchAudio
	add_child(audio)
	audio.watch(sim, 0, 1)
	sim.weapon_cast.emit(1, &"lata")
	sim.player_healed.emit(1, 50)
	sim.effect_applied.emit(2, StatusEffects.Type.STUN)
	sim.effect_applied.emit(2, StatusEffects.Type.POLYMORPH)
	sim.player_rescued.emit(1, MatchSim.RELEASED_ALONE)
	sim.player_rescued.emit(2, MatchSim.RELEASED_ALONE)
	sim.match_won.emit(0)
	sim.match_won.emit(1)
	assert_eq(audio.played, [&"cast_lata", &"heal", &"stun", &"poof", &"revive", &"victory", &"defeat"] as Array[StringName], "a dummy walking out alone is quiet")


func test_running_makes_footstep_signals() -> void:
	var kid: KidModel = _kid(0)
	var state: PlayerState = PlayerState.new()
	watch_signals(kid)
	for i: int in 60:
		kid.animate(0.03, 5.0, state)
	# 1.8 s at 5 m/s = 9 m; two footfalls per 1.6 m stride
	assert_between(get_signal_emit_count(kid, "footstep"), 10, 12)


func test_camera_shake_kicks_then_settles() -> void:
	var camera: FollowCamera = autofree(FollowCamera.new()) as FollowCamera
	camera.rules = load("res://data/rules/camera_rules.tres") as CameraRules
	camera.layout = LAYOUT
	add_child(camera)
	camera.shake(0.3)
	camera._process(0.016)
	assert_ne(camera.h_offset, 0.0)
	for i: int in 60:
		camera._process(0.05)
	assert_eq(camera.h_offset, 0.0)


func test_every_skill_has_painted_art() -> void:
	for i: int in RULES.weapons.size():
		var def: WeaponDef = RULES.weapons[i]
		assert_not_null(Icons.art(StringName("btn_" + String(def.id))), String(def.id))
	for id: StringName in [&"gear"]:
		assert_not_null(Icons.art(id), String(id))


func test_a_moving_kid_keeps_running_between_the_30_hz_sim_steps() -> void:
	var kid: KidModel = _kid(0)
	var position: Vector2 = Vector2.ZERO
	var state: PlayerState = PlayerState.new()
	var run_frames: int = 0
	# 60 fps drawing, the sim moves the kid 5 m/s in 1/30 s steps (every other frame)
	for frame: int in 60:
		if frame % 2 == 0:
			position += Vector2(0.0, -5.0 / 30.0)
		var speed: float = kid.ground_speed(position, 1.0 / 60.0)
		kid.animate(1.0 / 60.0, speed, state)
		if frame > 12 and kid.current_animation() == "run":
			run_frames += 1
	assert_eq(run_frames, 47, "run on every drawn frame, never back to idle")
	for frame: int in 20:
		kid.animate(1.0 / 60.0, kid.ground_speed(position, 1.0 / 60.0), state)
	assert_eq(kid.current_animation(), "idle", "standing still again once the movement stops")


func test_every_kid_is_the_same_3d_model_at_one_height() -> void:
	for i: int in RULES.characters.size():
		var kid: KidModel = _kid(i)
		var model: Node3D = kid.find_child("Model", true, false) as Node3D
		assert_not_null(model, RULES.characters[i].display_name)
		var mesh: MeshInstance3D = model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		assert_almost_eq(mesh.get_aabb().size.y * model.scale.y, KidModel.KID_HEIGHT, 0.01, "one kid height")
		assert_null(kid.find_child("Sprite", true, false), "no sprite: a real model")


func test_the_model_has_every_animation_and_loops_only_the_continuous_ones() -> void:
	var player: AnimationPlayer = _kid(0).find_child("AnimationPlayer", true, false) as AnimationPlayer
	for clip: String in ["idle", "run", "cast", "stun", "ko"]:
		assert_true(player.has_animation(clip), clip)
	for clip: String in ["idle", "run", "stun"]:
		assert_eq(player.get_animation(clip).loop_mode, Animation.LOOP_LINEAR, "%s loops" % clip)
	for clip: String in ["cast", "ko"]:
		assert_eq(player.get_animation(clip).loop_mode, Animation.LOOP_NONE, "%s plays once" % clip)


func test_the_model_gets_the_matte_look_and_a_tint() -> void:
	var kid: KidModel = _kid(0)
	var mesh: MeshInstance3D = kid.find_children("*", "MeshInstance3D", true, false).filter(func(n: Node) -> bool: return n.name == "Mesh0")[0] as MeshInstance3D
	var material: StandardMaterial3D = mesh.get_surface_override_material(0) as StandardMaterial3D
	assert_not_null(material)
	assert_eq(material.roughness, 1.0)
	assert_eq(material.metallic, 0.0)
	assert_false(material.normal_enabled)
	assert_eq(material.diffuse_mode, BaseMaterial3D.DIFFUSE_LAMBERT_WRAP)
	assert_true(material.rim_enabled)
	var state: PlayerState = PlayerState.new()
	kid.animate(0.05, 0.0, state)
	assert_almost_eq(material.albedo_color.r, ModelLook.ALBEDO_GAIN, 0.001, "untinted")
	state.tagged = true
	kid.animate(0.05, 0.0, state)
	assert_lt(material.albedo_color.r, ModelLook.ALBEDO_GAIN * 0.6, "greyed out in the box")


func test_the_run_cycle_follows_the_ground_speed() -> void:
	var kid: KidModel = _kid(0)
	var player: AnimationPlayer = kid.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var state: PlayerState = PlayerState.new()
	for i: int in 10:
		kid.animate(0.05, 2.5, state)
	var slow: float = player.speed_scale
	for i: int in 10:
		kid.animate(0.05, 5.0, state)
	assert_gt(player.speed_scale, slow * 1.5, "faster ground speed, faster legs")


func test_a_cast_plays_at_the_cast_time_and_restarts() -> void:
	var kid: KidModel = _kid(0)
	var player: AnimationPlayer = kid.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var state: PlayerState = PlayerState.new()
	kid.play_cast(0.5)
	kid.animate(0.02, 0.0, state)
	assert_eq(player.current_animation, "cast")
	assert_almost_eq(player.speed_scale, player.get_animation("cast").length / 0.5, 0.01)
	kid.animate(0.2, 0.0, state)
	player.advance(0.2)
	var before: float = player.current_animation_position
	assert_gt(before, 0.0)
	kid.play_cast(0.5)
	kid.animate(0.02, 0.0, state)
	assert_lt(player.current_animation_position, before, "a second cast starts over")


func test_a_knockout_tips_the_kid_over_backwards_and_back_up() -> void:
	var kid: KidModel = _kid(1)
	var body: Node3D = kid.find_child("Body", true, false) as Node3D
	var state: PlayerState = PlayerState.new()
	state.effects.apply(StatusEffects.Type.KNOCKOUT, 3.0)
	for i: int in 30:
		kid.animate(0.02, 0.0, state)
	assert_almost_eq(body.rotation.x, PI * 0.5, 0.05, "lying on the back")
	assert_gt(body.position.y, 0.1, "lies on the street, not in it")
	state.effects.clear()
	for i: int in 30:
		kid.animate(0.02, 0.0, state)
	assert_almost_eq(body.rotation.x, 0.0, 0.05, "back on their feet")


func test_stars_circle_the_head_only_while_stunned() -> void:
	var kid: KidModel = _kid(0)
	var stars: Node3D = kid.find_child("Stars", true, false) as Node3D
	var state: PlayerState = PlayerState.new()
	kid.animate(0.05, 0.0, state)
	assert_false(stars.visible)
	state.effects.apply(StatusEffects.Type.STUN, 2.0)
	kid.animate(0.05, 0.0, state)
	assert_true(stars.visible)


func test_the_card_portrait_is_a_picture_of_the_kid() -> void:
	var portrait: Texture2D = KidModel.portrait(&"junjun")
	assert_not_null(portrait)
	assert_gt(portrait.get_size().y, portrait.get_size().x, "a tall portrait, not a wide empty cell")
	assert_eq(KidModel.portrait(&"nobody"), portrait, "kids with no portrait use Junjun's")
