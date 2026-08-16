# godot_project

2D top-down **survivors-like arena roguelite** (auto-attacking abilities, move-only player,
level-up card picks). Playable prototype — see `README.md` for gameplay + architecture.

## Skills — load both at the start of a task

- **`claude-dev-playbook`** — cross-project layer: how this user works, environment facts
  (interpreter paths, proxy, tool locations), plan-first workflow, token discipline.
  §7 is the growing game-dev lessons section.
- **`godot-verify`** — this project's mechanics: the fmt → check → run → visual loop,
  and how to read Godot failures.

## Engine

Godot **4.7.1.stable** (`a13da4feb`), **standard build — not .NET/Mono**.
GDScript only. There is no .NET SDK on this machine, so do not propose C# solutions.

The download zip extracted into a *directory* whose name ends in `.exe`. The real
binaries are one level down — this trips up every path you write by hand:

```
c:/Users/kundaxu/Downloads/Godot_v4.7.1-stable_win64.exe/   <- directory
├── Godot_v4.7.1-stable_win64.exe                           <- GUI build (editor)
└── Godot_v4.7.1-stable_win64_console.exe                   <- console build (use for CLI/stdout capture)
```

Use the **console** build whenever output needs to be captured; the GUI build is a
Windows-subsystem binary and won't reliably write to a pipe.

## Commands

Always go through the wrapper — it hardcodes the awkward paths and the non-obvious flags:

```bash
tools/g.sh check          # gdlint + gdformat --check + Godot parse check  <- run before handing work back
tools/g.sh run [frames]   # headless run, auto-quit (default 120 frames)
tools/g.sh play           # windowed run
tools/g.sh fmt            # gdformat in place
tools/g.sh import         # reimport assets / rebuild .godot/
tools/g.sh editor         # open the Godot editor
tools/g.sh shot           # render frames to reports/frames/ (no --screenshot flag exists in Godot 4.7)
tools/g.sh test           # GdUnit4 — only works if you install the addon first (see below)
```

`-d --remote-debug tcp://127.0.0.1:0` is load-bearing and easy to lose: it stops Godot
dropping into its interactive `debug>` prompt on a parse error, which otherwise hangs a
non-interactive run forever.

**There is currently no test suite.** The old `tests/smoke_test.gd` asserted a layout
(`res://scenes/player/`) that the game has since outgrown; it was moved out to
`../_archive/godot_project_old_tests/` on 2026-08-16 and `addons/` was un-vendored.
`check` + `run` are the only gates right now — that means **wiring bugs are unguarded**,
so re-read `godot-verify`'s "it runs but nothing happens" section before debugging silence.
If tests come back: GdUnit4 hard-refuses headless (exit 103) without `--ignoreHeadlessMode`,
and discovery must be scoped to `res://tests` or it pulls in the framework's own ~800 files.

## Style

- **Tabs**, not spaces (Godot convention; `.vscode/settings.json` enforces it).
- Max line length **100** (gdformat default, matches `gdlintrc`).
- Static typing is expected: `warnings/untyped_declaration=1` is on in `project.godot`.
- `gdformat` is authoritative on formatting — don't hand-tune whitespace, just run `tools/g.sh fmt`.
- The existing gameplay code is **not** gdformat-clean (79 lint findings as of 2026-08-16:
  trailing whitespace, definition order, unused args). Deliberate — a blanket `fmt` would
  rewrite nearly every file. Format the files you touch, don't sweep the repo.

## Layout

```
scenes/autoload/     GameEvents bus — registered as an autoload in project.godot
scenes/component/    reusable behaviour: health / hitbox / hurtbox / vial_drop
scenes/game_object/  on-field entities: player, basic_enemy, experience_vial, game_camera
scenes/ability/      an ability + its controller, one folder each (sword, axe)
scenes/manger/       arena_time / enemy / experience / upgrade managers  [sic: "manger"]
scenes/ui/           experience_bar, arena_time_ui, upgrade_screen, ability_upgrade_card, end_screen
scenes/main/         the world scene — run/main_scene points here
resources/           TileSet + AbilityUpgrade .tres configs
assets/              art the game actually loads
tools/               g.sh wrapper + setup_input_map.gd
```

One folder per entity, co-locating `.tscn` + `.gd` + art. No central `scripts/`.
`tools/g.sh` lints whichever of `scripts scenes tools tests` exist, so adding any of
them later is picked up automatically.

**Not in git** (all gitignored, project runs without them): `addons/`, `TinnyDungeon/`
(raw Kenney pack — the used files were copied into `assets/`), `.godot/`, `reports/`,
`.mcp.json`, `.claude/settings.local.json`.

## Cross-scene conventions — follow these, don't invent new ones

- **Never hard-code a NodePath across scenes.** Look things up by global group:
  `player`, `enemy`, `entities_layer`, `foreground_layer` (declared in `project.godot`).
  Spawned entities go into `entities_layer`; ability VFX go into `foreground_layer`.
- **Cross-system notifications go through `GameEvents`** (`scenes/autoload/game_events.gd`),
  not direct references. Add a signal + an `emit_*` wrapper there.
- **Damage is component-mediated**: attacker gets a `HitboxComponent` carrying `damage`,
  target gets `HurtboxComponent` + `HealthComponent`. Never write `if is_player` branches.
- Managers wire their dependencies via `@export var ... : Node` + `node_paths` in the
  `.tscn`, so `main.tscn` is where the graph is assembled.

## Tooling notes

- `gdformat`/`gdlint` come from pip **gdtoolkit 4.5.0**. Its console scripts are **not on PATH**;
  invoke as `/c/Python314/python.exe -m gdtoolkit.formatter` / `.linter`.
- MCP server `godot` (Coding-Solo/godot-mcp, 14 tools) is registered in `.mcp.json` (untracked),
  built at `../godot-mcp/build/index.js`. Useful for `run_project` + `get_debug_output`.
  For plain file edits use the normal file tools, not the MCP.
- The `code` command on PATH resolves to **Cursor**, not VS Code. Real VS Code is at
  `/c/Users/kundaxu/AppData/Local/Programs/Microsoft VS Code/bin/code`.
