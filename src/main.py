from PIL import Image
import math

from typedefs import *
from pose import find_bone as find_pose_bone
from skinmap import find_blob as find_skinmap_blob

defs = {
    "head": ((255, 0, 0, 255), True, False),
    "rarm": ((0, 255, 0, 255), False, True),
    "rleg": ((0, 0, 255, 255), False, True),
    "body": ((128, 0, 0, 255), True, False),
    "larm": ((0, 128, 0, 255), False, True),
    "lleg": ((0, 0, 128, 255), False, True),
}

pose = Image.open("pose.png")
skinmap = Image.open("skinmap.png")
skin = Image.open("skin.png").load()


def draw_line(pixels, a: IVec, b: IVec, color: Color):
    if a == b:
        pixels[a] = color
        return
    step = (b[0] - a[0], b[1] - a[1])
    steps = int(max(abs(step[0]), abs(step[1])))
    step = (step[0] / steps, step[1] / steps)

    for i in range(steps + 1):
        pixels[round(a[0]), round(a[1])] = color
        a = (a[0] + step[0], a[1] + step[1])


def process_frame(frame: Image) -> Image:
    img = Image.new("RGBA", frame.size, (0, 0, 0, 0))
    pixels = img.load()

    for (key, (color, h_strips, endpoints)) in reversed(defs.items()):
        line = find_pose_bone(frame, color)
        if endpoints: line.insert(0, (line[0][0], line[0][1] - 1))
        blob = find_skinmap_blob(skinmap, color)
        last_row = None
        for (i, point) in enumerate(line):
            row = blob[round(i / len(line) * len(blob))]
            if h_strips:
                normal = (0, 1)
            else:
                normal = tuple(cl - cf for (cf, cl) in zip(
                    line[i - 1] if i > 0 else point,
                    line[i + 1] if i + 1 < len(line) else point,
                ))
                if abs(normal[0]) > abs(normal[1]):
                    normal = (math.copysign(1, normal[0]), 0)
                elif abs(normal[1]) > abs(normal[0]):
                    normal = (0, math.copysign(1, normal[1]))
                else:
                    normal = (math.copysign(1, normal[0]), math.copysign(1, normal[1]))
            x_axis = (normal[1], -normal[0])

            offset = (
                (len(row) - 1) / 2 if len(row) % 2 == 1
                else len(row) / 2 - (1 if line[-1][0] > line[0][0] else 0)
            )
            row_cords = []
            for (i, pixel) in enumerate(row):
                coord = (point[0] + x_axis[0] * (i - offset), point[1] + x_axis[1] * (i - offset))
                row_cords.append(coord)
                if pixel:
                    if h_strips:
                        pixels[coord] = skin[pixel]  # color
                    else:
                        draw_line(pixels, last_row[i] if last_row else coord, coord, skin[pixel])  # color
            if not h_strips and abs(normal[0]) == abs(normal[1]):
                points = sorted(zip(row_cords, row), key=lambda point: point[0][1])
                for (point, pixel) in points[:-1]:
                    pixels[point[0], point[1] + 1] = skin[pixel]  # color
                for (point, pixel) in points[1:]:
                    pixels[point[0], point[1] - 1] = skin[pixel]  # color
            last_row = row_cords
    return img

img = process_frame(pose)
# img.show()
img.save('image.png')
