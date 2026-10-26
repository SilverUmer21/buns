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

The current pass implements and reviews patches 01–06 as tooling permits; patch 07 remains staged work, not a claim that six puzzles are already playable. Each commit records its behavior and validation. Optional stars, motion amplitude and sound need human playtesting; source research cannot establish their final tuning.

Stop conditions: permission pending, failed export, unsupported device/rendering setup or a missing solved fixture must be stated precisely. Save logs/checkpoints and continue independent work. Never wait indefinitely on a shell command or label an unexecuted job successful.
