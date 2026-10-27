# Bunbreak · Sunshine Kitchen

A bright 3D flick-and-merge puzzle. Pick a round little bun, pull backwards, hold and release. Merge friends, crack the matching wafer and escape onto the plate.

## Play in your browser

[Open the Bunbreak browser preview](https://bunbreak-wobble-kitchen.sunlitbun1.chatgpt.site). The preview is private to the project owner. Select a bun, pull backwards, and release. Pause gives access to Undo, Retry, Show me, sound and reduced motion. The kitchen trail contains six puzzles and saves progress locally.

To run the web game locally, use `cd web && npm run serve`, then open `http://localhost:4173` in a WebGL-capable browser. `node --test web/tests/*.test.mjs` runs its physics and level tests. All six stages have actual physics solution fixtures; star thresholds remain provisional pending human playtesting.

## Earlier Godot downloads

- [Updated v0.3 Godot project](https://raw.githubusercontent.com/SilverUmer21/buns/downloads/Bunbreak-v0.3-godot.zip) — Godot 4.6.3 Standard; unzip, import `project.godot`, press F5.
- [All current source](https://github.com/SilverUmer21/buns/archive/refs/heads/main.zip) — editable Blender files, authoring and tests; import `godot/project.godot`.
- [Previous visual review PDF](https://raw.githubusercontent.com/SilverUmer21/buns/downloads/Bunbreak-v2-review.pdf) — actual Blender models and evaluated poses, predating the v0.3 HUD; not a Godot screenshot.
- [Baseline downloads and verification](docs/DOWNLOADS.md).

The Godot downloads are earlier single-level snapshots. Active web development, including the six-level trail, lives under `web/`.

## What changed

- Round cream, strawberry and mango buns with eight named clips each and editable 11-bone rigs.
- Directional jiggle, smooth held squash/cancel, and delayed crest/limb follow-through. Visual spring updates agree across 30/60/120 render schedules; collision shapes remain stable.
- A title with Play, board-first HUD, pause settings, earned wafer stars, result/replay and an honest kitchen trail. Recipe/marketing panels are removed from play.
- Undo, Retry, actual-physics aiming, a verified Show me solution, mute, reduced motion and local progress/settings. Demonstrations award no completion rewards.

## Checks

**48 gameplay + 56 motion + 35 flow checks pass locally**, with eight GLB exports validated independently. Reports live under `reports/`. CI repeats a clean import and the suites, removing old reports first so stale results cannot pass.

```sh
. authoring/environment.sh
godot --headless --editor --path godot --import
godot --headless --path godot --script tests/validate_game.gd
godot --headless --path godot --script tests/validate_motion.gd
godot --headless --path godot --script tests/validate_flow.gd
python3 authoring/validate_glb.py
```

Passing headless checks does not establish visual polish, measured phone frame rate or tactile input quality. The browser build has also been inspected in actual Chromium frame captures. A physical phone playtest and performance measurement remain pending. An intermittent baseline Godot ObjectDB-at-exit warning remains under review.

## Design and source

- [Game design document](docs/GDD.md)
- [Cited Play Store and game design research](research/game-ui-research.md)
- [Small-patch plan](docs/PLAN.md)
- [Agent startup and execution rules](AGENTS.md)

Blender sources are in `blend/`; GLBs are in `exports/` and `godot/assets/`. The fixed planar solver is independent of visual deformation. No original prototype source ZIP was supplied; this is a new implementation of the handoff rules. Commercial references were researched through listings/screenshots/articles, not installed and played. No commercial game assets are reused.
