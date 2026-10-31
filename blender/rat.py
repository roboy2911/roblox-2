"""Rat enemy. Faces -Y.

    python blender/rat.py [output_dir]

Parts (the game animates them by name):
    Body, Head, Tail, LegFL, LegFR, LegBL, LegBR
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import common as c  # noqa: E402


def build():
    fur = c.fur("Fur", color=(0.32, 0.27, 0.24), streak_axis="Y")
    belly = c.fur("Belly", color=(0.55, 0.5, 0.45), streak_axis="Y")
    pink = c.skin("Pink", color=(0.86, 0.56, 0.56))
    eye = c.solid("Eye", (0.02, 0.02, 0.02), 0.2)
    shine = c.solid("Shine", (0.95, 0.95, 0.95), 0.2)
    tooth = c.solid("Tooth", (0.95, 0.92, 0.8), 0.4)

    c.join([
        c.paint(c.sphere(1, (0, 0, 0.78), scale=(0.58, 0.98, 0.52)), fur),
        c.paint(c.sphere(1, (0, 0.45, 0.72), scale=(0.62, 0.6, 0.5)), fur),
        c.paint(c.sphere(1, (0, 0.05, 0.5), scale=(0.45, 0.8, 0.28)), belly),
    ], "Body")

    head = [
        c.paint(c.sphere(1, (0, -1.0, 0.88), scale=(0.44, 0.52, 0.42)), fur),
        c.paint(c.cylinder(0.3, 0.6, (0, -1.5, 0.8), rot=(math.radians(90), 0, 0), verts=10, top_radius=0.08), fur),
        c.paint(c.sphere(0.1, (0, -1.8, 0.8), segments=8, rings=6), pink),
        c.paint(c.box((0.12, 0.04, 0.12), (0, -1.72, 0.62)), tooth),
    ]
    for side in (1, -1):
        head.append(c.paint(c.sphere(0.12, (0.3 * side, -1.3, 1.06), segments=10, rings=8), eye))
        head.append(c.paint(c.sphere(0.035, (0.33 * side, -1.4, 1.12), segments=6, rings=4), shine))
        head.append(c.paint(c.sphere(0.24, (0.3 * side, -0.85, 1.28), scale=(1, 0.35, 1), segments=10, rings=6), pink))
    c.join(head, "Head")

    c.join([c.paint(c.curve_tube(
        [((0, 0.85, 0.62), 1.0), ((0, 1.55, 0.35), 0.7), ((0.25, 2.3, 0.5), 0.35), ((0.15, 2.8, 0.8), 0.1)], 0.09, "Tail"), pink)], "Tail")

    for name, x, y in [("LegFL", -0.36, -0.5), ("LegFR", 0.36, -0.5), ("LegBL", -0.4, 0.55), ("LegBR", 0.4, 0.55)]:
        c.join([
            c.paint(c.cylinder(0.13, 0.5, (x, y, 0.25), verts=8), fur),
            c.paint(c.sphere(0.15, (x, y - 0.06, 0.04), scale=(1, 1.4, 0.5), segments=8, rings=5), pink),
        ], name)


if __name__ == "__main__":
    c.reset()
    build()
    c.bake_and_export("Rat", c.out_dir(), texture_size=1024,
                      preview={"camera": (-4.2, -4.6, 2.6), "target": (0, -0.3, 0.6), "size": (640, 420)})
