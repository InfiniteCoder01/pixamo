from PIL import Image
import math
import argparse

from pixamo.typedefs import *
from pixamo.pose import find_bone as find_pose_bone
from pixamo.skinmap import find_blob as find_skinmap_blob

defs = {
    "head": ((255, 0, 0, 255), True, False),
    "rarm": ((0, 255, 0, 255), False, True),
    "rleg": ((0, 0, 255, 255), False, True),
    "body": ((128, 0, 0, 255), True, False),
    "larm": ((0, 128, 0, 255), False, True),
    "lleg": ((0, 0, 128, 255), False, True),
}


def put_pixel(image: Image.Image, pixels, point: IVec, color: Color):
    if point[0] >= 0 and point[1] >= 0 and point[0] < image.size[0] and point[1] < image.size[1]:
        pixels[point] = color


def draw_line(image: Image.Image, pixels, a: IVec, b: IVec, color: Color):
    if a == b:
        pixels[a] = color
        return
    step = (b[0] - a[0], b[1] - a[1])
    steps = int(max(abs(step[0]), abs(step[1])))
    step = (step[0] / steps, step[1] / steps)

    for i in range(steps + 1):
        put_pixel(image, pixels, (round(a[0]), round(a[1])), color)
        a = (a[0] + step[0], a[1] + step[1])


def process_image(pose: Image, skinmap: Image, skin) -> Image:
    img = Image.new("RGBA", pose.size, (0, 0, 0, 0))
    pixels = img.load()

    for (key, (color, h_strips, endpoints)) in reversed(defs.items()):
        for line in find_pose_bone(pose, color):
            if line is None: continue
            if endpoints: line.insert(0, (line[0][0], line[0][1] - 1))
            blob = find_skinmap_blob(skinmap, color)

            def calculate_normal(index: int) -> IVec:
                normal = tuple(cl - cf for (cf, cl) in zip(
                    line[index - 1] if index > 0 else line[index],
                    line[index + 1] if index + 1 < len(line) else line[index]
                ))
                if abs(normal[0]) > abs(normal[1]):
                    return int(math.copysign(1, normal[0])), 0
                elif abs(normal[1]) > abs(normal[0]):
                    return 0, int(math.copysign(1, normal[1]))
                else:
                    return int(math.copysign(1, normal[0])), int(math.copysign(1, normal[1]))

            last_row = None
            last_normal = None
            next_normal = calculate_normal(0)
            for (i, point) in enumerate(line):
                row = blob[round(i / len(line) * len(blob))]
                if h_strips:
                    normal = (0, 1)
                else:
                    normal = next_normal
                    next_normal = calculate_normal(i + 1) if i + 1 < len(line) else normal
                    if last_normal == next_normal and abs(last_normal[0]) != abs(last_normal[1]):
                        normal = last_normal
                    last_normal = normal
                x_axis = (normal[1], -normal[0])

                if not h_strips and abs(normal[0]) == abs(normal[1]) and len(row) > 3:
                    new_length = round(len(row) / math.sqrt(2))
                    row = [row[round(i / new_length * len(row))] for i in range(new_length)]

                offset = (
                    (len(row) - 1) / 2 if len(row) % 2 == 1
                    else len(row) / 2 - (1 if line[-1][0] > line[0][0] else 0)
                )
                row_cords = []

                def pixel_color(pixel: IVec) -> Color:
                    if skin is not None:
                        return skin[pixel]
                    else:
                        return pixel + (0, 255)

                for (i, pixel) in enumerate(row):
                    coord = (point[0] + x_axis[0] * (i - offset), point[1] + x_axis[1] * (i - offset))
                    row_cords.append(coord)
                    if pixel:
                        # put_pixel(img, pixels, coord, pixel_color(pixel))
                        if h_strips:
                            put_pixel(img, pixels, coord, pixel_color(pixel))
                        else:
                            draw_line(img, pixels, last_row[round(i / len(row) * len(last_row))] if last_row else coord,
                                      coord, pixel_color(pixel))
                if not h_strips and abs(normal[0]) == abs(normal[1]):
                    points = sorted(zip(row_cords, row), key=lambda point: point[0][1])
                    for (point, pixel) in points[:-1]:
                        put_pixel(img, pixels, (point[0], point[1] + 1), pixel_color(pixel))
                    for (point, pixel) in points[1:]:
                        put_pixel(img, pixels, (point[0], point[1] - 1), pixel_color(pixel))
                last_row = row_cords
    return img

def main():
    parser = argparse.ArgumentParser(
        prog='pixamo',
        description='Generates sprites from pixel art skeleton')

    parser.add_argument('pose_file')
    parser.add_argument('skinmap_file')
    parser.add_argument('-s', '--skin')
    parser.add_argument('-o', '--output')
    args = parser.parse_args()

    pose = Image.open(args.pose_file)
    skinmap = Image.open(args.skinmap_file)
    skin = Image.open(args.skin).load() if args.skin is not None else None

    img = process_image(pose, skinmap, skin)
    # img.show()
    img.save(args.output if args.output is not None else 'image.png')

if __name__ == '__main__':
    main()
