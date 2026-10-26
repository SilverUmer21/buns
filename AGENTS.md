# Bunbreak working agreement

## Start every task

1. Read this file, `docs/GDD.md`, `docs/PLAN.md`, the latest validation reports and the current source before editing. Inspect `git status`; preserve others' work.
2. Identify the player-visible problem and a small patch that fixes it. Research the relevant game design or engine behavior first. Open primary sources, actual store listings/screenshots or first-party documentation; record citations and separate observed evidence from design inference in `research/`. Never claim to have played a game when only reading its listing.
3. Tell the owner what you are doing. Continue useful independent work while a tool, download or optional answer is pending. Do not repeatedly request authorization already granted in the conversation.
4. Establish what is implemented and tested today. Do not present a concept image, Blender still, headless test, simulated frame rate or unrun export as a rendered/playtested game or physical-device evidence.

## Product rules

- This is a tactile flick-and-merge puzzle. Preserve responsive mouse/touch drag, immediate release, predictable planar physics, equal-tier merging, tier-based gate eligibility, unlimited attempts, Undo and Retry.
- Pip + Pip becomes Berry; Berry + Berry becomes Mango. Crests and scale identify tiers as well as color. Maximum-tier collisions do not invent a fourth tier.
- The board and buns dominate play. Use a compact game HUD, contextual teaching, purposeful pause/result/trail screens and a clear escape goal. Avoid persistent dashboard panels and explanatory marketing text during play. Buttons are appropriate when they serve play, recovery, settings or progression.
- Use bright soft dough colors, rounded silhouettes, readable faces and volume-preserving squash. Wobble belongs to visual rigs; it must never alter collider dimensions or shot solutions. Never delay the shot to finish an anticipation animation.
- Keep the camera calm during aiming. Provide mute and reduced motion; retain visible feedback. Stars are optional mastery, never a progress paywall. Do not add energy timers, ads, purchases or accounts without a product decision.

## Work in small patches

- Prefer one coherent behavior per commit: research/GDD, baseline assets, runtime, motion, game flow, content, platform build or validation. Push incrementally; do not dump source, binary archives and generated caches together.
- The owner authorized pushes to `SilverUmer21/buns`. Verify the remote and current branch, preserve existing history, and never force push. Use release assets or a dedicated downloads branch for distributable ZIP/PDF files; keep them off the source branch.
- Exclude `.godot/`, toolchains, private keys, local credentials, temporary logs, rendered movie intermediates and Blender backups. Keep editable authoring sources and compact exported assets.
- Before each push, review the diff and run checks appropriate to the change. Record what passed, which command produced it and what remains unverified. Use meaningful behavioral tests, not assertions that merely mirror code.

## Stalls and execution

- Launch long jobs with a short initial yield, retain their session/cell IDs, save logs and inspect progress. Keep the owner informed at least every 60 seconds of active work.
- Use bounded probes (~15–30s), bounded render/model units (~180s), downloads with connection/inactivity limits and bounded export jobs (~300s). A multi-stage job must expose stage progress and checkpoints.
- A pending permission review is not a running shell command; an inner `timeout` cannot stop it. Yield control before awaiting such calls so independent work and communication can continue. Do not repeatedly start the same blocked operation.
- On failure, inspect the actual error, retry once with a justified smaller/fixed path, then use a supported fallback or report the concrete blocker. Never bypass sandbox restrictions, configured proxies, TLS checks or network policy.

## Verify the game

- Run `godot --headless --editor --path godot --import` on a clean checkout, then the gameplay, motion and flow suites present under `godot/tests/`.
- Verify fixed-step replays across 30/60/120 render schedules; repeated and simultaneous contacts; merges; maximum-speed collisions; slow matching-tier gate contact; held pull; touch cancellation/focus loss; pause; Undo across merges/wins; Retry; saved progress and scene transitions.
- Review actual Godot footage and portrait/desktop captures. Inspect weak/strong release, held squash, oblique impacts, jelly, merge and escape. Keep report claims bounded to evidence.
- Build/sign/package checks complement actual Android device tests. Do not claim phone performance, touch feel, safe-area correctness or a target frame rate from headless desktop tests.
- Every handoff should give usable HTTPS download links, the Godot version/run steps, current test results and any concrete remaining limitations. Verify links and archive checksums; workspace file links alone are not sufficient for this owner.
