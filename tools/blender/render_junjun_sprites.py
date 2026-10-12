"""Renders Junjun's game sprites from the rigged 3D boy (Meshy model, Mixamo skeleton).

Same files and cells as tools/sprites/slice_sheets.py makes: 7 poses x 5 directions
(toward, toward_right, right, away_right, away; the left side is mirrored in game),
transparent PNGs on one fixed canvas so every pose has the same pixels-per-metre.

usage: python render_junjun_sprites.py -- model.glb out_dir [pose,pose,...]
The model (not stored in the repo) is the owner's Meshy GLB with its Mixamo skeleton.
Poses reuse the throw rig code (throw_boy.py): spine twists only about the vertical,
feet are IK-planted, arms follow the torso.
"""
import math
import os
import sys

import bpy
import bmesh
from mathutils import Euler, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import throw_boy as T  # noqa: E402

DIRS = [("toward", 0), ("toward_right", 45), ("right", 90), ("away_right", 135), ("away", 180)]
W, H = 640, 560
PX_PER_M = 252.0
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
    "run": dict(
        key=pose(hips=(0, -0.03, -0.05), hyaw=-9, cyaw=11, lean=14, hy=0, hp=-4, sr=(-6, 0), sl=(8, 0),
                 arm_r=(-0.2, 0.7, -0.7), fore_r=(-0.2, -0.3, -0.9), hand_r=(-0.2, -0.4, -0.85),
                 arm_l=(0.25, -0.65, -0.7), fore_l=(0.15, -0.5, 0.75), hand_l=(0.15, -0.55, 0.65),
                 foot_l=(0.13, 0.26, 0.24), foot_r=(-0.13, -0.3, 0.03)),
        rot=(0, 0), lift=0.0, target=0.92),
    "cast": dict(key=None, rot=(0, 0), lift=0.0, target=0.78),  # the throw's release pose
    "stun": dict(
        key=pose(hips=(0, 0, -0.1), lean=6, hyaw=4, cyaw=-6, hp=10, hy=-6, sr=(0, -3), sl=(0, -3),
                 arm_r=(-0.62, -0.1, -0.78), fore_r=(-0.55, -0.25, -0.8), hand_r=(-0.5, -0.3, -0.8),
                 arm_l=(0.62, -0.1, -0.78), fore_l=(0.55, -0.25, -0.8), hand_l=(0.5, -0.3, -0.8),
                 foot_l=(0.2, 0.0, 0.0), foot_r=(-0.2, 0.05, 0.0)),
        rot=(0, 0), lift=0.0, target=0.92, stars=True),
    "down": dict(  # face down
        key=pose(arm_r=(-0.7, -0.1, -0.7), fore_r=(-0.7, 0.0, -0.7), hand_r=(-0.7, 0.0, -0.7),
                 arm_l=(0.7, -0.1, -0.7), fore_l=(0.7, 0.0, -0.7), hand_l=(0.7, 0.0, -0.7),
                 foot_l=(0.14, 0.0, 0.0), foot_r=(-0.14, 0.0, 0.0)),
        rot=(90, 0), lift=0.14, target=0.2, shift=0.95),
    "ko_stagger": dict(  # falling backwards, arms flung up
        key=pose(hips=(0, 0.1, -0.05), lean=-16, hp=-8, sr=(0, 8), sl=(0, 8),
                 arm_r=(-0.75, 0.1, 0.65), fore_r=(-0.7, 0.2, 0.7), hand_r=(-0.7, 0.2, 0.7),
                 arm_l=(0.75, 0.1, 0.65), fore_l=(0.7, 0.2, 0.7), hand_l=(0.7, 0.2, 0.7),
                 foot_l=(0.15, -0.25, 0.1), foot_r=(-0.15, 0.1, 0.32)),
        rot=(-24, 0), lift=0.12, target=0.88),
    "ko_lying": dict(  # on the back
        key=pose(arm_r=(-0.9, 0.0, -0.3), fore_r=(-0.9, 0.0, -0.3), hand_r=(-0.9, 0.0, -0.3),
                 arm_l=(0.9, 0.0, -0.3), fore_l=(0.9, 0.0, -0.3), hand_l=(0.9, 0.0, -0.3),
                 foot_l=(0.2, 0.0, 0.0), foot_r=(-0.2, 0.0, 0.0)),
        rot=(-90, 0), lift=0.14, target=0.2, shift=-0.95),
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


def make_stars(pivot):
    stars = []
    mat = bpy.data.materials.new("Star")
    mat.use_nodes = True
    p = mat.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = (1.0, 0.62, 0.0, 1)
    p.inputs["Roughness"].default_value = 0.8
    p.inputs["Emission Color"].default_value = (1.0, 0.55, 0.0, 1)
    p.inputs["Emission Strength"].default_value = 0.7
    for i in range(5):
        bm = bmesh.new()
        bmesh.ops.create_icosphere(bm, subdivisions=1, radius=0.11)
        mesh = bpy.data.meshes.new("Star")
        bm.to_mesh(mesh)
        bm.free()
        mesh.materials.append(mat)
        obj = bpy.data.objects.new("Star", mesh)
        a = i / 5 * math.tau
        obj.location = (math.cos(a) * 0.28, math.sin(a) * 0.28, 1.74)
        obj.scale = (1.0, 1.0, 0.45)
        obj.parent = pivot
        bpy.context.scene.collection.objects.link(obj)
        stars.append(obj)
    return stars


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


def main():
    argv = sys.argv[sys.argv.index("--") + 1:]
    src, out_dir = argv[0], argv[1]
    wanted = argv[2].split(",") if len(argv) > 2 else list(POSES)
    os.makedirs(out_dir, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=src)
    ico = bpy.data.objects.get("Icosphere")
    if ico:
        bpy.data.objects.remove(ico)
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
    stars = make_stars(pivot)
    release = dict(T.KEYS)[24]
    for name in wanted:
        spec = POSES[name]
        key = spec["key"] or release
        T.KEYS = [(1, key), (2, key)]
        T.pose_frame(rig, rest, 1)
        scene.frame_set(1)
        rig.rotation_mode = "XYZ"
        rig.rotation_euler = (math.radians(spec["rot"][0]), 0, 0)
        rig.location = (0, spec.get("shift", 0.0), spec["lift"])
        for s in stars:
            s.hide_render = not spec.get("stars")
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
