# Animation direction research · 27 October 2026

The owner wants more expressive, smoothly connected pull, launch, merge and escape performances, with 45° as the preferred board elevation. These sources inform the design; none proves a particular duration will feel best, and no commercial game was played as part of this research.

## Observed in sources

- [Walt Disney Animation Studios: Animation](https://www.disneyanimation.com/process/animation/) names timing, clear staging, squash and stretch, anticipation, follow-through and secondary action as principles used to give characters life. This describes their filmmaking practice, not specific game timings.
- [Jonathan Cooper: The 12 Principles of Animation in Video Games](https://www.gameanim.com/2019/05/15/the-12-principles-of-animation-in-video-games/) describes preserving apparent volume in squash/stretch, varying the timing of secondary parts, and placing weight in the follow-through while maintaining an immediate response. He recommends that follow-through not prevent the next player action and that secondary action supports the main gesture.
- [W3C: Animation from Interactions](https://www.w3.org/WAI/WCAG22/Understanding/animation-from-interactions) explains the WCAG 2.2 AAA criterion that interaction-triggered nonessential motion can be disabled. It recommends respecting user motion preferences or providing a control. This does not establish that the current game satisfies all WCAG criteria.

## Design interpretation to test

Use the player's pull as the wind-up, with immediate visible response and a soft saturation near full tension. The release changes physics immediately; an elastic directional extension, face reaction and staggered crest/limb movement communicate stored energy after release. Match the gesture to the actual shot direction, preserve approximate body volume and keep features attached. Returning input to the player when physics settles must not wait for decorative recovery.

At a merge, keep the two-to-one relationship legible: draw the old friends into the contact, show a brief recognizable new-tier silhouette with a soft overshoot, then relax. Effects frame the bun, not cover its face or aim. For escape, stage an excited anticipation, a small celebratory hop and a soft landing before the result screen; the success state is immediate and the celebration is presentation only. Ensure Undo, reset, pause, repeated events and reduced motion behave correctly at every stage. Durations and amplitudes in the GDD are Bunbreak tuning hypotheses, not measured properties of referenced titles.
