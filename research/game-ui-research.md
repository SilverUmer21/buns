# Bunbreak: game UI and game-feel research

Research date: 2026-10-27. Scope: Play Store listings and their published screenshot links, first-party engine documentation, and articles by working game designers/animators. These games were **not installed or played** in this session; no claim about their real input latency, animation timing, retention or device performance follows from this review. All Bunbreak recommendations below are design proposals to verify in the actual game.

## What the references establish

| Reference opened | Observed or documented fact | Bunbreak implication (our inference) |
| --- | --- | --- |
| [Angry Birds 2 — Google Play](https://play.google.com/store/apps/details?hl=en_US&id=com.rovio.baba) | The official listing describes selecting a bird, slingshot strategy, multi-stage puzzles, and many levels. It also lists separate progression and event systems. The listing provides gameplay screenshots and a trailer entry. | Make the immediate verb clear: choose a bun, pull, release. Stage selection and results belong around the play loop. We do not need to import its large live-service economy to make Bunbreak feel like a game. |
| [Cut the Rope 2 — Google Play](https://play.google.com/store/apps/details?hl=en_US&id=com.zeptolab.ctr2.f2p.google) | The listing presents a character with a concrete candy objective, physics puzzles, distinct helpers, and optional alternate objectives on the same setup. | Give the buns an expressive escape goal. Introduce mechanics through staged puzzles. Let optional mastery rewards reuse a completed puzzle without blocking normal progress. |
| [Suika Game — official Aladdin X listing](https://play.google.com/store/apps/details?id=com.aladdinx.suikagame&hl=en) | Same-type fruit collisions evolve into the next fruit, with a clear terminal goal and an overflow failure condition. | Bunbreak's three-tier merge ladder can carry its own reward feedback. Show the next tier through silhouettes and reactions; keep Bunbreak's unlimited attempts and escape objective rather than copying Suika's loss rule. |
| [Unity: effective UI and game design](https://unity.com/blog/games/how-to-immerse-your-players-through-effective-ui-and-game-design) | The article discusses both world-integrated interfaces and conventional HUDs. It recommends conveying necessary state, reducing unnecessary text, learning genre conventions and iterating. | The goal is a coherent game presentation, not the removal of every button. Keep a small legible pause/Undo interface; replace the current explanatory desktop side columns with world feedback and contextual teaching. |
| [Steve Swink: Principles of Virtual Sensation](https://www.gamedeveloper.com/design/principles-of-virtual-sensation) | Swink treats challenge, mastery and control as central to game feel, connecting animation principles such as anticipation, staging and follow-through to sensation. | Evaluate control and animation together. A cute delay that postpones the shot harms the main interaction. Launch immediately; let visual follow-through continue afterward. |
| [Jonathan Cooper: animation principles in games](https://www.gamedeveloper.com/production/the-12-principles-of-animation-in-video-games) | The animator describes directional squash/stretch, preserving volume, anticipation and staging in interactive animation. | Use directional, volume-preserving deformation. Faces must remain readable, crests should follow through, and reactions should communicate the shot rather than decorate the whole screen. |

The first published screenshot links for all three Play Store listings were opened as part of the research. They are comparison material, not reusable Bunbreak assets. No commercial game art, sound or UI has been copied into this project.

## Current Bunbreak gaps found in local source

`godot/scripts/game.gd` currently opens directly into a single level and maintains a large heading, explanatory text, desktop recipe/marketing side columns, persistent Undo/Retry/Show me controls and a shot counter. A win changes text and triggers a hop, but provides no level-completion sequence, next-level progression, meaningful replay mastery or trail. This makes the implementation read like an interactive demo despite having real physics.

`bun_motion_driver.gd` already separates visual springs from the solver and has held pull, release, impact and merge hooks. The next improvement is expressive direction and event sequencing, not simply increasing a sine-wave amplitude. Current release/impact impulses and hard clamps need visual review across weak/strong shots and rapid repeated contacts before being described as polished.

## Proposed player experience

1. **Enter the kitchen.** A small animated title and one clear Play/Continue action over the bun world. First launch can lead into the first simple puzzle without a full menu tour.
2. **Learn by doing.** One first-drag hand/arrow cue anchored to the selectable bun. Show a brief pull-and-release cue, then dismiss it after successful input. Keep the goal visible through the plate and gate emblem.
3. **Aim.** The selected bun looks engaged, squashes into the held pose, and follows the pull direction. An unobtrusive trajectory cue remains outside the finger. Keep other buns calm. No ambient camera motion or screen shake during aiming.
4. **Resolve a shot.** Release stretch, wall/jelly compression, delayed crest/limb follow-through, a distinct merge pop, and a tier reveal. Feedback belongs at the event location. Small sound/haptic accents are optional and independently controllable.
5. **Escape and celebrate.** Brief plate arrival, bun celebration and a clean completion reveal. Show the earned wafer stars and one dominant Next action, with quieter Replay and Trail choices.
6. **Choose the next puzzle.** A six-stop kitchen trail represented by tactile cookies/plates. Completed stages retain best stars locally. Returning players resume the next available stage.

Screens, menus and buttons are normal game tools. In Bunbreak they should feel like kitchen toys and serve play, pause, recovery or progression; persistent explanatory panels should disappear once the player understands the interaction.

## Gamification that fits this game

- Keep the original six-stage teaching sequence: **Hello bun** (straight exit), **Better together** (first merge), **Jelly belly** (deflection), **Mango magic** (second tier), **The big escape** (four Pips), **One happy family** (mixed tiers). Solve and replay fixtures must be verified separately for every layout.
- Award one star for any successful escape, a second for a verified generous shot target, and a third for a verified mastery target. Publish targets only after solver replays and human playtests establish they are fair; do not choose arbitrary par values.
- Unlock the next puzzle on completion regardless of stars. Stars encourage replay and expressive celebration, never block progress. Keep unlimited attempts, Undo and Retry.
- A merge is a small reward, a new tier is a larger reveal, and escape is the main celebration. Avoid making all three effects equally loud.
- Persist level completion, best mastery result and tutorial dismissal locally. Include a clear settings reset. No account, energy timer, daily obligation, store or paid currency is needed for this scope.

## Motion direction and initial tuning proposals

These are starting targets, not measurements from commercial games or acceptance evidence:

| Beat | Proposed response | Review criterion |
| --- | --- | --- |
| Idle | Subtle breathing; occasional staggered blink | No synchronized bobbing or moving collision bodies |
| Pull | About 100–140 ms to a held squash, proportional to drag; directional lean | Holds indefinitely without looping back or creeping off the collision center |
| Release | Immediate shot; a short stretch leading into two diminishing rebounds | No input delay, pose snap or uncontrolled oscillation |
| Impact | Compression follows collision normal; crest/limbs lag the body | Walls and jelly feel distinct; weak impacts stay small |
| Merge | Short gather/pop, clear tier silhouette reveal and happy recovery | Incoming buns disappear exactly once; new collision state remains deterministic |
| Escape | A brief happy hop then readable completion UI | Celebration never obscures an active aim; Skip/Next is available after the reveal |

Use a damped spring with continuous velocity, tuned by frequency and damping rather than frame-count lerps. The author's [Spring-Roll-Call](https://theorangeduck.com/page/spring-roll-call) explains why naive per-frame smoothing changes behavior with frame rate and how exact dampers/springs address it. Keep the fixed planar collision solver authoritative. Godot's [physics interpolation introduction](https://docs.godotengine.org/en/4.6/tutorials/physics/interpolation/physics_interpolation_introduction.html) distinguishes fixed simulation ticks from variable rendered frames and explains interpolation between previous/current states.

Use one owner for procedural body/crest deformation after imported clips. Godot's [SkeletonModifier3D reference](https://docs.godotengine.org/en/4.6/classes/class_skeletonmodifier3d.html) states that modifiers run after AnimationMixer; current 4.6 documentation favors the delta-taking callback. Check the installed engine's supported callback before changing working animation code.

## UI, accessibility and quality gates

- In-play screen: board dominates; goal/tier icon and a small stage marker are enough. Keep pause discoverable. Undo can remain a compact safe-margin control; Retry, sound, hints and Trail can live in pause. A result screen may use explicit Next/Replay actions.
- Treat phone targets as physical touch regions, not just pretty icons. [Android accessibility guidance](https://support.google.com/accessibility/android/answer/7101858?hl=en) recommends at least 48dp targets and spacing; Godot canvas pixels require a density-aware check on actual devices.
- Tier recognition uses crest and relative size as well as color. Preserve strong face contrast, clear selection feedback, reduced motion, mute and visible alternatives to sound/haptics.
- Review in portrait and landscape/desktop safe areas, with notches and the player finger covering an aim. Do not let corner controls consume the aim path or cover buns.
- Record real Godot footage of held pull, cancel, weak/strong release, oblique wall impact, jelly impact, merge, and escape at 30/60/120 render limits. Static Blender proofs and headless assertions are complementary evidence, not substitutes for visual or tactile review.
- Keep deterministic replay, same-frame contact/merge, paused input, focus loss, Undo after a merge/win, save/load and level transition regressions. Measure phone rendering/performance separately from simulation equivalence.

## Small-patch order

1. Commit this research, a concrete GDD, review gates and `AGENTS.md` startup/stall rules.
2. Preserve/import the playable Godot baseline and document reproducible tests and downloads.
3. Add explicit title/play/pause/result/trail states and board-first HUD; retain known puzzle physics.
4. Refine directional body/crest/limb response and event effects; capture actual motion comparisons.
5. Add and solve the six levels, local progression and optional mastery stars.
6. Build browser/native test artifacts, validate phone inputs and release downloadable previews with size/checksum/install notes.

Every patch should identify player-visible behavior, relevant tests, actual evidence and any pending device review. A stalled tool should have a bounded timeout, saved log and a useful independent next task; permission prompts themselves are not successful command execution.
