class_name PatinteroMatch
extends Node3D
## The Patintero practice screen (scenes/match/patintero.tscn): you and two bots against three
## bots on the street, your team running first. Runs a local PatinteroSim and draws it: the
## kids, the chalk grid (the taggers' lines in the tagging team's colour, the runners' home
## tinted), a HOME! tag over runners who turned back. Input goes through MatchInput (the stick
## only) like the main match. Reads sim state only; all rules live in scripts/sim/.

const LOCAL_ID: int = 1
const LOCAL_TEAM: int = 0
const ALLY_IDS: Array[int] = [2, 3]
const ENEMY_IDS: Array[int] = [4, 5, 6]
const MAX_STEPS_PER_FRAME: int = 8
const TITLE_SCENE: String = "res://scenes/ui/title_screen.tscn"
const HOME_TINT: Color = Color(0.2, 0.5, 1.0, 0.14)
const FAR_TINT: Color = Color(1.0, 0.85, 0.3, 0.14)
## The taggers' lines are painted thicker, in the tagging team's colour.
const GUARD_LINE_WIDTH: float = 0.26
const TAG_HEIGHT: float = 1.9

@export var rules: GameRules
@export var patintero: PatinteroRules
@export var layout: MapLayout

var sim: PatinteroSim
var input: MatchInput = MatchInput.new()
## id -> the name shown on the result card ("YOU" for the local kid).
var names: Dictionary[int, String] = {}

var _accumulator: float = 0.0
var _views: Dictionary[int, KidModel] = {}
var _home_tags: Dictionary[int, Label3D] = {}
var _characters: Dictionary[StringName, CharacterDef] = {}
## The paint of the guarded lines and the middle line (recoloured when the teams switch).
var _guard_paint: StandardMaterial3D
var _snap_camera: bool = true
## The soft focus beyond the ends of the street (null when off).
var _far_blur: ShaderMaterial

@onready var hud: PatinteroHud = %Hud
@onready var _camera: FollowCamera = %FollowCamera
@onready var _actors: Node3D = %Actors
@onready var _map: StreetMap = %Map
@onready var _audio: MatchAudio = %Audio


func _ready() -> void:
	for character: CharacterDef in rules.characters:
		_characters[character.id] = character
	_setup_sim()
	for id: int in sim.players:
		names[id] = _name_of(id)
		_make_kid(id)
	_build_field()
	_map.show_back_button(false)
	_audio.prepare()
	input.camera_yaw = _camera.rules.yaw_offset_degrees
	_far_blur = StreetGameView.add_camera_finish(self, _camera)
	_connect_hud()
	_connect_sim()
	_views[LOCAL_ID].footstep.connect(func() -> void: _audio.play(&"footstep", 0.15))
	sim.start(LOCAL_TEAM)
	_paint_guard_lines()
	_audio.start_music()
	_sync(0.0)


func _process(delta: float) -> void:
	advance(delta)


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		input.clear()
		if is_node_ready():
			hud.cancel_controls()


# ---- public API (tests and the HUD) -----------------------------------------------

func set_stick(value: Vector2) -> void:
	input.set_stick(value)


## Tests: jump past the opening show straight into play.
func skip_intro() -> void:
	if sim.phase == PatinteroSim.Phase.INTRO:
		sim.phase_left = 0.0
		sim.phase = PatinteroSim.Phase.PLAYING
		sim.intro_finished.emit()


## Runs as many fixed sim ticks as `delta` allows, then updates the visuals.
func advance(delta: float) -> void:
	_accumulator += delta
	var dt: float = rules.tick_dt()
	var steps: int = 0
	while _accumulator >= dt and steps < MAX_STEPS_PER_FRAME:
		sim.set_input(LOCAL_ID, input.build(false, _no_aim, sim.tick))
		sim.step(dt)
		_accumulator -= dt
		steps += 1
	if steps == MAX_STEPS_PER_FRAME:
		_accumulator = 0.0
	_sync(delta)


# ---- setup ---------------------------------------------------------------------------

func _setup_sim() -> void:
	sim = PatinteroSim.new(rules, patintero, layout, Time.get_ticks_usec())
	sim.add_player(LOCAL_ID, LOCAL_TEAM)
	for id: int in ALLY_IDS:
		sim.add_bot(id, LOCAL_TEAM, PatinteroBrain.new())
	for id: int in ENEMY_IDS:
		sim.add_bot(id, 1 - LOCAL_TEAM, PatinteroBrain.new())
	sim.assign_characters(LOCAL_ID, StringName(Session.avatar_id))


func _connect_hud() -> void:
	hud.joystick.changed.connect(set_stick)
	hud.again_pressed.connect(func() -> void: get_tree().reload_current_scene())
	hud.exit_pressed.connect(func() -> void: get_tree().change_scene_to_file(TITLE_SCENE))


func _connect_sim() -> void:
	sim.intro_finished.connect(func() -> void: hud.show_banner("GO!"))
	sim.point_scored.connect(func(id: int, team: int) -> void:
		var ours: bool = team == LOCAL_TEAM
		_audio.play(&"point" if ours else &"lose_point")
		var score: String = "%d-%d" % [sim.points[LOCAL_TEAM], sim.points[1 - LOCAL_TEAM]]
		if id == LOCAL_ID:
			hud.show_banner("YOU SCORED!  %s" % score)
		else:
			hud.show_banner(("POINT!  %s" if ours else "THEY SCORED  %s") % score))
	sim.runner_caught.connect(_on_runner_caught)
	sim.turn_timed_out.connect(func() -> void:
		_audio.play(&"horn")
		hud.show_banner("TIME!\nSWITCH SIDES"))
	sim.sides_switched.connect(func(team: int) -> void:
		hud.joystick.release()
		_snap_camera = true
		_paint_guard_lines()
		hud.show_banner("YOUR TEAM RUNS!" if team == LOCAL_TEAM else "YOUR TEAM TAGS!"))
	sim.match_over.connect(func(winner: int) -> void:
		_audio.play(&"victory" if winner == LOCAL_TEAM else &"defeat")
		MatchHistory.record("patintero", winner == LOCAL_TEAM, sim.points[LOCAL_TEAM], sim.points[1 - LOCAL_TEAM]))


func _on_runner_caught(id: int, by_id: int) -> void:
	_audio.play(&"ko")
	if id == LOCAL_ID:
		_camera.shake(0.25)
	var who: String = "YOU" if id == LOCAL_ID else names[id]
	if by_id == PatinteroSim.OUT_OF_BOUNDS:
		hud.show_banner("OUT OF BOUNDS!\n%s - SWITCH SIDES" % who)
	else:
		hud.show_banner("TAGGED!\n%s - SWITCH SIDES" % who)


func _name_of(id: int) -> String:
	if id == LOCAL_ID:
		return "YOU"
	var character: CharacterDef = _characters.get(sim.players[id].character_id) as CharacterDef
	return character.display_name.to_upper() if character != null else "KID %d" % id


func _make_kid(id: int) -> void:
	var state: PatinteroPlayer = sim.players[id]
	var character: CharacterDef = _characters.get(state.character_id) as CharacterDef
	if character == null:
		character = rules.characters[0]
	var color: Color = Palette.TEAM_ENEMY
	if id == LOCAL_ID:
		color = Palette.TEAM_OWN
	elif state.team == LOCAL_TEAM:
		color = Palette.TEAM_ALLY
	var view: KidModel = KidModel.new()
	view.setup(character, color, rules.player_radius)
	_actors.add_child(view)
	_views[id] = view
	var tag: Label3D = Label3D.new()
	tag.text = "HOME!"
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.no_depth_test = true
	tag.font_size = 56
	tag.outline_size = 14
	tag.modulate = StreetGameHud.GOLD
	tag.pixel_size = 0.006
	tag.visible = false
	add_child(tag)
	_home_tags[id] = tag


## The chalk grid: the runners' home behind the start line (tinted blue), the far end past the
## back line (tinted gold), the side lines, the start and back lines, and the taggers' lines
## (each line across and the middle line, thicker and in the tagging team's colour).
func _build_field() -> void:
	var half: float = patintero.field_half_width
	var street: Rect2 = layout.lane_rect()
	var start: float = patintero.start_line_z
	var back: float = patintero.back_line_z
	Chalk.add_rect(self, Rect2(-half, start, half * 2.0, street.end.y - start), Chalk.material(HOME_TINT), Chalk.HEIGHT - 0.01)
	Chalk.add_rect(self, Rect2(-half, street.position.y, half * 2.0, back - street.position.y), Chalk.material(FAR_TINT), Chalk.HEIGHT - 0.01)
	var chalk: StandardMaterial3D = Chalk.material(Chalk.COLOR)
	for x: float in [-half, half]:
		Chalk.add_line(self, Vector2(x, start), Vector2(x, back), chalk)
	for z: float in [start, back]:
		Chalk.add_line(self, Vector2(-half, z), Vector2(half, z), chalk)
	_guard_paint = Chalk.material(Chalk.COLOR)
	for z: float in patintero.guard_lines:
		Chalk.add_line(self, Vector2(-half, z), Vector2(half, z), _guard_paint, GUARD_LINE_WIDTH)
	Chalk.add_line(self, Vector2(0.0, start), Vector2(0.0, back), _guard_paint, GUARD_LINE_WIDTH)


## The taggers' lines in the tagging team's colour: red when your team runs, blue when it tags.
func _paint_guard_lines() -> void:
	var tagging_is_us: bool = sim.attacking_team != LOCAL_TEAM
	_guard_paint.albedo_color = (Palette.TEAM_OWN if tagging_is_us else Palette.TEAM_ENEMY).lerp(Chalk.COLOR, 0.35)


# ---- drawing -------------------------------------------------------------------------

func _sync(delta: float) -> void:
	for id: int in sim.players:
		var state: PatinteroPlayer = sim.players[id]
		var view: KidModel = _views[id]
		view.position = Vector3(state.position.x, 0.0, state.position.y)
		view.face(state.facing)
		view.animate(delta, minf(view.ground_speed(state.position, delta), 20.0), state)
		var tag: Label3D = _home_tags[id]
		tag.visible = state.role == PatinteroPlayer.Role.RUNNER and state.reached_back and sim.phase == PatinteroSim.Phase.PLAYING
		tag.position = Vector3(state.position.x, TAG_HEIGHT, state.position.y)
	hud.sync(sim, LOCAL_ID, names, delta)
	_camera.follow(sim.players[LOCAL_ID].position, false, 0.0 if _snap_camera else delta)
	StreetGameView.update_far_blur(_far_blur, _camera, layout)
	_snap_camera = false


## Patintero has no aimed buttons: Q / E aim nothing.
func _no_aim(_slot: int) -> Vector2:
	return Vector2.ZERO
