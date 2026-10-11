class_name TiltRules
extends Resource
## How tilting the phone turns into movement (docs/GDD.md "Controls"). Values live
## in data/rules/tilt_rules.tres. Angles are degrees away from the way you held the
## phone when the match started (or when you last re-centred).

## Small wobbles inside this angle do nothing, so holding the phone still is standing still.
@export var deadzone_degrees: float = 0.0
## Full running speed at this angle (a gentle tilt, not a big one).
@export var full_tilt_degrees: float = 0.0
## How fast the movement follows the tilt (1/s); smooths hand shake.
@export var smoothing_rate: float = 0.0
## The player's sensitivity setting scales the tilt by one of these.
@export var sensitivity_steps: Array[float] = []
## Index into sensitivity_steps used until the player changes it.
@export var default_sensitivity: int = 0
