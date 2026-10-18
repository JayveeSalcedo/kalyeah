class_name KidPose
extends SkeletonModifier3D
## Code-made poses layered over a kid's own animation (the rigged GLBs have no pick-up or carry
## clip yet): `pickup` bends the spine forward and reaches both arms down, `carry` holds both
## arms out in front with the hands together, `guard` spreads both arms out to the sides (a
## Patintero tagger on their line), `reach` lunges forward with both arms (a tag). The legs keep
## whatever they were doing. Each is
## a weight from 0 (off) to 1 (full). It runs after the AnimationPlayer every frame, works in the
## model's space (+Y up, +Z the way the kid faces, bones point along their own Y) and finds the
## bones by name, so it fits every kid's rig. View only; a real clip from the owner (Blender) can
## replace it later.

## How far the whole spine bends forward at a full pick-up (radians, shared by the spine bones).
const PICKUP_BEND: float = 0.95
## Where the arms point at a full pick-up (model space, the left arm; the right is mirrored).
const REACH_UPPER: Vector3 = Vector3(0.12, -0.8, 0.58)
const REACH_LOWER: Vector3 = Vector3(0.04, -0.75, 0.66)
## Where the arms point while carrying: upper arms forward and down, forearms in toward the middle.
const CARRY_UPPER: Vector3 = Vector3(0.18, -0.55, 0.82)
const CARRY_LOWER: Vector3 = Vector3(-0.62, 0.12, 0.78)
## A tagger's guard: arms straight out to the sides, a little forward (nearly a T-pose).
const GUARD_UPPER: Vector3 = Vector3(1.0, -0.04, 0.18)
const GUARD_LOWER: Vector3 = Vector3(1.0, 0.04, 0.28)
## A tag: both arms lunge forward and out, the spine leaning in.
const REACH_ARM: Vector3 = Vector3(0.32, -0.08, 0.94)
const REACH_LEAN: float = 0.35

## 0..1: how far into the pick-up bend.
var pickup: float = 0.0
## 0..1: how far into the carry pose.
var carry: float = 0.0
## 0..1: how far into the tagger's arms-out guard.
var guard: float = 0.0
## 0..1: how far into the tag lunge.
var reach: float = 0.0

var _spine: Array[int] = []
## [upper arm, forearm, hand] per side: index 0 left, 1 right.
var _arms: Array[Array] = []


func _ready() -> void:
	_find_bones()


func _skeleton_changed(_old: Skeleton3D, _new: Skeleton3D) -> void:
	_find_bones()


## The point between the two hands (world space), or the skeleton's origin when it has no hands.
func hands_position() -> Vector3:
	var skeleton: Skeleton3D = get_skeleton()
	if skeleton == null or _arms.size() < 2:
		return global_position
	var sum: Vector3 = Vector3.ZERO
	for arm: Array in _arms:
		sum += skeleton.get_bone_global_pose(arm[2] as int).origin
	return skeleton.global_transform * (sum / 2.0)


func _process_modification_with_delta(_delta: float) -> void:
	var skeleton: Skeleton3D = get_skeleton()
	if skeleton == null or (pickup <= 0.0 and carry <= 0.0 and guard <= 0.0 and reach <= 0.0):
		return
	var bend: float = PICKUP_BEND * pickup + REACH_LEAN * reach
	if bend > 0.0 and not _spine.is_empty():
		var step: float = bend / _spine.size()
		for bone: int in _spine:
			_turn(skeleton, bone, Basis(Vector3.RIGHT, step))
	for side: int in _arms.size():
		var arm: Array = _arms[side]
		var mirror: Vector3 = Vector3(1.0 if side == 0 else -1.0, 1.0, 1.0)
		# later poses win over earlier ones: carry, guard, pick-up, then the tag lunge
		if carry > 0.0:
			_aim(skeleton, arm[0] as int, CARRY_UPPER * mirror, carry)
			_aim(skeleton, arm[1] as int, CARRY_LOWER * mirror, carry)
		if guard > 0.0:
			_aim(skeleton, arm[0] as int, GUARD_UPPER * mirror, guard)
			_aim(skeleton, arm[1] as int, GUARD_LOWER * mirror, guard)
		if pickup > 0.0:
			_aim(skeleton, arm[0] as int, REACH_UPPER * mirror, pickup)
			_aim(skeleton, arm[1] as int, REACH_LOWER * mirror, pickup)
		if reach > 0.0:
			_aim(skeleton, arm[0] as int, REACH_ARM * mirror, reach)
			_aim(skeleton, arm[1] as int, REACH_ARM * mirror, reach)


## Turns a bone (and so everything hanging off it) by `turn` in model space, about its own origin.
func _turn(skeleton: Skeleton3D, bone: int, turn: Basis) -> void:
	var pose: Transform3D = skeleton.get_bone_global_pose(bone)
	pose.basis = turn * pose.basis
	skeleton.set_bone_global_pose(bone, pose)


## Swings a bone so it points along `direction` (model space), `weight` of the way there.
func _aim(skeleton: Skeleton3D, bone: int, direction: Vector3, weight: float) -> void:
	var pose: Transform3D = skeleton.get_bone_global_pose(bone)
	var along: Vector3 = pose.basis.y.normalized()
	var swing: Quaternion = Quaternion(along, direction.normalized())
	pose.basis = Basis(Quaternion.IDENTITY.slerp(swing, clampf(weight, 0.0, 1.0))) * pose.basis
	skeleton.set_bone_global_pose(bone, pose)


func _find_bones() -> void:
	_spine.clear()
	_arms.clear()
	var skeleton: Skeleton3D = get_skeleton()
	if skeleton == null:
		return
	for bone: int in skeleton.get_bone_count():
		var bone_name: String = skeleton.get_bone_name(bone)
		if bone_name.begins_with("spine") or bone_name == "chest":
			_spine.append(bone)
	for side: String in ["L", "R"]:
		var bones: Array[int] = []
		for part: String in ["upper_arm.", "forearm.", "hand."]:
			bones.append(skeleton.find_bone(part + side))
		if not bones.has(-1):
			_arms.append(bones)
	if _arms.size() < 2:
		_arms.clear()
