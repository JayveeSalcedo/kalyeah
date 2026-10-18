class_name Cinematic
extends RefCounted
## The cinematic layer of the match view (docs/ART.md "Daylight and depth"): the
## film finish over the picture (vignette and grain, no blur:
## shaders/cinematic.gdshader). View only. (The floating dust motes were removed.)

const SHADER: Shader = preload("res://shaders/cinematic.gdshader")
## Under the HUD (which uses layer 1) and over the 3D view.
const FINISH_LAYER: int = 0


## The wide curve lens goes just under the film finish, over the 3D view and under the HUD.
const LENS_LAYER: int = -1
const LENS_SHADER: Shader = preload("res://shaders/lens_curve.gdshader")


## Bends everything the 3D camera shows (not the HUD) like a wide-angle lens, barrel strength `k`
## (CameraRules.lens_k). Returns its layer, or null when the lens is off.
static func add_lens(parent: Node, k: float) -> CanvasLayer:
	if is_zero_approx(k):
		return null
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "WideCurveLens"
	layer.layer = LENS_LAYER
	var rect: ColorRect = ColorRect.new()
	rect.name = "Lens"
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = LENS_SHADER
	material.set_shader_parameter("k", k)
	rect.material = material
	layer.add_child(rect)
	parent.add_child(layer)
	return layer


## The soft focus for everything beyond the ends of the play area. It sits just over the 3D view
## (and the lens), under the film finish and the HUD. Returns its material (or null when off).
const BLUR_LAYER: int = -1
const BLUR_SHADER: Shader = preload("res://shaders/depth_blur.gdshader")


static func add_depth_blur(parent: Node, radius_px: float, falloff: float, hold: float) -> ShaderMaterial:
	if radius_px <= 0.0:
		return null
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "FarBlur"
	layer.layer = BLUR_LAYER
	var rect: ColorRect = ColorRect.new()
	rect.name = "Blur"
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = BLUR_SHADER
	material.set_shader_parameter("radius_px", radius_px)
	material.set_shader_parameter("falloff", falloff)
	material.set_shader_parameter("hold", hold)
	rect.material = material
	layer.add_child(rect)
	parent.add_child(layer)
	return material


## Adds the film finish over everything `parent` shows; returns its layer.
static func add_film_finish(parent: Node) -> CanvasLayer:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "FilmFinish"
	layer.layer = FINISH_LAYER
	var rect: ColorRect = ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = SHADER
	rect.material = material
	layer.add_child(rect)
	parent.add_child(layer)
	return layer
