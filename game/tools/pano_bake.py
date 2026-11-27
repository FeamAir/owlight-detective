#!/usr/bin/env python3
"""Second half of tools/render_panos.sh: cube faces → equirectangular panoramas, map, anchors → YAML.

Input: the directory written by art_src/render_panos.gd (<VP>_<face>.png, map.png, bake.json).
Output:
  game/assets/pano/<panorama>.jpg        equirect 2:1 (contract of scripts/core/pano_math.gd:
                                          u = 0.5 + yaw/360, v = 0.5 - pitch/180, centre = yaw 0)
  game/assets/map/map_grounds.jpg        top view of the zone, north up
  game/data/world/pano_anchors.yaml      yaw/pitch/size_deg of every hotspot, overlay and transition mark
                                          from the 3D scene + viewpoint headings and map positions
  game/data/world/hotspots.yaml, viewpoints.yaml   yaw/pitch/size_deg rewritten in place from the anchors
                                          (comments and layout kept; data_build.py checks they still match)

Usage: python3 game/tools/pano_bake.py --in DIR [--width 4096] [--quality 84] [--no-images]
"""
from __future__ import annotations

import argparse
import json
import math
import re
import sys
from pathlib import Path

import numpy as np
import yaml
from PIL import Image

GAME = Path(__file__).resolve().parent.parent
DATA = GAME / "data"
PANO_OUT = GAME / "assets" / "pano"
MAP_OUT = GAME / "assets" / "map"

# must match art_src/render_panos.gd FACES
FACES = {
    "front": ((0, 0, -1), (0, 1, 0)),
    "right": ((1, 0, 0), (0, 1, 0)),
    "back": ((0, 0, 1), (0, 1, 0)),
    "left": ((-1, 0, 0), (0, 1, 0)),
    "up": ((0, 1, 0), (0, 0, 1)),
    "down": ((0, -1, 0), (0, 0, -1)),
}

IMPORT_LOSSY = """[remap]

importer="texture"
type="CompressedTexture2D"

[params]

compress/mode=1
compress/lossy_quality=0.82
mipmaps/generate=false
"""


def cube_to_equirect(faces: dict[str, np.ndarray], width: int) -> np.ndarray:
    hgt = width // 2
    s = next(iter(faces.values())).shape[0]
    u = (np.arange(width, dtype=np.float32) + 0.5) / width
    v = (np.arange(hgt, dtype=np.float32) + 0.5) / hgt
    yaw = (u - 0.5) * 2.0 * math.pi
    pitch = (0.5 - v) * math.pi
    yaw, pitch = np.meshgrid(yaw, pitch)
    d = np.stack([np.sin(yaw) * np.cos(pitch), np.sin(pitch), -np.cos(yaw) * np.cos(pitch)], axis=-1)
    out = np.zeros((hgt, width, 3), dtype=np.float32)
    best = np.full((hgt, width), -np.inf, dtype=np.float32)
    for name, (f, up) in FACES.items():
        f = np.array(f, dtype=np.float32)
        up = np.array(up, dtype=np.float32)
        r = np.cross(f, up)
        z = d @ f
        mask = z > best
        best = np.where(mask, z, best)
        sel = mask & (z > 1e-6)
        if not sel.any():
            continue
        ds = d[sel]
        zs = z[sel]
        x = (ds @ r) / zs
        y = (ds @ up) / zs
        px = np.clip((x + 1.0) * 0.5 * s - 0.5, 0, s - 1.001)
        py = np.clip((1.0 - y) * 0.5 * s - 0.5, 0, s - 1.001)
        x0 = np.floor(px).astype(np.int32)
        y0 = np.floor(py).astype(np.int32)
        fx = (px - x0)[:, None]
        fy = (py - y0)[:, None]
        img = faces[name]
        c = (img[y0, x0] * (1 - fx) * (1 - fy) + img[y0, x0 + 1] * fx * (1 - fy)
             + img[y0 + 1, x0] * (1 - fx) * fy + img[y0 + 1, x0 + 1] * fx * fy)
        out[sel] = c
    return np.clip(out, 0, 255).astype(np.uint8)


def write_import(path: Path) -> None:
    imp = path.with_name(path.name + ".import")
    if not imp.exists():
        imp.write_text(IMPORT_LOSSY, encoding="utf-8")


# ------------------------------------------------------------------ YAML rewriting

NUM = r"-?\d+(?:\.\d+)?"


def fmt(x: float) -> str:
    r = round(x, 1)
    return str(int(r)) if r == int(r) else f"{r:.1f}"


def set_nums(line: str, vals: dict) -> str:
    for k, v in vals.items():
        line = re.sub(rf"(\b{k}:\s*){NUM}", lambda m: m.group(1) + fmt(v), line, count=1)
    return line


def rewrite_hotspots(text: str, anchors: dict) -> tuple[str, int]:
    out, n = [], 0
    cur_id = cur_vp = None
    for line in text.splitlines(keepends=True):
        m = re.match(r"\s*- id:\s*(HS-[\w-]+)", line)
        if m:
            cur_id, cur_vp = m.group(1), None
        m = re.match(r"\s*vp:\s*(VP-[\w-]+)", line)
        if m and cur_id:
            cur_vp = m.group(1)
        if cur_id and cur_vp and re.match(r"\s*pos:\s*\{", line):
            a = anchors.get(cur_vp, {}).get(cur_id)
            if a:
                new = set_nums(line, {"yaw": a["yaw"], "pitch": a["pitch"], "size_deg": a["size_deg"]})
                n += new != line
                line = new
        m = re.search(r"visible_from:\s*\[\s*\{\s*vp:\s*(VP-[\w-]+)", line)
        if m and cur_id:
            a = anchors.get(m.group(1), {}).get(cur_id)
            if a:
                new = set_nums(line, {"yaw": a["yaw"], "pitch": a["pitch"]})
                n += new != line
                line = new
        out.append(line)
    return "".join(out), n


def rewrite_viewpoints(text: str, anchors: dict) -> tuple[str, int]:
    out, n = [], 0
    cur = None
    for line in text.splitlines(keepends=True):
        m = re.match(r"\s*- id:\s*(VP-[\w-]+)", line)
        if m:
            cur = m.group(1)
        if cur:
            for m in re.finditer(r"\{\s*to:\s*(VP-[\w-]+)", line):
                a = anchors.get(cur, {}).get(f"exit:{cur}>{m.group(1)}")
                if a:
                    # only the part of the line belonging to this mapping
                    start = m.start()
                    end = line.find("}", start)
                    seg = set_nums(line[start:end], {"yaw": a["yaw"], "pitch": a["pitch"]})
                    if seg != line[start:end]:
                        n += 1
                    line = line[:start] + seg + line[end:]
            m = re.search(r"\{\s*id:\s*([\w-]+),\s*kind:", line)
            if m:
                a = anchors.get(cur, {}).get(m.group(1))
                if a:
                    new = set_nums(line, {"yaw": a["yaw"], "pitch": a["pitch"], "size_deg": a["size_deg"]})
                    n += new != line
                    line = new
        out.append(line)
    return "".join(out), n


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--in", dest="src", required=True)
    ap.add_argument("--width", type=int, default=4096)
    ap.add_argument("--quality", type=int, default=84)
    ap.add_argument("--no-images", action="store_true")
    args = ap.parse_args()
    src = Path(args.src)
    bake = json.loads((src / "bake.json").read_text(encoding="utf-8"))
    vps_yaml = yaml.safe_load((DATA / "world" / "viewpoints.yaml").read_text(encoding="utf-8"))["viewpoints"]
    pano_name = {v["id"]: v.get("panorama") for v in vps_yaml}

    anchors = {vp: e["anchors"] for vp, e in bake["viewpoints"].items()}
    problems = [f"{vp}: {aid} occluded by {a['occluded_by']}" for vp, e in anchors.items() for aid, a in e.items() if a["occluded_by"]]

    if not args.no_images:
        PANO_OUT.mkdir(parents=True, exist_ok=True)
        for vp in bake["viewpoints"]:
            faces = {}
            for f in FACES:
                p = src / f"{vp}_{f}.png"
                if not p.exists():
                    break
                faces[f] = np.asarray(Image.open(p).convert("RGB"), dtype=np.float32)
            if len(faces) != 6:
                continue
            name = pano_name.get(vp)
            if not name:
                print(f"warning: {vp} has no panorama in viewpoints.yaml, skipped")
                continue
            eq = cube_to_equirect(faces, args.width)
            dst = PANO_OUT / f"{name}.jpg"
            Image.fromarray(eq).save(dst, quality=args.quality, optimize=True, progressive=True)
            write_import(dst)
            print(f"{dst.relative_to(GAME)}  {eq.shape[1]}x{eq.shape[0]}  {dst.stat().st_size // 1024} KB")
        if (src / "map.png").exists():
            MAP_OUT.mkdir(parents=True, exist_ok=True)
            dst = MAP_OUT / "map_grounds.jpg"
            Image.open(src / "map.png").convert("RGB").save(dst, quality=86, optimize=True)
            write_import(dst)
            print(f"{dst.relative_to(GAME)}  {dst.stat().st_size // 1024} KB")

    # anchors file (generated; data_build.py reads it)
    doc = {"generated_by": "game/tools/render_panos.sh from game/art_src/slice01_blockout.tscn",
           "map": {"image": "map_grounds", **{k: bake["map"][k] for k in ("size_px", "center_m", "px_per_m")}},
           "viewpoints": {}}
    for vp, e in bake["viewpoints"].items():
        m = bake["map"]["viewpoints"].get(vp, {})
        doc["viewpoints"][vp] = {
            "heading": e["heading"], "interior": e["interior"],
            "map": {"u": m.get("u"), "v": m.get("v")},
            "anchors": {aid: {"yaw": a["yaw"], "pitch": a["pitch"], "size_deg": a["size_deg"]} for aid, a in sorted(e["anchors"].items())},
        }
    header = ("# GENERATED by game/tools/render_panos.sh (3D blockout game/art_src/slice01_blockout.tscn) — do not edit.\n"
              "# yaw/pitch/size_deg of hotspots, overlays and transition marks as seen from each viewpoint;\n"
              "# heading — world direction of the viewpoint's yaw 0 (clockwise from north); map — position on the zone map (0..1).\n"
              "# hotspots.yaml / viewpoints.yaml are rewritten from this file; data_build.py fails if they diverge.\n")
    (DATA / "world" / "pano_anchors.yaml").write_text(header + yaml.safe_dump(doc, allow_unicode=True, sort_keys=False, width=140), encoding="utf-8")

    hp = DATA / "world" / "hotspots.yaml"
    t, n1 = rewrite_hotspots(hp.read_text(encoding="utf-8"), anchors)
    hp.write_text(t, encoding="utf-8")
    vpp = DATA / "world" / "viewpoints.yaml"
    t, n2 = rewrite_viewpoints(vpp.read_text(encoding="utf-8"), anchors)
    vpp.write_text(t, encoding="utf-8")
    print(f"pano_anchors.yaml written; updated {n1} hotspot and {n2} viewpoint lines")
    for p in problems:
        print("OCCLUDED:", p)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
