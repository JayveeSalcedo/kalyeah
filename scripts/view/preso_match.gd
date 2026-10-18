class_name PresoMatch
extends Node3D
## The Tumbang Preso practice screen (scenes/match/preso.tscn): you and three bots on the
## street, one of them the taya. Runs a local PresoSim and draws it: the kids, the chalk
## home line and can circle, the can, the slippers, a TAYA tag over the taya and the throw
## preview. Input goes through MatchInput (stick + weapon 1 = the slipper) like the main
## match. Reads sim state only; all rules live in scripts/sim/.

const LOCAL_ID: int = 1
const BOT_IDS: Array[int] = [2, 3, 4]
const MAX_STEPS_PER_FRAME: int = 8
const TITLE_SCENE: String = "res://scenes/ui/title_screen.tscn"
const HOME_TINT: Color = Color(0.2, 0.5, 1.0, 0.14)
## A flying slipper's arc: it leaves at hand height and peaks this much higher mid-flight.
const SLIPPER_HAND: float = 0.9
const SLIPPER_ARC: float = 1.4
const SLIPPER_SPIN: float = 14.0
const CAN_LIE_HEIGHT: float = 0.18
const CAN_CARRY_HEIGHT: float = 1.15
const TAG_HEIGHT: float = 1.9
const AIM_WIDTH: float = 0.12
## The ring under your own slipper lying on the street, so you can find it.
const MARKER_COLOR: Color = Color(1.0, 0.86, 0.3, 0.9)

@export var rules: GameRules
@export var preso: PresoRules
@export var layout: MapLayout

var sim: PresoSim
var input: MatchInput = MatchInput.new()
## id -> the name shown on the board ("YOU" for the local kid).
var names: Dictionary[int, String] = {}

var _accumulator: float = 0.0
var _views: Dictionary[int, KidModel] = {}
var _slipper_views: Dictionary[int, Node3D] = {}
var _characters: Dictionary[StringName, CharacterDef] = {}
var _can_view: Node3D
var _taya_tag: Label3D
var _aim_line: MeshInstance3D
var _marker: MeshInstance3D
var _snap_camera: bool = true

@onready var hud: PresoHud = %Hud
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
		_make_slipper(id)
	_build_field()
	_map.show_back_button(false)
	_audio.prepare()
	input.camera_yaw = _camera.rules.yaw_offset_degrees
	Cinematic.add_film_finish(self)
	_connect_hud()
	_connect_sim()
	_views[LOCAL_ID].footstep.connect(func() -> void: _audio.play(&"footstep", 0.15))
	sim.start(BOT_IDS[sim.rng.randi_range(0, BOT_IDS.size() - 1)])
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


func aim_started() -> void:
	input.aim_started(0)


## The slipper button was let go with a screen-space `aim` (zero = at the can).
func aim_released(aim: Vector2, cancelled: bool) -> void:
	input.aim_released(LocalInput.to_world(aim, false, input.camera_yaw), cancelled, 0)


## Tests: jump past the opening show straight into play.
func skip_intro() -> void:
	if sim.phase == PresoSim.Phase.INTRO:
		sim.phase_left = 0.0
		sim.phase = PresoSim.Phase.PLAYING
		sim.intro_finished.emit()


## Runs as many fixed sim ticks as `delta` allows, then updates the visuals.
func advance(delta: float) -> void:
	_accumulator += delta
	var dt: float = rules.tick_dt()
	var steps: int = 0
	while _accumulator >= dt and steps < MAX_STEPS_PER_FRAME:
		sim.set_input(LOCAL_ID, input.build(false, _mouse_aim, sim.tick))
		sim.step(dt)
		_accumulator -= dt
		steps += 1
	if steps == MAX_STEPS_PER_FRAME:
		_accumulator = 0.0
	_sync(delta)


# ---- setup ---------------------------------------------------------------------------

func _setup_sim() -> void:
	sim = PresoSim.new(rules, preso, layout, Time.get_ticks_usec())
	sim.add_player(LOCAL_ID)
	for id: int in BOT_IDS:
		sim.add_bot(id, PresoBrain.new())
	sim.assign_characters(LOCAL_ID, StringName(Session.avatar_id))


func _connect_hud() -> void:
	hud.joystick.changed.connect(set_stick)
	hud.throw_button.aim_started.connect(aim_started)
	hud.throw_button.aim_released.connect(aim_released)
	hud.again_pressed.connect(func() -> void: get_tree().reload_current_scene())
	hud.exit_pressed.connect(func() -> void: get_tree().change_scene_to_file(TITLE_SCENE))


func _connect_sim() -> void:
	sim.intro_finished.connect(func() -> void: hud.show_banner("GO!"))
	sim.slipper_thrown.connect(func(id: int) -> void:
		_views[id].play_cast()
		_audio.play(&"cast_tsinelas_light", 0.06))
	sim.slipper_picked_up.connect(func(id: int) -> void:
		if id == LOCAL_ID:
			_audio.play(&"click"))
	sim.can_knocked.connect(func(id: int) -> void:
		_audio.play(&"bonk")
		_camera.shake(0.15)
		hud.show_banner("NICE SHOT!" if id == LOCAL_ID else "%s KNOCKED THE CAN!" % names[id]))
	sim.can_set.connect(func(_id: int) -> void: _audio.play(&"thud"))
	sim.player_tagged.connect(_on_player_tagged)
	sim.taya_changed.connect(func(id: int) -> void:
		hud.joystick.release()
		_snap_camera = true
		hud.show_banner("YOU ARE THE TAYA!" if id == LOCAL_ID else "%s IS THE TAYA" % names[id]))
	sim.match_over.connect(func() -> void:
		var won: bool = sim.ranking()[0] == LOCAL_ID
		_audio.play(&"victory" if won else &"defeat"))


func _on_player_tagged(id: int, by_id: int) -> void:
	_audio.play(&"ko")
	if id == LOCAL_ID:
		_camera.shake(0.25)
	var who: String = "YOU" if id == LOCAL_ID else names[id]
	if by_id == PresoSim.TOO_SLOW:
		hud.show_banner("TOO SLOW!\n%s %s THE TAYA" % [who, "ARE" if id == LOCAL_ID else "IS"])
	else:
		hud.show_banner("TAGGED!\n%s %s THE TAYA" % [who, "ARE" if id == LOCAL_ID else "IS"])


func _name_of(id: int) -> String:
	if id == LOCAL_ID:
		return "YOU"
	var character: CharacterDef = _characters.get(sim.players[id].character_id) as CharacterDef
	return character.display_name.to_upper() if character != null else "KID %d" % id


func _make_kid(id: int) -> void:
	var state: PresoPlayer = sim.players[id]
	var character: CharacterDef = _characters.get(state.character_id) as CharacterDef
	if character == null:
		character = rules.characters[0]
	var view: KidModel = KidModel.new()
	view.setup(character, Palette.TEAM_OWN if id == LOCAL_ID else Palette.TEAM_ALLY, rules.player_radius)
	_actors.add_child(view)
	_views[id] = view


func _make_slipper(id: int) -> void:
	var view: Node3D = WeaponModel.make(&"tsinelas_light", true)
	view.visible = false
	_actors.add_child(view)
	_slipper_views[id] = view


## The chalk on the street (the home line, a faint tint behind it, the can's circle), the can,
## the TAYA tag, the throw preview and the ring under your own slipper.
func _build_field() -> void:
	var street: Rect2 = layout.lane_rect()
	var home: Rect2 = Rect2(street.position.x, preso.throw_line_z, street.size.x, street.end.y - preso.throw_line_z)
	var chalk: StandardMaterial3D = Chalk.material(Chalk.COLOR)
	Chalk.add_rect(self, home, Chalk.material(HOME_TINT), Chalk.HEIGHT - 0.01)
	Chalk.add_line(self, Vector2(street.position.x, preso.throw_line_z), Vector2(street.end.x, preso.throw_line_z), chalk)
	Chalk.add_ring(self, preso.can_spot, preso.can_circle_radius, chalk)
	_can_view = WeaponModel.make(&"lata", false)
	add_child(_can_view)
	_taya_tag = Label3D.new()
	_taya_tag.text = "TAYA"
	_taya_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_taya_tag.no_depth_test = true
	_taya_tag.font_size = 72
	_taya_tag.outline_size = 18
	_taya_tag.modulate = PresoHud.TAYA_COLOR
	_taya_tag.pixel_size = 0.006
	add_child(_taya_tag)
	_aim_line = Chalk.add_rect(self, Rect2(-AIM_WIDTH / 2.0, -0.5, AIM_WIDTH, 1.0), Chalk.material(Color(1.0, 1.0, 1.0, 0.55)), Chalk.HEIGHT + 0.01)
	_aim_line.visible = false
	_marker = Chalk.add_ring(self, Vector2.ZERO, 0.48, Chalk.material(MARKER_COLOR), 0.13)
	_marker.visible = false


# ---- drawing -------------------------------------------------------------------------

func _sync(delta: float) -> void:
	for id: int in sim.players:
		var state: PresoPlayer = sim.players[id]
		var view: KidModel = _views[id]
		view.position = Vector3(state.position.x, 0.0, state.position.y)
		view.face(state.facing)
		view.animate(delta, minf(view.ground_speed(state.position, delta), 20.0), state)
		_sync_slipper(id, delta)
	_sync_can()
	var taya: PresoPlayer = sim.players.get(sim.taya_id) as PresoPlayer
	_taya_tag.visible = taya != null and sim.phase != PresoSim.Phase.TAG_FREEZE
	if taya != null:
		_taya_tag.position = Vector3(taya.position.x, TAG_HEIGHT, taya.position.y)
	_sync_aim()
	hud.sync(sim, LOCAL_ID, names, delta)
	_camera.follow(sim.players[LOCAL_ID].position, false, 0.0 if _snap_camera else delta)
	_snap_camera = false


func _sync_slipper(id: int, delta: float) -> void:
	var view: Node3D = _slipper_views[id]
	var slipper: PresoSim.Slipper = sim.slippers.get(id) as PresoSim.Slipper
	view.visible = slipper != null
	if slipper == null:
		if id == LOCAL_ID:
			_marker.visible = false
		return
	var height: float = 0.05
	if slipper.flying:
		var t: float = clampf(slipper.travelled / preso.slipper_range, 0.0, 1.0)
		height = lerpf(SLIPPER_HAND, 0.05, t) + sin(t * PI) * SLIPPER_ARC
		view.rotation.y += delta * SLIPPER_SPIN
	view.position = Vector3(slipper.position.x, height, slipper.position.y)
	if id == LOCAL_ID:
		_marker.visible = not slipper.flying
		_marker.position = Vector3(slipper.position.x, Chalk.HEIGHT, slipper.position.y)


func _sync_can() -> void:
	var at: Vector3 = Vector3(sim.can_position.x, 0.0, sim.can_position.y)
	match sim.can_state:
		PresoSim.CanState.STANDING:
			_can_view.position = at
			_can_view.rotation = Vector3.ZERO
		PresoSim.CanState.DOWN:
			_can_view.position = at + Vector3.UP * CAN_LIE_HEIGHT
			_can_view.rotation = Vector3(0.0, 0.6, PI / 2.0)
		PresoSim.CanState.CARRIED:
			_can_view.position = at + Vector3.UP * CAN_CARRY_HEIGHT
			_can_view.rotation = Vector3.ZERO


## While you hold the slipper button (or Q) and can throw: a line on the street where it goes.
func _sync_aim() -> void:
	var player: PresoPlayer = sim.players[LOCAL_ID]
	var stick: Vector2
	if input.touch_held[0]:
		stick = LocalInput.to_world(hud.throw_button.aim, false, input.camera_yaw)
	elif input.key_held[0]:
		stick = input.key_aim[0]
	else:
		_aim_line.visible = false
		hud.cancel_zone.visible = false
		return
	hud.cancel_zone.visible = input.touch_held[0]
	_aim_line.visible = sim.can_throw(player)
	if not _aim_line.visible:
		return
	var direction: Vector2 = sim.throw_direction(player, stick)
	var middle: Vector2 = player.position + direction * preso.slipper_range / 2.0
	_aim_line.position = Vector3(middle.x, Chalk.HEIGHT + 0.01, middle.y)
	_aim_line.rotation.y = atan2(direction.x, direction.y)
	_aim_line.scale = Vector3(1.0, 1.0, preso.slipper_range)


## Q held: the mouse on the ground, relative to you, as a stick (the slipper always flies full range).
func _mouse_aim(_slot: int) -> Vector2:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return Vector2.ZERO
	var mouse: Vector2 = viewport.get_mouse_position()
	var hit: Variant = Plane(Vector3.UP, 0.0).intersects_ray(_camera.project_ray_origin(mouse), _camera.project_ray_normal(mouse))
	if hit == null:
		return Vector2.ZERO
	var point: Vector3 = hit as Vector3
	return (Vector2(point.x, point.z) - sim.players[LOCAL_ID].position).normalized()
