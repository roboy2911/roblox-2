"""Images for particles and trails (white, so the game can tint them).

    python blender/effects.py [output_dir]

Writes FxSpark.png, FxDust.png, FxGlow.png, FxRing.png, FxTrail.png, FxFlame.png.
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import common as c  # noqa: E402
from mathutils import Vector, noise  # noqa: E402


def save(name, width, height, pixel, out):
    img = c.bpy.data.images.new(name, width, height, alpha=True)
    data = []
    for y in range(height):
        for x in range(width):
            u = (x + 0.5) / width * 2 - 1
            v = (y + 0.5) / height * 2 - 1
            r, g, b, a = pixel(u, v)
            data += [r, g, b, max(0.0, min(1.0, a))]
    img.pixels = data
    img.filepath_raw = os.path.join(out, name + ".png")
    img.file_format = "PNG"
    img.save()
    print("wrote", img.filepath_raw)


def spark(u, v):
    # Bright core with a long streak and a short cross streak.
    d = math.hypot(u, v)
    core = max(0, 1 - d / 0.25) ** 2
    streak = max(0, 1 - abs(v) / 0.08) * max(0, 1 - abs(u)) ** 1.5
    cross = max(0, 1 - abs(u) / 0.06) * max(0, 1 - abs(v) / 0.5) ** 2 * 0.6
    a = min(1, core + streak + cross)
    return 1, 1, 1, a


def dust(u, v):
    # Soft cloudy puff with lumpy edges.
    d = math.hypot(u, v)
    lumps = noise.noise(Vector((u * 3, v * 3, 0.5))) * 0.25 + noise.noise(Vector((u * 7, v * 7, 1.5))) * 0.1
    edge = max(0, 1 - (d + lumps) / 0.9)
    shade = 0.85 + noise.noise(Vector((u * 5, v * 5, 3.0))) * 0.15
    return shade, shade, shade, edge ** 1.4


def glow(u, v):
    d = math.hypot(u, v)
    a = max(0, 1 - d) ** 2.2
    return 1, 1, 1, a


def ring(u, v):
    # Thin bright ring with a soft inner haze, slightly broken up.
    d = math.hypot(u, v)
    band = max(0, 1 - abs(d - 0.8) / 0.09) ** 1.5
    haze = max(0, 1 - abs(d - 0.65) / 0.3) * 0.25
    angle = math.atan2(v, u)
    breakup = 0.75 + 0.25 * noise.noise(Vector((math.cos(angle) * 3, math.sin(angle) * 3, 0)))
    return 1, 1, 1, (band + haze) * breakup


def trail(u, v):
    # Bright at the head (left), fading toward the tail, wispy edges.
    t = (u + 1) / 2
    across = max(0, 1 - abs(v) / 0.9)
    wisps = 0.7 + 0.3 * noise.noise(Vector((t * 8, v * 3, 0)))
    return 1, 1, 1, across ** 1.5 * wisps * (1 - t * 0.3)


def flame(u, v):
    # Teardrop flame, wide at the bottom, licking up to a point.
    y = (v + 1) / 2  # 0 bottom, 1 top
    width = 0.75 * (1 - y) ** 0.6 * min(1, y * 4 + 0.3)
    wobble = noise.noise(Vector((u * 2, y * 3, 2.0))) * 0.15
    inside = max(0, 1 - abs(u + wobble) / max(width, 0.01))
    flicker = 0.75 + 0.25 * noise.noise(Vector((u * 6, y * 6, 4.0)))
    return 1, 1, 1, inside ** 0.8 * flicker * (1 - y) ** 0.3


def tile(colors, scale, pebbles=False, waves=False):
    """Seamless-ish ground tile: noise sampled on a torus so edges wrap."""
    a, b, d = colors

    def pixel(u, v):
        x, y = (u + 1) * math.pi, (v + 1) * math.pi
        p = Vector((math.cos(x) * scale, math.sin(x) * scale, math.cos(y) * scale + math.sin(y) * scale * 0.7))
        n = noise.noise(p) * 0.5 + 0.5
        n2 = noise.noise(p * 3.1) * 0.5 + 0.5
        t = n * 0.65 + n2 * 0.35
        if waves:
            t = 0.5 + 0.5 * math.sin((v + 1) * math.pi * 4 + n * 6)
        col = [a[i] + (b[i] - a[i]) * t for i in range(3)]
        if pebbles and n2 > 0.78:
            col = [d[i] for i in range(3)]
        return col[0], col[1], col[2], 1

    return pixel


if __name__ == "__main__":
    out = c.out_dir()
    c.bpy.ops.wm.read_factory_settings(use_empty=True)
    save("FxSpark", 128, 128, spark, out)
    save("FxDust", 128, 128, dust, out)
    save("FxGlow", 128, 128, glow, out)
    save("FxRing", 256, 256, ring, out)
    save("FxTrail", 256, 64, trail, out)
    save("FxFlame", 128, 128, flame, out)
    save("TileGrass", 128, 128, tile(((0.22, 0.4, 0.14), (0.36, 0.56, 0.2), (0.3, 0.3, 0.2)), 1.2), out)
    save("TileForest", 128, 128, tile(((0.12, 0.26, 0.09), (0.25, 0.38, 0.13), (0.3, 0.22, 0.12)), 1.4, pebbles=True), out)
    save("TileSand", 128, 128, tile(((0.78, 0.68, 0.46), (0.9, 0.82, 0.6), (0.6, 0.55, 0.45)), 1.6, pebbles=True), out)
    save("TileWater", 128, 128, tile(((0.12, 0.38, 0.55), (0.22, 0.55, 0.72), (0, 0, 0)), 1.0, waves=True), out)
