"""Whisperwood Forest models and the sea props. Creatures face -Y.

    python blender/whisperwood.py [output_dir] [Name ...]

Wolf parts: Body, Head, Tail, LegFL, LegFR, LegBL, LegBR (like the Rat)
Goblin / GoblinKing parts: Torso, Head, ArmL, ArmR (holds the club), LegL, LegR
Ranger parts: Body, Head (quest giver)
Rowboat, Dock, Rock: one part each
"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(__file__))
import common as c  # noqa: E402
from characters import eyes  # noqa: E402


def wolf():
    fur = c.fur("Fur", color=(0.42, 0.42, 0.44), streak_axis="Y")
    pale = c.fur("Pale", color=(0.72, 0.7, 0.68), streak_axis="Y")
    dark = c.solid("Nose", (0.05, 0.05, 0.05), 0.3)
    eye = c.solid("Eye", (0.85, 0.65, 0.1), 0.2)
    tooth = c.solid("Tooth", (0.95, 0.93, 0.85), 0.4)
    c.join([
        c.paint(c.sphere(1, (0, 0.1, 1.45), scale=(0.62, 1.35, 0.6)), fur),
        c.paint(c.sphere(1, (0, -0.7, 1.5), scale=(0.7, 0.6, 0.66)), fur),
        c.paint(c.sphere(1, (0, -0.6, 1.15), scale=(0.5, 0.6, 0.4)), pale),
    ], "Body")
    head = [
        c.paint(c.sphere(0.55, (0, -1.6, 1.85), scale=(1, 1.1, 0.95)), fur),
        c.paint(c.cylinder(0.3, 0.75, (0, -2.25, 1.75), rot=(math.radians(90), 0, 0), verts=8, top_radius=0.16), fur),
        c.paint(c.sphere(0.24, (0, -2.1, 1.6), scale=(1.1, 1.4, 0.6)), pale),
        c.paint(c.sphere(0.1, (0, -2.62, 1.82), segments=8, rings=6), dark),
        c.paint(c.box((0.06, 0.04, 0.14), (0.12, -2.45, 1.52)), tooth),
        c.paint(c.box((0.06, 0.04, 0.14), (-0.12, -2.45, 1.52)), tooth),
    ]
    for side in (1, -1):
        head.append(c.paint(c.cylinder(0.2, 0.5, (0.3 * side, -1.45, 2.4), rot=(math.radians(-10), math.radians(15 * side), 0), verts=4, top_radius=0.02), fur))
        head.append(c.paint(c.sphere(0.08, (0.24 * side, -2.0, 2.0), segments=8, rings=6), eye))
    c.join(head, "Head")
    c.join([c.paint(c.curve_tube([((0, 1.35, 1.6), 1.0), ((0, 2.0, 1.3), 1.4), ((0, 2.6, 0.9), 0.7), ((0, 2.9, 0.6), 0.2)], 0.22, "Tail"), fur)], "Tail")
    for name, x, y in [("LegFL", -0.35, -0.75), ("LegFR", 0.35, -0.75), ("LegBL", -0.38, 0.95), ("LegBR", 0.38, 0.95)]:
        c.join([
            c.paint(c.cylinder(0.17, 1.2, (x, y, 0.65), verts=8, top_radius=0.22), fur),
            c.paint(c.sphere(0.18, (x, y - 0.08, 0.06), scale=(1, 1.3, 0.5), segments=8, rings=5), pale),
        ], name)


def goblin_parts(king=False):
    s = 1.0
    skin = c.skin("Skin", color=(0.38, 0.55, 0.22))
    rag = c.cloth("Rag", color=(0.42, 0.3, 0.18), weave=50)
    belt = c.skin("Belt", color=(0.25, 0.15, 0.07))
    wood = c.wood("Club", light=(0.45, 0.3, 0.15), dark=(0.22, 0.13, 0.06), grain_axis="Y")
    eye = c.solid("Eye", (0.95, 0.85, 0.15), 0.2)
    pupil = c.solid("Pupil", (0.05, 0.05, 0.05), 0.2)
    tooth = c.solid("Tooth", (0.95, 0.92, 0.75), 0.4)
    torso = [
        c.paint(c.sphere(1, (0, 0, 2.3), scale=(0.75, 0.55, 0.85)), skin),
        c.paint(c.cylinder(0.72, 0.9, (0, 0, 1.85), verts=12, top_radius=0.65), rag),
        c.paint(c.cylinder(0.7, 0.15, (0, 0, 2.2), verts=12), belt),
    ]
    if king:
        cape = c.fur("Cape", color=(0.45, 0.3, 0.18), streak_axis="Z")
        gold = c.metal("Gold", color=(0.9, 0.68, 0.2), scratches=0.15)
        torso.append(c.paint(c.sphere(1, (0, 0.25, 2.75), scale=(1.0, 0.5, 0.35)), cape))
        torso.append(c.paint(c.cylinder(0.8, 1.6, (0, 0.35, 2.0), verts=12, top_radius=0.95), cape))
        torso.append(c.paint(c.box((0.3, 0.08, 0.22), (0, -0.66, 2.2)), gold))
    c.join(torso, "Torso")

    head = [
        c.paint(c.sphere(0.55, (0, -0.05, 3.45), scale=(1.05, 0.95, 0.9)), skin),
        c.paint(c.cylinder(0.12, 0.45, (0, -0.6, 3.38), rot=(math.radians(100), 0, 0), verts=8, top_radius=0.05), skin),
        c.paint(c.box((0.07, 0.04, 0.1), (0.13, -0.5, 3.12)), tooth),
        c.paint(c.box((0.07, 0.04, 0.1), (-0.13, -0.5, 3.12)), tooth),
    ]
    for side in (1, -1):
        head.append(c.paint(c.cylinder(0.18, 0.75, (0.72 * side, 0, 3.55), rot=(0, math.radians(75 * side), 0), verts=4, top_radius=0.02), skin))
        head.append(c.paint(c.sphere(0.12, (0.2 * side, -0.45, 3.55), segments=8, rings=6), eye))
        head.append(c.paint(c.sphere(0.05, (0.2 * side, -0.56, 3.55), segments=6, rings=4), pupil))
    if king:
        for i in range(5):
            a = i / 5 * math.pi * 2
            head.append(c.paint(c.cylinder(0.08, 0.35, (math.cos(a) * 0.4, math.sin(a) * 0.4, 4.05), verts=4, top_radius=0.0), gold))
        head.append(c.paint(c.cylinder(0.45, 0.18, (0, 0, 3.92), verts=14), gold))
    c.join(head, "Head")

    for name, side in (("ArmL", -1), ("ArmR", 1)):
        arm = [
            c.paint(c.cylinder(0.17, 1.2, (0.85 * side, 0, 2.2), verts=8), skin),
            c.paint(c.sphere(0.2, (0.85 * side, -0.05, 1.58), segments=8, rings=6), skin),
        ]
        if side == 1:
            club_len = 2.4 if king else 1.6
            club = c.cylinder(0.1, club_len, (0.85, -club_len / 2, 1.58), rot=(math.radians(90), 0, 0), verts=8, top_radius=0.24 if king else 0.18)
            arm.append(c.paint(club, wood))
            if king:
                stone = c.stone("Spikes", color=(0.4, 0.4, 0.42))
                for i in range(6):
                    a = i / 6 * math.pi * 2
                    arm.append(c.paint(c.cylinder(0.06, 0.3, (0.85 + math.cos(a) * 0.25, -club_len + 0.3, 1.58 + math.sin(a) * 0.25),
                                                  rot=(0, math.pi / 2 - a, 0), verts=4, top_radius=0), stone))
        c.join(arm, name)
    for name, side in (("LegL", -1), ("LegR", 1)):
        c.join([
            c.paint(c.cylinder(0.2, 1.3, (0.3 * side, 0, 0.75), verts=8), skin),
            c.paint(c.sphere(0.24, (0.3 * side, -0.12, 0.1), scale=(1, 1.5, 0.5), segments=8, rings=5), skin),
        ], name)


def ranger():
    cloak = c.cloth("Cloak", color=(0.2, 0.36, 0.18), weave=60)
    tunic = c.cloth("Tunic", color=(0.45, 0.35, 0.22), weave=70)
    skin = c.skin("Skin", color=(0.85, 0.64, 0.5))
    hair = c.fur("Hair", color=(0.6, 0.35, 0.15), streak_axis="Z")
    leather = c.skin("Leather", color=(0.32, 0.2, 0.1))
    bow = c.wood("Bow", grain_axis="Z")
    eye = c.solid("Eye", (0.08, 0.2, 0.1), 0.2)
    body = [
        c.paint(c.cylinder(0.85, 3.2, (0, 0, 1.6), verts=16, top_radius=0.62), tunic),
        c.paint(c.sphere(1, (0, 0, 3.55), scale=(0.75, 0.5, 0.6)), cloak),
        c.paint(c.cylinder(0.95, 3.0, (0, 0.18, 2.0), verts=16, top_radius=0.72), cloak),
        c.paint(c.torus(0.7, 0.07, (0, 0, 2.5), major_segments=20, minor_segments=6), leather),
        c.paint(c.torus(0.9, 0.05, (0, 0.75, 2.8), rot=(math.radians(90), math.radians(20), 0), major_segments=20, minor_segments=4), bow),
        c.paint(c.cylinder(0.18, 1.2, (-0.4, 0.75, 3.1), rot=(math.radians(10), math.radians(-20), 0), verts=8), leather),
    ]
    for side in (1, -1):
        body.append(c.paint(c.cylinder(0.22, 1.4, (0.8 * side, -0.15, 3.1), rot=(math.radians(-15), math.radians(-12 * side), 0), verts=10, top_radius=0.18), cloak))
        body.append(c.paint(c.sphere(0.19, (0.86 * side, -0.4, 2.35)), skin))
    c.join(body, "Body")
    head = [
        c.paint(c.sphere(0.48, (0, 0, 4.4)), skin),
        c.paint(c.sphere(0.5, (0, 0.08, 4.5), scale=(1.02, 1, 1)), hair),
        c.paint(c.sphere(0.58, (0, 0.14, 4.5), scale=(1.05, 1.05, 1.08)), cloak),
        c.paint(c.sphere(0.09, (0, -0.47, 4.35), segments=8, rings=6), skin),
    ]
    eyes(head, 4.47, -0.43, 0.16, 0.06, eye, hair)
    c.join(head, "Head")


def rowboat():
    hull = c.planks("Hull", light=(0.52, 0.34, 0.18), dark=(0.26, 0.15, 0.07), plank_axis="Y", planks_per_unit=3)
    rim = c.wood("Rim", light=(0.42, 0.26, 0.13), dark=(0.2, 0.12, 0.05), grain_axis="Y")
    c.bpy.ops.mesh.primitive_uv_sphere_add(segments=20, ring_count=10, radius=1, location=(0, 0, 0.9))
    shell = c.bpy.context.active_object
    shell.scale = (1.6, 4.2, 1.0)
    c.bpy.ops.object.mode_set(mode="EDIT")
    import bmesh
    me = shell.data
    bm = bmesh.from_edit_mesh(me)
    for v in [v for v in bm.verts if v.co.z > 0.0]:
        bm.verts.remove(v)
    bmesh.update_edit_mesh(me)
    c.bpy.ops.object.mode_set(mode="OBJECT")
    solid = shell.modifiers.new("Thick", "SOLIDIFY")
    solid.thickness = 0.12
    c.bpy.ops.object.modifier_apply(modifier="Thick")
    parts = [c.paint(shell, hull)]
    parts.append(c.paint(c.torus(1, 0.08, (0, 0, 0.9), major_segments=28, minor_segments=4), rim))
    parts[-1].scale = (1.6, 4.2, 1)
    for y in (-1.6, 0.4, 2.2):
        parts.append(c.paint(c.box((2.6, 0.5, 0.12), (0, y, 0.6)), rim))
    for side in (1, -1):
        parts.append(c.paint(c.cylinder(0.05, 3.2, (1.7 * side, 0.2, 0.95), rot=(math.radians(80), 0, math.radians(15 * side)), verts=6), rim))
    c.join(parts, "Boat")


def dock():
    boards = c.planks("Boards", light=(0.55, 0.38, 0.22), dark=(0.28, 0.18, 0.09), plank_axis="X", planks_per_unit=1.5)
    post = c.wood("Post", light=(0.38, 0.25, 0.13), dark=(0.18, 0.1, 0.05), grain_axis="Z")
    rope = c.stripes("Rope", a=(0.55, 0.42, 0.25), b=(0.7, 0.56, 0.35), axis="DIAG", count=50)
    parts = [c.paint(c.box((8, 24, 0.5), (0, 0, -0.25)), boards)]
    for x in (-3.6, 3.6):
        for y in (-10, -3, 4, 11):
            parts.append(c.paint(c.cylinder(0.35, 5, (x, y, -2.3), verts=8), post))
        parts.append(c.paint(c.cylinder(0.08, 22, (x, 0.5, 0.9), rot=(math.radians(90), 0, 0), verts=6), rope))
        for y in (-10, -3, 4, 11):
            parts.append(c.paint(c.cylinder(0.18, 1.3, (x, y, 0.55), verts=8), post))
    c.join(parts, "Dock")


def rock():
    random.seed(3)
    stone = c.stone("Stone", color=(0.42, 0.41, 0.4))
    moss = c.leaves("Moss", color=(0.25, 0.38, 0.15))
    c.bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=1.5, location=(0, 0, 0.9))
    r = c.bpy.context.active_object
    for v in r.data.vertices:
        v.co *= 1 + random.uniform(-0.18, 0.18)
    r.scale = (1.3, 1.0, 0.75)
    c.bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=1.45, location=(0, 0, 1.45))
    m = c.bpy.context.active_object
    m.scale = (1.15, 0.9, 0.35)
    c.join([c.paint(r, stone), c.paint(m, moss)], "Rock")


MODELS = {
    "Wolf": (wolf, 1024, {"camera": (-5.5, -6.5, 3.5), "target": (0, -0.4, 1.2), "size": (640, 420)}),
    "Goblin": (lambda: goblin_parts(False), 1024, {"camera": (4, -6, 3), "target": (0, -0.3, 2.0), "size": (480, 600)}),
    "GoblinKing": (lambda: goblin_parts(True), 1024, {"camera": (4, -6, 3), "target": (0, -0.4, 2.2), "size": (480, 600)}),
    "Ranger": (ranger, 1024, {"camera": (4.5, -7.5, 4.0), "target": (0, 0, 2.7), "size": (480, 640)}),
    "Rowboat": (rowboat, 1024, {"camera": (7, -9, 5), "target": (0, 0, 0.5), "size": (640, 420)}),
    "Dock": (dock, 1024, {"camera": (14, -20, 9), "target": (0, 0, 0), "size": (640, 420)}),
    "Rock": (rock, 512, {"camera": (4, -5, 3), "target": (0, 0, 0.8), "size": (480, 400)}),
}


if __name__ == "__main__":
    out = c.out_dir()
    for name in sys.argv[2:] or list(MODELS):
        build, size, preview = MODELS[name]
        c.reset()
        build()
        c.bake_and_export(name, out, texture_size=size, preview=preview)
