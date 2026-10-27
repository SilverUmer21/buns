# Browser review, 2026-10-27

The browser version was run in Chromium with software WebGL. We captured the actual 3D game at 16 points, including [play](play.png), [held pull](held-pull.png), [release](release.png), [phone layout](phone.png), pause, result and desktop layout. These are game frames, not concept art.

In the captured pull/release sequence, Pip's rig height moved from about 1.0 to 0.853 when held, stretched to 1.071 after release, then settled near 1.0. The measured Body scale product stayed at 1.0. Those numbers confirm the rig moved during this particular capture; they do not establish how it feels on a phone.

The browser test drove the in-game Show me replay to completion for each of the six stages. For speed, the full-level replay portion advanced the simulation without drawing every intermediate frame. The displayed pull/release frames were actually rendered. The automated physics suites separately passed 14 rules checks and 28 level/replay checks, including 30/60/120 render-schedule equivalence and an actual jelly collision.

The earlier Godot screenshot clipped cream highlights and rendered the board neon cyan. The browser renderer uses a more restrained palette, neutral lighting, tone mapping and soft contact shadows. Physical-device performance, human playtests, final star thresholds, collision feel and comprehensive visual review of every event are still pending.
