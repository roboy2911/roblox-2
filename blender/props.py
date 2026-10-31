"""World props, each exported as its own textured model.

    python blender/props.py [output_dir] [PropName ...]

Builds all props, or only the ones named. Sizes are in studs (the game
uses them as-is, except DirtPad which it scales to fit an area).
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import common as c  # noqa: E402
import bmesh  # noqa: E402  (needs bpy loaded first)


def mesh_from(name, verts, faces):
    me = c.bpy.data.meshes.new(name)
    bm = bmesh.new()
    bverts = [bm.verts.new(v) for v in verts]
    for f in faces:
        bm.faces.new([bverts[i] for i in f])
    bm.to_mesh(me)
    bm.free()
    obj = c.bpy.data.objects.new(name, me)
    c.bpy.context.collection.objects.link(obj)
    c.bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    c.bpy.context.view_layer.objects.active = obj
    return obj


def bulge(obj, amount):
    """Makes a cylinder fatter in the middle (barrel shape)."""
    zs = [v.co.z for v in obj.data.vertices]
    lo, hi = min(zs), max(zs)
    for v in obj.data.vertices:
        t = (v.co.z - lo) / (hi - lo)
        s = 1 + amount * math.sin(t * math.pi)
        v.co.x *= s
        v.co.y *= s


def subdivide(obj, cuts):
    c.bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    c.bpy.context.view_layer.objects.active = obj
    c.bpy.ops.object.mode_set(mode="EDIT")
    c.bpy.ops.mesh.select_all(action="SELECT")
    c.bpy.ops.mesh.subdivide(number_cuts=cuts)
    c.bpy.ops.object.mode_set(mode="OBJECT")


def barrel():
    wood = c.planks("Staves", light=(0.5, 0.31, 0.16), dark=(0.24, 0.14, 0.06), plank_axis="Z", planks_per_unit=3.5)
    lid = c.planks("Lid", light=(0.45, 0.28, 0.14), dark=(0.22, 0.13, 0.06), plank_axis="X", planks_per_unit=3)
    iron = c.metal("Iron", color=(0.32, 0.31, 0.3))
    body = c.cylinder(0.95, 2.6, (0, 0, 1.3), verts=16)
    subdivide(body, 4)
    bulge(body, 0.12)
    parts = [c.paint(body, wood), c.paint(c.cylinder(0.92, 0.04, (0, 0, 2.61), verts=16), lid)]
    for z, r in [(0.3, 0.99), (1.3, 1.08), (2.3, 0.99)]:
        parts.append(c.paint(c.torus(r, 0.05, (0, 0, z), major_segments=20, minor_segments=4), iron))
    c.join(parts, "Barrel")


def hay_bale():
    hay = c.straw("Hay", axis="X")
    twine = c.stripes("Twine", a=(0.35, 0.24, 0.12), b=(0.5, 0.36, 0.2), axis="DIAG", count=60)
    bale = c.box((3, 2, 2), (0, 0, 1))
    parts = [c.paint(bale, hay)]
    for x in (-0.8, 0.8):
        parts.append(c.paint(c.box((0.1, 2.06, 2.06), (x, 0, 1)), twine))
    c.join(parts, "HayBale")


def crate():
    boards = c.planks("Boards", light=(0.62, 0.45, 0.26), dark=(0.33, 0.22, 0.11), plank_axis="X", planks_per_unit=2.5)
    frame = c.wood("Frame", light=(0.42, 0.27, 0.13), dark=(0.22, 0.13, 0.06), grain_axis="Z")
    s = 2.4
    parts = [c.paint(c.box((s, s, s), (0, 0, s / 2)), boards)]
    t = 0.2
    for x in (-1, 1):
        for y in (-1, 1):
            parts.append(c.paint(c.box((t, t, s + 0.04), (x * (s / 2), y * (s / 2), s / 2)), frame))
    for z in (0, s):
        for x in (-1, 1):
            parts.append(c.paint(c.box((t, s + 0.04, t), (x * (s / 2), 0, z)), frame))
        for y in (-1, 1):
            parts.append(c.paint(c.box((s + 0.04, t, t), (0, y * (s / 2), z)), frame))
    c.join(parts, "Crate")


def tent():
    canvas = c.stripes("Canvas", a=(0.45, 0.16, 0.12), b=(0.36, 0.12, 0.09), axis="X", count=6)
    pole = c.wood("Pole", grain_axis="Z")
    rope = c.stripes("Rope", a=(0.5, 0.38, 0.22), b=(0.62, 0.5, 0.3), axis="DIAG", count=50)
    w, l, h = 2.6, 3.6, 4.0  # half width, half length, height
    shell = mesh_from("Shell", [(-w, -l, 0), (w, -l, 0), (0, -l, h), (-w, l, 0), (w, l, 0), (0, l, h)],
                      [(0, 2, 5, 3), (1, 4, 5, 2), (3, 5, 4), (0, 1, 2)])
    parts = [c.paint(shell, canvas)]
    for y in (-l - 0.05, l + 0.05):
        parts.append(c.paint(c.cylinder(0.1, h + 0.4, (0, y, (h + 0.4) / 2), verts=8), pole))
    parts.append(c.paint(c.cylinder(0.08, 2 * l + 0.4, (0, 0, h), rot=(math.pi / 2, 0, 0), verts=8), pole))
    for x in (-1, 1):
        for y in (-l, l):
            parts.append(c.paint(c.cylinder(0.03, 1.6, (x * (w + 0.5), y, 0.5), rot=(0, x * math.radians(-55), 0), verts=6), rope))
            parts.append(c.paint(c.cylinder(0.06, 0.5, (x * (w + 1.1), y, 0.15), verts=6), pole))
    c.join(parts, "Tent")


def campfire():
    rock = c.stone("Rock", color=(0.3, 0.29, 0.28))
    log = c.wood("Log", light=(0.4, 0.26, 0.14), dark=(0.18, 0.1, 0.05), grain_axis="X")
    char = c.dirt("Ash", color=(0.12, 0.1, 0.09), pebbles=False)
    parts = [c.paint(c.cylinder(1.0, 0.08, (0, 0, 0.04), verts=16), char)]
    for i in range(9):
        a = i / 9 * math.pi * 2
        parts.append(c.paint(c.sphere(0.32, (math.cos(a) * 1.25, math.sin(a) * 1.25, 0.18), scale=(1.2, 1, 0.75), segments=8, rings=6), rock))
    for i in range(4):
        a = i / 4 * math.pi + 0.3
        parts.append(c.paint(c.cylinder(0.14, 1.9, (0, 0, 0.22 + i * 0.06), rot=(math.radians(84), 0, a), verts=8), log))
    c.join(parts, "Campfire")


def sign():
    wood = c.wood("Post", light=(0.4, 0.26, 0.13), dark=(0.2, 0.12, 0.06), grain_axis="Z")
    board = c.planks("Board", light=(0.55, 0.37, 0.2), dark=(0.3, 0.19, 0.09), plank_axis="X", planks_per_unit=1.6)
    c.join([c.paint(c.box((0.45, 0.45, 5.4), (0, 0, 2.7)), wood)], "Post")
    c.join([c.paint(c.box((7, 0.35, 2.5), (0, -0.4, 4.6)), board)], "Board")


def dirt_pad():
    ground = c.dirt("Dirt", color=(0.42, 0.33, 0.22))
    pad = c.cylinder(20, 0.3, (0, 0, 0.15), verts=48)
    c.join([c.paint(pad, ground)], "DirtPad")


def stall():
    wood = c.wood("StallWood", grain_axis="Z")
    top = c.planks("Counter", light=(0.55, 0.37, 0.2), dark=(0.3, 0.19, 0.09), plank_axis="X", planks_per_unit=2)
    awning = c.stripes("Awning", a=(0.7, 0.15, 0.12), b=(0.92, 0.86, 0.72), axis="X", count=5)
    parts = [c.paint(c.box((5, 2, 0.25), (0, 0, 2.6)), top), c.paint(c.box((5, 0.2, 2.5), (0, 0.9, 1.3)), top)]
    for x in (-2.4, 2.4):
        for y in (-0.9, 0.9):
            parts.append(c.paint(c.box((0.25, 0.25, 5.5 if y > 0 else 4.6), (x, y, (5.5 if y > 0 else 4.6) / 2)), wood))
    roof = mesh_from("Awning", [(-2.7, -1.6, 4.4), (2.7, -1.6, 4.4), (2.7, 1.1, 5.6), (-2.7, 1.1, 5.6)], [(0, 1, 2, 3)])
    c.bpy.ops.object.mode_set(mode="EDIT")
    c.bpy.ops.mesh.select_all(action="SELECT")
    c.bpy.ops.mesh.extrude_region_move(TRANSFORM_OT_translate={"value": (0, 0, 0.12)})
    c.bpy.ops.object.mode_set(mode="OBJECT")
    parts.append(c.paint(roof, awning))
    c.join(parts, "Stall")


PROPS = {
    "Barrel": (barrel, 512, {"camera": (4, -5, 3), "target": (0, 0, 1.2)}),
    "HayBale": (hay_bale, 512, {"camera": (4, -5, 3), "target": (0, 0, 1)}),
    "Crate": (crate, 512, {"camera": (4, -5, 3.5), "target": (0, 0, 1.2)}),
    "Tent": (tent, 1024, {"camera": (9, -11, 5), "target": (0, 0, 1.8)}),
    "Campfire": (campfire, 512, {"camera": (3, -3.5, 2.5), "target": (0, 0, 0.2)}),
    "Sign": (sign, 512, {"camera": (5, -8, 4.5), "target": (0, 0, 3.5)}),
    "DirtPad": (dirt_pad, 1024, {"camera": (0, -30, 25), "target": (0, 0, 0)}),
    "Stall": (stall, 1024, {"camera": (6, -9, 5), "target": (0, 0, 2.5)}),
}


if __name__ == "__main__":
    out = c.out_dir()
    wanted = sys.argv[2:] or list(PROPS)
    for name in wanted:
        build, size, preview = PROPS[name]
        c.reset()
        build()
        c.bake_and_export(name, out, texture_size=size, preview=preview)
