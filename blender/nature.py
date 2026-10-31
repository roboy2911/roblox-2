"""Nature and items: Tree and the Ember Gem.

    python blender/nature.py [output_dir] [Name ...]
"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(__file__))
import common as c  # noqa: E402


def tree():
    random.seed(7)
    bark = c.bark("Bark")
    leaf = c.leaves("Leaves")
    leaf_dark = c.leaves("LeavesDark", color=(0.17, 0.34, 0.11))
    parts = [c.paint(c.cylinder(1.0, 9, (0, 0, 4.5), verts=12, top_radius=0.55), bark)]
    # Roots flaring out at the base.
    for i in range(5):
        a = i / 5 * math.pi * 2 + 0.3
        parts.append(c.paint(c.cylinder(0.45, 2.2, (math.cos(a) * 0.9, math.sin(a) * 0.9, 0.45),
                                        rot=(math.radians(70), 0, a + math.pi / 2), verts=8, top_radius=0.15), bark))
    # Two branches.
    for a, z in ((0.6, 6.5), (3.5, 7.4)):
        parts.append(c.paint(c.cylinder(0.32, 3.5, (math.cos(a) * 1.3, math.sin(a) * 1.3, z + 0.8),
                                        rot=(math.radians(50), 0, a + math.pi / 2), verts=8, top_radius=0.15), bark))
    # Canopy: overlapping lumpy blobs.
    blobs = [((0, 0, 11), 4.2), ((2.6, 0.8, 9.6), 3.0), ((-2.4, -1.2, 9.8), 3.1), ((0.8, -2.6, 10.2), 2.8),
             ((-0.9, 2.5, 10.4), 2.9), ((0.3, 0.2, 13.4), 2.8)]
    for i, (loc, r) in enumerate(blobs):
        c.bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=r, location=loc)
        blob = c.bpy.context.active_object
        for v in blob.data.vertices:
            v.co *= 1 + random.uniform(-0.12, 0.12)
        blob.scale = (1, 1, 0.82)
        parts.append(c.paint(blob, leaf if i % 2 == 0 else leaf_dark))
    c.join(parts, "Tree")


def ember_gem():
    gem = c.crystal("Ember", bright=(1.0, 0.62, 0.12), deep=(0.7, 0.1, 0.02))
    gold = c.metal("Gold", color=(0.85, 0.62, 0.2), scratches=0.15)
    c.bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.5, location=(0, 0, 0.75))
    stone = c.bpy.context.active_object
    stone.scale = (0.8, 0.8, 1.35)
    parts = [c.paint(stone, gem)]
    # A small gold band around the middle, like it's been set by a jeweler.
    parts.append(c.paint(c.torus(0.4, 0.05, (0, 0, 0.75), major_segments=16, minor_segments=4), gold))
    c.join(parts, "Gem")


ITEMS = {
    "Tree": (tree, 1024, {"camera": (16, -20, 9), "target": (0, 0, 7), "size": (480, 600)}),
    "EmberGem": (ember_gem, 512, {"camera": (1.8, -2.4, 1.6), "target": (0, 0, 0.75), "size": (400, 400)}),
}


if __name__ == "__main__":
    out = c.out_dir()
    for name in sys.argv[2:] or list(ITEMS):
        build, size, preview = ITEMS[name]
        c.reset()
        build()
        c.bake_and_export(name, out, texture_size=size, preview=preview)
