class_name GameRules
extends Resource
## Global gameplay numbers (docs/GDD.md "Core"). Values live in
## data/rules/game_rules.tres; nothing here is hardcoded.

@export var tick_rate: int = 0
@export var player_max_hp: int = 0
@export var move_speed: float = 0.0
@export var player_radius: float = 0.0
@export var spawn_spacing: float = 0.0
## Takbo (dash): distance over `dash_duration`, then a stumble where the player can't move or cast.
@export var dash_distance: float = 0.0
@export var dash_duration: float = 0.0
@export var dash_stumble: float = 0.0
@export var dash_cooldown: float = 0.0
## Bookmark: leave a mark, blink forward, get a speed bonus; when the boost ends the player returns to the mark.
@export var bookmark_blink: float = 0.0
@export var bookmark_speed_bonus: float = 0.0
@export var bookmark_boost_duration: float = 0.0
@export var bookmark_cooldown: float = 0.0
## Data toggle: return to the mark when the boost ends (GDD D7 default).
@export var bookmark_returns: bool = false
## Pin: after the short blink the player tumbles (can't move or cast) this long.
@export var bookmark_tumble: float = 0.0
## Tag: at 0 HP a player is sent to their team's box. A free teammate stepping into
## the box rescues everyone waiting there (data toggle: off = one per touch).
@export var rescue_frees_all: bool = true
## Practice: a tagged training dummy walks out of the box on its own after this long.
@export var dummy_release_time: float = 0.0
## Every weapon in the game (docs/GDD.md "Weapons"); each player equips two different ones.
@export var weapons: Array[WeaponDef] = []
## The six cosmetic characters, assigned at random with no duplicates.
@export var characters: Array[CharacterDef] = []
## Weapon pick time (match start).
@export var weapon_pick_time: float = 0.0
## POLYMORPH: walk at this fraction of normal speed (no casting).
@export var polymorph_speed_scale: float = 0.0
## Aim stick shorter than this counts as "no aim" and the weapon auto-aims.
@export var aim_deadzone: float = 0.0
## A returning boomerang is caught when this close to its thrower.
@export var boomerang_catch_distance: float = 0.0
## Scoring: a capture (the whole team in the enemy base, or every enemy tagged) has
## to hold this long to win the point.
@export var capture_time: float = 0.0
## Freeze after a point before everyone is reset to their posts.
@export var point_freeze_time: float = 0.0
## A set is won at `set_points_to_win` with a lead of `set_win_by`, or at `set_point_cap`.
@export var set_points_to_win: int = 0
@export var set_win_by: int = 0
@export var set_point_cap: int = 0
## Sets needed to win the match (1 = the first set decides it).
@export var match_sets_to_win: int = 0
## Practice-mode training dummies (two enemies and one ally).
@export var dummy_z: float = 0.0
@export var dummy_stand_x: float = 0.0
@export var dummy_patrol_x: float = 0.0
@export var dummy_patrol_range: float = 0.0
@export var dummy_patrol_speed_scale: float = 0.0
@export var dummy_ally_x: float = 0.0
@export var dummy_ally_z: float = 0.0


## Fixed simulation step in seconds (1 / tick_rate).
func tick_dt() -> float:
	return 1.0 / tick_rate
