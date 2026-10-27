# Camera and character review

Actual Chromium/WebGL renders of the new build. `angle-35.png`, `angle-55.png` and `angle-75.png` show the adjustable board on a 390×844 simulated viewport. The camera check also verified that every tray corner stays within the canvas, the selected setting persists after reload, and screen/ground coordinates round-trip at every angle without changing physics.

`held-right.png` captures the held, direction-dependent pull; `merge-2-arrival.png` and `merge-2-settling.png` capture the Pip-to-Berry reaction; `merge-3-arrival.png` and `merge-3-settling.png` capture the Berry-to-Mango reaction. The combined 16-frame browser suite replayed all six levels with no JavaScript errors. The targeted character review checked mouth-shape availability, a held expression, both tier arrivals and positive volume-preserving body scales.

Berry and Mango now have a subtle deterministic bump treatment in the web renderer. The authored GLBs remain standard PBR and do not contain a baked texture. Pip's GLB remains byte-for-byte identical. The camera and color direction are adjustable/provisional: actual mobile-device touch feel, performance, user preference and a future Clash-inspired color/shine study remain separate review work.
