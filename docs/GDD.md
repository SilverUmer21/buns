# Bunbreak · Sunshine Kitchen

Status: living design, 2026-10-27. Active game: browser and Three.js WebGL with Blender 4.3.2 authoring and GLB assets; the earlier Godot 4.6.3 project is retained as a reference. Audience: broad; no age group inferred from colors. The original prototype source was not supplied, so the current solver is a new implementation of the handoff rules.

## Player promise

Pick a soft little bun, pull backwards and let it boing. Match friends into a bigger, brighter bun, break the right wafer and escape onto the plate. The challenge is spatial reasoning and shot control. Expressive reactions make each action satisfying without making outcomes unpredictable.

## Core rules and controls

Two cream Pips merge into a pink Berry; two Berries merge into a golden Mango. Different tiers and Mango/Mango pairs bounce. Size and crest distinguish tiers as well as color. A matching-tier gate opens on contact, including very slow contact; speed is not a hidden eligibility requirement.

Mouse and touch use the same select/pull/hold/release interaction. The bun holds its squash while aiming; shot physics starts immediately on release. A trajectory cue is simulated by the same solver. Releasing outside the board, canceling a touch or losing focus cancels the shot. Unlimited attempts, pre-shot Undo and Retry support experimentation. Tap-to-aim remains a later accessibility option, not a current claim.

## Presentation and player flow

Title → Play → aim/resolve → escape celebration → result → replay/trail. Pause is a small overlay with recovery and settings. Gameplay uses a board-first composition, a small stage/shot marker, compact Undo and pause; remove the existing recipe and marketing side columns. The plate and wafer tier emblem communicate the objective in the world. A short contextual cue teaches the first drag and then gets out of the way.

The browser game contains six solver-verified puzzles, including **The big escape**: four Pips, one jelly, one Mango gate, one exit. The trail unlocks stages in sequence and saves progress locally. Each Next action opens an implemented stage; mastery targets remain provisional until human playtesting.

Planned six-stage teaching sequence:

| Stage | Lesson | Gate / content quality gate |
| --- | --- | --- |
| Hello bun | Straight flick to the plate | Proven one-shot introductory solution |
| Better together | First merge | Berry silhouette/goal and verified merge solution |
| Jelly belly | Deflection | A solution that actually uses the bumper |
| Mango magic | Second-tier merge | Proven two-Berry-to-Mango path |
| The big escape | Sequential merges | Existing four-shot solver fixture |
| One happy family | Mixed-tier reasoning | Verified mixed-tier solution and Undo regression |

## Feedback and motion

One owner applies procedural deformation after imported animation. Preserve bulk volume through squash/stretch; keep eyes, mouth and cheeks attached to the body. Crests and limbs lag slightly behind the body. Idle breathing and occasional staggered blinking remain subtle. Pull tracks input continuously, release stretches immediately, impacts compress in their direction, jelly gives a softer recoil, merge pops into a readable new silhouette, and escape gives a short happy hop.

Initial target: roughly 100–140 ms pull response and about 0.6–0.7 seconds to settle after a strong shot. These are tuning goals, not values measured from other games. Final acceptance needs actual Godot footage and tactile phone review. Stronger wobble is not automatically better: reject face distortion, detached limbs, hard limit snaps and lingering motion that obscures a new aim. Reduced motion attenuates reactive deformation and decorative effects while preserving input and essential cues.

## Progression and rewards

Completion grants a wafer star and unlocks the next implemented stage, regardless of shot count. Optional extra stars can encourage replay. The known four-shot Big Escape solution is evidence for a proposed mastery target of four shots; a proposed generous target of six needs human playtesting. Treat both as provisional design values and never block progress on them. Save best result and completion locally. No energy system, paid currency, account or daily obligation belongs in this scope.

Pause contains Retry, sound, reduced motion, hint/replay and Trail. A result screen celebrates completion with an earned-star reveal and one clear next action. For the current single-stage slice that action is Replay, not a nonfunctional Next button. Sound uses short soft event accents, can be muted, and is never the only indication of an event. Haptics remain optional future work.

## Art and simulation

Round cream, strawberry pink and mango gold buns; short characteristic crests; broad cocoa faces; turquoise ceramic board, glossy jelly and shallow wafer relief. Quiet surroundings and limited focal effects keep phone-size characters readable. Generated turnaround concept art is a target; editable `.blend` geometry and its actual renders are separate deliverables. Source PNGs/screenshots are not ready-made 3D geometry.

Fixed planar physics runs at 120 Hz with four collision substeps. The visual spring layer has no authority over collisions, positions, tier or shot velocity. Current defaults: radii 0.55/0.65/0.77; masses 1/2/4; launch cap 12 units/s; drag 1.45/s; wall restitution 0.82; unequal bun restitution 0.7. Changes require deterministic replay and solved-puzzle checks. Preserve stable IDs and one-time consumption in simultaneous merges.

## Quality gates

Functional: clean Godot import; complete actual physics solution; reproducible 30/60/120 render-schedule outcomes; fast collisions; unequal/max-tier contacts; repeated/simultaneous merges; slow gate eligibility; aiming/cancellation; Undo/reset/pause and save/flow regressions.

Visual: actual browser captures of phone/desktop compositions and held/weak/strong/impact/merge/escape motion. Readable faces at small scale; no effects over an active aim; clear result and recovery controls; usable touch targets. Measure safe areas and rendering performance on a physical inexpensive Android device before declaring phone readiness.

Delivery: editable sources, GLBs, Godot project, real captured media, verified downloadable archives, Android debug build when exported and signed successfully, plus explicit pending-device notes. An exported APK or passing headless check alone is not a completed playtest.

Research and rationale: [game UI research](../research/game-ui-research.md). The cited listings/articles were read; commercial games were not installed or played in this session. No commercial art, UI assets or audio were copied.
