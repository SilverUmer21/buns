# Runtime motion audit and patch

## Concrete gaps found

1. `bun_motion_driver.gd` advanced springs with render delta, then clamped and multiplied velocity per rendered frame. The scalar helper was analytic, but the composed driver included frame-dependent limits and sampled crest coupling. Existing tests only compared the scalar helper across frame rates.
2. `reset_motion()` instantly changed a held height of 0.72 back to 1.0. Touch cancellation therefore produced a visible silhouette snap even though it correctly avoided shooting.
3. Limbs had authored event poses but no delayed procedural response to pull, impact or release. Crest response depended only on lean, so a centered compression had little crest follow-through.
4. Disabling wobble reset visible fields but retained stored spring velocities. Re-enabling it could expose an old impulse.
5. Oversized direction and impact inputs were not normalized/clamped at the public hooks.

## Changes

- Runtime motion uses its own fixed 240 Hz clock, separate from 120 Hz collision physics. Body limits, coupled spring targets and their damping now receive the same integration sequence at 30, 60 and 120 render FPS.
- Body release is a soft, bounded stretch with diminishing oscillation. Side impacts also drive a small anisotropic squeeze. The three scale factors multiply to one, including directional jiggle.
- Crest follows body lean and compression with a separate slower response. Arms and feet receive a delayed additive layer after the authored tracks, while Body/Crest remain owned by the skeleton modifier.
- Cancelled pulls relax critically toward rest. `reset_motion(immediate := false)` keeps all existing call sites valid; callers that need a hard reset can explicitly use `true`.
- Wobble disable clears stored impulses, and input hooks normalize directions and bound intensity.
- All collision coordinates, radii, merge rules and solver code remain unchanged.

## Verification

Commands, run with a 30 second outer timeout each:

```sh
. authoring/environment.sh
godot --headless --path godot --script tests/validate_game.gd
godot --headless --path godot --script tests/validate_motion.gd
```

The existing gameplay suite passed **48 checks** after the motion patch. The new actual-driver/skeleton suite passed **56 checks**. See `motion-validation.json` for the machine-readable result.

Measured in the release test:

| Measurement | Result |
| --- | --- |
| Peak body height | 1.15285 times rest height |
| Lowest sampled release height | 0.78053 times rest height |
| Diminishing crossings through rest | 5 |
| Peak combined crest angle | 0.27513 radians |
| Peak combined limb response | 0.25064 radians |
| Largest actual modifier bulk-volume error | 0.000000095 |

The test compares actual driver state throughout a pull/release/impact/cancel timeline at 30, 60 and 120 FPS. It also checks continuous cancellation, long-held squash, relaxation, re-enable behavior, 40 repeated impact/release bursts, facial bone parent attachment on all three real GLB rigs and identical solver snapshots while visual impulse bursts run.

These are headless motion and skeleton checks. They establish bounded deterministic motion and runtime asset compatibility; they do not establish final visual appeal, rendered phone readability, Android frame rate or physical device performance. Those remain separate review gates.

## Files changed

- `godot/scripts/spring_profile.gd`
- `godot/scripts/bun_motion_driver.gd`
- `godot/scripts/bun_modifier.gd`
- `godot/tests/validate_motion.gd`

No `game.gd`, solver, exported geometry or physics fixtures were changed by this motion patch.
