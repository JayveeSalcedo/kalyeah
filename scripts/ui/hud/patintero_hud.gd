class_name PatinteroHud
extends StreetGameHud
## The Patintero HUD: the shared street-game pieces (the turn clock counting down, settings,
## stick, prompt, banners, opening title, result card) plus the score card at the top left
## (your team's points and theirs, first to 3) with whose turn it is under it. No buttons: the
## stick is the whole game. The match screen feeds it sim state through `sync()`.

const SCORE_SIZE: Vector2 = Vector2(230.0, 64.0)
const ROLE_SIZE: Vector2 = Vector2(230.0, 40.0)

var score_label: Label
var role_label: Label


## What the kid `id` should do right now, in a few words ("" when nothing to say).
static func prompt_for(sim: PatinteroSim, id: int) -> String:
	if sim.phase != PatinteroSim.Phase.PLAYING:
		return ""
	var state: PatinteroPlayer = sim.players[id]
	match state.role:
		PatinteroPlayer.Role.LINE_GUARD:
			return "SLIDE ON YOUR LINE - TAG THEM!"
		PatinteroPlayer.Role.CENTRE_GUARD:
			return "GUARD THE MIDDLE LINE!"
	if state.reached_back:
		return "NOW RUN BACK HOME!"
	if sim.in_far(state.position):
		return "TURN BACK!"
	return "CROSS THE LINES TO THE END!"


## "YOU 1 - 0 THEM" from the local team's side.
static func score_text(sim: PatinteroSim, local_team: int) -> String:
	return "YOU %d - %d THEM" % [sim.points[local_team], sim.points[1 - local_team]]


## The result card's title for the local team.
static func result_text(sim: PatinteroSim, local_team: int) -> String:
	if sim.winner < 0:
		return "DRAW!"
	return "YOU WIN!" if sim.winner == local_team else "YOU LOSE"


## Each kid's points this match, your team first: "YOU  2".
static func final_lines(sim: PatinteroSim, local_team: int, names: Dictionary[int, String]) -> PackedStringArray:
	var lines: PackedStringArray = [score_text(sim, local_team), ""]
	for team: int in [local_team, 1 - local_team]:
		for id: int in sim.players:
			if sim.players[id].team == team:
				lines.append("%s  %d" % [names.get(id, "?"), sim.players[id].points])
	return lines


func sync(sim: PatinteroSim, local_id: int, names: Dictionary[int, String], delta: float) -> void:
	var local_team: int = sim.players[local_id].team
	set_clock(sim.turn_left)
	score_label.text = score_text(sim, local_team)
	var running: bool = sim.attacking_team == local_team
	role_label.text = "YOUR TEAM RUNS" if running else "YOUR TEAM TAGS"
	role_label.add_theme_color_override("font_color", OWN_COLOR if running else ENEMY_COLOR)
	show_stick(sim.phase == PatinteroSim.Phase.PLAYING)
	set_prompt(prompt_for(sim, local_id), Color.WHITE if running else ENEMY_COLOR)
	show_intro(sim.phase == PatinteroSim.Phase.INTRO)
	if sim.phase == PatinteroSim.Phase.MATCH_OVER:
		show_result(result_text(sim, local_team), final_lines(sim, local_team, names))
	else:
		show_result("")
	tick(delta)


func top_controls() -> Array[Control]:
	return [score_label, role_label]


func _build_game() -> void:
	score_label = _label("YOU 0 - 0 THEM", 28, Vector4(0, 0, 0, 0), Vector4(MARGIN, TOP_Y, MARGIN + SCORE_SIZE.x, TOP_Y + SCORE_SIZE.y))
	score_label.theme_type_variation = &"HudPill"
	var below: float = TOP_Y + SCORE_SIZE.y + 6.0
	role_label = _label("", 20, Vector4(0, 0, 0, 0), Vector4(MARGIN, below, MARGIN + ROLE_SIZE.x, below + ROLE_SIZE.y))
	role_label.theme_type_variation = &"HudPill"


func _build_intro_bar() -> void:
	super._build_intro_bar()
	intro_title.text = "PATINTERO!"
	intro_sub.text = "RUN TO THE END AND BACK  •  DON'T GET TAGGED\nFIRST TO 3"


func _build_result_card() -> void:
	super._build_result_card()
	result_heading.text = "POINTS"
