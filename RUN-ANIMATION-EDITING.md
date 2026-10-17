# Edit procedural sheathed run and climbing

Open **characters/run_sheathed.tscn** in Godot. This is the editable source used by the preview and the actual Darkiron hero for both sheathed running and ladder climbing. You do not edit `darkiron.tscn` for these procedural motions.

## Edit bones in AnimationPlayer

1. Open the **2D** workspace, select **Controls → AnimationPlayer**, and choose **run_sheathed** or **climb_sheathed** (also aliased as **climb**).
   - On the root **RunSheathed** node in the Inspector, the **Preview Mode** can be left on **Auto** (which automatically switches between running and climbing based on the selected animation in AnimationPlayer), or explicitly set to **Run** or **Climb**. When climbing, the preview draws a subtle background ladder guide.
2. Scrub through the animation keys:
   - **run_sheathed**: 13 evenly spaced keys from **0.0000 to 0.4665 seconds** (~0.0389 s apart).
   - **climb_sheathed**: 13 evenly spaced keys from **0.0000 to 1.0833 seconds** (~0.0903 s apart, matching the signed distance-driven climbing speed of 145 px/s).
3. Under **Controls → Skeleton2D**, select a bone such as **RightThigh** or **RightForearm**. You can also filter the scene tree by its name. Select the bone with that exact name, not its locked **...Pose** parent.
4. Use the regular 2D Move/Rotate/Scale gizmos, or the bone's **Transform** properties in the Inspector. You see the artwork follow immediately. Key the changed property using the Inspector's key icon, or edit the existing key in AnimationPlayer. The Inspector displays rotation in degrees.
5. Keep the Animation panel pinned while selecting bones if needed. Scrub away and back to confirm that the key was recorded. **F6** plays the looping preview.
6. **Ctrl+S**, then restart the game. Sheath with **S**, and run with **Shift + Left/Right** or climb ladders with **Up/Down** to see the same edits in gameplay.

The native bone transform workflow is the same as editing `darkiron.tscn`; the values here are **adjustments relative to the moving procedural pose**. Neutral values are Position **(0, 0)**, Rotation **0**, Scale **(1, 1)**. Leave the `phase` track's existing linear 0 → 1 progression unchanged.

## Posing examples

- **Raise the run knee**: At **0.3110 seconds** in `run_sheathed`, select **RightThigh** (near/bright leg), rotate it until the knee reaches the height you want, and key **Rotation**. Select **RightShin**, adjust its rotation to refine the lower-leg bend, and key that too.
- **Adjust ladder climbing grip**: At **0.3611 seconds** in `climb_sheathed`, select **RightForearm** or **RightShoulder** to adjust hand reach on the ladder rungs. Select **RightThigh** or **RightShin** to adjust ladder stepping depth.

The final bone edits are applied after procedural calculation, so no solver moves the bones back. Neutral keys elsewhere constrain the change to the part of the cycle you want. Keep the first and last keys equal for a continuous loop.

## Bone names and parenting

- **Hip** carries the whole character; **Torso** carries head, shoulders and the slung weapon.
- **RightThigh → RightShin → RightFoot** is the near/bright leg; **Left…** is the far/dark leg.
- **RightShoulder → RightForearm → RightHand** and the corresponding left chain control the arms.
- **Head** and **Weapon** have independent native position/rotation/scale adjustments.
- The locked, zero-length **…Pose** bones between editable bones carry the procedural pose. Do not key, move, rename or delete these helper nodes. The procedural driver updates them every frame.

All initial bone keys in `climb_sheathed` are neutral, reproducing the original procedural climbing motion 100%.

## Earlier numeric controls (optional)

These controls are still evaluated before the final bone layer. Prefer the native bone tracks above for direct posing.

| Track | Effect |
|---|---|
| `hip_offset` | Moves the pelvis target; torso follows, legs recompute. Horizontal hip movement also shifts stride/ladder targets. |
| `torso_offset` | Moves chest, head, shoulders and slung weapon relative to the pelvis. |
| `torso_lean_degrees` | Adjusts chest artwork lean and the head's inherited lean. |
| `head_tilt_degrees` | Adjusts head rotation independently. |
| `front_foot_offset`, `back_foot_offset` | Offsets ankle targets; knees are solved again by IK. |
| `front_foot_pitch_degrees`, `back_foot_pitch_degrees` | Rotates each boot around its ankle. |
| `front_arm_swing_degrees`, `back_arm_swing_degrees` | Adjusts upper-arm swing, carrying elbow/hand with it. |
| `front_elbow_bend_degrees`, `back_elbow_bend_degrees` | Adjusts forearm bend and hand position. |
| `weapon_offset`, `weapon_tilt_degrees` | Adjusts the slung weapon relative to the torso. |
| `phase` | **Preview driver: leave the existing linear 0 → 1 keys unchanged.** This is not a pose adjustment. |

“Front” means the near, brightly lit limb; “back” means the far, darkened limb. Offsets are in the character's facing space and mirror with the character. Angles are degrees. Leave matching values at the start/end to keep the loop continuous.

## How it works and current scope

The preview and game both render through `scripts/rig.gd`. Original procedural calculations and any earlier numeric controls generate the base pose. Each locked Pose parent receives its procedural transform relative to its parent. AnimationPlayer exclusively owns the editable Bone2D child transforms. The final hierarchy transforms the original retained artwork without changing its texture, dimensions, tint or draw ordering. No IK runs after bone adjustments. The procedural driver never assigns editable bone transforms.

Runtime loads only the `Controls` branch from the editing scene, not its preview actor, camera or labels. The tracks are sampled at the actual movement gait phase:
- During running, `run_sheathed` is sampled.
- During ladder climbing, `climb_sheathed` is sampled, and the procedural ladder climbing motion is restored with the slung weapon held accurately against the back and alternating limb ladder strides.

Edits are disabled for drawn weapons, airborne poses, crouch, cover and death; enemy/Drake/Azure rendering is unaffected.

## Verification

- `tests/climb_bone_edits.gd`: Compares the final rendered artwork transforms against procedural climbing at 121 phases (tolerance 0.002 px). Tests native thigh rotation, shin translation/rotation, arm adjustments, native bone gizmo agreement, repeated evaluation, and real `main.tscn` ladder climbing integration.
- `tests/run_bone_edits.gd`: Verifies the sheathed run animation pipeline and bone editing.
- `tests/controls.gd`: Verifies gameplay controls including ladder climbing priority and transitions.

Run the test using Godot's `--script tests/climb_bone_edits.gd` option with `--headless`.
