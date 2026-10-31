"""Characters: the Millbrook quest giver and the Bandit Thug enemy. Face -Y.

    python blender/characters.py [output_dir] [Name ...]

QuestGiver parts: Body, Head
BanditThug parts: Torso, Head, ArmL, ArmR (holds the sword), LegL, LegR
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import common as c  # noqa: E402


def eyes(parts, z, y, spread, size, eye_mat, brow_mat=None, angry=False):
    for side in (1, -1):
        parts.append(c.paint(c.sphere(size, (spread * side, y, z), segments=8, rings=6), eye_mat))
        if brow_mat:
            tilt = math.radians(-20 * side) if angry else 0
            parts.append(c.paint(c.box((0.2, 0.06, 0.05), (spread * side, y + 0.02, z + 0.13), rot=(0, tilt, 0)), brow_mat))


def quest_giver():
    robe = c.cloth("Robe", color=(0.22, 0.36, 0.2), weave=70)
    trim = c.cloth("Trim", color=(0.72, 0.6, 0.3), weave=90)
    skin = c.skin("Skin", color=(0.85, 0.64, 0.5))
    beard = c.fur("Beard", color=(0.86, 0.85, 0.82), streak_axis="Z")
    leather = c.skin("Leather", color=(0.32, 0.2, 0.1))
    staff = c.wood("Staff", light=(0.45, 0.3, 0.16), dark=(0.22, 0.13, 0.06), grain_axis="Z")
    eye = c.solid("Eye", (0.05, 0.05, 0.08), 0.2)
    hat = c.cloth("Hat", color=(0.35, 0.24, 0.14), weave=60)

    body = [
        c.paint(c.cylinder(1.05, 3.2, (0, 0, 1.6), verts=16, top_radius=0.62), robe),
        c.paint(c.sphere(1, (0, 0, 3.55), scale=(0.72, 0.5, 0.6)), robe),
        c.paint(c.torus(0.78, 0.07, (0, 0, 2.55), major_segments=20, minor_segments=6), leather),
        c.paint(c.cylinder(1.07, 0.15, (0, 0, 0.08), verts=16), trim),
    ]
    for side in (1, -1):
        # Sleeves hang from the shoulders, hands in front.
        body.append(c.paint(c.cylinder(0.24, 1.5, (0.8 * side, -0.18, 3.15), rot=(math.radians(-15), math.radians(-12 * side), 0), verts=10, top_radius=0.2), robe))
        body.append(c.paint(c.cylinder(0.27, 0.12, (0.86 * side, -0.37, 2.45), rot=(math.radians(-15), 0, 0), verts=10), trim))
        body.append(c.paint(c.sphere(0.2, (0.88 * side, -0.42, 2.3)), skin))
    body.append(c.paint(c.cylinder(0.07, 5.4, (1.05, -0.5, 2.7), verts=8), staff))
    body.append(c.paint(c.sphere(0.17, (1.05, -0.5, 5.45), segments=10, rings=8), staff))
    c.join(body, "Body")

    head = [
        c.paint(c.sphere(0.5, (0, 0, 4.42)), skin),
        c.paint(c.cylinder(0.42, 0.9, (0, -0.22, 3.85), rot=(math.radians(10), 0, 0), verts=12, top_radius=0.1), beard),
        c.paint(c.sphere(0.4, (0, -0.25, 4.17), scale=(1.05, 0.7, 0.6)), beard),
        c.paint(c.sphere(0.1, (0, -0.5, 4.38), segments=8, rings=6), skin),
        c.paint(c.cylinder(0.62, 0.08, (0, 0, 4.72), verts=16), hat),
        c.paint(c.cylinder(0.42, 0.55, (0, 0, 4.98), verts=16, top_radius=0.3), hat),
    ]
    eyes(head, 4.52, -0.44, 0.17, 0.065, eye, beard)
    c.join(head, "Head")


def bandit_thug():
    skin = c.skin("Skin", color=(0.74, 0.52, 0.38))
    shirt = c.cloth("Shirt", color=(0.45, 0.37, 0.28), weave=70)
    pants = c.cloth("Pants", color=(0.24, 0.22, 0.2), weave=80)
    leather = c.skin("Leather", color=(0.27, 0.16, 0.08))
    mask = c.cloth("Bandana", color=(0.58, 0.1, 0.08), weave=90)
    hood = c.cloth("Hood", color=(0.2, 0.18, 0.16), weave=60)
    steel = c.metal("Steel", color=(0.68, 0.7, 0.72))
    iron = c.metal("Iron", color=(0.3, 0.28, 0.26))
    eye = c.solid("Eye", (0.04, 0.04, 0.04), 0.2)
    brow = c.solid("Brow", (0.12, 0.08, 0.05), 0.8)

    c.join([
        c.paint(c.cylinder(0.78, 1.9, (0, 0, 3.3), verts=14, top_radius=0.9), shirt),
        c.paint(c.sphere(1, (0, 0, 4.15), scale=(0.95, 0.5, 0.32)), shirt),
        c.paint(c.cylinder(0.82, 0.25, (0, 0, 2.5), verts=14), leather),
        c.paint(c.box((0.3, 0.1, 0.24), (0, -0.82, 2.5)), iron),
    ], "Torso")

    head = [
        c.paint(c.sphere(0.46, (0, 0, 4.72)), skin),
        c.paint(c.sphere(0.49, (0, 0.1, 4.82), scale=(1.05, 1.0, 1.0)), hood),
        c.paint(c.sphere(0.48, (0, -0.02, 4.55), scale=(1.02, 1.02, 0.55)), mask),
    ]
    eyes(head, 4.76, -0.42, 0.16, 0.06, eye, brow, angry=True)
    c.join(head, "Head")

    for name, side in (("ArmL", -1), ("ArmR", 1)):
        arm = [
            c.paint(c.cylinder(0.26, 0.7, (0.98 * side, 0, 3.75), verts=10), shirt),
            c.paint(c.cylinder(0.21, 0.9, (0.98 * side, 0, 2.95), verts=10), skin),
            c.paint(c.cylinder(0.24, 0.3, (0.98 * side, 0, 2.6), verts=10), leather),
            c.paint(c.sphere(0.24, (0.98 * side, -0.05, 2.32), segments=10, rings=8), skin),
        ]
        if side == 1:
            # Sword held out in front, blade forward.
            arm += [
                c.paint(c.cylinder(0.07, 0.5, (0.98, -0.1, 2.32), rot=(math.radians(90), 0, 0), verts=8), leather),
                c.paint(c.box((0.6, 0.12, 0.12), (0.98, -0.38, 2.32)), iron),
                c.paint(c.box((0.08, 2.3, 0.26), (0.98, -1.58, 2.32)), steel),
                c.paint(c.cylinder(0.13, 0.04, (0.98, -2.75, 2.32), rot=(math.radians(90), 0, 0), verts=4), steel),
            ]
        c.join(arm, name)

    for name, side in (("LegL", -1), ("LegR", 1)):
        c.join([
            c.paint(c.cylinder(0.33, 1.9, (0.38 * side, 0, 1.45), verts=10, top_radius=0.36), pants),
            c.paint(c.box((0.52, 0.85, 0.65), (0.38 * side, -0.1, 0.32)), leather),
        ], name)


CHARACTERS = {
    "QuestGiver": (quest_giver, {"camera": (4.5, -7.5, 4.2), "target": (0, 0, 2.9), "size": (480, 640)}),
    "BanditThug": (bandit_thug, {"camera": (5, -7.5, 4.2), "target": (0, -0.6, 2.8), "size": (480, 640)}),
}


if __name__ == "__main__":
    out = c.out_dir()
    for name in sys.argv[2:] or list(CHARACTERS):
        build, preview = CHARACTERS[name]
        c.reset()
        build()
        c.bake_and_export(name, out, texture_size=1024, preview=preview)
