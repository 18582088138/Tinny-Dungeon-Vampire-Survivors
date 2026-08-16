#!/usr/bin/env bash
# Thin wrapper around the Godot 4.7.1 CLI + the project's tooling.
# Exists because the engine lives at an awkward path (the download zip
# extracted into a *directory* literally named "...win64.exe").
#
#   tools/g.sh editor            open the Godot editor on this project
#   tools/g.sh run [frames]      headless run, auto-quit after N frames (default 120)
#   tools/g.sh play              windowed run (what a human would see)
#   tools/g.sh test [path]       GdUnit4 suite, headless (default res://tests)
#                                needs GdUnit4 installed into addons/ — not vendored here
#   tools/g.sh check             gdlint + gdformat --check + Godot parse check (every .gd)
#   tools/g.sh fmt               gdformat in place
#   tools/g.sh import            (re)import assets, refresh .godot/
#   tools/g.sh shot [outdir]     render frames to a dir (default reports/frames)
#   tools/g.sh setup-input       regenerate the [input] map in project.godot (WASD + arrows)
set -euo pipefail

GODOT_DIR="c:/Users/kundaxu/Downloads/Godot_v4.7.1-stable_win64.exe"
GODOT="$GODOT_DIR/Godot_v4.7.1-stable_win64_console.exe"  # console build: stdout is pipeable
PROJ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Pin the interpreter: there are 5+ pythons on PATH here (3.14, 3.13, 3.12, miniforge,
# 3.9) and gdtoolkit is installed only into 3.14's user site-packages. A bare `python`
# resolves correctly today but breaks the moment a conda env is activated.
PY="/c/Python314/python.exe"

[[ -x "$GODOT" ]] || { echo "Godot not found at: $GODOT" >&2; exit 1; }

# Strip ANSI colour so output is readable in logs / agent transcripts.
strip() { sed 's/\x1b\[[0-9;]*m//g'; }

# Source dirs to lint/format/parse — only the ones that actually exist, so removing
# a directory doesn't break `check`. addons/ is deliberately excluded (vendor code).
src_dirs() {
  local d found=()
  for d in scripts scenes tools tests; do
    [[ -d "$PROJ/$d" ]] && found+=("$d")
  done
  echo "${found[@]}"
}

cmd="${1:-check}"
shift || true

case "$cmd" in
editor)
  "$GODOT_DIR/Godot_v4.7.1-stable_win64.exe" --editor --path "$PROJ" "$@" &
  echo "editor launched (pid $!)"
  ;;
run)
  frames="${1:-120}"
  "$GODOT" --headless --path "$PROJ" --quit-after "$frames" 2>&1 | strip
  ;;
play)
  "$GODOT" --path "$PROJ" "$@" 2>&1 | strip
  ;;
test)
  target="${1:-res://tests}"
  # --ignoreHeadlessMode: GdUnit4 hard-refuses headless otherwise (exit 103).
  # --remote-debug to an unbound port: stops Godot dropping into its interactive
  # `debug>` prompt on a parse error, which would hang forever in CI/agent use.
  "$GODOT" --headless --path "$PROJ" -s -d --remote-debug tcp://127.0.0.1:0 \
    res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a "$target" 2>&1 | strip
  ;;
check)
  echo "--- gdlint ---"
  (cd "$PROJ" && "$PY" -m gdtoolkit.linter $(src_dirs))
  echo "--- gdformat --check ---"
  (cd "$PROJ" && "$PY" -m gdtoolkit.formatter --check $(src_dirs))
  echo "--- godot script parse check ---"
  # Parse every project script, not just one. gdlint catches style, only Godot
  # catches real GDScript type/API errors.
  (cd "$PROJ" && find $(src_dirs) -name '*.gd' 2>/dev/null) | while read -r gd; do
    "$GODOT" --headless --path "$PROJ" --check-only --script "res://$gd" 2>&1 |
      strip | grep -v "^Godot Engine v" | grep -v "^$" && echo "  ^ in $gd" && exit 1
  done
  echo "all checks passed"
  ;;
setup-input)
  # Regenerates the [input] section of project.godot. Idempotent.
  # The two "remote port / Unable to connect" errors are expected: port 0 is
  # deliberately unbound so Godot can't fall into its interactive debugger.
  "$GODOT" --headless --path "$PROJ" -s -d --remote-debug tcp://127.0.0.1:0 \
    res://tools/setup_input_map.gd 2>&1 | strip |
    grep -vE "remote port number|Unable to connect to host|at: (connect_to_host|create_tcp)"
  ;;
fmt)
  (cd "$PROJ" && "$PY" -m gdtoolkit.formatter $(src_dirs))
  ;;
import)
  "$GODOT" --headless --path "$PROJ" --import 2>&1 | strip | tail -5
  ;;
shot)
  # Godot 4.7 has no --screenshot flag. --write-movie with a .png path dumps a
  # numbered PNG per frame, so we render a few frames and keep the last one.
  outdir="${1:-$PROJ/reports/frames}"
  rm -rf "$outdir" && mkdir -p "$outdir"
  "$GODOT" --path "$PROJ" --quit-after 20 --fixed-fps 10 --write-movie "$outdir/f.png" 2>&1 | strip || true
  ls "$outdir" | tail -3
  ;;
*)
  sed -n '2,20p' "${BASH_SOURCE[0]}"
  exit 1
  ;;
esac
