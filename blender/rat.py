"""Builds the Rat enemy model and exports it as FBX for Roblox.

Run with Blender's Python (bpy):
    python blender/rat.py [output_dir]

Body parts are separate objects so the game can move them (legs walk,
tail wags, head bites). The game finds them by name:
    Body, Head, Nose, Eyes, Ears, Tail, LegFL, LegFR, LegBL, LegBR
Colors are set in the game by name, so no textures are needed.
"""

import math
import os
import sys

import bpy

OUT_DIR = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "out")
os.makedirs(OUT_DIR, exist_ok=True)

COLORS = {
    "Fur": (0.30, 0.25, 0.22, 1),
    "Pink": (0.86, 0.56, 0.56, 1),
    "Eye": (0.02, 0.02, 0.02, 1),
}

_materials = {}


def material(kind):
    if kind not in _materials:
        mat = bpy.data.materials.new(kind)
        mat.diffuse_color = COLORS[kind]
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        bsdf.inputs["Base Color"].default_value = COLORS[kind]
        bsdf.inputs["Roughness"].default_value = 0.3 if kind == "Eye" else 0.85
        _materials[kind] = mat
    return _materials[kind]


def sphere(radius, loc, scale=(1, 1, 1), segments=16, rings=10):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, radius=radius, location=loc)
    obj = bpy.context.active_object
    obj.scale = scale
    return obj


def cylinder(radius, depth, loc, rot=(0, 0, 0), verts=8, top_radius=None):
    if top_radius is None:
        bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=depth, location=loc, rotation=rot)
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=radius, radius2=top_radius, depth=depth, location=loc, rotation=rot)
    return bpy.context.active_object


def finish(objs, name, kind):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    if len(objs) > 1:
        bpy.ops.object.join()
    obj = bpy.context.active_object
    obj.name = name
    obj.data.name = name
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    bpy.ops.object.shade_flat()
    obj.data.materials.clear()
    obj.data.materials.append(material(kind))
    return obj


def tail():
    """A curved, tapering tail made from a bevelled curve."""
    curve = bpy.data.curves.new("TailCurve", type="CURVE")
    curve.dimensions = "3D"
    curve.bevel_depth = 0.09
    curve.bevel_resolution = 2
    curve.resolution_u = 8
    spline = curve.splines.new("BEZIER")
    points = [((0, 0.85, 0.62), 1.0), ((0, 1.55, 0.35), 0.7), ((0.25, 2.3, 0.5), 0.35), ((0.15, 2.8, 0.8), 0.1)]
    spline.bezier_points.add(len(points) - 1)
    for bp, (co, radius) in zip(spline.bezier_points, points):
        bp.co = co
        bp.radius = radius
        bp.handle_left_type = bp.handle_right_type = "AUTO"
    obj = bpy.data.objects.new("Tail", curve)
    bpy.context.collection.objects.link(obj)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.convert(target="MESH")
    return bpy.context.active_object


def build():
    # The rat faces -Y. Sizes are rough; the game rescales it.
    body = sphere(1, (0, 0, 0.78), scale=(0.58, 0.98, 0.52))
    rump = sphere(1, (0, 0.45, 0.72), scale=(0.62, 0.6, 0.5))
    finish([body, rump], "Body", "Fur")

    head = sphere(1, (0, -1.0, 0.88), scale=(0.44, 0.52, 0.42))
    snout = cylinder(0.3, 0.6, (0, -1.5, 0.8), rot=(math.radians(90), 0, 0), verts=10, top_radius=0.08)
    finish([head, snout], "Head", "Fur")

    finish([sphere(0.1, (0, -1.8, 0.8), segments=8, rings=6)], "Nose", "Pink")
    finish(
        [sphere(0.12, (0.3, -1.3, 1.06), segments=10, rings=8), sphere(0.12, (-0.3, -1.3, 1.06), segments=10, rings=8)],
        "Eyes",
        "Eye",
    )
    finish(
        [sphere(0.24, (0.3, -0.85, 1.28), scale=(1, 0.35, 1), segments=10, rings=6),
         sphere(0.24, (-0.3, -0.85, 1.28), scale=(1, 0.35, 1), segments=10, rings=6)],
        "Ears",
        "Pink",
    )
    finish([tail()], "Tail", "Pink")

    for name, x, y in [("LegFL", -0.36, -0.5), ("LegFR", 0.36, -0.5), ("LegBL", -0.4, 0.55), ("LegBR", 0.4, 0.55)]:
        leg = cylinder(0.13, 0.5, (x, y, 0.25), verts=8)
        foot = sphere(0.15, (x, y - 0.06, 0.04), scale=(1, 1.4, 0.5), segments=8, rings=5)
        finish([leg, foot], name, "Fur")


def tri_count():
    return sum(
        sum(len(p.vertices) - 2 for p in o.data.polygons) for o in bpy.data.objects if o.type == "MESH"
    )


def export():
    path = os.path.join(OUT_DIR, "Rat.fbx")
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.fbx(
        filepath=path,
        use_selection=True,
        object_types={"MESH"},
        apply_scale_options="FBX_SCALE_ALL",
        axis_forward="-Z",
        axis_up="Y",
        mesh_smooth_type="FACE",
    )
    return path


def render_preview():
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 24
    scene.cycles.device = "CPU"
    scene.render.resolution_x = 640
    scene.render.resolution_y = 420
    scene.render.filepath = os.path.join(OUT_DIR, "Rat_preview.png")
    scene.view_settings.view_transform = "Standard"

    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.55, 0.7, 0.85, 1)
    scene.world = world

    bpy.ops.mesh.primitive_plane_add(size=30, location=(0, 0, 0))
    ground = bpy.context.active_object
    gmat = bpy.data.materials.new("Grass")
    gmat.use_nodes = True
    gmat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.2, 0.45, 0.15, 1)
    ground.data.materials.append(gmat)

    bpy.ops.object.light_add(type="SUN", rotation=(math.radians(50), math.radians(10), math.radians(30)))
    bpy.context.active_object.data.energy = 4

    bpy.ops.object.camera_add(location=(-4.2, -4.6, 2.6), rotation=(math.radians(72), 0, math.radians(-42)))
    scene.camera = bpy.context.active_object
    bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    bpy.ops.wm.read_factory_settings(use_empty=True)
    build()
    print("triangles:", tri_count())
    print("exported:", export())
    render_preview()
