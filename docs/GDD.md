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

Six-stage teaching sequence:

| Stage | Lesson | Gate / content quality gate |
| --- | --- | --- |
| Hello bun | Straight flick to the plate | Proven one-shot introductory solution |
| Better together | First merge | Berry silhouette/goal and verified merge solution |
| Jelly belly | Deflection | A solution that actually uses the bumper |
| Mango magic | Second-tier merge | Proven two-Berry-to-Mango path |
| The big escape | Sequential merges | Existing four-shot solver fixture |
| One happy family | Mixed-tier reasoning | Verified mixed-tier solution and Undo regression |

## Feedback and motion

### Tactile rework after playtest rejection

The previous smoothness pass was rejected by the owner after playing. Its numerical checks remain useful for correctness, but are not evidence of satisfying feel. The next implementation replaces a diagonal-cancelling squash approximation with properly oriented deformation, blocks noticeably different loaded/launch/recovery poses, adds facial responses and a visible elastic connection to the actual drag, and stages merge contact/compression/reveal/landing instead of simply shrinking both old buns. Preserve Pip's recognizable design, the 45° default and immediate fixed-plane physics. Review native phone frames and close-up before/after comparisons before updating the preview. [Research and concrete acceptance](../research/tactile-rework.md).

**Owner-approved pull design:** dragging right pulls the right side of the dough toward the finger into a rounded teardrop; the opposite side stays close to its starting point. The plump region holds the readable face, with eyes tracking the actual finger and a cute effort expression. A quick recoil accompanies immediate launch, followed by two small decaying jiggles and delayed crest/feet. Apply the same local-shape behavior to vertical and diagonal drags; launch direction is opposite to the finger. Stretch is bounded and visual only. Reduced motion keeps directional feedback and clear state with smaller recoil. This replaces symmetric whole-bun width scaling as the held action.

### Current performance pass · shot to celebration

The owner selected **45°** as the preferred default camera elevation. Reset returns to 45°; existing saved personal angles remain respected. The user can still adjust the view from 35–75° without changing physics.

Make the response a connected performance with distinct poses instead of one repeated bounce. Starting targets for iteration, not sourced measurements: (1) selection registers immediately; (2) dragging progressively loads a directional crouch/lean, with restrained elastic resistance and expressive eyes, mouth, crest and limbs; (3) release launches the solver on the same input event and flows from held pose to a directional stretch and soft recovery; (4) impacts compress along the contact direction and dissipate with small overlapping follow-through. A cancelled pull eases home and never launches. Weak and strong shots should be meaningfully different while the aim remains accurate.

For a merge, make both inputs readable as they gather at their actual contact position; the next-tier friend appears with a tier-specific excited expression, pop and recovery. Avoid obscuring the face with rings or particles. Release the player's next shot as soon as physics allows, regardless of remaining decorative follow-through. For a win, make the escaped bun's personality visible through a staged joyful reaction, hop and landing before the result panel; completion, progression and Undo must be correct immediately and independent of the animation. Pause, reset and repeated simultaneous events must not leave ghost rigs or effects behind. Give reduced-motion players a clear result and essential state feedback with nonessential motion suppressed.

Inspect actual browser sequences at 45° in portrait and desktop, using multiple held, release, merge and win frames, including an interrupted/cancelled hold. Check smooth changes without static poses, detached facial parts, flattening into a pancake, clipping at board edges or effects hiding the next action. Compare equivalent moments at 30/60/120 render schedules and run all existing deterministic puzzle solutions. User approval and physical-device touch/performance playtesting remain necessary. Keep the current palette; richer Clash-inspired color and shine remains a later separate study. Research: [animation direction](../research/animation-direction-2026-10.md).

### Current improvement pass: owner feedback and acceptance

Pip's cream bun is the visual benchmark and should remain recognizable. Prioritize Berry and Mango proportions, crests, surface depth and facial appeal at actual in-game scale; their expressions and timing should feel related without looking like recolored statues. Compare real browser frames against Pip and the supplied screenshots, then iterate using editable geometry or a clearly documented non-destructive runtime treatment. Keep the established palette in this pass.

Replace generic horizontal widening as the dominant squash. While held, show an asymmetric directional pull with the face and crest leaning into the action; on release move the solver immediately, then stretch along motion and settle with diminishing nonuniform follow-through. On impact compress along the impact direction, not always the vertical body axis; offset crest and limbs with a small delay. Distinguish anticipation, release, impact, merge, idle/blink and escape with restrained facial and body cues while keeping eyes, mouth and cheeks attached and readable. Avoid pose snaps, inverted scales, detached features and permanent wobble. Reduced motion retains essential cues with smaller motion.

Merge feedback has a clear beginning, arrival and end: two matching buns respond at contact; they resolve into one readable next-tier friend with a short pop/expression and local accent, then settle. Solver state and collision changes remain immediate and stable. Never double-consume a bun or obscure the next shot. Distinguish wall, jelly, gate and escape with restrained visual/sound accents that respect mute and reduced motion.

#### Adjustable framing

Provide an accessible angle control in pause/settings with a live preview, readable degrees and reset. Tuning range: **35–75° elevation** measured from the board plane; default and reset are **45°** per the owner's selection. Persist an explicitly saved choice locally and retain it between levels. Change only the camera, never the simulation plane. Disable adjustments while buns move or a pull is active; cancellation must not fire. Use orthographic framing that refits the full tray, gate and exit with a margin for portrait/desktop resize. Project the gate badge, cursor-to-plane aim, prediction and picking with the selected camera. Keep board and characters prominent while reserving safe margins for fingers, HUD and notches.

Acceptance: actual browser frames at default and angle limits on phone and desktop, with all board edges and aim/goal overlays visible; per-tier character views; weak/strong pull, opposite directions, release, impact, jelly, both merge tiers and escape. Verify finite positive scales and approximate volume, attached facial pieces, readable silhouettes, ray-plane round trips, safe touch targets and identical solver outcomes at 30/60/120 render schedules with wobble on/off. Final color and feel approval requires user and physical-device playtesting.

One owner applies procedural deformation after imported animation. Preserve bulk volume through squash/stretch; keep eyes, mouth and cheeks attached to the body. Crests and limbs lag slightly behind the body. Idle breathing and occasional staggered blinking remain subtle. Pull tracks input continuously, release stretches immediately, impacts compress in their direction, jelly gives a softer recoil, merge pops into a readable new silhouette, and escape gives a short happy hop.

Initial target: roughly 100–140 ms pull response and about 0.6–0.7 seconds to settle after a strong shot. These are tuning goals, not values measured from other games. Final acceptance needs actual browser footage and tactile phone review. Stronger wobble is not automatically better: reject face distortion, detached limbs, hard limit snaps and lingering motion that obscures a new aim. Reduced motion attenuates reactive deformation and decorative effects while preserving input and essential cues.

## Progression and rewards

Completion grants a wafer star and unlocks the next implemented stage, regardless of shot count. Optional extra stars can encourage replay. The known four-shot Big Escape solution is evidence for a proposed mastery target of four shots; a proposed generous target of six needs human playtesting. Treat both as provisional design values and never block progress on them. Save best result and completion locally. No energy system, paid currency, account or daily obligation belongs in this scope.

Pause contains Retry, sound, reduced motion, hint/replay and Trail. A result screen celebrates completion with an earned-star reveal and one clear next action: Next for the first five stages and Replay at the end of the trail. Sound uses short soft event accents, can be muted, and is never the only indication of an event. Haptics remain optional future work.

## Art and simulation

**Deferred color/shine direction:** the owner likes the richer color and shine of Clash of Clans and Clash Royale and wants to explore it later. Make a separate reference and swatch study with controlled highlights and readable facial contrast. Do not copy their assets, reintroduce clipped/neon highlights, or change the current palette under the camera/character-motion task.

Round cream, strawberry pink and mango gold buns; short characteristic crests; broad cocoa faces; turquoise ceramic board, glossy jelly and shallow wafer relief. Quiet surroundings and limited focal effects keep phone-size characters readable. Generated turnaround concept art is a target; editable `.blend` geometry and its actual renders are separate deliverables. Source PNGs/screenshots are not ready-made 3D geometry.

Fixed planar physics runs at 120 Hz with four collision substeps. The visual spring layer has no authority over collisions, positions, tier or shot velocity. Current defaults: radii 0.55/0.65/0.77; masses 1/2/4; launch cap 12 units/s; drag 1.45/s; wall restitution 0.82; unequal bun restitution 0.7. Changes require deterministic replay and solved-puzzle checks. Preserve stable IDs and one-time consumption in simultaneous merges.

## Quality gates

Functional: clean browser load; complete actual physics solutions; reproducible 30/60/120 render-schedule outcomes; fast collisions; unequal/max-tier contacts; repeated/simultaneous merges; slow gate eligibility; aiming/cancellation; Undo/reset/pause and save/flow regressions. The prior Godot project can be validated separately as a historical reference.

Visual: actual browser captures of phone/desktop compositions and held/weak/strong/impact/merge/escape motion. Readable faces at small scale; no effects over an active aim; clear result and recovery controls; usable touch targets. Measure safe areas and rendering performance on a physical inexpensive Android device before declaring phone readiness.

Delivery: browser preview, editable sources, GLBs, real captured media, verified downloadable archives and explicit pending-device notes. An exported build or passing headless check alone is not a completed playtest.

Research and rationale: [game UI research](../research/game-ui-research.md) and [character feel research](../research/character-feel-research.md). The cited listings/articles were read; commercial games were not installed or played in this session. No commercial art, UI assets or audio were copied.
