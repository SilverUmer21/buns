# Small-patch implementation plan

Research precedes design/code decisions. Continue from the existing playable slice, preserve the original delivery snapshots, and verify each patch before pushing.

| Patch | Concrete outcome | Acceptance |
| --- | --- | --- |
| 01 · reliable handoff | HTTPS downloads with sizes/checksums and clear run steps | Actual GET/HEAD plus archive verification |
| 02 · research and agreement | Cited Play Store/article review, GDD and AGENTS.md | Facts distinguished from proposals; current vs planned content explicit |
| 03 · reproducible baseline | Character/prop sources, GLBs, Godot runtime, tests and authoring scripts in focused commits | Clean import, 48 baseline gameplay checks, GLB validation |
| 04 · expressive motion | Frame-consistent directional squash, crest/limb lag and smooth cancel | Actual driver replay at 30/60/120, positive scales/volume, existing physics unchanged |
| 05 · game flow | Title, board-first play, pause, result and honest trail; local progress and reduced motion | State/input transitions, pause/cancel/Undo/retry/save regressions; visual captures |
| 06 · platform review | Actual Godot screenshots/movie, signed Android APK and downloadable project | Export/signature/package verification; physical device review stated separately |
| 07 · content expansion | The other five puzzles, one at a time | Each gets a real solver fixture, fair provisional star targets and playtesting |

The active product direction is now the browser build in `web/`: six implemented puzzles, WebGL assets and motion, responsive layout, local progress, and captured browser frames. The previous Godot project and its checks remain as historical reference. Each patch records its behavior and validation. Optional stars, motion amplitude and sound need human playtesting; solver results and source research cannot establish their final tuning.

## Current owner-requested iteration

### Teardrop silhouette correction

1. Inspect the oval-producing radial expansion and review taper deformation references.
2. Replace pulled-side thickening with a tapered shoulder and narrow rounded tip while preserving the anchored bulb and face.
3. Review rendered all-tier weak/strong and multi-direction silhouettes, then check recoil, cancellation and recovery.
4. Keep physics fixtures passing; push a focused shape patch, publish the preview and refresh the verified browser ZIP.

### Tactile rework

1. Inspect rejected phone frames and current runtime; record the diagonal deformation defect and the weak silhouette/merge staging.
2. Replace the deformation basis and create distinct loaded, launch and recovery poses; add expressive character reactions and a pointer-linked elastic cue.
3. Replace shrink-away merging with readable contact, compressed new friend, reveal/hop and landing, without delaying physics or new actions.
4. Capture and compare actual browser frames at native mobile size and close-up; check diagonal input, reversal, cancel, both tiers and reduced motion. Run the existing physics, flow and render-schedule checks.
5. Push focused patches and evidence, publish the verified preview and refresh the HTTPS archive. The color/shine study remains deferred.

### Shot-to-celebration pass

1. Read and record primary animation and accessibility sources; distinguish research from Bunbreak-specific timing hypotheses. Set 45° as default/reset while preserving saved player choices and verify camera fit and aiming.
2. Tune continuous, directional pull/cancel and immediate launch with soft connected pose transitions, volume compensation, expression and staggered crest/limb follow-through. Preserve solver state, collision boundaries and responsive input.
3. Strengthen each tier's merge into an understandable gather, reveal and recovery; stage the escaping character's win through a joyful reaction, hop and landing without changing the timing of game-state completion or blocking recovery controls.
4. Inspect multi-frame actual browser captures of weak/strong pulls, launch, both merge tiers and the entire win at portrait/desktop. Exercise cancellation, mute, reduced motion, pause/Undo/retry and 30/60/120 schedules; run all six puzzle fixtures. Iterate if the evidence exposes problems.
5. Ship focused commits and update the live browser preview and download. Record what was really tested and explicitly leave physical-device feel and final subjective approval open. Reserve color/shine exploration for its own later pass.

### Earlier camera and fruit pass

1. **Research and GDD:** record sourced animation/camera findings, the owner's Pip benchmark and a precise plan. Mark Clash-inspired color/shine as a future study.
2. **Camera and scale:** add a pause-menu elevation slider (initial 35–75°) with live preview, value, persistence and default reset; refit the full board across phone and desktop. Freeze/cancel safely during a held pull or moving shot; validate ray-plane mapping, aim/goal overlay and unchanged solver outcomes at extremes.
3. **Character appeal:** preserve Pip, improve Berry/Mango's in-game shape, material depth, crest and expression; compare actual rendered close-up and gameplay views at phone size. Keep source/GLB editable or document any runtime shape change.
4. **Interactive motion:** make pull, release, impacts and cancel directional, expressive and time-consistent, combining volume-preserving body deformation with asymmetric lean and staggered limb/crest behavior. Keep face registration and colliders stable. Capture real frames rather than trusting stills or unit checks alone.
5. **Interaction feedback:** improve both merge tiers, jelly, gate and escape with staged, restrained visual/audio/character reactions; respect mute/reduced motion and simultaneous-contact correctness. Maintain responsive launch and deterministic physics.
6. **Verification and handoff:** run six solution fixtures and event/undo/pause tests at 30/60/120 render schedules; capture multiple angles and all event sequences in Chromium; test portrait/desktop, camera persistence and pointer mapping. Push small logical commits, update browser preview/download, and disclose pending physical-phone testing and subjective user review.

Deferred: a Clash-inspired material/color/shine study comes later, not as an unsolicited palette change in this patch.

Stop conditions: permission pending, failed export, unsupported device/rendering setup or a missing solved fixture must be stated precisely. Save logs/checkpoints and continue independent work. Never wait indefinitely on a shell command or label an unexecuted job successful.
