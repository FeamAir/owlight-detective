#!/usr/bin/env bash
# Renders the slice 01 blockout (game/art_src/slice01_blockout.tscn) into:
#   game/assets/pano/pan_*.jpg          360° panoramas (equirect 2:1), one per viewpoint
#   game/assets/map/map_grounds.jpg     zone map (top view)
#   game/data/world/pano_anchors.yaml   yaw/pitch/size_deg of hotspots, overlays and transition marks from the 3D scene
# and rewrites yaw/pitch/size_deg in game/data/world/hotspots.yaml and viewpoints.yaml from the anchors.
#
#   game/tools/render_panos.sh                 full quality (cube faces 2048 → equirect 4096×2048, ~1 min)
#   game/tools/render_panos.sh --fast          preview (faces 768 → 2048×1024)
#   game/tools/render_panos.sh --if-stale      only if the blockout is newer than the panoramas (used by build_apk.sh)
#
# Needs: Godot 4.7.2 (GODOT), an OpenGL context — xvfb-run + Mesa (llvmpipe) is enough on a headless machine,
# Python 3 with numpy, Pillow, PyYAML. The results are committed (JPEG ≤ ~1.5 MB each), so the APK build
# does not need a GPU unless the blockout changed.
set -euo pipefail

GAME_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-godot}"
face=2048
width=4096
if_stale=0
for a in "$@"; do
  case "$a" in
    --fast) face=768; width=2048 ;;
    --if-stale) if_stale=1 ;;
    *) echo "unknown option $a"; exit 2 ;;
  esac
done

if [ "$if_stale" -eq 1 ]; then
  newest_src=$(stat -c %Y "$GAME_DIR"/art_src/*.gd "$GAME_DIR"/art_src/*.tscn | sort -n | tail -1)
  oldest_out=$(stat -c %Y "$GAME_DIR"/assets/pano/*.jpg "$GAME_DIR"/data/world/pano_anchors.yaml 2>/dev/null | sort -n | head -1 || echo 0)
  if [ -n "$oldest_out" ] && [ "$oldest_out" -ge "$newest_src" ]; then
    echo "panoramas are up to date"
    exit 0
  fi
  echo "blockout changed → re-rendering panoramas"
fi

OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT
run=("$GODOT" --path "$GAME_DIR" --rendering-driver opengl3 -s res://art_src/render_panos.gd -- "--out=$OUT" "--face=$face")
if [ -z "${DISPLAY:-}" ]; then
  command -v xvfb-run >/dev/null || { echo "no DISPLAY and no xvfb-run: cannot render (install xvfb + Mesa)"; exit 1; }
  run=(xvfb-run -a "${run[@]}")
fi
echo "== render blockout (faces ${face}px)"
"${run[@]}" >"$OUT/godot.log" 2>&1 || { tail -30 "$OUT/godot.log"; echo "RENDER FAILED"; exit 1; }
grep -E "^rendered|OCCLUDED|SCRIPT ERROR" "$OUT/godot.log" || true
if grep -q "SCRIPT ERROR" "$OUT/godot.log"; then tail -30 "$OUT/godot.log"; exit 1; fi
echo "== bake equirect ${width}×$((width / 2)), map, anchors"
python3 "$GAME_DIR/tools/pano_bake.py" --in "$OUT" --width "$width"
