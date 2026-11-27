#!/usr/bin/env python3
"""
Generates Cyberpunk.otf (in ./assets/Cyberpunk.otf and ./sekaipop/assets/fonts/Cyberpunk.otf)
as a 50/50 hybrid combining chiseled Cyberpunk 2077 katana-blade facets, solid-filled
katana extensions, a flattened 2077 horizon rail, and a low-slung forward katana stance
with organic brush curves, corner lightning spikes, open angular counters, and a native
cubic-Bezier cross-hatched interior core, with all source identifying metadata stripped.
"""

import math
import os
import shutil
import struct
import subprocess

ROOT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC_OTF = os.path.join(ROOT_DIR, "tmp", "Sectar_SP.otf")
OUT_ASSETS_OTF = os.path.join(ROOT_DIR, "assets", "Cyberpunk.otf")
OUT_SHELL_OTF = os.path.join(ROOT_DIR, "sekaipop", "assets", "fonts", "Cyberpunk.otf")


def read_index(buf, pos):
    count = struct.unpack(">H", buf[pos : pos + 2])[0]
    pos += 2
    if count == 0:
        return [], pos
    off_size = buf[pos]
    pos += 1
    offsets = [
        int.from_bytes(buf[pos + i * off_size : pos + (i + 1) * off_size], "big")
        for i in range(count + 1)
    ]
    pos += (count + 1) * off_size
    data_start = pos - 1
    return [
        buf[data_start + offsets[i] : data_start + offsets[i + 1]]
        for i in range(count)
    ], data_start + offsets[-1]


def write_index(items):
    count = len(items)
    if count == 0:
        return struct.pack(">H", 0)
    data = b"".join(items)
    max_off = len(data) + 1
    if max_off <= 0xFF:
        off_size = 1
    elif max_off <= 0xFFFF:
        off_size = 2
    elif max_off <= 0xFFFFFF:
        off_size = 3
    else:
        off_size = 4
    out = bytearray(struct.pack(">HB", count, off_size))
    off = 1
    out.extend(off.to_bytes(off_size, "big"))
    for it in items:
        off += len(it)
        out.extend(off.to_bytes(off_size, "big"))
    out.extend(data)
    return bytes(out)


def parse_dict(buf):
    pos = 0
    stack = []
    d = []
    dmap = {}
    while pos < len(buf):
        b0 = buf[pos]
        if b0 <= 21:
            op = b0
            pos += 1
            if op == 12:
                op = (12, buf[pos])
                pos += 1
            d.append((op, list(stack)))
            dmap[op] = list(stack)
            stack = []
        elif b0 == 28:
            stack.append(struct.unpack(">h", buf[pos + 1 : pos + 3])[0])
            pos += 3
        elif b0 == 29:
            stack.append(struct.unpack(">i", buf[pos + 1 : pos + 5])[0])
            pos += 5
        elif b0 == 30:
            start = pos
            pos += 1
            while True:
                b = buf[pos]
                pos += 1
                if (b & 0xF) == 15 or (b >> 4) == 15:
                    break
            stack.append(("raw_float", buf[start:pos]))
        elif 32 <= b0 <= 246:
            stack.append(b0 - 139)
            pos += 1
        elif 247 <= b0 <= 250:
            stack.append((b0 - 247) * 256 + buf[pos + 1] + 108)
            pos += 2
        elif 251 <= b0 <= 254:
            stack.append(-(b0 - 251) * 256 - buf[pos + 1] - 108)
            pos += 2
    return d, dmap


def encode_dict_int(v):
    v = int(round(v))
    if -107 <= v <= 107:
        return bytes([v + 139])
    if 108 <= v <= 1131:
        v -= 108
        return bytes([(v >> 8) + 247, v & 0xFF])
    if -1131 <= v <= -108:
        v = -v - 108
        return bytes([(v >> 8) + 251, v & 0xFF])
    if -32768 <= v <= 32767:
        return struct.pack(">Bh", 28, v)
    return struct.pack(">Bi", 29, v)


def encode_dict(d_list):
    out = bytearray()
    for op, vals in d_list:
        for v in vals:
            if isinstance(v, tuple) and v[0] == "raw_float":
                out.extend(v[1])
            else:
                out.extend(encode_dict_int(v))
        if isinstance(op, tuple):
            out.extend(bytes([op[0], op[1]]))
        else:
            out.append(op)
    return bytes(out)


def encode_cs_num(v):
    iv = int(round(v))
    if abs(v - iv) < 1e-3:
        if -107 <= iv <= 107:
            return bytes([iv + 139])
        if 108 <= iv <= 1131:
            iv -= 108
            return bytes([(iv >> 8) + 247, iv & 0xFF])
        if -1131 <= iv <= -108:
            iv = -iv - 108
            return bytes([(iv >> 8) + 251, iv & 0xFF])
        if -32768 <= iv <= 32767:
            return struct.pack(">Bh", 28, iv)
    return struct.pack(">Bi", 255, int(round(v * 65536.0)))


def encode_charstring(contours, width_delta=None):
    out = bytearray()
    if width_delta is not None:
        out.extend(encode_cs_num(width_delta))
    cx = 0.0
    cy = 0.0
    for c in contours:
        if not c:
            continue
        for seg in c:
            kind = seg[0]
            if kind == "M":
                nx, ny = seg[1]
                dx = round(nx - cx)
                dy = round(ny - cy)
                cx += dx
                cy += dy
                out.extend(encode_cs_num(dx))
                out.extend(encode_cs_num(dy))
                out.append(21)
            elif kind == "L":
                nx, ny = seg[1]
                dx = round(nx - cx)
                dy = round(ny - cy)
                if dx == 0 and dy == 0:
                    continue
                cx += dx
                cy += dy
                out.extend(encode_cs_num(dx))
                out.extend(encode_cs_num(dy))
                out.append(5)
            elif kind == "C":
                (x1, y1), (x2, y2), (x3, y3) = seg[1], seg[2], seg[3]
                dx1 = round(x1 - cx)
                dy1 = round(y1 - cy)
                p1x = cx + dx1
                p1y = cy + dy1
                dx2 = round(x2 - p1x)
                dy2 = round(y2 - p1y)
                p2x = p1x + dx2
                p2y = p1y + dy2
                dx3 = round(x3 - p2x)
                dy3 = round(y3 - p2y)
                cx = p2x + dx3
                cy = p2y + dy3
                for val in (dx1, dy1, dx2, dy2, dx3, dy3):
                    out.extend(encode_cs_num(val))
                out.append(8)
    out.append(14)
    return bytes(out)


def sample_contour_poly(c, steps=5):
    pts = []
    cx, cy = 0.0, 0.0
    for seg in c:
        if seg[0] == "M":
            cx, cy = seg[1]
            pts.append((cx, cy))
        elif seg[0] == "L":
            cx, cy = seg[1]
            pts.append((cx, cy))
        elif seg[0] == "C":
            p0 = (cx, cy)
            p1, p2, p3 = seg[1], seg[2], seg[3]
            for s in range(1, steps + 1):
                t = s / steps
                mt = 1.0 - t
                x = (
                    mt**3 * p0[0]
                    + 3 * mt**2 * t * p1[0]
                    + 3 * mt * t**2 * p2[0]
                    + t**3 * p3[0]
                )
                y = (
                    mt**3 * p0[1]
                    + 3 * mt**2 * t * p1[1]
                    + 3 * mt * t**2 * p2[1]
                    + t**3 * p3[1]
                )
                pts.append((x, y))
            cx, cy = p3
    return pts


def poly_area_signed(pts):
    if len(pts) < 3:
        return 0.0
    a = 0.0
    n = len(pts)
    for i in range(n):
        x1, y1 = pts[i]
        x2, y2 = pts[(i + 1) % n]
        a += x1 * y2 - x2 * y1
    return 0.5 * a


def poly_to_contour(pts, ccw=False):
    is_ccw = poly_area_signed(pts) > 0
    if is_ccw != ccw:
        pts = list(reversed(pts))
    c = [("M", pts[0])]
    for p in pts[1:]:
        c.append(("L", p))
    c.append(("L", pts[0]))
    return c


def clip_poly_halfplane(pts, nx, ny, c_val):
    if not pts:
        return []
    out = []
    n = len(pts)
    for i in range(n):
        p1 = pts[i]
        p2 = pts[(i + 1) % n]
        d1 = nx * p1[0] + ny * p1[1] - c_val
        d2 = nx * p2[0] + ny * p2[1] - c_val
        if d1 >= 0:
            out.append(p1)
            if d2 < 0:
                t = d1 / (d1 - d2 + 1e-12)
                out.append(
                    (p1[0] + t * (p2[0] - p1[0]), p1[1] + t * (p2[1] - p1[1]))
                )
        elif d2 >= 0:
            t = d1 / (d1 - d2 + 1e-12)
            out.append(
                (p1[0] + t * (p2[0] - p1[0]), p1[1] + t * (p2[1] - p1[1]))
            )
    return out


def poly_minus_convex(subj_pts, clip_poly):
    if poly_area_signed(clip_poly) < 0:
        clip_poly = list(reversed(clip_poly))
    rem = list(subj_pts)
    pieces = []
    m = len(clip_poly)
    for i in range(m):
        if len(rem) < 3:
            break
        x1, y1 = clip_poly[i]
        x2, y2 = clip_poly[(i + 1) % m]
        dx, dy = x2 - x1, y2 - y1
        nx, ny = dy, -dx
        c_val = nx * x1 + ny * y1
        out_piece = clip_poly_halfplane(rem, nx, ny, c_val)
        if len(out_piece) >= 3 and abs(poly_area_signed(out_piece)) > 15.0:
            pieces.append(out_piece)
        rem = clip_poly_halfplane(rem, -nx, -ny, -c_val)
    return pieces


def carve_counter(contours, outer_hole_poly, rim_thickness=40.0, add_hole=True):
    cx = sum(p[0] for p in outer_hole_poly) / len(outer_hole_poly)
    cy = sum(p[1] for p in outer_hole_poly) / len(outer_hole_poly)
    inner_hole_poly = []
    for px, py in outer_hole_poly:
        dx = px - cx
        dy = py - cy
        dist = math.hypot(dx, dy) or 1.0
        scale = max(0.32, (dist - rim_thickness) / dist)
        inner_hole_poly.append((cx + dx * scale, cy + dy * scale))

    hx = [p[0] for p in outer_hole_poly]
    hy = [p[1] for p in outer_hole_poly]
    hxmin, hxmax, hymin, hymax = min(hx), max(hx), min(hy), max(hy)

    filtered = []
    for idx, c in enumerate(contours):
        if idx == 0:
            filtered.append(c)
            continue
        pts = sample_contour_poly(c, steps=5)
        if len(pts) < 3:
            continue
        px = [p[0] for p in pts]
        py = [p[1] for p in pts]
        if max(px) < hxmin or min(px) > hxmax or max(py) < hymin or min(py) > hymax:
            filtered.append(c)
            continue
        for piece in poly_minus_convex(pts, outer_hole_poly):
            filtered.append(poly_to_contour(piece, ccw=False))

    if add_hole:
        filtered.append(poly_to_contour(inner_hole_poly, ccw=False))
    return filtered


def reduce_all_spikes_and_chisel(contours):
    """
    1. Synchronized Spike Compression across ALL contours (outer + inner cross-hatch):
       - Computes the core letter body box [x_lo..x_hi, y_lo..y_hi] from contours[0]
         (using 12th..88th horizontal and 10th..90th vertical percentiles).
       - Compresses every outlier spike protruding outside that core body box by 56%
         horizontally (* 0.44) and 50% vertically (* 0.50) on BOTH contours[0] and
         contours[1..N] together, keeping spikes compact while preserving the organic
         brush texture.
    2. Outward-Only Thorn Shaver on contours[0] (CCW):
       - Shaves bushy side thorns (cross > 0) by 76% and sharp corner barbs by 38%
         into sleek chiseled 2077 edges while never filling inward V-crotches or mouths (cross <= 0).
    """
    if not contours:
        return contours
    pts0 = sample_contour_poly(contours[0], steps=2)
    if poly_area_signed(pts0) < 0:
        pts0 = list(reversed(pts0))
    n = len(pts0)
    if n < 12:
        return contours

    xs = sorted(p[0] for p in pts0)
    ys = sorted(p[1] for p in pts0)
    l_slices = [
        min(p[0] for p in pts0 if b <= p[1] <= b + 50)
        for b in range(50, 750, 50)
        if any(b <= p[1] <= b + 50 for p in pts0)
    ]
    med_l = sorted(l_slices)[len(l_slices) // 2] if l_slices else xs[int(n * 0.12)]

    x_lo = max(xs[int(n * 0.12)], med_l - 30.0)
    x_hi = xs[int(n * 0.88)]
    y_lo = ys[int(n * 0.10)]
    y_hi = ys[int(n * 0.90)]

    def compress_pt(x, y):
        if x < x_lo:
            x = x_lo - (x_lo - x) * 0.36
        elif x > x_hi:
            x = x_hi + (x - x_hi) * 0.44
        if y < y_lo:
            y = y_lo - (y_lo - y) * 0.50
        elif y > y_hi:
            y = y_hi + (y - y_hi) * 0.50
        return (x, y)

    contours = warp_glyph(contours, compress_pt)

    cur = [compress_pt(px, py) for px, py in pts0]
    for step_span in (1, 2, 3, 2, 1, 2, 1):
        nxt = []
        for i in range(n):
            p_prev = cur[(i - step_span) % n]
            p_cur = cur[i]
            p_next = cur[(i + step_span) % n]
            dx_c = p_next[0] - p_prev[0]
            dy_c = p_next[1] - p_prev[1]
            dx_p = p_cur[0] - p_prev[0]
            dy_p = p_cur[1] - p_prev[1]
            cross = dx_p * dy_c - dy_p * dx_c
            chord_len = math.hypot(dx_c, dy_c)
            if cross > 0 and chord_len < 220.0:
                mx = 0.5 * (p_prev[0] + p_next[0])
                my = 0.5 * (p_prev[1] + p_next[1])
                is_corner = (
                    p_cur[0] <= x_lo + 25
                    or p_cur[0] >= x_hi - 25
                    or p_cur[1] <= y_lo + 25
                    or p_cur[1] >= y_hi - 25
                )
                alpha = 0.38 if is_corner else 0.76
                nxt.append(
                    (
                        (1.0 - alpha) * p_cur[0] + alpha * mx,
                        (1.0 - alpha) * p_cur[1] + alpha * my,
                    )
                )
            else:
                nxt.append(p_cur)
        cur = nxt

    contours[0] = poly_to_contour(cur, ccw=True)
    return contours


READABLE_COUNTERS = {
    "zero": [[(285, 95), (565, 115), (715, 495), (665, 645), (410, 625), (245, 245)]],
    "four": [[(215, 255), (520, 265), (595, 515), (265, 345)]],
    "six": [[(235, 65), (525, 80), (605, 285), (345, 310), (195, 175)]],
    "eight": [
        [(375, 445), (655, 465), (725, 665), (475, 695), (335, 550)],
        [(215, 50), (535, 65), (615, 285), (335, 310), (175, 165)],
    ],
    "nine": [[(290, 375), (640, 395), (735, 635), (420, 660), (255, 495)]],
}


OPTICAL_PAD = {
    "C": 45,
    "Y": 30,
    "K": -35,
    "R": -25,
    "Q": -35,
    "L": -20,
    "A": 15,
    "D": 25,
    "E": 25,
    "S": 25,
}


def warp_contour(c, fn):
    out = []
    for seg in c:
        if seg[0] in ("M", "L"):
            out.append((seg[0], fn(*seg[1])))
        elif seg[0] == "C":
            out.append(("C", fn(*seg[1]), fn(*seg[2]), fn(*seg[3])))
    return out


def warp_glyph(contours, fn):
    return [warp_contour(c, fn) for c in contours]


def warp_glyph_differential(contours, fn, inner_weight=0.85):
    out = []
    for idx, c in enumerate(contours):
        w = 1.0 if idx == 0 else inner_weight

        def blended_fn(x, y, w=w):
            nx, ny = fn(x, y)
            return (x + w * (nx - x), y + w * (ny - y))

        out.append(warp_contour(c, blended_fn))
    return out


VERTICAL_TARGETS = {
    "B": (-166.0, 780.0),
    "C": (-162.0, 760.0),
    "D": (-164.0, 762.0),
    "F": (-174.0, 756.0),
    "K": (-172.0, 758.0),
    "L": (-165.0, 770.0),
    "P": (-174.0, 756.0),
    "Q": (-188.0, 756.0),
    "R": (-172.0, 758.0),
    "Y": (-174.0, 760.0),
    "FOUR": (-172.0, 752.0),
    "SEVEN": (-172.0, 752.0),
    "NINE": (-172.0, 752.0),
}


def transform_glyph_50_50(name, contours):
    if not contours:
        return contours

    # 1. De-slant horizontally (-0.22) AND level the raw upward-rightward brush tilt (-0.055)
    #    so the right side of letters (U, N, E, B, D, M) does not float above the left side.
    contours = warp_glyph(
        contours,
        lambda x, y: (x - 0.22 * (y - 350.0), y - 0.055 * (x - 450.0)),
    )

    # 2. Synchronized Spike Reduction (~50% smaller spikes) + Outward-Only Thorn Shaving
    contours = reduce_all_spikes_and_chisel(contours)

    # 3. Carve crisp open angular 2077 counters on numerals (0, 4, 6, 8, 9) while keeping native Sectar bowls on A-Z
    if name in READABLE_COUNTERS:
        adj_polys = [
            [(px - 0.22 * (py - 350.0), py - 0.055 * (px - 450.0)) for px, py in poly]
            for poly in READABLE_COUNTERS[name]
        ]
        for poly in adj_polys:
            contours = carve_counter(contours, poly, rim_thickness=30.0, add_hole=True)

    # 4. Moderate, well-proportioned 2077 Katana-Blade Warps + Baseline Leveling (inner_weight=0.85)
    uname = name.upper()
    if uname == "C":
        def fn(x, y):
            if x > 420 and y > 480:
                t = (x - 420) / 550.0
                return (x + 65 * t, y + 35 * t)
            if x > 360 and y < 240:
                t = (x - 360) / 550.0
                return (x + 60 * t, y - 25 * t)
            return (x, y)
        contours = warp_glyph_differential(contours, fn, inner_weight=0.85)
    elif uname == "Y":
        # Lift Y's upper V-arms so Y's top aligns with C and B, and keep a controlled lower stem
        def fn(x, y):
            if y > 420:
                t = (y - 420) / 360.0
                return (x, y + 55 * t)
            if y < 200:
                t = (200 - y) / 520.0
                return (x - 35 * t, y - 95 * t)
            return (x, y)
        contours = warp_glyph_differential(contours, fn, inner_weight=0.85)
    elif uname == "B":
        def fn(x, y):
            if y > 620 and x < 760:
                t = (y - 620) / 350.0
                return (x + 40 * t, y + 105 * t)
            return (x, y)
        contours = warp_glyph_differential(contours, fn, inner_weight=0.85)
    elif uname in ("P", "F"):
        def fn(x, y):
            if y < 180 and x < 420:
                t = (180 - y) / 580.0
                return (x - 35 * t, y - 95 * t)
            return (x, y)
        contours = warp_glyph_differential(contours, fn, inner_weight=0.85)
    elif uname == "R":
        def fn(x, y):
            if x > 400 and y < 240:
                t = ((x - 400) / 700.0) * ((240 - y) / 620.0)
                return (x + 110 * t, y - 115 * t)
            return (x, y)
        contours = warp_glyph_differential(contours, fn, inner_weight=0.85)
    elif uname == "K":
        def fn(x, y):
            if x > 420 and y < 260:
                t = ((x - 420) / 680.0) * ((260 - y) / 650.0)
                return (x + 130 * t, y - 120 * t)
            if x > 480 and y > 520:
                t = ((x - 480) / 620.0) * ((y - 520) / 420.0)
                return (x + 80 * t, y + 55 * t)
            return (x, y)
        contours = warp_glyph_differential(contours, fn, inner_weight=0.85)
    elif uname == "D":
        def fn(x, y):
            if y > 680 and x > 320:
                t = ((y - 680) / 340.0) * ((x - 320) / 650.0)
                return (x + 75 * t, y + 45 * t)
            if y < 60 and x < 120:
                t = (60 - y) / 450.0
                return (x - 40 * t, y - 65 * t)
            return (x, y)
        contours = warp_glyph_differential(contours, fn, inner_weight=0.85)
    elif uname == "U":
        # Ground U's bottom bowl (especially the center-right curve) so U sits full-height on the baseline
        def fn(x, y):
            if y < 280:
                ty = (280 - y) / 420.0
                tx = max(0.0, (x - 180) / 650.0)
                return (x, y - (45 + 55 * tx) * ty)
            return (x, y)
        contours = warp_glyph_differential(contours, fn, inner_weight=0.85)
    elif uname in ("V", "W"):
        def fn(x, y):
            if y < 240:
                ty = (240 - y) / 380.0
                return (x, y - 45 * ty)
            return (x, y)
        contours = warp_glyph_differential(contours, fn, inner_weight=0.85)
    elif uname == "N":
        # Ground N's floating right leg apex so both feet of N sit solidly on the baseline
        def fn(x, y):
            if x > 340 and y < 280:
                tx = (x - 340) / 520.0
                ty = (280 - y) / 400.0
                return (x, y - 95 * tx * ty)
            return (x, y)
        contours = warp_glyph_differential(contours, fn, inner_weight=0.85)
    elif uname in ("H", "L"):
        def fn(x, y):
            if y > 640 and x < 620:
                t = (y - 640) / 350.0
                return (x + 40 * t, y + 95 * t)
            return (x, y)
        contours = warp_glyph_differential(contours, fn, inner_weight=0.85)
    elif uname in ("Q", "X"):
        def fn(x, y):
            if x > 420 and y < 220:
                t = ((x - 420) / 680.0) * ((220 - y) / 600.0)
                return (x + 115 * t, y - 110 * t)
            return (x, y)
        contours = warp_glyph_differential(contours, fn, inner_weight=0.85)
    elif name in ("four", "seven", "nine"):
        def fn(x, y):
            if y < 120:
                t = (120 - y) / 460.0
                return (x - 45 * t, y - 95 * t)
            return (x, y)
        contours = warp_glyph_differential(contours, fn, inner_weight=0.85)

    # 5. Subtle 2077 top horizon rail levelling & balanced proportions
    out_final = []
    for idx, c in enumerate(contours):
        def stance_fn(x, y):
            if (
                uname
                in (
                    "E", "R", "P", "N", "D", "F", "G", "O", "Q", "S", "T", "U", "V", "W", "Z",
                    "ZERO", "TWO", "THREE", "FIVE", "SEVEN", "EIGHT", "NINE",
                )
                and y > 750
            ):
                y = 750.0 + (y - 750.0) * 0.42
            return (x * 0.96, y * 0.96)

        out_final.append(warp_contour(c, stance_fn))

    # 6. Per-Glyph Vertical Baseline & Cap-Line Alignment Normalization:
    #    Eliminates vertical drift across words ("CYBERP" vs "UNK") by mapping every letter
    #    and numeral to a consistent baseline and cap-line envelope.
    is_alpha = len(name) == 1 and name.isalpha()
    is_digit = uname in (
        "ZERO", "ONE", "TWO", "THREE", "FOUR", "FIVE", "SIX", "SEVEN", "EIGHT", "NINE",
    )
    if is_alpha or is_digit:
        pts_v = sample_contour_poly(out_final[0], steps=2)
        cur_ymin = min(p[1] for p in pts_v)
        cur_ymax = max(p[1] for p in pts_v)
        cur_h = cur_ymax - cur_ymin
        if cur_h > 100.0:
            default_target = (-160.0, 754.0) if is_alpha else (-155.0, 748.0)
            t_ymin, t_ymax = VERTICAL_TARGETS.get(uname, default_target)
            t_h = t_ymax - t_ymin
            out_final = warp_glyph(
                out_final,
                lambda x, y, cy0=cur_ymin, ch=cur_h, ty0=t_ymin, th=t_h: (
                    x,
                    ty0 + ((y - cy0) / ch) * th,
                ),
            )

    return out_final


def build_cmap_table(glyph_names):
    gid_map = {name: i for i, name in enumerate(glyph_names)}
    uni_to_name = {
        0x0020: "space",
        0x0021: "exclam",
        0x0022: "quotedbl",
        0x0023: "numbersign",
        0x0024: "dollar",
        0x0026: "ampersand",
        0x0027: "quotesingle",
        0x0028: "parenleft",
        0x0029: "parenright",
        0x002A: "asterisk",
        0x002B: "plus",
        0x002C: "comma",
        0x002D: "hyphen",
        0x002E: "period",
        0x0030: "zero",
        0x0031: "one",
        0x0032: "two",
        0x0033: "three",
        0x0034: "four",
        0x0035: "five",
        0x0036: "six",
        0x0037: "seven",
        0x0038: "eight",
        0x0039: "nine",
        0x003A: "colon",
        0x003B: "semicolon",
        0x003D: "equal",
        0x003F: "question",
        0x0040: "at",
        0x00A0: "space",
        0x20AC: "Euro",
    }
    for c in range(ord("A"), ord("Z") + 1):
        uni_to_name[c] = chr(c)
    for c in range(ord("a"), ord("z") + 1):
        uni_to_name[c] = chr(c)
    accent_fallbacks = {
        "A": [0x00C0, 0x00C1, 0x00C2, 0x00C3, 0x00C4, 0x00C5],
        "C": [0x00C7],
        "E": [0x00C8, 0x00C9, 0x00CA, 0x00CB],
        "I": [0x00CC, 0x00CD, 0x00CE, 0x00CF],
        "N": [0x00D1],
        "O": [0x00D2, 0x00D3, 0x00D4, 0x00D5, 0x00D6, 0x00D8],
        "U": [0x00D9, 0x00DA, 0x00DB, 0x00DC],
        "Y": [0x00DD],
        "a": [0x00E0, 0x00E1, 0x00E2, 0x00E3, 0x00E4, 0x00E5],
        "c": [0x00E7],
        "e": [0x00E8, 0x00E9, 0x00EA, 0x00EB],
        "i": [0x00EC, 0x00ED, 0x00EE, 0x00EF],
        "n": [0x00F1],
        "o": [0x00F2, 0x00F3, 0x00F4, 0x00F5, 0x00F6, 0x00F8],
        "u": [0x00F9, 0x00FA, 0x00FB, 0x00FC],
        "y": [0x00FD, 0x00FF],
    }
    for base, codes in accent_fallbacks.items():
        for cp in codes:
            uni_to_name[cp] = base

    cmap_pairs = sorted(
        (cp, gid_map[nm]) for cp, nm in uni_to_name.items() if nm in gid_map
    )

    segments = []
    for cp, gid in cmap_pairs:
        if (
            segments
            and segments[-1][1] + 1 == cp
            and segments[-1][2] + (cp - segments[-1][0]) == gid
        ):
            segments[-1] = (segments[-1][0], cp, segments[-1][2])
        else:
            segments.append((cp, cp, gid))
    segments.append((0xFFFF, 0xFFFF, 0))

    seg_count = len(segments)
    seg_count_x2 = seg_count * 2
    entry_sel = int(math.floor(math.log2(seg_count)))
    search_range = (1 << entry_sel) * 2
    range_shift = seg_count_x2 - search_range

    end_codes = b"".join(struct.pack(">H", s[1]) for s in segments)
    start_codes = b"".join(struct.pack(">H", s[0]) for s in segments)
    id_deltas = bytearray()
    for s in segments:
        delta = 0 if s[0] == 0xFFFF else (s[2] - s[0])
        id_deltas.extend(struct.pack(">H", delta & 0xFFFF))
    id_range_offsets = b"\x00\x00" * seg_count

    sub_len = 16 + 4 * seg_count_x2
    fmt4 = (
        struct.pack(
            ">HHHHHHH",
            4,
            sub_len,
            0,
            seg_count_x2,
            search_range,
            entry_sel,
            range_shift,
        )
        + end_codes
        + b"\x00\x00"
        + start_codes
        + bytes(id_deltas)
        + id_range_offsets
    )
    hdr = (
        struct.pack(">HH", 0, 2)
        + struct.pack(">HHI", 0, 3, 20)
        + struct.pack(">HHI", 3, 1, 20)
    )
    return hdr + fmt4


def build_name_table(family="Cyberpunk", subfamily="Regular"):
    full = f"{family} {subfamily}"
    ps = f"{family}-{subfamily}"
    records_data = [
        (1, family),
        (2, subfamily),
        (3, f"1.000;{ps}"),
        (4, full),
        (5, "Version 1.000"),
        (6, ps),
    ]
    entries = []
    str_pool = bytearray()
    for plat, enc, lang in [(1, 0, 0), (3, 1, 0x0409)]:
        for name_id, text in records_data:
            raw = (
                text.encode("utf-16-be")
                if plat == 3
                else text.encode("ascii", "replace")
            )
            off = len(str_pool)
            str_pool.extend(raw)
            entries.append((plat, enc, lang, name_id, len(raw), off))
    entries.sort()
    count = len(entries)
    storage_off = 6 + count * 12
    out = bytearray(struct.pack(">HHH", 0, count, storage_off))
    for plat, enc, lang, name_id, length, off in entries:
        out.extend(struct.pack(">HHHHHH", plat, enc, lang, name_id, length, off))
    out.extend(str_pool)
    return bytes(out)


def build_kern_and_gpos(pair_kerns):
    items = sorted((g1, g2, val) for (g1, g2), val in pair_kerns.items() if val != 0)
    n_pairs = len(items)
    entry_sel = int(math.floor(math.log2(max(1, n_pairs))))
    search_range = (1 << entry_sel) * 6
    range_shift = n_pairs * 6 - search_range
    sub_hdr = struct.pack(">HHHH", n_pairs, search_range, entry_sel, range_shift)
    sub_body = b"".join(struct.pack(">HHh", g1, g2, val) for g1, g2, val in items)
    sub_len = 6 + len(sub_hdr) + len(sub_body)
    kern_tbl = (
        struct.pack(">HH", 0, 1)
        + struct.pack(">HHH", 0, sub_len, 0x0001)
        + sub_hdr
        + sub_body
    )

    by_first = {}
    for g1, g2, val in items:
        by_first.setdefault(g1, []).append((g2, val))
    first_gids = sorted(by_first.keys())

    cov_bytes = struct.pack(">HH", 1, len(first_gids)) + b"".join(
        struct.pack(">H", g) for g in first_gids
    )
    pair_sets = []
    for g1 in first_gids:
        plist = by_first[g1]
        ps = struct.pack(">H", len(plist)) + b"".join(
            struct.pack(">Hh", g2, val) for g2, val in plist
        )
        pair_sets.append(ps)

    pp_hdr_size = 10 + 2 * len(first_gids)
    cov_off = pp_hdr_size
    cur_off = cov_off + len(cov_bytes)
    ps_offs = []
    for ps in pair_sets:
        ps_offs.append(cur_off)
        cur_off += len(ps)
    pairpos_sub = (
        struct.pack(">HHHHH", 1, cov_off, 0x0004, 0x0000, len(first_gids))
        + b"".join(struct.pack(">H", o) for o in ps_offs)
        + cov_bytes
        + b"".join(pair_sets)
    )

    lookup_tbl = struct.pack(">HHHH", 2, 0, 1, 8) + pairpos_sub
    lookup_list = struct.pack(">HH", 1, 4) + lookup_tbl

    feat_tbl = struct.pack(">HHH", 0, 1, 0)
    feat_list = struct.pack(">H4sH", 1, b"kern", 8) + feat_tbl

    lang_sys = struct.pack(">HHHH", 0, 0xFFFF, 1, 0)
    script_tbl = struct.pack(">HH", 4, 0) + lang_sys
    script_list = (
        struct.pack(">H4sH4sH", 2, b"DFLT", 14, b"latn", 14) + script_tbl
    )

    sl_off = 10
    fl_off = sl_off + len(script_list)
    ll_off = fl_off + len(feat_list)
    gpos_tbl = (
        struct.pack(">IHHH", 0x00010000, sl_off, fl_off, ll_off)
        + script_list
        + feat_list
        + lookup_list
    )
    return kern_tbl, gpos_tbl


def calc_checksum(buf):
    padded = buf + b"\x00" * ((4 - len(buf) % 4) % 4)
    s = 0
    for i in range(0, len(padded), 4):
        s = (s + struct.unpack(">I", padded[i : i + 4])[0]) & 0xFFFFFFFF
    return s


def main():
    with open(SRC_OTF, "rb") as f:
        orig_data = f.read()

    num_tables = struct.unpack(">H", orig_data[4:6])[0]
    tables = {}
    for i in range(num_tables):
        off = 12 + i * 16
        tag, chk, toff, tlen = struct.unpack(">4sIII", orig_data[off : off + 16])
        tables[tag.decode("ascii")] = orig_data[toff : toff + tlen]

    cff = tables["CFF "]
    hdr_size = cff[2]
    names, pos = read_index(cff, hdr_size)
    top_dicts, pos = read_index(cff, pos)
    strings, pos = read_index(cff, pos)
    global_subrs, pos = read_index(cff, pos)
    td_list, td = parse_dict(top_dicts[0])
    charset_off = td[15][0]
    charstrings_off = td[17][0]
    priv_size, priv_off = td[18]
    priv_list, priv = parse_dict(cff[priv_off : priv_off + priv_size])
    local_subrs, _ = read_index(cff, priv_off + priv[19][0])
    charstrings, _ = read_index(cff, charstrings_off)
    charset_bytes = cff[charset_off:charstrings_off]

    gbias = 107 if len(global_subrs) < 1240 else 1131
    lbias = 107 if len(local_subrs) < 1240 else 1131

    def decode_cs(cs):
        stack = []
        contours = []
        cur = []
        x = 0.0
        y = 0.0
        stems = 0
        have_width = False
        width_delta = None

        def run(buf):
            nonlocal x, y, cur, stems, have_width, width_delta
            pos = 0
            while pos < len(buf):
                b0 = buf[pos]
                if b0 == 28:
                    stack.append(struct.unpack(">h", buf[pos + 1 : pos + 3])[0])
                    pos += 3
                elif b0 == 255:
                    stack.append(
                        struct.unpack(">i", buf[pos + 1 : pos + 5])[0] / 65536.0
                    )
                    pos += 5
                elif 32 <= b0 <= 246:
                    stack.append(b0 - 139)
                    pos += 1
                elif 247 <= b0 <= 250:
                    stack.append((b0 - 247) * 256 + buf[pos + 1] + 108)
                    pos += 2
                elif 251 <= b0 <= 254:
                    stack.append(-(b0 - 251) * 256 - buf[pos + 1] - 108)
                    pos += 2
                else:
                    pos += 1
                    op = b0
                    if op == 12:
                        op = (12, buf[pos])
                        pos += 1
                    if op in (1, 3, 18, 23):
                        if not have_width and (len(stack) % 2 == 1):
                            width_delta = stack.pop(0)
                        have_width = True
                        stems += len(stack) // 2
                        stack.clear()
                    elif op in (19, 20):
                        if not have_width and (len(stack) % 2 == 1):
                            width_delta = stack.pop(0)
                        have_width = True
                        stems += len(stack) // 2
                        stack.clear()
                        pos += (stems + 7) // 8
                    elif op == 21:
                        if not have_width and len(stack) > 2:
                            width_delta = stack.pop(0)
                        have_width = True
                        if cur:
                            contours.append(cur)
                        dy = stack.pop()
                        dx = stack.pop()
                        x += dx
                        y += dy
                        cur = [("M", (x, y))]
                        stack.clear()
                    elif op == 4:
                        if not have_width and len(stack) > 1:
                            width_delta = stack.pop(0)
                        have_width = True
                        if cur:
                            contours.append(cur)
                        dy = stack.pop()
                        y += dy
                        cur = [("M", (x, y))]
                        stack.clear()
                    elif op == 22:
                        if not have_width and len(stack) > 1:
                            width_delta = stack.pop(0)
                        have_width = True
                        if cur:
                            contours.append(cur)
                        dx = stack.pop()
                        x += dx
                        cur = [("M", (x, y))]
                        stack.clear()
                    elif op == 5:
                        while len(stack) >= 2:
                            dx = stack.pop(0)
                            dy = stack.pop(0)
                            x += dx
                            y += dy
                            cur.append(("L", (x, y)))
                    elif op == 6:
                        horiz = True
                        while stack:
                            d = stack.pop(0)
                            if horiz:
                                x += d
                            else:
                                y += d
                            cur.append(("L", (x, y)))
                            horiz = not horiz
                    elif op == 7:
                        horiz = False
                        while stack:
                            d = stack.pop(0)
                            if horiz:
                                x += d
                            else:
                                y += d
                            cur.append(("L", (x, y)))
                            horiz = not horiz
                    elif op == 8:
                        while len(stack) >= 6:
                            dx1, dy1, dx2, dy2, dx3, dy3 = [
                                stack.pop(0) for _ in range(6)
                            ]
                            p1 = (x + dx1, y + dy1)
                            p2 = (p1[0] + dx2, p1[1] + dy2)
                            p3 = (p2[0] + dx3, p2[1] + dy3)
                            x, y = p3
                            cur.append(("C", p1, p2, p3))
                    elif op == 24:
                        while len(stack) >= 8:
                            dx1, dy1, dx2, dy2, dx3, dy3 = [
                                stack.pop(0) for _ in range(6)
                            ]
                            p1 = (x + dx1, y + dy1)
                            p2 = (p1[0] + dx2, p1[1] + dy2)
                            p3 = (p2[0] + dx3, p2[1] + dy3)
                            x, y = p3
                            cur.append(("C", p1, p2, p3))
                        dx = stack.pop(0)
                        dy = stack.pop(0)
                        x += dx
                        y += dy
                        cur.append(("L", (x, y)))
                    elif op == 25:
                        while len(stack) > 6:
                            dx = stack.pop(0)
                            dy = stack.pop(0)
                            x += dx
                            y += dy
                            cur.append(("L", (x, y)))
                        dx1, dy1, dx2, dy2, dx3, dy3 = [
                            stack.pop(0) for _ in range(6)
                        ]
                        p1 = (x + dx1, y + dy1)
                        p2 = (p1[0] + dx2, p1[1] + dy2)
                        p3 = (p2[0] + dx3, p2[1] + dy3)
                        x, y = p3
                        cur.append(("C", p1, p2, p3))
                    elif op == 26:
                        dx1 = stack.pop(0) if (len(stack) % 4 == 1) else 0
                        while len(stack) >= 4:
                            dy1, dx2, dy2, dy3 = [stack.pop(0) for _ in range(4)]
                            p1 = (x + dx1, y + dy1)
                            p2 = (p1[0] + dx2, p1[1] + dy2)
                            p3 = (p2[0], p2[1] + dy3)
                            x, y = p3
                            cur.append(("C", p1, p2, p3))
                            dx1 = 0
                    elif op == 27:
                        dy1 = stack.pop(0) if (len(stack) % 4 == 1) else 0
                        while len(stack) >= 4:
                            dx1, dx2, dy2, dx3 = [stack.pop(0) for _ in range(4)]
                            p1 = (x + dx1, y + dy1)
                            p2 = (p1[0] + dx2, p1[1] + dy2)
                            p3 = (p2[0] + dx3, p2[1])
                            x, y = p3
                            cur.append(("C", p1, p2, p3))
                            dy1 = 0
                    elif op == 30:
                        horiz = False
                        while len(stack) >= 4:
                            if not horiz:
                                dy1, dx2, dy2, dx3 = [stack.pop(0) for _ in range(4)]
                                dy3 = stack.pop(0) if len(stack) == 1 else 0
                                p1 = (x, y + dy1)
                                p2 = (p1[0] + dx2, p1[1] + dy2)
                                p3 = (p2[0] + dx3, p2[1] + dy3)
                            else:
                                dx1, dx2, dy2, dy3 = [stack.pop(0) for _ in range(4)]
                                dx3 = stack.pop(0) if len(stack) == 1 else 0
                                p1 = (x + dx1, y)
                                p2 = (p1[0] + dx2, p1[1] + dy2)
                                p3 = (p2[0] + dx3, p2[1] + dy3)
                            x, y = p3
                            cur.append(("C", p1, p2, p3))
                            horiz = not horiz
                    elif op == 31:
                        horiz = True
                        while len(stack) >= 4:
                            if horiz:
                                dx1, dx2, dy2, dy3 = [stack.pop(0) for _ in range(4)]
                                dx3 = stack.pop(0) if len(stack) == 1 else 0
                                p1 = (x + dx1, y)
                                p2 = (p1[0] + dx2, p1[1] + dy2)
                                p3 = (p2[0] + dx3, p2[1] + dy3)
                            else:
                                dy1, dx2, dy2, dx3 = [stack.pop(0) for _ in range(4)]
                                dy3 = stack.pop(0) if len(stack) == 1 else 0
                                p1 = (x, y + dy1)
                                p2 = (p1[0] + dx2, p1[1] + dy2)
                                p3 = (p2[0] + dx3, p2[1] + dy3)
                            x, y = p3
                            cur.append(("C", p1, p2, p3))
                            horiz = not horiz
                    elif op == 10:
                        run(local_subrs[int(stack.pop()) + lbias])
                    elif op == 29:
                        run(global_subrs[int(stack.pop()) + gbias])
                    elif op == 11:
                        return
                    elif op == 14:
                        if not have_width and len(stack) >= 1:
                            width_delta = stack.pop(0)
                        have_width = True
                        if cur:
                            contours.append(cur)
                        cur = []
                        return

        run(cs)
        if cur:
            contours.append(cur)
        return contours, width_delta

    glyph_names = (
        subprocess.check_output(["otfinfo", "-g", SRC_OTF], text=True)
        .strip()
        .splitlines()
    )

    orig_hmtx = tables["hmtx"]
    nominal_w = 909
    new_charstrings = []
    adv_widths = []
    lsbs = []
    bands = list(range(-120, 840, 40))
    core_bands = [b for b in bands if 120 <= b <= 660]
    glyph_slices = {}

    for gid, cs in enumerate(charstrings):
        gname = glyph_names[gid]
        orig_aw, orig_lsb = struct.unpack(">Hh", orig_hmtx[gid * 4 : gid * 4 + 4])
        if gname in (".notdef", "space"):
            new_charstrings.append(cs)
            adv_widths.append(orig_aw)
            lsbs.append(orig_lsb)
            continue

        contours, _ = decode_cs(cs)
        contours = transform_glyph_50_50(gname, contours)

        pts0 = sample_contour_poly(contours[0], steps=3)
        xmin_all = min(p[0] for p in pts0)
        xmax_all = max(p[0] for p in pts0)

        slices_raw = {}
        for b in bands:
            bpts = [p[0] for p in pts0 if b - 25 <= p[1] <= b + 65]
            if bpts:
                slices_raw[b] = (min(bpts), max(bpts))

        core_l = sorted(slices_raw[b][0] for b in core_bands if b in slices_raw)
        core_r = sorted(slices_raw[b][1] for b in core_bands if b in slices_raw)
        if core_l and core_r:
            avg_l = sum(core_l) / len(core_l)
            avg_r = sum(core_r) / len(core_r)
            opt_xmin = min(xmin_all + 70.0, 0.65 * xmin_all + 0.35 * avg_l)
            opt_xmax = max(xmax_all - 75.0, 0.65 * xmax_all + 0.35 * avg_r)
        else:
            opt_xmin, opt_xmax = xmin_all, xmax_all

        left_bearing = 24.0
        dx_shift = left_bearing - opt_xmin
        contours = warp_glyph(contours, lambda x, y, dx=dx_shift: (x + dx, y))

        span_opt = opt_xmax - opt_xmin
        adv = max(280, int(round(left_bearing + span_opt + 20.0)))
        wd_delta = adv - nominal_w

        new_charstrings.append(encode_charstring(contours, wd_delta))
        adv_widths.append(adv)
        lsbs.append(int(round(xmin_all + dx_shift)))
        glyph_slices[gid] = {
            b: (l + dx_shift, r + dx_shift) for b, (l, r) in slices_raw.items()
        }

    kern_gids = [
        gid
        for gid, nm in enumerate(glyph_names)
        if (len(nm) == 1 and nm.isalpha())
        or nm
        in (
            "zero",
            "one",
            "two",
            "three",
            "four",
            "five",
            "six",
            "seven",
            "eight",
            "nine",
        )
    ]
    pair_kerns = {}
    for g1 in kern_gids:
        sl1 = glyph_slices.get(g1)
        if not sl1:
            continue
        adv1 = adv_widths[g1]
        for g2 in kern_gids:
            sl2 = glyph_slices.get(g2)
            if not sl2:
                continue
            min_gap = 9999.0
            core_gaps = []
            for b1, (_, r1) in sl1.items():
                for db in (-40, 0, 40):
                    b2 = b1 + db
                    if b2 in sl2:
                        l2, _ = sl2[b2]
                        pen = 22.0 if db != 0 else 0.0
                        g = (adv1 + l2) - r1 + pen
                        if g < min_gap:
                            min_gap = g
                if b1 in core_bands and b1 in sl2:
                    core_gaps.append((adv1 + sl2[b1][0]) - r1)
            if not core_gaps:
                continue
            avg_core = sum(core_gaps) / len(core_gaps)
            shift_min = 74.0 - min_gap
            shift_core = 212.0 - avg_core
            desired = 0.65 * shift_min + 0.35 * shift_core
            safe_floor = 70.0 - min_gap
            kern = int(round(max(desired, safe_floor, -200.0)))
            if abs(kern) >= 10:
                pair_kerns[(g1, g2)] = kern

    kern_tbl, gpos_tbl = build_kern_and_gpos(pair_kerns)

    def rebuild_cff():
        hdr = cff[:hdr_size]
        name_idx = write_index([b"Cyberpunk-Regular"])
        clean_strings = [
            b"Euro",
            b"1.000",
            b"Cyberpunk",
            b"Cyberpunk Regular",
            b"Regular",
        ]
        strings_idx = write_index(clean_strings)
        gsubr_idx = write_index([])

        new_priv_list = [(op, vals) for op, vals in priv_list if op != 19]
        priv_bytes = encode_dict(new_priv_list)
        cs_idx = write_index(new_charstrings)

        td_bytes = top_dicts[0]
        for _ in range(4):
            prefix_len = (
                len(hdr)
                + len(name_idx)
                + len(write_index([td_bytes]))
                + len(strings_idx)
                + len(gsubr_idx)
            )
            new_charset_off = prefix_len
            new_cs_off = new_charset_off + len(charset_bytes)
            new_priv_off = new_cs_off + len(cs_idx)
            new_td_list = []
            for op, vals in td_list:
                if op == 1 or op == (12, 0):
                    continue
                elif op == 0:
                    new_td_list.append((0, [392]))
                elif op == 2:
                    new_td_list.append((2, [394]))
                elif op == 3:
                    new_td_list.append((3, [393]))
                elif op == 4:
                    new_td_list.append((4, [395]))
                elif op == 15:
                    new_td_list.append((15, [new_charset_off]))
                elif op == 17:
                    new_td_list.append((17, [new_cs_off]))
                elif op == 18:
                    new_td_list.append((18, [len(priv_bytes), new_priv_off]))
                elif op == 5:
                    new_td_list.append((5, [-850, -850, 2200, 1400]))
                else:
                    new_td_list.append((op, vals))
            td_bytes = encode_dict(new_td_list)

        return (
            hdr
            + name_idx
            + write_index([td_bytes])
            + strings_idx
            + gsubr_idx
            + charset_bytes
            + cs_idx
            + priv_bytes
        )

    tables["CFF "] = rebuild_cff()
    tables["name"] = build_name_table("Cyberpunk", "Regular")
    tables["cmap"] = build_cmap_table(glyph_names)
    tables["hmtx"] = b"".join(
        struct.pack(">Hh", adv_widths[i], lsbs[i]) for i in range(len(charstrings))
    )
    tables["kern"] = kern_tbl
    tables["GPOS"] = gpos_tbl

    if "OS/2" in tables:
        os2 = bytearray(tables["OS/2"])
        if len(os2) >= 62:
            os2[8:10] = b"\x00\x00"  # fsType = 0 (Installable)
            os2[58:62] = b"    "     # achVendID = blank
        tables["OS/2"] = bytes(os2)

    head = bytearray(tables["head"])
    head[4:8] = struct.pack(">I", 0x00010000)  # fontRevision = 1.0
    head[8:12] = b"\x00\x00\x00\x00"
    if len(head) >= 36:
        head[20:36] = b"\x00" * 16  # clear created (20..28) & modified (28..36)
    tables["head"] = bytes(head)

    tags = sorted(tables.keys())
    num_t = len(tags)
    entry_sel = int(math.floor(math.log2(num_t)))
    search_range = (1 << entry_sel) * 16
    range_shift = num_t * 16 - search_range

    header = bytearray(
        struct.pack(">4sHHHH", b"OTTO", num_t, search_range, entry_sel, range_shift)
    )
    dir_size = 12 + num_t * 16
    body = bytearray()
    records = []
    for tag in tags:
        tbuf = tables[tag]
        toff = dir_size + len(body)
        tlen = len(tbuf)
        tchk = calc_checksum(tbuf)
        records.append((tag, tchk, toff, tlen))
        body.extend(tbuf)
        body.extend(b"\x00" * ((4 - len(tbuf) % 4) % 4))

    for tag, tchk, toff, tlen in records:
        header.extend(struct.pack(">4sIII", tag.encode("ascii"), tchk, toff, tlen))

    otf_bytes = bytearray(header + body)
    total_chk = calc_checksum(otf_bytes)
    adj = (0xB1B0AFBA - total_chk) & 0xFFFFFFFF
    for tag, tchk, toff, tlen in records:
        if tag == "head":
            otf_bytes[toff + 8 : toff + 12] = struct.pack(">I", adj)
            break

    os.makedirs(os.path.dirname(OUT_ASSETS_OTF), exist_ok=True)
    os.makedirs(os.path.dirname(OUT_SHELL_OTF), exist_ok=True)
    with open(OUT_ASSETS_OTF, "wb") as f:
        f.write(otf_bytes)
    shutil.copyfile(OUT_ASSETS_OTF, OUT_SHELL_OTF)
    print(f"Generated {OUT_ASSETS_OTF} and {OUT_SHELL_OTF} ({len(otf_bytes)} bytes)")


if __name__ == "__main__":
    main()
