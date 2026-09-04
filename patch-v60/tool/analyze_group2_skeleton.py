"""Derive in-glyph centerlines from the approved PDF outline polygons.

This is a read-only audit helper: it prints Dart Offset lists and never edits
the generated template source.
"""

from __future__ import annotations

import heapq
import math
import re
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from skimage.morphology import skeletonize as skimage_skeletonize


SOURCE = Path("lib/features/lesson/writing/group2_fatha_templates.g.dart")
IDS = ("dal", "dhal", "raa", "zay", "seen")
BASE_GLYPHS = {
    "dal": "د",
    "dhal": "د",
    "raa": "ر",
    "zay": "ر",
    "seen": "س",
}


def body_data(text: str, letter_id: str):
    start = text.index(f"const {letter_id}FathaTemplate")
    end = min(
        [
            value
            for next_id in IDS
            if (value := text.find(f"const {next_id}FathaTemplate", start + 1)) >= 0
        ]
        or [len(text)]
    )
    block = text[start:end]
    body_start = block.index("id: 'body'")
    body_end = block.find("LetterTracePart(", body_start)
    if body_end < 0:
        body_end = len(block)
    body = block[body_start:body_end]
    outline_text = body.split("outline: [", 1)[1].split("],", 1)[0]
    center_text = body.split("centerline: [", 1)[1].split("],", 1)[0]
    pattern = r"Offset\((-?[\d.]+),\s*(-?[\d.]+)\)"
    outline = [(float(x), float(y)) for x, y in re.findall(pattern, outline_text)]
    center = [(float(x), float(y)) for x, y in re.findall(pattern, center_text)]
    aspect = float(re.search(r"aspectRatio:\s*([\d.]+)", block).group(1))
    return outline, center, aspect


def skeletonize(mask: np.ndarray) -> np.ndarray:
    return skimage_skeletonize(mask > 0)


def nearest_pixel(points: np.ndarray, target: tuple[float, float]):
    delta = points - np.asarray(target)
    return tuple(points[np.argmin(np.sum(delta * delta, axis=1))])


def shortest_path(skeleton: np.ndarray, start, end):
    height, width = skeleton.shape
    queue = [(0.0, start)]
    distance = {start: 0.0}
    parent = {}
    directions = (
        (-1, -1, math.sqrt(2)), (-1, 0, 1), (-1, 1, math.sqrt(2)),
        (0, -1, 1), (0, 1, 1),
        (1, -1, math.sqrt(2)), (1, 0, 1), (1, 1, math.sqrt(2)),
    )
    while queue:
        cost, current = heapq.heappop(queue)
        if current == end:
            break
        if cost != distance[current]:
            continue
        y, x = current
        for dy, dx, step in directions:
            other = (y + dy, x + dx)
            oy, ox = other
            if not (0 <= oy < height and 0 <= ox < width and skeleton[oy, ox]):
                continue
            next_cost = cost + step
            if next_cost < distance.get(other, float("inf")):
                distance[other] = next_cost
                parent[other] = current
                heapq.heappush(queue, (next_cost, other))
    if end not in distance:
        raise RuntimeError("Skeleton endpoints are disconnected")
    result = [end]
    while result[-1] != start:
        result.append(parent[result[-1]])
    result.reverse()
    return result


def rdp(points, epsilon):
    if len(points) < 3:
        return points
    start = np.asarray(points[0], dtype=float)
    end = np.asarray(points[-1], dtype=float)
    vector = end - start
    length = np.linalg.norm(vector)
    if length == 0:
        distances = [np.linalg.norm(np.asarray(point) - start) for point in points]
    else:
        distances = [
            abs(vector[0] * (point[1] - start[1]) - vector[1] * (point[0] - start[0]))
            / length
            for point in points
        ]
    index = int(np.argmax(distances))
    if distances[index] <= epsilon:
        return [points[0], points[-1]]
    return rdp(points[: index + 1], epsilon)[:-1] + rdp(points[index:], epsilon)


def derive(outline, old_center, aspect):
    scale = 1400
    margin = 24
    width = int(scale * aspect) + margin * 2
    height = scale + margin * 2
    polygon = np.asarray(
        [[margin + x * scale * aspect, margin + y * scale] for x, y in outline],
        dtype=np.int32,
    )
    mask = np.zeros((height, width), dtype=np.uint8)
    cv2.fillPoly(mask, [polygon], 255)
    skeleton = skeletonize(mask)
    to_pixel = lambda p: (margin + p[1] * scale, margin + p[0] * scale * aspect)
    _, labels = cv2.connectedComponents(skeleton.astype(np.uint8), connectivity=8)
    start_target = to_pixel(old_center[0])
    end_target = to_pixel(old_center[-1])
    candidates = []
    for label in range(1, labels.max() + 1):
        pixels = np.argwhere(labels == label)
        if len(pixels) < 8:
            continue
        start_pixel = nearest_pixel(pixels, start_target)
        end_pixel = nearest_pixel(pixels, end_target)
        penalty = np.linalg.norm(np.asarray(start_pixel) - np.asarray(start_target))
        penalty += np.linalg.norm(np.asarray(end_pixel) - np.asarray(end_target))
        candidates.append((penalty, pixels, start_pixel, end_pixel))
    _, pixels, start, end = min(candidates, key=lambda item: item[0])
    skeleton = labels == labels[start]
    path = shortest_path(skeleton, start, end)
    # Simplify only a little: dense straight segments keep every chord inside
    # the approved silhouette, including the three teeth of seen.
    path = rdp(path, 2.2)
    return [
        ((x - margin) / (scale * aspect), (y - margin) / scale)
        for y, x in path
    ], mask, skeleton, start, end


def derive_from_arial(letter_id, outline, old_center):
    font = ImageFont.truetype(r"C:\Windows\Fonts\arial.ttf", 1100)
    glyph = BASE_GLYPHS[letter_id]
    image = Image.new("L", (1600, 1600), 0)
    ImageDraw.Draw(image).text((120, 80), glyph, fill=255, font=font)
    raw = np.asarray(image)
    ys, xs = np.nonzero(raw)
    raw = raw[ys.min() : ys.max() + 1, xs.min() : xs.max() + 1]
    mask = (raw > 127).astype(np.uint8) * 255
    skeleton = skeletonize(mask)
    count, labels = cv2.connectedComponents(skeleton.astype(np.uint8), connectivity=8)
    label = max(range(1, count), key=lambda item: np.count_nonzero(labels == item))
    skeleton = labels == label
    pixels = np.argwhere(skeleton)
    ymin, ymax = min(y for _, y in outline), max(y for _, y in outline)
    xmin, xmax = min(x for x, _ in outline), max(x for x, _ in outline)
    height, width = skeleton.shape

    def target(point):
        x = (point[0] - xmin) / max(1e-9, xmax - xmin) * (width - 1)
        y = (point[1] - ymin) / max(1e-9, ymax - ymin) * (height - 1)
        return (y, x)

    # Prefer actual skeleton endpoints; a centerline must traverse the whole
    # glyph rather than stopping on a nearby spur.
    neighbours = cv2.filter2D(skeleton.astype(np.uint8), -1, np.ones((3, 3), np.uint8))
    endpoints = np.argwhere(skeleton & (neighbours == 2))
    if len(endpoints) < 2:
        endpoints = pixels
    start = nearest_pixel(endpoints, target(old_center[0]))
    remaining = endpoints[np.any(endpoints != np.asarray(start), axis=1)]
    end = nearest_pixel(remaining, target(old_center[-1]))
    path = shortest_path(skeleton, start, end)
    path = rdp(path, 2.0)
    result = []
    for y, x in path:
        result.append((
            xmin + x / max(1, width - 1) * (xmax - xmin),
            ymin + y / max(1, height - 1) * (ymax - ymin),
        ))
    return result


def derive_from_flutter_mask(letter_id, old_center, aspect):
    raw = cv2.imread(f"tmp/v58_masks/{letter_id}.png", cv2.IMREAD_GRAYSCALE)
    if raw is None:
        raise RuntimeError("Run test/v58_mask_export_test.dart first")
    mask = (raw > 127).astype(np.uint8) * 255
    skeleton = skeletonize(mask)
    count, labels = cv2.connectedComponents(skeleton.astype(np.uint8), connectivity=8)
    label = max(range(1, count), key=lambda item: np.count_nonzero(labels == item))
    skeleton = labels == label
    pixels = np.argwhere(skeleton)
    width = min(1600 * .82, 1000 * .88 * aspect)
    height = width / aspect
    left = (1600 - width) / 2
    top = (1000 - height) / 2

    def target(point):
        return (top + point[1] * height, left + point[0] * width)

    neighbours = cv2.filter2D(skeleton.astype(np.uint8), -1, np.ones((3, 3), np.uint8))
    endpoints = np.argwhere(skeleton & (neighbours == 2))
    if len(endpoints) < 2:
        endpoints = pixels
    normalized_endpoints = [
        ((x - left) / width, (y - top) / height) for y, x in endpoints
    ]
    print(f"{letter_id} endpoints: " + ", ".join(
        f"({x:.3f},{y:.3f})" for x, y in normalized_endpoints
    ))
    if letter_id == "seen":
        ordered_targets = [(0.95, .31), (.82, .36), (.56, .29), (.09, .42)]
        visits = [nearest_pixel(endpoints, target(point)) for point in ordered_targets]
        path = []
        for index in range(len(visits) - 1):
            segment = rdp(shortest_path(skeleton, visits[index], visits[index + 1]), 2.0)
            path.extend(segment if not path else segment[1:])
    else:
        start = nearest_pixel(endpoints, target(old_center[0]))
        remaining = endpoints[np.any(endpoints != np.asarray(start), axis=1)]
        end = nearest_pixel(remaining, target(old_center[-1]))
        path = rdp(shortest_path(skeleton, start, end), 2.0)
    return [((x - left) / width, (y - top) / height) for y, x in path]


def main():
    text = SOURCE.read_text(encoding="utf-8")
    for letter_id in IDS:
        outline, old_center, aspect = body_data(text, letter_id)
        path = derive_from_flutter_mask(letter_id, old_center, aspect)
        print(f"\n{letter_id}: {len(path)} points")
        print("centerline: [" + ",\n".join(
            f"Offset({x:.6f}, {y:.6f})" for x, y in path
        ) + "],")


if __name__ == "__main__":
    main()
