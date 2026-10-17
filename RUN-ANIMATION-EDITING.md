# Edit the procedural sheathed run

Open **characters/run_sheathed.tscn** in Godot. This is the editable source used by the preview and the actual Darkiron hero. You do not edit `darkiron.tscn` for this experiment.

## Edit bones in AnimationPlayer

1. Open the **2D** workspace, select **Controls → AnimationPlayer**, and choose **run_sheathed**.
2. Scrub to one of **13 evenly spaced key times**, from **0.0000 to 0.4665 seconds**, approximately **0.0389 seconds** apart. Every editable bone has position, rotation and scale tracks with 13 keys.
3. Under **Controls → Skeleton2D**, select a bone such as **RightThigh**. You can also filter the scene tree by its name. Select the bone with that exact name, not its locked **RightThighPose** parent.
4. Use the regular 2D Move/Rotate/Scale gizmos, or the bone's **Transform** properties in the Inspector. You see the artwork follow immediately. Key the changed property using the Inspector's key icon, or edit the existing key in AnimationPlayer. The Inspector displays rotation in degrees.
5. Keep the Animation panel pinned while selecting bones if needed. Scrub away and back to confirm that the key was recorded. **F6** plays the looping preview.
6. **Ctrl+S**, then restart the game. Sheath with **S**, and run with **Shift + Left/Right** to see the same edits in gameplay. A running game does not automatically reload saved scene resources.

The native bone transform workflow is the same as editing `darkiron.tscn`; the values here are **adjustments relative to the moving procedural pose**. Neutral values are Position **(0, 0)**, Rotation **0**, Scale **(1, 1)**. Leave the `phase` track's existing linear 0 → 1 progression unchanged.

## Raise the knee

At **0.3110 seconds**, select **RightThigh** (near/bright leg), rotate it until the knee reaches the height you want, and key **Rotation**. The shin and foot follow the thigh. Select **RightShin**, adjust its rotation to refine the lower-leg bend, and key that rotation too. Use **LeftThigh / LeftShin** for the far/dark leg.

You can also move **RightShin** with the Move gizmo to reposition the knee and its descendants, or scale **RightThigh** to alter its reach. These have ordinary rigid bone semantics: translating a child does not automatically stretch its parent's artwork to close the gap. Rotating the thigh/shin preserves their existing lengths; use those first for a natural knee adjustment. The final bone edits are applied after IK, so no solver moves the bones back.

The ankle is not pinned after a thigh rotation: this is forward-kinematic editing, just like a conventional bone chain. Edits during foot contact can move the planted foot. Neutral keys elsewhere constrain the change to the part of the cycle you want. Keep the first and last keys equal for a continuous loop.

## Bone names and parenting

- **Hip** carries the whole character; **Torso** carries head, shoulders and the slung weapon.
- **RightThigh → RightShin → RightFoot** is the near/bright leg; **Left…** is the far/dark leg.
- **RightShoulder → RightForearm → RightHand** and the corresponding left chain control the arms.
- **Head** and **Weapon** have independent native position/rotation/scale adjustments.
- The locked, zero-length **…Pose** bones between editable bones carry the procedural pose. Do not key, move, rename or delete these helper nodes. The procedural driver updates them every frame.

All initial bone keys are neutral. The rendered demonstration modifications are used only by the test and are not saved into your editing scene. Existing numeric control tracks remain available and retain their previous values.

## Earlier numeric controls (optional)

These controls are still evaluated before the final bone layer. Prefer the native bone tracks above for direct posing.

| Track | Effect |
|---|---|
| `hip_offset` | Moves the pelvis target; torso follows, legs recompute. Horizontal hip movement also shifts the stride targets. |
| `torso_offset` | Moves chest, head, shoulders and slung weapon relative to the pelvis. |
| `torso_lean_degrees` | Adjusts chest artwork lean and the head's inherited lean; does not rotate shoulder targets around the hip. |
| `head_tilt_degrees` | Adjusts head rotation independently. |
| `front_foot_offset`, `back_foot_offset` | Offsets ankle targets; knees are solved again by the original IK. |
| `front_foot_pitch_degrees`, `back_foot_pitch_degrees` | Rotates each boot around its ankle. |
| `front_arm_swing_degrees`, `back_arm_swing_degrees` | Adjusts upper-arm swing, carrying elbow/hand with it. |
| `front_elbow_bend_degrees`, `back_elbow_bend_degrees` | Adjusts forearm bend and hand position. |
| `weapon_offset`, `weapon_tilt_degrees` | Adjusts the slung weapon relative to the torso. |
| `phase` | **Preview driver: leave the existing linear 0 → 1 keys unchanged.** This is not a pose adjustment. |

“Front” means the near, brightly lit limb; “back” means the far, darkened limb. Offsets are in the character's facing space and mirror with the character. Angles are degrees. Leave matching values at the start/end to keep the loop continuous.

## How it works and current scope

The preview and game both render through `scripts/rig.gd`. Original procedural calculations and any earlier numeric controls generate the base pose. Each locked Pose parent receives its procedural transform relative to its parent. AnimationPlayer exclusively owns the editable Bone2D child transforms. The final hierarchy transforms the original retained artwork without changing its texture, dimensions, tint or draw ordering. No IK runs after bone adjustments. The procedural driver never assigns editable bone transforms.

Runtime loads only the `Controls` branch from the editing scene, not its preview actor, camera or labels. The tracks are sampled at the actual movement gait phase. At full run speed the cycle matches the preview; while accelerating, its phase remains tied to distance traveled. Changing clip length does not change movement speed or stride distance. Leave `phase` linear so preview and game stay aligned.

Edits fade with the existing run/movement weights and weapon blend, so a small contribution can remain while transitioning out of running. They are disabled for drawn weapons, airborne poses, crouch, cover, climbing and death; enemy/Drake/Azure rendering is unaffected. This experiment does not change drawn-gun skeleton running.

Bone edits can intentionally break foot contact or change limb lengths. There is no automatic foot pinning or reach clamp after the final adjustment layer.

## Verification

`tests/run_bone_edits.gd` compares the final rendered artwork transforms against the original procedural path at 121 phases (tolerance 0.002 px). It tests native thigh rotation, shin translation/rotation, scale inheritance, knee/ankle movement, matching native bone gizmo transforms, repeated evaluation without accumulation, backward scrubbing, saved/reopened bone keys, actual `main.tscn` integration and facing/scope behavior. The native Skeleton2D registers 16 helper bones and 16 editable bones. The existing numeric-control and animation-runtime tests also pass.

Run the test using Godot's `--script tests/run_bone_edits.gd` option with `--headless`. Omit `--headless` and add `-- --visual` to generate `preview-run-bone-edits.png`, comparing the original run and temporary native bone edits. The scene also loads in the editor with its tool scripts enabled.
