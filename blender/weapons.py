"""Weapons. Each is built standing up: grip at the bottom, blade/head up (+Z).

    python blender/weapons.py [output_dir] [Name ...]

The game holds a weapon by its grip (a set distance above the bottom, see
Config/Combat Weapons Grip) and points the blade forward.
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import common as c  # noqa: E402


def iron_sword():
    steel = c.metal("Steel", color=(0.5, 0.52, 0.56), scratches=0.2)
    edge = c.metal("Edge", color=(0.68, 0.7, 0.74), scratches=0.1)
    iron = c.metal("Iron", color=(0.32, 0.3, 0.28))
    leather = c.stripes("Grip", a=(0.3, 0.17, 0.08), b=(0.4, 0.24, 0.12), axis="DIAG", count=40)

    parts = [
        c.paint(c.sphere(0.12, (0, 0, 0.1), segments=10, rings=6), iron),  # pommel
        c.paint(c.cylinder(0.07, 0.75, (0, 0, 0.55), verts=8), leather),  # grip
        c.paint(c.box((0.75, 0.14, 0.12), (0, 0, 0.98)), iron),  # crossguard
        c.paint(c.box((0.22, 0.05, 2.9), (0, 0, 2.5)), steel),  # blade
        c.paint(c.box((0.05, 0.03, 2.9), (0, 0, 2.5)), edge),  # fuller shine
    ]
    # Pointed tip.
    c.bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=0.155, radius2=0, depth=0.45, location=(0, 0, 4.17), rotation=(0, 0, math.radians(45)))
    tip = c.bpy.context.active_object
    tip.scale = (1, 0.25, 1)
    parts.append(c.paint(tip, steel))
    for x in (-0.4, 0.4):
        parts.append(c.paint(c.sphere(0.07, (x, 0, 0.98), segments=8, rings=5), iron))
    c.join(parts, "Weapon")


def battle_axe():
    wood = c.wood("Haft", light=(0.5, 0.33, 0.18), dark=(0.26, 0.15, 0.07), grain_axis="Z")
    steel = c.metal("AxeHead", color=(0.45, 0.46, 0.49), scratches=0.25)
    iron = c.metal("Bands", color=(0.3, 0.28, 0.26))
    leather = c.stripes("Wrap", a=(0.28, 0.16, 0.07), b=(0.38, 0.22, 0.1), axis="DIAG", count=40)

    parts = [
        c.paint(c.cylinder(0.1, 4.4, (0, 0, 2.2), verts=10), wood),
        c.paint(c.cylinder(0.12, 0.9, (0, 0, 0.7), verts=10), leather),
        c.paint(c.cylinder(0.13, 0.12, (0, 0, 0.06), verts=10), iron),
        c.paint(c.cylinder(0.13, 0.12, (0, 0, 3.4), verts=10), iron),
        c.paint(c.cylinder(0.13, 0.12, (0, 0, 4.3), verts=10), iron),
    ]
    # Big crescent blade on one side, a spike on the other.
    blade = c.bpy.data.meshes.new("Blade")
    import bmesh
    bm = bmesh.new()
    profile = [(0.1, 3.45), (0.55, 3.25), (1.05, 2.95), (1.25, 3.55), (1.3, 3.95), (1.25, 4.35), (1.05, 4.95), (0.55, 4.6), (0.1, 4.4)]
    front = [bm.verts.new((x, -0.07, z)) for x, z in profile]
    back = [bm.verts.new((x, 0.07, z)) for x, z in profile]
    bm.faces.new(front)
    bm.faces.new(list(reversed(back)))
    n = len(profile)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new([front[i], front[j], back[j], back[i]])
    bm.to_mesh(blade)
    bm.free()
    obj = c.bpy.data.objects.new("Blade", blade)
    c.bpy.context.collection.objects.link(obj)
    parts.append(c.paint(obj, steel))
    c.bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=0.14, radius2=0, depth=0.7, location=(-0.4, 0, 3.95), rotation=(0, math.radians(-90), 0))
    parts.append(c.paint(c.bpy.context.active_object, steel))
    c.join(parts, "Weapon")


WEAPONS = {
    "IronSword": (iron_sword, 512, {"camera": (3.2, -4.5, 3.0), "target": (0, 0, 2.2), "size": (400, 560)}),
    "BattleAxe": (battle_axe, 512, {"camera": (3.6, -5.2, 3.2), "target": (0.3, 0, 2.6), "size": (400, 560)}),
}


if __name__ == "__main__":
    out = c.out_dir()
    for name in sys.argv[2:] or list(WEAPONS):
        build, size, preview = WEAPONS[name]
        c.reset()
        build()
        c.bake_and_export(name, out, texture_size=size, preview=preview)
