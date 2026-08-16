---
name: godot-verify
description: Build, lint, test, run, and visually verify this Godot 4.7.1 project. Use whenever a GDScript or scene change needs to be proven working — before reporting any Godot change as done, and whenever asked to run/play/screenshot the game or check that a scene loads.
---

# Verifying a change in this Godot project

Everything routes through `tools/g.sh`. Never call the Godot binary by hand — the engine
path contains a directory literally named `...win64.exe` and several flags are load-bearing.

## Standard loop after any GDScript/scene edit

Run in this order and stop at the first failure:

```bash
tools/g.sh fmt      # normalize formatting first, so lint errors are real errors
tools/g.sh check    # gdlint + gdformat --check + Godot parse check
tools/g.sh test     # GdUnit4, headless
tools/g.sh run 120  # headless boot — catches runtime errors gdlint can't see
```

`check` passing is necessary but weak: it only proves the scripts *parse*. A scene can parse
fine and still fail at runtime (missing node paths, null refs in `_ready`, bad resource
loads). `run` is what catches those, so don't skip it.

## Reading failures

- **`SCRIPT ERROR:` / `Attempt to call ... on a null instance`** in `run` output — runtime bug.
  Godot exits 0 even with script errors printed, so **grep the output**, don't trust the exit code:
  ```bash
  tools/g.sh run 120 2>&1 | grep -iE "SCRIPT ERROR|ERROR:|WARNING:|null instance"
  ```
- **Test run hangs** — a parse error dropped Godot into its interactive `debug>` prompt.
  `tools/g.sh test` already passes `--remote-debug tcp://127.0.0.1:0` to prevent this; if you
  invoked Godot directly instead, that's the cause.
- **Exit 103 from tests** — GdUnit4 refusing headless. Needs `--ignoreHeadlessMode`
  (the wrapper passes it).
- **New asset not found** — run `tools/g.sh import` to refresh `.godot/`.

## Visual verification

When the change is visual (layout, sprites, UI, shaders), text output proves nothing. Render
frames and actually look at one:

```bash
tools/g.sh shot            # writes reports/frames/f000000NN.png
```

Then Read the highest-numbered PNG. Early frames may be mid-initialization, so prefer the last.
Godot 4.7 has no `--screenshot` flag; this uses `--write-movie`, which needs a real window
(it will flash one open).

## "It runs but nothing happens" — check these first

Godot fails **silently** for all three of the most common setup mistakes. No error, no warning,
exit code 0. Check them in this order before debugging any logic:

1. **Is the right scene the main scene?**
   `run/main_scene` in `project.godot` is usually a `uid://…`, which is unreadable — a wrong value
   looks identical to a right one. Resolve it:
   ```bash
   grep main_scene project.godot          # then find which file owns that uid:
   grep -rl "<the-uid>" scenes/ --include=*.tscn
   ```
   Pointing it at a sub-scene (e.g. the player) instead of the world scene means F5 runs a bare
   actor at position (0,0) — top-left corner, usually clipped off-screen entirely.

2. **Is the script actually attached to the node?**
   A `.gd` file existing next to a `.tscn` proves nothing. The scene must contain a
   `script = ExtResource(...)` line on the node:
   ```bash
   grep -L "script =" scenes/**/*.tscn     # scenes with NO script attached anywhere
   ```
   An unattached script never runs and never errors.

3. **Do the input actions exist?**
   `Input.get_action_strength("move_left")` on an undefined action returns 0.0 forever.
   ```bash
   grep -A2 "^\[input\]" project.godot || echo "no input map at all"
   ```
   Regenerate with `tools/g.sh setup-input` (defines WASD + arrows). Never hand-write the
   `Object(InputEventKey,…)` blob — let Godot's serializer emit it.

Nothing above is caught by `check` or by a headless `run`; only the tests in `tests/smoke_test.gd`
assert them. Keep those assertions when you refactor.

## Writing tests

Suites live in `tests/` as `*_test.gd` extending `GdUnitTestSuite`. Wrap instantiated nodes in
`auto_free()` or GdUnit4 reports orphans. Scope runs to a single file while iterating:

```bash
tools/g.sh test res://tests/my_thing_test.gd
```

## Reporting back

State which of `check` / `test` / `run` actually ran and their results. If a visual change
went unverified because no frame was inspected, say so rather than implying it was checked.
