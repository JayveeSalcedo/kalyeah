class_name MatchScore
extends RefCounted
## One-tier scoring (docs/GDD.md "Scoring"): every capture is one point and the
## match is best of 3, 5 or 7 (the host picks it in the lobby): the first team to
## win more than half of them wins. Plain data; MatchSim decides when a point happens.

enum Result { POINT, MATCH }

## Points per team (0, 1). Kept as-is when the match ends.
var points: Array[int] = [0, 0]
## How many points the match is "best of" (3, 5 or 7).
var best_of: int = 3
## Team that won the match, or -1.
var winner: int = -1


func _init(p_best_of: int) -> void:
	best_of = p_best_of


## Points a team needs: a majority of `best_of` (2 of 3, 3 of 5, 4 of 7).
func points_to_win() -> int:
	return best_of / 2 + 1


func award_point(team: int) -> Result:
	if winner >= 0:
		return Result.MATCH
	points[team] += 1
	if points[team] >= points_to_win():
		winner = team
		return Result.MATCH
	return Result.POINT
