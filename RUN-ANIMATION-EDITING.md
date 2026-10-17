# Edit Darkiron animations

Open `characters/DarkironAnimationsTweaker.tscn` in Godot. This scene supplies the animation adjustments used by both its visual preview and Darkiron in gameplay. The base motion preserves the procedural renderer from `C:\Temp\Darkiron.old\Darkiron`; it is evaluated continuously rather than approximated with baked keyframes.

## Editing

1. Select **Controls > AnimationPlayer** in the 2D workspace and choose a clip. Leave the root's **Preview Mode** on **Auto**.
2. Scrub the timeline. Select a named bone below **Controls > Skeleton2D**, such as **RightThigh**, **RightForearm**, **Weapon**, or **Hip**.
3. Move, rotate, or scale it with the normal Godot gizmos and key the property. Scrub away and back to confirm the key. The artwork follows the edit immediately.
4. Save the scene, then restart gameplay. The game loads these same saved animation resources; no export or second scene needs updating.
5. For F6 playback, set the root's **Playback Clip** to the desired clip name. **Face Left** mirrors the preview. The camera frames the character automatically.

Bone keys are adjustments relative to the moving original pose: position `(0, 0)`, rotation `0`, and scale `(1, 1)` reproduce the source animation. The locked `...Pose` parents carry the base motion; do not edit or key those helper bones. Leave the `phase` track as a linear 0-to-1 ramp. Use matching first and last keys for looping clips.

## Supported clips

| Clips | Gameplay sampling |
|---|---|
| `idle_drawn`, `idle_sheathed` | Elapsed breathing time, looping |
| `walk_drawn`, `walk_sheathed` | Actual movement gait; walking speed |
| `run_drawn`, `run_sheathed` | Actual movement gait; running speed |
| `air_drawn`, `air_sheathed` | Time since entering the air state, looping |
| `crouch_drawn`, `crouch_sheathed` | Time in crouch, looping |
| `cover_drawn`, `cover_sheathed` | Time in cover, looping |
| `climb_sheathed` | Signed ladder gait; descending reverses the cycle |
| `recoil_drawn` | Shot recoil progress; additive over the current stance |
| `death` | Time since death, holding the final key |

There is no `climb_drawn`: gameplay requires a sheathed weapon on ladders. Sheathed cover is supported away from ladders. Recoil uses the original 1/7-second decay and can layer over walking, running, crouching, or airborne edits. Death keeps the original fall and fade, with editable bone adjustments over it. Its one-second edit timeline holds at the end while the original fade continues.

The original state transitions, weapon draw/sheath blend, distance-driven feet, recoil, and death behavior remain procedural. The tweaker adds authored corrections over that motion. Changing a movement clip's length redistributes its keys across the gait without changing gameplay speed. Recoil keys are similarly normalized to the actual shot progress. During weapon transitions, the edit variant switches at the blend midpoint.

## Bones and controls

**Hip** carries the full body. **Torso** carries the upper body. **Right...** bones represent the near limb, **Left...** the far limb. Weapon edits move both weapon artwork layers together. Cover has only the original near arm; editing its RightShoulder/RightForearm affects that visible arm.

Prefer native bone tracks for all poses. The older numeric Controls tracks are still supported: hip/torso/head offsets, ankle targets and foot pitch, free-arm swing/bend, and weapon offset/tilt. Arm swing controls apply to free arms; use native bones for drawn-weapon and climbing arms. Recoil numeric controls add to the stance controls, and recoil bone transforms apply after the stance bone transforms.

Edits affect the Darkiron hero. Enemy, Drake, and Azure rigs do not load the tweaker. `characters/darkiron.tscn` remains a standalone reference asset; it is not the hero's runtime animation source.

## Verification

- `tests/animation_parity.gd`: compares all 15 neutral clips at 65 phases against a frozen copy of the old renderer, including artwork order, transforms, and tints.
- `tests/animation_runtime.gd`: edits all 15 clips, saves and reloads them, verifies selection and sampling in `main.tscn`, and checks recoil composition.
- `tests/run_bone_edits.gd`, `tests/climb_bone_edits.gd`: verify native gizmos, hierarchy, saved keys, backward scrubbing, and preview/game geometry.
- `tests/controls.gd`: checks actual gameplay inputs and ladder/cover restrictions.

Run with Godot's `--headless --path . --script tests/<test>.gd`; use an absolute writable `--log-file` path if the default user log directory is unavailable.

## Bow cover and mouse-driven drawing

`bow_cover` ports the bow cover pose used by `debug_drones.tscn`. `bow_draw` exposes the existing mouse-driven draw as a parameterized clip: timeline phase 0 means no pull, phase 1 means full pull. It is not a timed firing sequence. Releasing still fires immediately through the original gameplay code.

Select either clip in **Controls > AnimationPlayer**. For `bow_draw`, scrub to set draw strength and change the root's **Bow Aim Degrees** to inspect different aim directions. F6 uses **Playback Clip** as before. The preview angle is a testing control; gameplay continues to use the mouse. The supported aim range matches the prototype (-57.3 to +34.4 degrees).

Use the usual Hip, Torso, Head and leg bone tracks for body changes. For direct arm corrections, select **LeftShoulder**, **RightShoulder**, **LeftForearm**, or **RightForearm** under **Controls > Skeleton2D** and use the **Move** gizmo. Key **Position** in `bow_cover` or `bow_draw`. Shoulder positions move the arm root; forearm positions move the elbow. The wrists stay connected to the bow grip/string. These are position handles: rotation and scale are not bow-arm posing controls. The original neutral rotation/scale keys prevent transforms from other clips leaking into the handles.

The following **Controls > Bow joint solver** properties also remain available:

| Control | Effect |
|---|---|
| `bow_grip_offset` | Moves the bow grip and attached hand; the opposite arm and string are solved to meet it. |
| `bow_left_shoulder_offset` | Adjusts the bow-supporting shoulder. |
| `bow_right_shoulder_offset` | Adjusts the drawing shoulder. |
| `bow_draw_elbow_degrees` | Adjusts the draw-arm bend during `bow_draw`; the string hand stays on the arrow line. |
| `bow_cover_angle_degrees` | Tilts the stowed bow during `bow_cover`; shooting aim remains mouse-controlled. |

The four native arm Position tracks are applied before drawing the connected arm segments. Their editor handles align with the rendered shoulders and elbows. Hand and Weapon bone transforms remain solver-controlled; use `bow_grip_offset` to move the bow and attached wrist. Start with small offsets and inspect several aim angles and pull amounts; extreme offsets can exceed the fixed-length arm solver's reach. Body Hip/Torso adjustments carry the bow shoulders as well. All new bow values default to zero, preserving the prototype's original motion.

Save and restart `debug_drones.tscn` or `debug_bow.tscn` to apply the edits. The gun-only `main.tscn` does not select bow clips. No input bindings, charge speed, projectile speed, or mouse aim rules were changed.

`tests/bow_animation_edits.gd` verifies original-pose parity, saved edits in the actual drone encounter, preview/game agreement, mouse-driven phase and aim, and shot direction. The preview now uses `scripts/animation_tweaker_preview.gd` and `scripts/animation_tweaker_actor.gd`.
