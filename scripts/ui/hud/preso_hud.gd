class_name PresoHud
extends StreetGameHud
## The Tumbang Preso HUD: the shared street-game pieces (clock counting down, settings, stick,
## prompt, banners, opening title, result card) plus the tally board on the left (every kid's
## times tagged, best first, the taya marked) and the slipper button at the bottom right (drag
## to aim, release to throw, tap = at the can); the taya has no button. The match screen feeds
## it sim state through `sync()`.

const BOARD_WIDTH: float = 230.0
const BOARD_ROW: float = 40.0
const TAYA_COLOR: Color = StreetGameHud.ENEMY_COLOR

var throw_button: AimButton
var board: VBoxContainer

var _board_text: PackedStringArray = []


## What the kid `id` should do right now, in a few words ("" when nothing to say).
static func prompt_for(sim: PresoSim, id: int) -> String:
	if sim.phase != PresoSim.Phase.PLAYING:
		return ""
	var state: PresoPlayer = sim.players[id]
	if sim.is_taya(id):
		match sim.can_state:
			PresoSim.CanState.DOWN:
				return "PICK UP THE CAN!"
			PresoSim.CanState.CARRIED:
				return "PUT IT BACK IN THE CIRCLE!"
		return "TAG A KID OUTSIDE THE LINE!"
	if state.has_slipper:
		if sim.in_home(state.position):
			return "THROW AT THE CAN!  %d" % ceili(sim.shot_clock_left(id))
		return "BACK BEHIND THE LINE!"
	var slipper: PresoSim.Slipper = sim.slippers.get(id) as PresoSim.Slipper
	if slipper == null or slipper.flying:
		return ""
	if sim.can_state != PresoSim.CanState.STANDING:
		return "THE CAN IS DOWN - GET YOUR SLIPPER!"
	if sim.in_home(state.position):
		return "GET YOUR SLIPPER!  %d" % ceili(sim.home_grace_left(id))
	return "GET YOUR SLIPPER - WATCH THE TAYA!"


## The tally board, best first: "1  YOU  0" with "TAYA" after whoever guards the can now.
static func board_lines(sim: PresoSim, names: Dictionary[int, String]) -> PackedStringArray:
	var lines: PackedStringArray = []
	var place: int = 1
	for id: int in sim.ranking():
		var line: String = "%d  %s  %d" % [place, names.get(id, "?"), sim.players[id].times_tagged]
		if sim.is_taya(id):
			line += "  TAYA"
		lines.append(line)
		place += 1
	return lines


## The result card's title for the local kid: a win for the best place, else the place.
static func result_text(sim: PresoSim, local_id: int) -> String:
	var place: int = sim.ranking().find(local_id) + 1
	return "YOU WIN!" if place == 1 else "#%d OF %d" % [place, sim.players.size()]


func sync(sim: PresoSim, local_id: int, names: Dictionary[int, String], delta: float) -> void:
	set_clock(sim.time_left())
	_sync_board(sim, local_id, names)
	var playing: bool = sim.phase == PresoSim.Phase.PLAYING
	var taya: bool = sim.is_taya(local_id)
	show_stick(playing)
	throw_button.visible = playing and not taya
	throw_button.set_locked(not sim.can_throw(sim.players[local_id]))
	set_prompt(prompt_for(sim, local_id), TAYA_COLOR if taya else Color.WHITE)
	show_intro(sim.phase == PresoSim.Phase.INTRO)
	if sim.phase == PresoSim.Phase.MATCH_OVER:
		show_result(result_text(sim, local_id), board_lines(sim, names))
	else:
		show_result("")
	tick(delta)


func aim_buttons() -> Array[AimButton]:
	return [throw_button]


func top_controls() -> Array[Control]:
	return [board]


func _build_game() -> void:
	board = VBoxContainer.new()
	_place(board, Vector4(0, 0, 0, 0), Vector4(MARGIN, TOP_Y, MARGIN + BOARD_WIDTH, TOP_Y + BOARD_ROW * 6.0))
	board.add_theme_constant_override("separation", 4)
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(board)
	throw_button = AimButton.new()
	throw_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	throw_button.icon_id = &"tsinelas_light"
	throw_button.sub_text = "THROW"
	throw_button.cancel_zone = cancel_zone
	add_child(throw_button)
	_put_button(throw_button)


func _build_intro_bar() -> void:
	super._build_intro_bar()
	intro_title.text = "TUMBANG PRESO!"
	intro_sub.text = "KNOCK THE CAN  •  FETCH YOUR SLIPPER\nFEWEST TAGS WINS"


func _build_result_card() -> void:
	super._build_result_card()
	result_heading.text = "TIMES TAGGED"


func _sync_board(sim: PresoSim, local_id: int, names: Dictionary[int, String]) -> void:
	var lines: PackedStringArray = board_lines(sim, names)
	if lines == _board_text:
		return
	_board_text = lines
	var ids: Array[int] = sim.ranking()
	for child: Node in board.get_children():
		child.queue_free()
	for index: int in lines.size():
		var row: Label = Label.new()
		row.text = lines[index]
		row.theme_type_variation = &"HudPill"
		row.custom_minimum_size = Vector2(0.0, BOARD_ROW)
		row.add_theme_font_size_override("font_size", 22)
		var color: Color = Color.WHITE
		if sim.is_taya(ids[index]):
			color = TAYA_COLOR
		elif ids[index] == local_id:
			color = OWN_COLOR
		row.add_theme_color_override("font_color", color)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		board.add_child(row)
