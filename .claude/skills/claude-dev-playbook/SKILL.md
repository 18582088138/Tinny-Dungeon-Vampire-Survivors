---
name: claude-dev-playbook
description: >
  Cross-project development playbook for this user's workspace (C:\Users\kundaxu\Downloads\xkd —
  godot_project, FireFlyAI, HCD_project, Models, Multi-agent-app, PD_separate,
  VideoStreamSegmentation, etc.). Project-agnostic. Load this at the START of ANY development task
  for this user. It captures: (1) who the user is and how they like to work, (2) how to make Claude
  remember context across sessions (memory + per-project skills), (3) the plan-first / test-gated
  workflow, (4) how to keep token cost low, (5) quality practices, and (6) which harness features /
  MCP / hooks to use. For project-specific mechanics ALSO load that project's own skill — in
  godot_project that is `godot-verify` (build/lint/test/visual-verify loop).
---

# Claude dev playbook — how to work with this user

Distilled from real collaboration. Reuse across every project under `C:\Users\kundaxu\Downloads\xkd`.
This is the **general** layer; each project may have its own skill with concrete conventions — load both.

> **Path note:** the original draft of this playbook was written with the username `test`.
> This machine's user is **`kundaxu`**. All paths below are corrected and were verified on
> **2026-08-04**. Facts marked ⚠️ conflict with the original draft — trust the values here.

---

## 1. Who I'm working with (defaults, assume unless told otherwise)

**Communication**
- The user writes in **Chinese**; reply in Chinese. Code comments on core functions are **bilingual (中/英)**.
- The user is a hands-on developer: give recommendations, not option-surveys. When a decision is genuinely theirs, ask concisely (AskUserQuestion) — don't stall on defaults.
- Report outcomes honestly: if tests fail, show output; if a step was skipped, say so. No hedging, no "done" until verified.

**Environment (same machine across projects)**
- OS: **Windows 11 Enterprise**, shell is **Git Bash (POSIX sh)** — use `/dev/null`, forward slashes, `$VAR`.
- Python: **many interpreters are on PATH** (3.14, 3.13, 3.12, miniforge, 3.9). A bare `python`
  currently resolves to `C:\Python314\python.exe` (3.14.2), but that silently changes the moment a
  conda env is activated. **Always pin the full interpreter path in scripts.**
  - For ML/OpenVINO work use the existing conda env **`ov_env_py312`** (Python 3.12.13) — **do NOT create new envs**:
    ⚠️ `/c/Users/kundaxu/AppData/Local/miniforge3/envs/ov_env_py312/python.exe`
    (the original draft said `C:\Users\test\miniforge3\...` — wrong prefix *and* wrong user).
  - Avoid `conda run` (mangles `-c`). Avoid bare `py`/`PY` (hits the Windows launcher → base env → `ModuleNotFoundError`).
- Node: **v24.13.0** / npm 11.6.2. git 2.53.0. **No .NET SDK installed** — don't propose C# solutions.
- Hardware: Intel, with **iGPU (XPU)** available for accelerated inference (torch+xpu, OpenVINO). Prefer XPU/CPU paths; don't assume CUDA.
- **Corporate proxy** — ⚠️ two different values are live, don't hardcode one blindly:
  - shell env: `HTTP(S)_PROXY=http://proxy-dmz.intel.com:912`, `NO_PROXY=localhost,127.0.0.1,.intel.com`
  - `~/.claude/settings.json`: `http(s)_proxy=http://child-prc.intel.com:913`, `no_proxy=localhost,127.0.0.1`
  - Consequence is unchanged: any tool that spins a **localhost service** gets **403'd by the proxy**
    → **unset proxy + set NO_PROXY** for that subprocess. But **model/data downloads NEED the proxy ON**
    → pre-download with proxy ON, then run offline with proxy off.
  - Verified reachable through the proxy from Bash: github.com, npm registry, PyPI.
    ⚠️ **WebFetch to github.com is blocked** by enterprise policy — use `git`/`gh`/Bash instead.
- `code` on PATH resolves to **Cursor**, not VS Code. Real VS Code:
  `/c/Users/kundaxu/AppData/Local/Programs/Microsoft VS Code/bin/code`. They have different extension sets.
- Secrets (`.env`, API keys) are **git-ignored** — never commit or echo them.

**Constraints the user cares about**
- **Cost-conscious** — both API $ and token spend. Free-tier API quotas are small (e.g. OpenRouter free = ~50 req/day account-wide) → keep live API calls minimal; prefer local models / cached fixtures for iteration.
- **Privacy** — no PII in artifacts or VCS. Use running-index ids (S01/S02…), not names/filenames. Keep large/private data out of git.
- **Reproducibility** — every run has an exact, copy-pasteable command (full interpreter path, explicit flags).
- **Cross-platform intent** — develops on Windows but wants Linux compatibility kept.

---

## 2. How to make Claude remember (persistence protocol)

Context is lost between sessions unless written down. Two durable stores — use both deliberately.

**Memory (`<project>/memory/` or `~/.claude/projects/<slug>/memory/`)** — one fact per file + `MEMORY.md` index.
- Save: **decisions and their WHY**, project status/roadmap, environment facts verified, external refs (URLs/tickets), user preferences/feedback. Convert relative dates to absolute.
- Do NOT save: what the code/git already records, or what only matters to the current conversation.
- Keep a **"READ FIRST" one-page overview** memory per project (what/where/status/architecture/commands/gotchas).
- Before saving, check for an existing file to update instead of duplicating; delete memories proven wrong.
- Recalled memories are background context that reflects when they were written — **verify a named file/flag still exists before acting on it.** (This playbook is itself a case in point: 5 of its "already configured" claims were stale.)

**Per-project skill** — stable conventions for one project.
- Project-scoped (travels with the repo, survives clone): `<project>/.claude/skills/<name>/SKILL.md`
- User-scoped (cross-project): `~/.claude/skills/<name>/SKILL.md` ⚠️ this directory does **not** exist yet.
- Contents: tech stack (decided), environment, core principles, architecture, docs structure, **"hard-won lessons"** (bugs that cost time + their root cause), and a **cost discipline** section.
- Keep it **lean** — it's re-sent every turn it's active; high-signal only, prune stale lines.

**Why both:** memory = evolving facts/state; skill = stable how-we-work. When something surprising costs time, write the lesson to the skill so it's never rediscovered.

---

## 3. Workflow conventions

1. **Plan first for non-trivial work.** Use EnterPlanMode to explore + propose before writing code. Get sign-off on approach. Skip only for trivial/obvious edits.
2. **Test-gated modules.** After each module: write/upgrade the matching test, run it, and **tests must pass before moving on**. Keep a short test README noting method + expected output.
   - Python: `tests/test_<module>.py` (pytest). GDScript: `tests/<thing>_test.gd` (GdUnit4) — see `godot-verify`.
3. **Offline-first tests.** Default tests run with **zero network/API**. Mark live-LLM tests `@pytest.mark.live` and slow/real-heavy ones `@pytest.mark.slow`; both **skip gracefully** when unavailable. Save real tool outputs as **fixtures** so offline tests are deterministic.
4. **Reproducible problem logs.** Record issues in `docs/issues/` — categorized trackers (`track_{algorithm,frontend,backend,unit,e2e}.md`, IDs like `ALG/FE/BE/UT/E2E-NN`, status OPEN→DONE, cross-linked) + numbered research docs. Each issue: symptom + exact repro command + suspected location + suggested direction.
5. **Atomic, staged git commits.** One logical change per commit, dependency-ordered (config/deps → core → subsystems → tests → docs). Branch before committing on `main` for new workstreams. Commit/push **only when the user asks**. Recommend `.gitignore` for large/private/regenerable artifacts (datasets, vector DBs, generated reports, model weights) — keep only small fixtures + generators.
6. **Keep docs a single source of truth** with clear ownership per file (no duplication): stage summary, architecture diagrams, dev plan, tests, packaging, deployment, agents/prompts, data/RAG, API reference, issues.

---

## 4. Cost / token discipline (biggest lever on dev cost)

The main context is **re-sent every turn** — the longer it grows, the more every subsequent step costs. Optimize for a small, clean main context.

- **Delegate search & multi-file reading to subagents** (Explore / general-purpose). They read a lot internally but return only the **conclusion** to the main thread — big file dumps never pollute your context. This is the #1 saver on any real codebase. (Only when the user hasn't asked you to stay solo.)
- **Run only the tests relevant to what you changed** — `pytest tests/test_<module>.py -q` / `-k name` / `::test_fn`. Run the full offline suite **once at the end** as the final gate, not after every edit. Prefer `-q -x --no-header`; avoid `-v` unless diagnosing.
- **Don't re-read a file right after editing** (Edit/Write already confirm). **Don't re-run a passing test** to "double-check".
- **Read targeted line ranges** of large files when you know the region; Grep/Glob to locate first. Prefer the dedicated Read/Grep/Glob tools over `cat`/`grep`/`find` in Bash.
- **Batch independent tool calls in one turn** (parallel) instead of serial round-trips.
- **Strip ANSI colour and tail long CLI output** before it lands in context — Godot/GdUnit4 emit hundreds of coloured lines (`tools/g.sh` already does this).
- **Keep persistent context lean** — `CLAUDE.md`, active skills, `MEMORY.md` are all re-sent each turn. Trim ruthlessly.
- **`/compact` at task boundaries** (finishing one task, starting another) rather than letting context balloon to auto-compaction.
- **Model routing** — use **Haiku 4.5** for mechanical/boilerplate/large-mechanical edits; reserve **Opus** for hard reasoning. (`/fast` speeds Opus output but does NOT lower cost.)
- **Reuse fixtures** — never re-run an expensive tool (OCR, training, scraping) just to re-verify unchanged behavior.

---

## 5. Quality practices

- **Match surrounding code** — comment density, naming, idioms. Don't impose a new style.
- **Verify before claiming done** — run the scoped test; paste real output. If a memory/skill names a file or flag, confirm it still exists.
- **Don't trust a vendor's compatibility matrix or a doc's "already configured" claim — probe it.**
  Both burned us: GdUnit4's README stops at Godot 4.5.2 yet works on 4.7.1; this playbook claimed a
  statusline and an empty MCP config that didn't match reality.
- **Distrust exit codes on engines/tools that print errors and still exit 0** (Godot does). Grep the output.
- **Confirm before irreversible/outward-facing actions** (deletes, overwrites, pushes, sending data to external services). Approval in one context doesn't extend to the next.
- **For find→verify tasks, use an adversarial second pass** — a separate check that tries to *refute* a finding catches plausible-but-wrong conclusions. (A Workflow can fan this out when the user opts into multi-agent orchestration.)
- **State limitations plainly** — if a demo used hand-authored/mocked data, say so; never present a mock as a real result.

---

## 6. Harness / MCP / tooling to reach for

**Built-in harness features (use proactively):**
- **EnterPlanMode / ExitPlanMode** — design + sign-off before non-trivial builds.
- **Subagents (Agent tool)** — `Explore` for read-only search fan-out; `general-purpose` for multi-step research; keeps main context clean (see §4).
- **AskUserQuestion** — for genuine either/or decisions that change what you build; give a recommended option first.
- **TodoWrite** — track multi-step work so nothing is dropped and the user sees progress.
- **Skills + memory** — persistence (see §2).
- **Workflow** — deterministic multi-agent orchestration (fan-out review, migrate, research) **only when the user explicitly opts in** (it can spend a lot of tokens).
- **Git worktrees (EnterWorktree)** — isolated parallel work, only when the user asks.

**Settings / plugins worth adding (one-time, long-term savings):**
- **Cost/context statusline** — show live token usage / context %; keeps spend visible while developing. (`statusline-setup` agent can configure it.)
- **Hooks** — e.g. `PostToolUse` to truncate oversized command output before it hits context; guardrails against accidental destructive commands. (Note: hook output also enters context — keep it terse.)
- **MCP audit** — every connected MCP server's tool schemas cost context tokens per request. Connect **only what a project needs**; disable unused servers.

**Machine state, verified 2026-08-04 (supersedes the draft's 2026-07-30 claims):**
- ⚠️ **Statusline: NOT configured.** `~/.claude/statusline.py` does not exist and `~/.claude/settings.json`
  has no `statusLine` key (only `theme` + proxy). The draft said "already configured — don't redo"; that is
  false on this machine. Worth setting up, since §4 depends on watching `ctx %`.
- ⚠️ **MCP: no longer empty.** `godot_project/.mcp.json` registers **`godot`**
  (Coding-Solo/godot-mcp, 14 tools: launch_editor, run_project, get_debug_output, stop_project,
  get_godot_version, list_projects, get_project_info, create_scene, add_node, load_sprite,
  export_mesh_library, save_scene, get_uid, update_project_uids). It is project-scoped, so it costs
  nothing in other projects. Keep the "one server per real need" rule.
  - Known issue: it pins `@modelcontextprotocol/sdk@0.6.0`, which carries an unpatched high advisory.
    Upgrading is a breaking change. Local stdio only, no external input → accepted risk, not forgotten.
- ⚠️ **`~/.claude/skills/` does not exist** — there are no user-scoped skills yet. Everything installed
  so far is project-scoped under `godot_project/.claude/skills/`.

**When starting a new project for this user:**
1. Load this playbook + the project's own skill (if any).
2. Read the project's `MEMORY.md` "READ FIRST" overview.
3. Confirm environment (interpreter path, proxy behavior, tool paths) still holds — **probe, don't assume.**
4. Plan → implement module → scoped test → commit → repeat. Full suite as final gate.
5. Log surprises to the project skill's "hard-won lessons" and decisions to memory.

---

## 7. Game-dev layer (godot_project) — grows from here

This section is the extension point for game-development lessons. Mechanics live in the
**`godot-verify`** skill and `CLAUDE.md`; put *transferable* lessons here.

**Stack (decided):** Godot **4.7.1.stable**, **standard build — GDScript only, no C#/.NET**.
GdUnit4 v6.2.0 for tests, gdtoolkit 4.5.0 for lint/format, all driven through `tools/g.sh`.

**Hard-won lessons so far (2026-08-04, all verified by running them):**
- The Godot download zip extracted into a **directory whose name ends in `.exe`**; the real binaries are
  one level deeper. Every hand-written path missed this.
- Use the **`_console.exe`** build for anything whose stdout you need to capture; the GUI build is a
  Windows-subsystem binary and won't reliably write to a pipe.
- **GdUnit4 hard-refuses headless** (exit 103) without `--ignoreHeadlessMode`.
- A GDScript **parse error drops Godot into an interactive `debug>` prompt** and hangs a
  non-interactive run forever. Always pass `-d --remote-debug tcp://127.0.0.1:0` (an unbound port).
- **Godot 4.7 has no `--screenshot` flag.** Use `--write-movie out.png` + `--quit-after N` to dump a
  frame sequence, then Read the last frame. This is the only real visual-verification loop.
- **`--headless` exits 0 even when script errors were printed.** Grep for `SCRIPT ERROR|ERROR:|null instance`.
- Scope test discovery to `res://tests` — `addons/gdUnit4` ships ~1000 files including its own suite.
- gdtoolkit's `gdformat`/`gdlint` console scripts are **not on PATH**; invoke via
  `/c/Python314/python.exe -m gdtoolkit.{formatter,linter}`.

**Godot-specific style:** tabs not spaces; max line 100; static typing expected
(`warnings/untyped_declaration=1`); `gdformat` is authoritative — never hand-tune whitespace.
Avoid long assert chains in tests: gdformat reflows them into unreadable parenthesised blocks.
Collect failures into an array and assert once instead — the diagnostic is better anyway.

**Transferable lesson (2026-08-05): Godot's default failure mode is silence.**
Three separate misconfigurations (main scene pointing at the wrong sub-scene, a script not attached
to its node, an entirely absent input map) each produced **zero errors, zero warnings, exit code 0**
and a blank or inert window. `--check-only`, gdlint and a headless run were all green throughout.
- Consequence for tooling: lint/parse gates prove nothing about *wiring*. The only things that
  caught these were assertions on `ProjectSettings`, `PackedScene.instantiate().get_script()`, and
  `InputMap`. **Write wiring assertions, not just logic tests.**
- Consequence for debugging: when an engine reports nothing, stop reading code and start
  *resolving indirection* — uids to filenames, scene files to attached scripts, action names to the
  input map. The bug is almost always a broken reference, not broken logic.
- `uid://` references make this worse: a wrong uid is visually indistinguishable from a right one.
  Always resolve a uid to its file before trusting it.
- **Reproduce visually before fixing.** One `tools/g.sh shot` at the start proved the window was
  genuinely blank (not a focus/scale issue), which ruled out a whole branch of hypotheses for free.

**Generating engine config: let the engine serialize it.** Hand-writing Godot's
`Object(InputEventKey,"resource_local_to_scene":false,…)` blobs into `project.godot` is a trap.
Drive `ProjectSettings.set_setting()` + `ProjectSettings.save()` from a headless script instead
(`tools/setup_input_map.gd`) — the format is then correct by construction and re-runnable.
Do still diff the output: Godot 4.7's `InputEventKey.new()` defaults `device` to `16`, and a typed
`Array[InputEventKey]` serializes as `Array[InputEventKey]([…])` where the editor writes a bare
`[…]`. Both were normalised by hand after generation.

---

_Maintenance: this is a living document. When a new cross-project lesson emerges (something that would
apply to the NEXT project too), add it to §1–6; put game-specific detail in §7 or the `godot-verify` skill._
