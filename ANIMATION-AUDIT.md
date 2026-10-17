# Darkiron animation audit — 2026-10-17

The seven clips in `characters/darkiron.tscn` are **not a visually or temporally exact port** of `scripts/rig.gd`. The scene's authored keys were preserved during this audit. Runtime wiring was corrected separately.

## Pose comparison

`tests/animation_parity.gd` samples 65 phases per clip against the original procedural renderer. It compares torso, head, weapon, thigh and shin origins/rotations in unscaled skeleton space. Cover and crouch compare their held midpoint poses. These are maximum sampled discrepancies, not pixel-image error scores or bounds on every bone. The visual sheet also shows the arms, hands and artwork.

| Clip | Largest sampled joint error | Largest sampled rotation error |
|---|---:|---:|
| idle | 5.23 px | 7.49° |
| walk | 16.09 px | 21.76° |
| run | 21.90 px | 85.67° |
| air | 1.11 px | 1.54° |
| crouch | 14.71 px | 21.32° |
| cover | 10.41 px | 1.45° |
| climb | 68.00 px | 164.33° |

`preview-animation-parity.png` shows procedural rendering on the left and authored rendering on the right at phase 43/64 (cover/crouch are held at their midpoint). Visually, the run recovery leg, crouch depth, supporting hand, torso breadth and climbing weapon placement differ. Climbing leaves the weapon beside the raised hand instead of slung against the back. Air is the closest of the sampled body poses, but this does not establish identical artwork or transition behavior.

The clips use sparse, linearly interpolated pose keys. For example, run has five keys across the whole cycle; the procedural gait includes piecewise contact/recovery trajectories, cubic foot rotation and nonlinear pelvis motion. Matching the endpoints or overall cycle length cannot reproduce those intermediate poses. The original torso artwork also receives a 0.80 width multiplier that the skeleton torso polygon lacks.

## Timing

| Clip | Authored length | Procedural behavior |
|---|---:|---|
| idle | 2.244 s | Breathing period `TAU / 2.8 = 2.243995 s`; matching period, different sampled curve. |
| walk | 0.5386 s | Distance-driven cycle: `TAU * 18 / 210 = 0.538559 s` at full walk speed. |
| run | 0.46666667 s | Distance-driven cycle: `TAU * 24.5 / 330 = 0.466479 s` at full run speed. |
| climb | 1.0832 s | Signed distance-driven cycle: `TAU * 25 / 145 = 1.083308 s`; stops/reverses with ladder movement. |
| air | 0.786 s | No fixed procedural clip length; pose depends on state, gait and clock. Jump duration varies with early release and terrain. |
| crouch | 0.25 s | Scene enters over 0.125 s and exits over 0.125 s; original immediately changes some pose targets and fades standing weight at 8/s. Not equivalent. |
| cover | 0.2 s | Scene enters/exits over 0.1 s each; original fades cover weight at 9/s (0.111111 s) and standing weight at 8/s, while other targets change immediately. Not equivalent. |

Walk/run/climb runtime playback remains tied to the original gait phase. Editing their animation length changes how the timeline is sampled, not the character's distance per stride. Idle, air and held-state transition durations use scene resource lengths directly. Cover and crouch must retain the enter/hold-at-half-length/exit layout.

The procedural renderer also blends standing, walking and running weights over time. Switching directly between the current clips does not reproduce those transitions. The audit compares settled states, not every possible transition or combination (for example moving crouch).

## Runtime fixes and verification

- Removed duplicated hard-coded clip lengths; the AnimationPlayer resources now supply them.
- Crouch now holds the crouching midpoint rather than reaching and holding the final standing frame. It uses the authored exit half on release, with continuous timeline reversal on interruption.
- Cover uses the same duration-aware enter/hold/exit handling.
- Climb is allowed while the weapon is holstered, as required by the actual ladder controls. Previously its clip was unreachable in normal climbing.
- Advanced the clock before sampling the animation, avoiding the previous one-update lag.
- Corrected the existing save/reopen test, which tried to edit and seek 0.3 s in a 0.2 s clip.

`tests/animation_runtime.gd` instantiates `main.tscn`, changes an animation's head-position keys and length in memory, and verifies that the shipped player's rig selects every clip and retains those authored values across updates. It also checks gait sampling against edited lengths, held midpoints, exit playback and interrupted exits. The original animation resources are restored after each case. The save/reopen test separately verifies persistence of an authored key on disk.

Passing checks: animation runtime integration, cover/save/reopen, existing procedural walk-contact and run-contact tests. The contact tests validate original movement math; they do **not** certify foot planting of the sparse skeleton clips. The parity tool is diagnostic and exits successfully even when poses differ.

## Remaining coverage gaps

- Holstered idle/walk/run/air and weapon draw/holster transitions still use the procedural fallback. Scene edits do not affect those states.
- Death still uses the procedural fallback.
- Firing while the skeleton is active displays a muzzle flash but does not reproduce procedural weapon recoil/arm IK or the firing artwork variant. There is no recoil clip.
- Enemy/Drake/Azure rigs use their own procedural paths; this scene drives the Darkiron hero.
- To achieve full parity, the pose curves, artwork scale/attachment differences, state blending and missing weapon/death states still need migration. Do not run `tools/build_darkiron_skeleton.py` over edited work: it is an older one-time generator that only creates RESET and cover and would replace the scene.

## Reproduce

Run Godot from the project directory, supplying an absolute writable log path if the default user-data directory is unavailable:

```powershell
& C:/Temp/Godot/Godot_v4.7-stable_win64_console.exe --headless --path C:/Temp/Darkiron --log-file C:/Temp/Darkiron/.runtime/parity.log --script tests/animation_parity.gd
& C:/Temp/Godot/Godot_v4.7-stable_win64_console.exe --path C:/Temp/Darkiron --log-file C:/Temp/Darkiron/.runtime/parity-visual.log --script tests/animation_parity.gd -- --visual
& C:/Temp/Godot/Godot_v4.7-stable_win64_console.exe --headless --path C:/Temp/Darkiron --log-file C:/Temp/Darkiron/.runtime/runtime-animation.log --script tests/animation_runtime.gd
```
