"""Renders a kid's HUD portrait (transparent PNG, standing, facing the camera) from a rigged
3D kid, with the same soft three-light look as the game.

usage: python render_portrait.py -- model.glb out_dir [portrait.png]
Writes out_dir/idle_toward.png; with a third argument it also crops it to the kid and saves it
there (assets/portraits/<kid>.png). Works with the Meshy boy (Mixamo skeleton, posed here) and
with the rigged kids that carry their own clips (posed from the first frame of scratch_head,
a relaxed stand). The models are the owner's and are not stored in the repo.
"""
import math
import os
import sys

import bpy
from mathutils import Euler, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import throw_boy as T  # noqa: E402

DIRS = [("toward", 0)]
W, H = 720, 1000
PX_PER_M = 480.0
PITCH = 30.0  # degrees above the horizon, a little under the game camera so faces stay readable

BASE = dict(hips=(0, 0, 0), hyaw=0, cyaw=0, lean=0, hy=0, hp=0, sr=(0, 0), sl=(0, 0))


def pose(**kw):
    d = dict(BASE)
    d.update(kw)
    return d


POSES = {
    "idle": dict(
        key=pose(hips=(0, 0, -0.01), lean=2,
                 arm_r=(-0.25, -0.05, -1), fore_r=(-0.12, -0.35, -0.93), hand_r=(-0.1, -0.35, -0.93),
                 arm_l=(0.25, -0.05, -1), fore_l=(0.12, -0.35, -0.93), hand_l=(0.1, -0.35, -0.93),
                 foot_l=(0.13, 0.0, 0.0), foot_r=(-0.13, 0.0, 0.0)),
        rot=(0, 0), lift=0.0, target=0.92),
}


def tame_materials():
    """Matte, no gloss: the game wants soft painted surfaces."""
    for mat in bpy.data.materials:
        if not mat.use_nodes:
            continue
        for node in mat.node_tree.nodes:
            if node.type != "BSDF_PRINCIPLED":
                continue
            for name in ("Metallic", "Roughness"):
                for link in list(node.inputs[name].links):
                    mat.node_tree.links.remove(link)
            node.inputs["Metallic"].default_value = 0.0
            node.inputs["Roughness"].default_value = 0.9
            node.inputs["Specular IOR Level"].default_value = 0.1
            node.inputs["Coat Weight"].default_value = 0.0


def setup_scene():
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 40
    scene.cycles.use_denoising = True
    scene.render.film_transparent = True
    scene.render.resolution_x, scene.render.resolution_y = W, H
    scene.render.image_settings.color_mode = "RGBA"
    world = bpy.data.worlds.new("W")
    scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (0.82, 0.86, 0.95, 1)  # soft sky bounce
    bg.inputs["Strength"].default_value = 0.55

    def sun(name, energy, rot, color):
        light = bpy.data.lights.new(name, "SUN")
        light.energy = energy
        light.color = color
        light.angle = math.radians(14)  # soft shadows
        obj = bpy.data.objects.new(name, light)
        obj.rotation_euler = Euler([math.radians(a) for a in rot])
        scene.collection.objects.link(obj)

    sun("Key", 2.6, (52, 0, -32), (1.0, 0.95, 0.86))   # warm, from the front left, above
    sun("Fill", 0.9, (65, 0, 40), (0.85, 0.9, 1.0))    # cool, from the right
    sun("Rim", 1.3, (60, 0, 160), (1.0, 0.97, 0.92))   # from behind, to lift the outline
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = W / PX_PER_M
    scene.collection.objects.link(cam)
    scene.camera = cam
    return scene, cam


RELAXED_CLIP = "scratch_head"  # its first frame is a relaxed stand, arms down
CROP_MARGIN = 12


def crop_to_kid(src, dst):
    """Trim the transparent border around the kid (a small margin kept)."""
    from PIL import Image
    image = Image.open(src)
    left, top, right, bottom = image.getbbox()
    box = (max(0, left - CROP_MARGIN), max(0, top - CROP_MARGIN),
           min(image.width, right + CROP_MARGIN), min(image.height, bottom + CROP_MARGIN))
    image.crop(box).save(dst)


def render_rigged_kid(argv):
    """A rigged kid with its own clips: pose it from the relaxed clip and render it standing."""
    out_dir = argv[1]
    rig = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    for owner in [rig] + [o.data.shape_keys for o in bpy.data.objects if o.type == "MESH" and o.data.shape_keys]:
        if owner.animation_data:
            for track in owner.animation_data.nla_tracks:
                track.mute = True
    for action in bpy.data.actions:
        if action.name.startswith(RELAXED_CLIP):
            slot = next((sl for sl in action.slots if sl.target_id_type == "OBJECT"), None)
            if slot is not None:
                rig.animation_data_create()
                rig.animation_data.action = action
                rig.animation_data.action_slot = slot
    tame_materials()
    scene, cam = setup_scene()
    scene.frame_set(0)
    spec = POSES["idle"]
    pitch = math.radians(PITCH)
    target = Vector((0, 0, spec["target"]))
    cam.location = target + Vector((0, -math.cos(pitch), math.sin(pitch))) * 8.0
    cam.rotation_euler = (math.radians(90) - pitch, 0, 0)
    out = os.path.join(out_dir, "idle_toward.png")
    scene.render.filepath = out
    bpy.ops.render.render(write_still=True)
    if len(argv) > 2:
        crop_to_kid(out, argv[2])


def main():
    argv = sys.argv[sys.argv.index("--") + 1:]
    src, out_dir = argv[0], argv[1]
    wanted = ["idle"]
    os.makedirs(out_dir, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=src)
    ico = bpy.data.objects.get("Icosphere")
    if ico:
        bpy.data.objects.remove(ico)
    if "target_character" not in bpy.data.objects:
        render_rigged_kid(argv)
        return
    rig = bpy.data.objects["target_character"]
    rig.animation_data_create()
    rig.animation_data.action = bpy.data.actions.new("Pose")
    rest = {}
    for b in rig.data.bones:
        n = b.name.replace(T.P, "")
        rest[n] = {"rot": b.matrix_local.to_3x3(), "head": b.head_local.copy(), "len": b.length,
                   "dir": (b.tail_local - b.head_local).normalized()}
    tame_materials()
    scene, cam = setup_scene()
    pivot = bpy.data.objects.new("Pivot", None)
    scene.collection.objects.link(pivot)
    rig.parent = pivot
    for name in wanted:
        spec = POSES[name]
        key = spec["key"]
        T.KEYS = [(1, key), (2, key)]
        T.pose_frame(rig, rest, 1)
        scene.frame_set(1)
        rig.rotation_mode = "XYZ"
        rig.rotation_euler = (math.radians(spec["rot"][0]), 0, 0)
        rig.location = (0, spec.get("shift", 0.0), spec["lift"])
        for dname, yaw in DIRS:
            pivot.rotation_euler = (0, 0, math.radians(yaw))
            pitch = math.radians(PITCH)
            target = Vector((0, 0, spec["target"]))
            cam.location = target + Vector((0, -math.cos(pitch), math.sin(pitch))) * 8.0
            cam.rotation_euler = (math.radians(90) - pitch, 0, 0)
            scene.render.filepath = os.path.join(out_dir, f"{name}_{dname}.png")
            bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    main()
