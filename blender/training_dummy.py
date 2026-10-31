"""Builds the Training Dummy model and exports it as FBX for Roblox.

Run with Blender's Python (bpy):
    python blender/training_dummy.py [output_dir]

Each material is its own object so it becomes its own MeshPart in Roblox:
Post (wood), Body (straw), Head (burlap), Rope (rope). The game colors
them by name, so no textures are needed.
"""

import math
import os
import sys

import bpy

OUT_DIR = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "out")
os.makedirs(OUT_DIR, exist_ok=True)

COLORS = {
    "Post": (0.36, 0.22, 0.12, 1),
    "Body": (0.80, 0.68, 0.38, 1),
    "Head": (0.62, 0.50, 0.34, 1),
    "Rope": (0.55, 0.15, 0.12, 1),
}


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def material(name):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = COLORS[name]
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = COLORS[name]
    bsdf.inputs["Roughness"].default_value = 0.9
    return mat


def cylinder(radius, depth, loc, rot=(0, 0, 0), verts=12):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=depth, location=loc, rotation=rot)
    return bpy.context.active_object


def sphere(radius, loc, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=10, radius=radius, location=loc)
    obj = bpy.context.active_object
    obj.scale = scale
    return obj


def box(size, loc, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    obj = bpy.context.active_object
    obj.scale = size
    return obj


def join(objs, name):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    obj = bpy.context.active_object
    obj.name = name
    obj.data.name = name
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    bpy.ops.object.shade_flat()
    obj.data.materials.append(material(name))
    return obj


def taper_top(obj, factor):
    """Narrows the upper half of a mesh so the straw body looks stuffed."""
    zs = [v.co.z for v in obj.data.vertices]
    lo, hi = min(zs), max(zs)
    for v in obj.data.vertices:
        t = (v.co.z - lo) / (hi - lo)
        bulge = 1 + 0.18 * math.sin(t * math.pi)  # fatter in the middle
        s = bulge * (1 - (1 - factor) * t)
        v.co.x *= s
        v.co.y *= s


def build():
    # Heights in studs-ish units; the game rescales to exactly 6 studs tall.
    post = [
        cylinder(0.18, 5.0, (0, 0, 2.5)),
        cylinder(0.12, 3.4, (0, 0, 4.1), rot=(0, math.pi / 2, 0), verts=8),  # arm bar
        box((2.2, 0.35, 0.25), (0, 0, 0.125)),  # cross feet
        box((0.35, 2.2, 0.25), (0, 0, 0.125)),
        box((0.5, 0.5, 0.3), (0, 0, 0.4)),  # base block
    ]
    join(post, "Post")

    torso = cylinder(0.75, 2.2, (0, 0, 3.3), verts=16)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.subdivide(number_cuts=4)
    bpy.ops.object.mode_set(mode="OBJECT")
    # Object is at z=3.3, so local verts are centered on 0.
    taper_top(torso, 0.85)
    left_wrap = cylinder(0.24, 0.9, (-1.15, 0, 4.1), rot=(0, math.pi / 2, 0), verts=10)
    right_wrap = cylinder(0.24, 0.9, (1.15, 0, 4.1), rot=(0, math.pi / 2, 0), verts=10)
    join([torso, left_wrap, right_wrap], "Body")

    head = sphere(0.62, (0, 0, 5.15), scale=(1, 0.95, 1.05))
    neck = cylinder(0.3, 0.35, (0, 0, 4.55), verts=10)
    join([head, neck], "Head")

    rope = [
        cylinder(0.80, 0.12, (0, 0, 2.6), verts=16),
        cylinder(0.78, 0.12, (0, 0, 3.9), verts=16),
        cylinder(0.33, 0.1, (0, 0, 4.62), verts=10),
        cylinder(0.27, 0.1, (-1.4, 0, 4.1), rot=(0, math.pi / 2, 0), verts=10),
        cylinder(0.27, 0.1, (1.4, 0, 4.1), rot=(0, math.pi / 2, 0), verts=10),
    ]
    join(rope, "Rope")


def tri_count():
    total = 0
    for o in bpy.data.objects:
        if o.type == "MESH":
            total += sum(len(p.vertices) - 2 for p in o.data.polygons)
    return total


def export():
    path = os.path.join(OUT_DIR, "TrainingDummy.fbx")
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
    scene.render.resolution_x = 512
    scene.render.resolution_y = 640
    scene.render.filepath = os.path.join(OUT_DIR, "TrainingDummy_preview.png")
    scene.view_settings.view_transform = "Standard"

    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.55, 0.7, 0.85, 1)
    scene.world = world

    bpy.ops.mesh.primitive_plane_add(size=20, location=(0, 0, 0))
    ground = bpy.context.active_object
    gmat = bpy.data.materials.new("Grass")
    gmat.use_nodes = True
    gmat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.2, 0.45, 0.15, 1)
    ground.data.materials.append(gmat)

    bpy.ops.object.light_add(type="SUN", rotation=(math.radians(50), math.radians(10), math.radians(30)))
    bpy.context.active_object.data.energy = 4

    bpy.ops.object.camera_add(location=(7.0, -9.6, 4.6), rotation=(math.radians(80), 0, math.radians(36)))
    scene.camera = bpy.context.active_object
    bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    reset()
    build()
    print("triangles:", tri_count())
    print("exported:", export())
    render_preview()
    print("preview:", bpy.context.scene.render.filepath)
