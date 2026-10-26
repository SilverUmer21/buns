# Game presentation patch

The presentation follows `research/game-ui-research.md`: the board carries play, and menus serve entry, pause, recovery, results and progression.

## Player-visible changes

- **Title:** the bun world idles behind a small tactile Bunbreak card with one dominant Play action and a quieter Kitchen trail action. Puzzle simulation does not run behind the title.
- **Play:** the board dominates. Only the stage/shot marker, compact Undo and pause controls remain. The marketing heading and explanatory desktop side columns were removed. Retry, Show me, sound and motion settings are inside pause.
- **Pause:** a kitchen-colored sheet offers Keep playing, Retry, Show me, Sound, Motion and Kitchen trail. Entering pause cancels an aim without launching it, and freezes simulation and character animation.
- **Result:** a completed escape gets a short arrival/celebration, then wafer stars and a dominant Play again action. Kitchen trail is secondary. There is no fake Next button leading to a nonexistent level. Show me reaches a clearly labeled practice result and never earns progress.
- **Trail:** six named kitchen cookies are visible. Only The big escape is playable. The other five explicitly say Coming soon and are disabled. The playable cookie displays earned stars after a real completion.
- **Recovery/accessibility:** Undo remains available after a result through the existing public API and restores the pre-winning shot. Mute and reduced motion persist locally with best shots and tutorial dismissal. Reduced motion removes procedural wobble, jelly deformation, decorative sparkles and the big escape hop. Escape/Android Back respects the flow rather than opening an unrelated app screen.

## Rewards and scope

One star is earned by any successful player escape. A second optional target is six shots; the third is four shots. The existing four-shot replay verifies attainability. Six is an initial generous target allowing two extra shots, not an experimentally established par. Both targets are provisional until human difficulty playtesting. Stars never unlock/block the current stage or erase an earned clear. No optimal-solution claim is made.

Only the existing Big Escape puzzle is implemented. Five future cookies do not represent completed content.

## Public flow API

`flow` uses `Flow.TITLE`, `PLAY`, `PAUSE`, `RESULT`, `TRAIL`. New scenes start on TITLE.

- `_start_play()` resets the current puzzle and enters PLAY.
- `_retry()` and `_show_me()` also enter PLAY, preserving capture compatibility for the demo path.
- `_toggle_pause()` switches PLAY and PAUSE only.
- `_show_trail()` opens TRAIL.
- `_undo()` works in PLAY or RESULT and returns to PLAY.

Existing `recipe` and `left_note` fields were removed. `retry_button`, `hint_button`, `mute_button` and `motion_button` are pause-card children; use `is_visible_in_tree()` when asserting their visibility. The capture script's portrait/desktop static modes show the default title unless they explicitly call `_start_play()`; the existing demo/movie path already calls `_show_me()`.

## Verification

`tests/validate_flow.gd` passes **35 checks** against the actual scene: title/input/simulation gating, play controls, pause/cancel/freeze/resume, accessibility settings, one real trail stage and five upcoming stages, real Show me result without rewards, actual four-shot player result and star rules, Undo after a result, portrait/desktop HUD and pause bounds, and a fresh scene loading saved best/settings. The test backs up `user://progress.cfg` and restores it after completion, including restoring absence when no file existed.

Root adapted the existing gameplay tests for the new title entry and removed sidebar assertions; that suite continues to pass **48 checks**. The motion suite is separate and passes **56 checks**.

The scene smoke run and flow suite were bounded to 30 seconds. Both completed in under one second in this environment. These results establish code/input/state compatibility, not rendered visual polish, touch-target size in physical dp, Android frame rate or human difficulty fairness. Those require rendered capture and device review.

## Files

- `godot/scripts/game.gd`
- `godot/tests/validate_flow.gd`
- `reports/flow-validation.json`

No solver, level layout, physics replay, art geometry or capture script was changed by this presentation patch.
