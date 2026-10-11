class_name Scoreboard
extends Control
## Top-right scoreboard pill: your team's points (blue) and theirs (red), with the
## match length in the middle ("BO5" = best of 5). One tier: points only.
## Team-relative: you are always on the left.

const OWN: Color = Color(0.2, 0.5, 1.0)
const ENEMY: Color = Color(1.0, 0.3, 0.3)
const PANEL: Color = Color(0.1, 0.08, 0.14, 0.88)
const RIM: Color = Color(1.0, 0.82, 0.35)
const BIG_FONT: int = 40
const SMALL_FONT: int = 17

var mine: int = 0
var theirs: int = 0
var best_of: int = 3


func show_score(score: MatchScore, my_team: int) -> void:
	var values: Array[int] = [score.points[my_team], score.points[1 - my_team], score.best_of]
	if values != [mine, theirs, best_of]:
		mine = values[0]
		theirs = values[1]
		best_of = values[2]
		queue_redraw()


## Plain-text version (tests, accessibility).
func summary() -> String:
	return "YOU %d - %d THEM   Best of %d" % [mine, theirs, best_of]


func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	var w: float = size.x
	var h: float = size.y
	_round_rect(Rect2(0.0, 4.0, w, h), Color(0, 0, 0, 0.35), 18.0)
	_round_rect(Rect2(0.0, 0.0, w, h), PANEL, 18.0)
	var box: float = h - 12.0
	_round_rect(Rect2(6.0, 6.0, box * 1.25, box), OWN, 12.0)
	_round_rect(Rect2(w - 6.0 - box * 1.25, 6.0, box * 1.25, box), ENEMY, 12.0)
	_center_text(font, str(mine), Vector2(6.0 + box * 0.625, h / 2.0), BIG_FONT, Color.WHITE)
	_center_text(font, str(theirs), Vector2(w - 6.0 - box * 0.625, h / 2.0), BIG_FONT, Color.WHITE)
	_center_text(font, "BO%d" % best_of, Vector2(w / 2.0, h / 2.0), SMALL_FONT + 4, RIM)


func _round_rect(rect: Rect2, color: Color, radius: float) -> void:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(int(radius))
	draw_style_box(box, rect)


func _center_text(font: Font, text: String, center: Vector2, font_size: int, color: Color) -> void:
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var origin: Vector2 = center + Vector2(-text_size.x / 2.0, font_size * 0.35)
	draw_string_outline(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, 6, Icons.OUTLINE)
	draw_string(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)
