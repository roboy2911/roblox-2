"""Training Dummy: wooden post, straw body, burlap head, red rope.

    python blender/training_dummy.py [output_dir]

One part named "Dummy" with a baked texture.
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import common as c  # noqa: E402


def build():
    wood = c.wood("Wood", grain_axis="Z")
    wood_x = c.wood("WoodX", grain_axis="X")
    straw = c.straw("Straw", axis="Z")
    burlap = c.cloth("Burlap", color=(0.62, 0.5, 0.34), weave=90)
    rope = c.stripes("Rope", a=(0.5, 0.12, 0.1), b=(0.72, 0.22, 0.16), axis="DIAG", count=40)

    parts = [
        c.paint(c.cylinder(0.18, 5.0, (0, 0, 2.5)), wood),
        c.paint(c.cylinder(0.12, 3.4, (0, 0, 4.1), rot=(0, math.pi / 2, 0), verts=8), wood_x),
        c.paint(c.box((2.2, 0.35, 0.25), (0, 0, 0.125)), wood_x),
        c.paint(c.box((0.35, 2.2, 0.25), (0, 0, 0.125)), wood),
        c.paint(c.box((0.5, 0.5, 0.3), (0, 0, 0.4)), wood),
    ]

    torso = c.cylinder(0.75, 2.2, (0, 0, 3.3), verts=16)
    c.bpy.ops.object.mode_set(mode="EDIT")
    c.bpy.ops.mesh.subdivide(number_cuts=4)
    c.bpy.ops.object.mode_set(mode="OBJECT")
    zs = [v.co.z for v in torso.data.vertices]
    lo, hi = min(zs), max(zs)
    for v in torso.data.vertices:
        t = (v.co.z - lo) / (hi - lo)
        s = (1 + 0.18 * math.sin(t * math.pi)) * (1 - 0.15 * t)
        v.co.x *= s
        v.co.y *= s
    parts.append(c.paint(torso, straw))
    for x in (-1.15, 1.15):
        parts.append(c.paint(c.cylinder(0.24, 0.9, (x, 0, 4.1), rot=(0, math.pi / 2, 0), verts=10), straw))

    parts.append(c.paint(c.sphere(0.62, (0, 0, 5.15), scale=(1, 0.95, 1.05)), burlap))
    parts.append(c.paint(c.cylinder(0.3, 0.35, (0, 0, 4.55), verts=10), burlap))

    for loc, r, rot in [((0, 0, 2.6), 0.8, (0, 0, 0)), ((0, 0, 3.9), 0.78, (0, 0, 0)), ((0, 0, 4.62), 0.33, (0, 0, 0)),
                        ((-1.4, 0, 4.1), 0.27, (0, math.pi / 2, 0)), ((1.4, 0, 4.1), 0.27, (0, math.pi / 2, 0))]:
        parts.append(c.paint(c.cylinder(r, 0.12, loc, rot=rot, verts=16), rope))

    c.join(parts, "Dummy")


if __name__ == "__main__":
    c.reset()
    build()
    c.bake_and_export("TrainingDummy", c.out_dir(), texture_size=1024,
                      preview={"camera": (6.5, -9, 4.6), "target": (0, 0, 2.9), "size": (512, 640)})
