from PIL.Image import Image
from pixamo.typedefs import *


def find_bone(pose: Image, color: Color) -> list[IVec] | None:
    width, height = pose.size
    pixels = pose.load()

    def neighbours(point: IVec) -> list[IVec]:
        return [
            (x + point[0], y + point[1]) for x in range(-1, 2) for y in range(-1, 2)
            if (x, y) != (0, 0)
               and 0 <= x + point[0] < width and 0 <= y + point[1] < height
        ]

    visited = [[False for x in range(width)] for y in range(height)]

    def count_neighbours(point: IVec) -> int:
        if visited[point[1]][point[0]]: return 0
        count = 0
        for neighbour in neighbours(point):
            if neighbour[0] < 0 or neighbour[1] < 0: continue
            if neighbour[0] >= width or neighbour[1] >= height: continue
            if visited[neighbour[1]][neighbour[0]]: continue
            if pixels[neighbour] != color: continue
            count += 1
        return count

    origin = tuple(max(channel + 1 if channel == 255 else channel, 64) - 64 if i != 3 else channel for i, channel in
                   enumerate(color))
    origins = [(x, y) for x in range(width) for y in range(height) if pixels[x, y] == origin]
    for origin in origins:
        line = []
        v = origin
        while True:
            line.append(v)
            visited[v[1]][v[0]] = True
            points = neighbours(v)
            points = list(filter(lambda point: not visited[point[1]][point[0]], points))
            potential_next = list(filter(lambda point: pixels[point] == color, points))
            if len(potential_next) == 0:
                for point in points:
                    if count_neighbours(point) > 0:
                        potential_next.append(point)
                if len(potential_next) == 0: break
            v = max(potential_next, key=lambda point: count_neighbours(point))
        yield line
