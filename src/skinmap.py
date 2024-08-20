from PIL.Image import Image
from typedefs import *


def find_blob(skinmap: Image, color: Color) -> list[list[IVec | None]]:
    width, height = skinmap.size
    pixels = skinmap.load()

    points = []
    for y in range(height):
        for x in range(width):
            if pixels[x, y] == color: points.append((x, y))

    x_min = min(points, key=lambda point: point[0])[0]
    y_min = min(points, key=lambda point: point[1])[1]
    x_max = max(points, key=lambda point: point[0])[0]
    y_max = max(points, key=lambda point: point[1])[1]

    blob: list[list[IVec | None]] = [[None for x in range(x_max - x_min + 1)] for y in range(y_max - y_min + 1)]
    for point in points:
        blob[point[1] - y_min][point[0] - x_min] = point
    return blob
