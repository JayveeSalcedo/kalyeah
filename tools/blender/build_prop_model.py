"""Makes one of the owner's Meshy prop models light enough for the street (Blender bpy).

usage: python build_prop_model.py -- in.glb out.glb target_triangles texture_px
 * the model is moved so its base centre sits on the origin (x, y centred, bottom at z = 0),
   everything else (size, proportions) is left as modelled: the game scales it to fit;
 * the mesh is decimated to ~target_triangles with new UVs, and the base colour is baked from the
   full model onto one texture_px square image (no normal / metal-roughness maps: the game
   lights props matte);
 * exported as a GLB with one matte material.
The source GLBs are the owner's Meshy exports and are not stored in the repo.
"""
import os
import sys

import bpy
from mathutils import Vector


def bounds(obj):
    pts = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
    return Vector((min(p[i] for p in pts) for i in range(3))), Vector((max(p[i] for p in pts) for i in range(3)))


def main():
    argv = sys.argv[sys.argv.index("--") + 1:]
    src, out, target, px = argv[0], argv[1], int(argv[2]), int(argv[3])
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=src)
    high = [o for o in bpy.data.objects if o.type == "MESH"][0]
    bpy.context.view_layer.objects.active = high
    high.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    lo, hi = bounds(high)
    high.data.transform(__import__("mathutils").Matrix.Translation(Vector((-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -lo.z))))
    high.data.update()
    high.name = "high"
    tris = sum(len(p.vertices) - 2 for p in high.data.polygons)

    low = high.copy()
    low.data = high.data.copy()
    low.name = "Mesh0"
    bpy.context.scene.collection.objects.link(low)
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = low
    low.select_set(True)
    mod = low.modifiers.new("Decimate", "DECIMATE")
    mod.ratio = min(1.0, target / tris)
    bpy.ops.object.modifier_apply(modifier=mod.name)
    for uv in list(low.data.uv_layers):
        low.data.uv_layers.remove(uv)
    low.data.uv_layers.new(name="UVMap")
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=1.15, island_margin=0.006)
    bpy.ops.object.mode_set(mode="OBJECT")
    if low.data.has_custom_normals:
        bpy.ops.mesh.customdata_custom_splitnormals_clear()
    for poly in low.data.polygons:
        poly.use_smooth = True

    mat = bpy.data.materials.new("PropMat")
    mat.use_nodes = True
    image = bpy.data.images.new("prop_base_color", px, px)
    tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = image
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 1.0
    bsdf.inputs["Metallic"].default_value = 0.0
    mat.node_tree.nodes.active = tex
    low.data.materials.clear()
    low.data.materials.append(mat)

    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 16
    scene.render.bake.use_pass_direct = False
    scene.render.bake.use_pass_indirect = False
    scene.render.bake.use_pass_color = True
    scene.render.bake.use_selected_to_active = True
    scene.render.bake.cage_extrusion = 0.03
    scene.render.bake.max_ray_distance = 0.06
    scene.render.bake.margin = 6
    bpy.ops.object.select_all(action="DESELECT")
    high.select_set(True)
    low.select_set(True)
    bpy.context.view_layer.objects.active = low
    bpy.ops.object.bake(type="DIFFUSE")
    print("TRIS", sum(len(p.vertices) - 2 for p in low.data.polygons), "of", tris)

    bpy.data.objects.remove(high)
    bpy.ops.object.select_all(action="DESELECT")
    low.select_set(True)
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", use_selection=True, export_image_format="JPEG",
                              export_jpeg_quality=88)
    print("EXPORTED", out, os.path.getsize(out))


if __name__ == "__main__":
    main()
