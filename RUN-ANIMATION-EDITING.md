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
