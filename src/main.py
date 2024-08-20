from PIL import Image
import math

defs = {
    "head": ((255, 0, 0, 255), True, False),
    "rarm": ((0, 255, 0, 255), False, True),
    "rleg": ((0, 0, 255, 255), False, True),
    "body": ((128, 0, 0, 255), True, False),
    "larm": ((0, 128, 0, 255), False, True),
    "lleg": ((0, 0, 128, 255), False, True),
}

pose = Image.open("pose.png")
skin_map = Image.open("skin-map.png")
skin = Image.open("skin.png").load()

width, height = pose.size
pose_pixels = pose.load()
skinmap_pixels = skin_map.load()

def neighbours(point):
    return [(x + point[0], y + point[1]) for x in range (-1, 2) for y in range (-1, 2) if (x, y) != (0, 0)]

def find_pose_bone(color):
    visited = []
    def count_neighbours(point, color):
        if visited[point[1]][point[0]]: return 0
        count = 0
        for neighbour in neighbours(point):
            if neighbour[0] < 0 or neighbour[1] < 0: continue
            if neighbour[0] >= width or neighbour[1] >= height: continue
            if visited[neighbour[1]][neighbour[0]]: continue
            if pose_pixels[neighbour] != color: continue
            count += 1
        return count

    origin = tuple(max(channel + 1 if channel == 255 else channel, 64) - 64 if i != 3 else channel for i, channel in enumerate(color))
    origin = [(x, y) for x in range(width) for y in range(height) if pose_pixels[x, y] == origin][0]

    line = []
    visited = [[False for x in range(width)] for y in range(height)]
    v = origin
    while True:
        line.append(v)
        visited[v[1]][v[0]] = True
        points = neighbours(v)
        points = filter(lambda point: point[0] >= 0 and point[1] >= 0 and point[0] < width and point[1] < height, points)
        points = list(filter(lambda point: not visited[point[1]][point[0]] and pose_pixels[point] == color, points))
        if len(points) == 0: break
        v = max(points, key=lambda point: count_neighbours(point, color))
    return line

def find_skinmap_blob(color):
    points = []
    for y in range(skin_map.size[1]):
        for x in range(skin_map.size[0]):
            if skinmap_pixels[x, y] == color: points.append((x, y))

    xmin = min(points, key=lambda point: point[0])[0]
    ymin = min(points, key=lambda point: point[1])[1]
    xmax = max(points, key=lambda point: point[0])[0]
    ymax = max(points, key=lambda point: point[1])[1]

    blob = [[None for x in range(xmax - xmin + 1)] for y in range(ymax - ymin + 1)]
    for point in points:
        blob[point[1] - ymin][point[0] - xmin] = point
    return blob

img = Image.new("RGBA", pose.size, (0, 0, 0, 0))
pixels = img.load()

def draw_line(a, b, color):
    if a == b:
        pixels[a] = color
        return
    step = (b[0] - a[0], b[1] - a[1])
    steps = int(max(abs(step[0]), abs(step[1])))
    step = (step[0] / steps, step[1] / steps)

    for i in range(steps + 1):
        pixels[round(a[0]), round(a[1])] = color
        a = (a[0] + step[0], a[1] + step[1])

for (key, (color, hstrips, endpoints)) in reversed(defs.items()):
    line = find_pose_bone(color)
    if endpoints: line.insert(0, (line[0][0], line[0][1] - 1))
    blob = find_skinmap_blob(color)
    last_row = None
    for (i, point) in enumerate(line):
        row = blob[round(i / len(line) * len(blob))]
        if hstrips:
            x_axis = (1, 0)
        else:
            dir = tuple(cl - cf for (cf, cl) in zip(
                line[i - 1] if i > 0 else point,
                line[i + 1] if i + 1 < len(line) else point,
            ))
            if abs(dir[0]) > abs(dir[1]): dir = (math.copysign(1, dir[0]), 0)
            elif abs(dir[1]) > abs(dir[0]): dir = (0, math.copysign(1, dir[1]))
            else: dir = (math.copysign(1, dir[0]), math.copysign(1, dir[1]))
            x_axis = (dir[1], -dir[0])

        offset = (
            (len(row) - 1) / 2 if len(row) % 2 == 1
            else len(row) / 2 - (1 if line[-1][0] > line[0][0] else 0)
        )
        row_coords = []
        for (i, pixel) in enumerate(row):
            coord = (point[0] + x_axis[0] * (i - offset), point[1] + x_axis[1] * (i - offset))
            row_coords.append(coord)
            if pixel != None:
                if hstrips:
                    pixels[coord] = skin[pixel] # color
                else:
                    draw_line(last_row[i] if last_row else coord, coord, skin[pixel]) # color
        if not hstrips and abs(dir[0]) == abs(dir[1]):
            points = sorted(zip(row_coords, row), key=lambda point: point[0][1])
            for (point, pixel) in points[:-1]:
                pixels[point[0], point[1] + 1] = skin[pixel] # color
            for (point, pixel) in points[1:]:
                pixels[point[0], point[1] - 1] = skin[pixel] # color
        last_row = row_coords


# draw_line(lines["head"], (255, 255, 255, 255))
# draw_line(lines["larm"])
# draw_line(lines["lleg"])
# draw_line(lines["body"])
# draw_line(lines["rleg"])
# draw_line(lines["rarm"])

# img.show()
img.save('image.png')
