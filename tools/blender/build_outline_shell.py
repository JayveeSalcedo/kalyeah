"""Builds a smooth outline shell for a prop: a voxel-remeshed, smoothed, light envelope of the
prop's mesh, in the same place and size as the prop GLB, exported as its own GLB (no material).
The game draws it as an inverted hull in a team colour: a shell made from the detailed model
itself breaks up into jagged bits on its decimated surface.

usage: python build_outline_shell.py -- prop.glb out.glb [voxel_size] [target_triangles]
"""
import os
import sys

import bpy


def main():
    argv = sys.argv[sys.argv.index("--") + 1:]
    src, out = argv[0], argv[1]
    voxel = float(argv[2]) if len(argv) > 2 else 0.015
    target = int(argv[3]) if len(argv) > 3 else 1500
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=src)
    mesh = [o for o in bpy.data.objects if o.type == "MESH"][0]
    bpy.context.view_layer.objects.active = mesh
    mesh.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    mesh.data.materials.clear()
    remesh = mesh.modifiers.new("Remesh", "REMESH")
    remesh.mode = "VOXEL"
    remesh.voxel_size = voxel
    remesh.adaptivity = 0.0
    smooth = mesh.modifiers.new("Smooth", "SMOOTH")
    smooth.factor = 0.8
    smooth.iterations = 6
    for mod in list(mesh.modifiers):
        bpy.ops.object.modifier_apply(modifier=mod.name)
    tris = sum(len(p.vertices) - 2 for p in mesh.data.polygons)
    dec = mesh.modifiers.new("Decimate", "DECIMATE")
    dec.ratio = min(1.0, target / max(tris, 1))
    bpy.ops.object.modifier_apply(modifier=dec.name)
    for poly in mesh.data.polygons:
        poly.use_smooth = True
    for uv in list(mesh.data.uv_layers):
        mesh.data.uv_layers.remove(uv)
    mesh.name = "Outline"
    print("TRIS", sum(len(p.vertices) - 2 for p in mesh.data.polygons))
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", use_selection=True, export_materials="NONE")
    print("EXPORTED", out, os.path.getsize(out))


if __name__ == "__main__":
    main()
