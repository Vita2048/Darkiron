# Character rendering: Prince comparison

Inspected `C:\Temp\Prince\index.html` and its saved character comparison images. The Prince project was not changed.

## Findings

Prince is itself a hybrid: `princeLimb`, `princeBoot`, `dressedTorso`, and `portrait` construct the silhouette; `princeTexture` optionally adds a generated material atlas at restrained opacity. The material does not determine the anatomy. Darkiron currently stretches complete illustrated limb pieces along bones, so their built-in perspective and baked lighting can compete with the pose.

The reusable foundation is Prince's character system, translated into GDScript rather than embedded as JavaScript:

- `P`, `PS`, `lerpPose`, and `keyed`: explicit whole-body poses and transitions, including a nearly straight standing pose.
- `skeleton` and `legH`: constant bone lengths, hip height derived from leg reach, and consistent torso/shoulder/head relationships.
- `cycle`: periodic cubic interpolation, keeping velocity continuous across stride keys.
- `solveLeg` / `applyFootContacts`: stance-phase foot placement and reduced sliding.
- `solveArm` / `applyClimbingContacts`: attached hands during climbing, followed by a controlled release.
- `princeLimb` / `limbJoint`: continuous tapered silhouettes and joint caps, with restrained texture detail.
- `drawDetailedPerson`: explicit rear/front ordering, drawing gripping hands after the weapon.

## Applied in this revision

Adapted the Prince standing angles (front thigh/shin 4/0 degrees, rear -4/-3 degrees) and calculated pelvis height from vertical leg reach. Breathing moves the upper torso, not the planted legs. The approved run key poses are retained. The cape polygon had already been removed; this revision also removes the generated pointed hip armor and replaces it with a fitted waist belt, leaving no trailing cloth geometry.

## Recommendation

Keep Godot and the existing environment. Rebuild character anatomy and armor silhouettes using Prince's geometry-first approach, with consistent joint proportions, attached hands, explicit poses, and limited material overlays. Keep image generation for environments, surface materials, concept references, and selected rigid accessories. Avoid expanding the current whole-limb atlas into a large character animation library before that renderer is settled.

This is a focused stance correction and a source-based recommendation, not a completed port of the entire Prince character system. Prince's ledge-climbing logic would need adaptation to Darkiron's ladders and future ledges; its sword combat should not replace Darkiron's shotgun behavior.

## Vector Edition 06 follow-up

The character renderer now uses authored vector armor throughout; the earlier atlas comparison above describes the previous implementation. Prince-inspired joint poses and cubic gait interpolation remain. Armor geometry is baked into shared colored triangle meshes and animated by transforms, preserving vector detail while reducing draw calls. This is still not a wholesale port of Prince's ledge or combat systems.
