"""Generate the original roadside tower used by the native project.

Run from the repo root with:
blender --background --python Masalik-3D/tools/build_stone_tower.py
"""
from pathlib import Path

import bpy


def material(name, rgb):
    result = bpy.data.materials.new(name)
    result.diffuse_color = (*rgb, 1.0)
    return result


def box(name, location, size, finish):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location)
    part = bpy.context.object
    part.name = name
    part.dimensions = size
    part.data.materials.append(finish)
    return part


bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
stone = material("Ochre limestone", (0.49, 0.32, 0.19))
stone_light = material("Light sandstone", (0.73, 0.54, 0.34))
plaster = material("Lime plaster", (0.85, 0.77, 0.59))
wood = material("Dark timber", (0.12, 0.068, 0.035))
parts = [box("Stone volume", (0, 0, 3.15), (5.8, 5.1, 6.3), stone)]
for height in (0.42, 2.25, 4.34, 6.24):
    parts.append(box("Stone course", (0, 0, height), (5.91, 5.21, 0.15), stone_light))
for floor in (1.42, 3.32, 5.30):
    for x in (-1.7, 0, 1.7):
        parts.append(box("White jamb", (x, -2.575, floor), (0.78, 0.085, 0.96), plaster))
        parts.append(box("Shutter", (x, -2.635, floor - 0.02), (0.52, 0.045, 0.65), wood))
        parts.append(box("Window sill", (x, -2.66, floor - 0.5), (0.90, 0.20, 0.10), stone_light))
    for y in (-1.45, 0.52, 1.60):
        parts.append(box("Side jamb", (2.93, y, floor), (0.085, 0.74, 0.89), plaster))
        parts.append(box("Side shutter", (2.975, y, floor), (0.06, 0.53, 0.63), wood))

for y in (-2.41, 2.41):
    parts.append(box("Roof wall", (0, y, 6.51), (5.9, 0.31, 0.50), stone_light))
    for x in (-2.7, -1.65, -0.55, 0.55, 1.65, 2.7):
        parts.append(box("Parapet", (x, y, 6.88), (0.32, 0.35, 0.26), plaster))
for x in (-2.75, 2.75):
    parts.append(box("Roof return", (x, 0, 6.52), (0.3, 5.1, 0.5), stone_light))

bpy.ops.object.select_all(action="SELECT")
bpy.context.view_layer.objects.active = parts[0]
bpy.ops.object.join()
tower = bpy.context.object
tower.name = "HighlandStoneTower"
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
out = Path(__file__).resolve().parents[1] / "assets" / "buildings" / "stone_tower.glb"
bpy.ops.export_scene.gltf(filepath=str(out), export_format="GLB", export_yup=True)
