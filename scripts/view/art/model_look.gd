class_name ModelLook
extends RefCounted
## The soft, matte look every imported 3D model gets (the same recipe the owner approved on
## the first Junjun model): no gloss, no normal map, light wrapping round the body, a gentle
## rim so the outline lifts off the street, and the albedo pulled down a little because the
## game's sun and sky are bright and the painted textures wash out otherwise.

## Multiplies the texture colour (0.8 still washed out, 0.5 went muddy).
const ALBEDO_GAIN: float = 0.65
const SPECULAR: float = 0.15
const RIM: float = 0.2
const RIM_TINT: float = 0.3


## Gives every surface of every mesh under `root` its own copy of the look and returns them
## (so a tint can be applied per kid).
static func apply(root: Node, gain: float = ALBEDO_GAIN) -> Array[StandardMaterial3D]:
	var made: Array[StandardMaterial3D] = []
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		for surface: int in mesh_instance.mesh.get_surface_count():
			var source: Material = mesh_instance.get_active_material(surface)
			var material: StandardMaterial3D = StandardMaterial3D.new()
			if source is BaseMaterial3D:
				var base: BaseMaterial3D = source as BaseMaterial3D
				material.albedo_texture = base.albedo_texture
				material.albedo_color = base.albedo_color
			material.metallic = 0.0
			material.roughness = 1.0
			material.metallic_specular = SPECULAR
			material.normal_enabled = false
			material.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
			material.rim_enabled = true
			material.rim = RIM
			material.rim_tint = RIM_TINT
			material.albedo_color = Color(gain, gain, gain) * material.albedo_color
			mesh_instance.set_surface_override_material(surface, material)
			made.append(material)
	return made


## The colour a tint multiplies the lit albedo by.
static func tinted(tint: Color) -> Color:
	return Color(ALBEDO_GAIN * tint.r, ALBEDO_GAIN * tint.g, ALBEDO_GAIN * tint.b)
