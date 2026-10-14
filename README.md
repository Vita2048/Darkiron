# Darkiron: Ashen Gate

A small, playable Godot 4.7 scene exploring an original dark-fantasy/science-fiction platformer. Painted mountains are combined with detailed vector characters, procedural character posing, vector scenery, and particles. This is an early gameplay and animation study, not a complete first level.

## Play

Double-click **Play Darkiron.cmd**. It uses the Godot installation at `C:\Temp\Godot\Godot_v4.7-stable_win64.exe`.

Alternatively, import `project.godot` into Godot 4.7 and press F6 with `main.tscn` open, or F5 to run the project.

## Controls

| Action | Keys |
| --- | --- |
| Move | Left / Right arrows |
| Run | Hold Shift + Left / Right; sheathe the shotgun for free arm swings |
| Jump | Space; release early for a shorter jump |
| Climb / descend | Up / Down arrows while near the ladder, weapon sheathed |
| Draw / sheathe weapon | S (toggle) |
| Take cover | Hold Up away from a ladder; release to leave cover |
| Shoot | J, F, or left mouse button; fires in facing direction |
| Throw grenade | G |
| Crouch | Hold Down on the ground |
| Restart | R |
| Pause | Escape |
| Toggle sound | M |
| Fullscreen / maximized | F11 |

Cross the low rubble, defeat the first guard, climb to the upper walkway, defeat the second guard, destroy the marked barrier, and enter the gate. The gate opens only when both guards and the barrier are cleared. Crouching ducks standing enemy shots. Throw grenades from a distance; they bounce and detonate after a short fuse. Crouching and shooting also breaks the barrier if you run out of grenades. Shotgun ammunition is unlimited in this study. Grenades do not damage the player in this iteration.

Cover is available while grounded away from ladders, with either weapon state. Bullets pass behind the covered hero. Moving, jumping, shooting, and throwing grenades are blocked while holding cover. Near a ladder, Up climbs only after S has sheathed the weapon and the transition has finished. Drawing is blocked while climbing. A sheathed weapon cannot shoot; drawing and sheathing take 0.28 seconds. The coat has been removed. The new run cycle uses eight joint poses with rear heel recovery, forward knee drive, torso lean, and opposing arm swings when unarmed, guided by the supplied running reference.

## Implementation

- `scripts/game.gd`: scene assembly, projectiles, grenades, world drawing, sound synthesis, and encounter progression.
- `scripts/fighter.gd`: collision-based character controller, ladder state, combat and enemy behavior.
- `scripts/rig.gd`: retained vector armor meshes, analytical knee placement, eight-pose run cycle, weapon transitions, cover, crouching, recoil, and death pose.
- `scripts/hud.gd`: controls, health, objectives, pause/death/completion screens.
- `scripts/vector_armor.gd`: detailed authored vector armor, helmet, weapon and limb shapes.
- `scripts/vector_mesh.gd` and `vector_part.gd`: bake the vector primitives into shared colored meshes and animate transforms, preserving scalable geometry.
- `scripts/dropped_weapon.gd`: detached gun motion and floor settling on death.
- `assets/darkiron-rig.png`: retained experimental atlas; no longer used by characters.
- `assets/mountains.jpg`: byte-for-byte copy of the supplied `distant_Paralax.png` with its actual JPEG extension. Original references remain unchanged and their Godot import mode is Keep.

This initial rig is built programmatically with authored poses and procedural interpolation, rather than editor AnimationPlayer tracks. Guards reuse the same rig with a different tint. Sound effects are synthesized locally. There are no third-party code packages or downloaded music assets.

Study 04 extends the Prince-derived stance correction to walking and running. Explicit thigh/shin poses straighten the supporting leg while the other recovers; pelvis height follows leg reach instead of forcing both knees to bend. Periodic cubic interpolation keeps motion continuous between poses. The coat and pointed hip flaps are absent. Vector Edition 06 completes the vector character conversion. See `PRINCE-REVIEW.md` for the renderer comparison.

The base canvas is now **1920×1080**, with a 1280×720 initial window. Resizing or maximizing stretches the entire game and HUD to fill the client area, including non-16:9 windows. This intentionally permits aspect distortion when the window has a different shape. Canvas-item rendering draws at the actual window resolution; the existing level coordinates are mapped to the HD canvas without changing gameplay distances.

Still outside this scene's scope: ledge grabbing, controller bindings, checkpoints, persistent saves, multiple enemy archetypes, final animation polish, and the complete first level.

## Verification

Run:

```powershell
& 'C:\Temp\Godot\Godot_v4.7-stable_win64_console.exe' --headless --path 'C:\Temp\Darkiron' --fixed-fps 60 --script res://tests/playthrough.gd
```

The input-driven playthrough checks movement, jumping over an obstacle, combat, ascending and descending the ladder, grenade inventory, destructible barrier, completion, survivability, death, and restart. It does not teleport the player through the route. The death-state check repositions the already-dead player to isolate input behavior.

Run the additional control regression with the same command using `res://tests/controls.gd`. Its 16 checks cover physical key bindings, weapon toggling, draw timing, blocked firing when sheathed, cover protection against actual projectiles, cover exit vulnerability, ladder priority, airborne restrictions, and running. Add `-- --visual` without `--headless` to capture run and cover poses.

`res://tests/gait_display.gd` adds six checks for support-leg extension, running recovery, HD canvas size, stretch policy, and actual camera mapping. Its `--visual` mode captures walking/running phases, 16:9 and 4:3 resizing, and a maximized window. All 37 checks passed for Study 04.

To capture the real renderer at the starting view:

```powershell
& 'C:\Temp\Godot\Godot_v4.7-stable_win64_console.exe' --path 'C:\Temp\Darkiron' -- --capture
```

To render and capture stages of the automated playthrough, omit `--headless` and add `-- --visual` to the test command.

## Performance and verification (Vector Edition 06)

The top-right HUD displays sampled FPS and frame time. Armor primitives are baked once into nine shared vector meshes; animation changes only limb transforms. Offscreen geometry is skipped, without removing any visible detail or lowering rendering resolution. Defeated fighters release their guns; the detached weapon falls and settles flat on the platform.

On this machine's AMD Radeon integrated GPU, the same 180-frame, VSync-disabled benchmark at 3840�2054 measured 26.1 FPS / 38.3 ms before and 66.7 FPS / 15.0 ms after. Draw calls fell from 1,954 to 342. These are local scene measurements, not a guaranteed minimum FPS. Raw results are in `tests/performance-before.json` and `tests/performance-after.json`; run `--script res://tests/performance.gd` to repeat the current benchmark.

Regression scripts: `tests/controls.gd` (weapon, cover, ladder restrictions, dropped gun), `tests/playthrough.gd` (complete encounter), and `tests/gait_display.gd` (pose and display scaling).

## Animation refinement (Vector Edition 07)

Replaced the hanging waist frame with a compact belt; thigh and shin armor is about 30% wider. Boots pivot at the ankle and use authored heel-contact, flat-support, toe-off and recovery angles. Pelvis height accounts for the rotated sole to avoid ground penetration. Running cadence is 18% faster at the same travel speed, with two visible flight intervals per stride and up to 17 world units of sole clearance. The collision body remains grounded during this visual stride cycle so ladder and jump controls remain stable.

`tests/pose_review.gd` renders eight-pose walk/run review strips. The gait regression checks sole clearance, grounded support, and flight intervals.

## Proportion refinement (Vector Edition 08)

Torso and helmet are 14% narrower, upper arms 17% narrower, thighs 13% narrower and shins 10% narrower than Edition 07. Forearms are 18% fuller with broader palms. Rounded thigh roots sit beneath continuous pelvis armor, with the hip sockets moved closer together. Bone lengths, stride timing and boot contact geometry are preserved. Standing and eight-pose walking/running renders were inspected.

## Planted running stride (Vector Edition 09)

Torso breadth is reduced another 7.5%. Running speed is 330 units/second (was 300). Run phase advances from actual horizontal displacement, including collision response. During stance, the ankle moves backward locally by exactly the distance the body advances; the boot stays flat until release. Two-bone posing connects the pelvis to this contact target, followed by lifted heel recovery and an airborne interval. The left/right movement regression measured less than 0.00001 units of planted-foot drift over 106 contact samples; gait clearance checks pass. This contact correction applies to the running cycle.

## Torso continuity and weapon grip (Vector Edition 10)

Removed the separate waist rim and belt. The lower abdomen now bridges the leaned chest and hips as a continuous tapered surface. Added shotgun rail teeth, receiver and ejection-port details, fasteners, barrel channels, trigger guard and trigger. The visible arm meets the pistol grip; a separate articulated glove overlays the weapon, and its index finger and the trigger move together during firing recoil. Both weapon and hand share the same transform. Armed and unarmed stride sheets and the controls regression were verified.

## Side-view overlap (Vector Edition 11)

Compared Prince's skeleton and drawDetailedPerson: both legs originate at one projected hip, with a narrower, darker rear leg painted first. Darkiron now follows that layout instead of using horizontally separated hip sockets. Resting leg angles nearly overlap, while the far leg becomes visible during a stride. The firing elbow is tucked forward to keep joint armor inside the torso silhouette. Left/right armed poses, gait clearance, and planted running contact were checked.

## Proportions and energy rounds (Vector Edition 12)

Upper chest narrows 10% toward the shoulders while retaining the abdomen width; helmet narrows about 7%. Thighs broaden progressively below the unchanged hip socket, reaching 16% at the lower thigh; knee armor is fuller. Enemy health bars track the torso at 54 units above its origin, clearing the helmet. Blue player rounds and red-orange enemy rounds use white-hot cores, trails and two shared radial-gradient glow sprites per shot. No dynamic lights or fullscreen postprocessing are required. Combat glow and pose renders were inspected; gait checks pass.
