# Revised Berry and Mango asset review

The supplied screenshot made the fruit characters' faces appear smaller and lower than Pip's. Their previous models used the same absolute face dimensions as Pip on larger ellipsoid bodies. This pass keeps Pip's mesh, rig, animation and palette untouched and revises the two fruit models:

- Berry and Mango use gently tapered, fuller dough geometry with denser smooth silhouettes; their existing rounded tier sizes and separate Crest bones remain intact.
- Eyes, cheeks and smiles are larger and raised to stay legible from the elevated board camera. Facial patches use the same tapered surface formula as their bodies, keeping the features registered through the shared Body bone.
- Berry's three cream petals are seated into the body. Mango now has three shorter, broader golden lobes, making the two crowns distinct without introducing another palette.
- Materials remain standard, untextured PBR with their existing colors. A subtle procedural dough finish is a separate runtime-renderer change; no baked texture or new palette is claimed here.

Actual Blender renders: [Berry before](../docs/review/berry-before.png) / [Berry after](../docs/review/berry-after.png), [Mango before](../docs/review/mango-before.png) / [Mango after](../docs/review/mango-after.png), and [evaluated poses](../docs/review/fruit-pose-check.png). These are real model renders, not the design concept sheet. The previous previews use transparent backgrounds while the new proofs include a studio ground; compare geometry, not background colors. Browser framing and the combined interaction effects need their own visual check.

`authoring/build_assets.py -- --only berry` and `--only mango` rebuilt both characters independently. `authoring/finalize_fruit_sources.py` resaved their standalone Blender files. `authoring/update_fruit_master.py` replaced only the two fruit collections in the existing master and repaired family, board and turnaround instances; the Pip GLB copies remain byte-for-byte identical to the previous Git revision (SHA-256 `49a50c5cb90210ce292df2abff5e29df3da8e778d98e33403dfc14958c866218`).

`authoring/validate_glb.py` passed all eight assets, checking the two fruit skins have 11 joints, eight unique animation clips and morph tracks. `godot/tests/validate_fruit_assets.gd` passed 102 runtime checks, sampling both fruit rigs and eight clips at five times each. The shared 56-check motion suite also passed after reimport. These checks validate rig and transform integrity; they do not establish physical-device performance or taste of the final animation.
