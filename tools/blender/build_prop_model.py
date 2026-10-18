"""Makes one of the owner's Meshy prop models light enough for the street (Blender bpy).

usage: python build_prop_model.py -- in.glb out.glb target_triangles texture_px [keep_uv]
 * keep_uv: the owner's own UV layout and base colour image are kept (the image only scaled to
   texture_px) instead of unwrapping and baking again, which is far sharper for detailed models;
   only the mesh is decimated.
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
import bmesh  # noqa: E402 (needs bpy imported first)
from mathutils import Vector

# Welding distance as a fraction of the model's size: the glTF importer splits vertices at every
# UV and normal seam, and decimating that split mesh tears it into open pieces (holes, cracks,
# thousands of open edges). Welding first keeps the surface connected.
WELD = 1e-5


def weld(obj):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=max(obj.dimensions) * WELD)
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()


def open_edges(obj):
    """Edges used by one face only: the holes and cracks of the mesh (after welding)."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=max(obj.dimensions) * WELD)
    count = sum(1 for e in bm.edges if len(e.link_faces) == 1)
    bm.free()
    return count


def bounds(obj):
    pts = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
    return Vector((min(p[i] for p in pts) for i in range(3))), Vector((max(p[i] for p in pts) for i in range(3)))


def base_color_image(obj):
    """The image wired into the model's Base Color (the owner's own texture)."""
    for node in obj.data.materials[0].node_tree.nodes:
        if node.type == "BSDF_PRINCIPLED":
            link = node.inputs["Base Color"].links
            if link and link[0].from_node.type == "TEX_IMAGE":
                return link[0].from_node.image
    raise SystemExit("no base colour image on the model")


def main():
    argv = sys.argv[sys.argv.index("--") + 1:]
    src, out, target, px = argv[0], argv[1], int(argv[2]), int(argv[3])
    keep_uv = len(argv) > 4 and argv[4] == "keep_uv"
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=src, merge_vertices=True)
    # the model proper is the mesh with the most faces (some exports carry a tiny helper mesh first)
    high = max((o for o in bpy.data.objects if o.type == "MESH"), key=lambda o: len(o.data.polygons))
    bpy.context.view_layer.objects.active = high
    high.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    lo, hi = bounds(high)
    high.data.transform(__import__("mathutils").Matrix.Translation(Vector((-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -lo.z))))
    high.data.update()
    high.name = "high"
    source_image = base_color_image(high) if keep_uv else None
    weld(high)
    holes_before = open_edges(high)
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
    mod.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier=mod.name)
    weld(low)
    if not keep_uv:
        for uv in list(low.data.uv_layers):
            low.data.uv_layers.remove(uv)
        low.data.uv_layers.new(name="UVMap")
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.smart_project(angle_limit=1.15, island_margin=0.012)
        bpy.ops.object.mode_set(mode="OBJECT")
    if low.data.has_custom_normals:
        bpy.ops.mesh.customdata_custom_splitnormals_clear()
    for poly in low.data.polygons:
        poly.use_smooth = True

    mat = bpy.data.materials.new("PropMat")
    mat.use_nodes = True
    if keep_uv:
        image = source_image
        image.name = "prop_base_color"
        if image.size[0] != px:
            image.scale(px, px)
        else:
            image.pixels[:] = image.pixels[:]  # a touched image is re-encoded as a JPEG, not copied as the big source PNG
    else:
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
    if keep_uv:
        print("TRIS", sum(len(p.vertices) - 2 for p in low.data.polygons), "of", tris)
        print("OPEN EDGES source", holes_before, "-> game model", open_edges(low))
        bpy.data.objects.remove(high)
        bpy.ops.object.select_all(action="DESELECT")
        low.select_set(True)
        bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", use_selection=True, export_image_format="JPEG",
                                  export_jpeg_quality=78)
        print("EXPORTED", out, os.path.getsize(out))
        return
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 16
    scene.render.bake.use_pass_direct = False
    scene.render.bake.use_pass_indirect = False
    scene.render.bake.use_pass_color = True
    scene.render.bake.use_selected_to_active = True
    scene.render.bake.cage_extrusion = 0.03
    scene.render.bake.max_ray_distance = 0.06
    # fill the gaps round every island with the island's own colour, wide enough for the mip
    # levels the game reads small props at (empty gaps are black and bleed in as dark seams)
    scene.render.bake.margin_type = "EXTEND"
    scene.render.bake.margin = max(8, px // 32)
    bpy.ops.object.select_all(action="DESELECT")
    high.select_set(True)
    low.select_set(True)
    bpy.context.view_layer.objects.active = low
    bpy.ops.object.bake(type="DIFFUSE")
    print("TRIS", sum(len(p.vertices) - 2 for p in low.data.polygons), "of", tris)
    print("OPEN EDGES source", holes_before, "-> game model", open_edges(low))

    bpy.data.objects.remove(high)
    bpy.ops.object.select_all(action="DESELECT")
    low.select_set(True)
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", use_selection=True, export_image_format="JPEG",
                              export_jpeg_quality=88)
    print("EXPORTED", out, os.path.getsize(out))


if __name__ == "__main__":
    main()
