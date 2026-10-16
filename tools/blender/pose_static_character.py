"""Bakes a rigged character into a static, posed mesh (Blender bpy) so it can go through
build_prop_model.py like any other prop (used for the nanay, the street's grown-up).

usage: python pose_static_character.py -- rigged.glb out.glb [arm_down_degrees]
 * the rig is the Meshy "SmartRig" (Bone_023 / Bone_028 are the right / left upper arms of the
   A-pose); both arms are lowered by `arm_down_degrees` (default 28) towards the body;
 * the armature modifier is applied (the pose is baked into the vertices), then the rig and the
   importer's bone-shape sphere are removed and the mesh is exported alone.
The source GLB is the owner's Meshy export and is not stored in the repo.
"""
import math
import sys

import bpy

ARMS = {"Bone_023": 1.0, "Bone_028": -1.0}  # right arm turns one way, left the other


def main():
    argv = sys.argv[sys.argv.index("--") + 1:]
    src, out = argv[0], argv[1]
    down = float(argv[2]) if len(argv) > 2 else 28.0
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=src)
    rig = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    body = max(meshes, key=lambda o: len(o.data.vertices))
    for o in meshes:
        if o is not body:
            bpy.data.objects.remove(o)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="POSE")
    for name, sign in ARMS.items():
        bone = rig.pose.bones[name]
        bone.rotation_mode = "XYZ"
        # the bones' own Z axis swings an arm in towards the hips
        bone.rotation_euler = (0.0, 0.0, math.radians(down) * sign)
    bpy.ops.object.mode_set(mode="OBJECT")
    bpy.context.view_layer.update()
    bpy.context.view_layer.objects.active = body
    body.select_set(True)
    for mod in list(body.modifiers):
        if mod.type == "ARMATURE":
            bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.data.objects.remove(rig)
    body.parent = None
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", use_selection=True, export_image_format="JPEG", export_jpeg_quality=92)
    print("EXPORTED", out)


if __name__ == "__main__":
    main()
