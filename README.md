# Darkiron � The Cinderworks

A playable original dark-fantasy / science-fiction platformer level in Godot 4.7. Chapter 01 now spans a fortress yard, elevated demolition gallery, supply alcove, relay checkpoint and furnace gate, with generated raster environment art and animated vector characters.

## Play

Double-click **Play Darkiron.cmd**. The game starts maximized, fills the window and displays FPS. It uses `C:\Temp\Godot\Godot_v4.7-stable_win64.exe`. F11 toggles fullscreen.

| Action | Control |
|---|---|
| Move / climb | Arrow keys |
| Run | Shift + Left / Right |
| Jump | Space |
| Draw / sheathe | S |
| Take cover | Hold Up (at ladders: gun drawn) |
| Crouch | Down |
| Shoot | J / F / left mouse |
| Throw bomb | G |
| Continue after death | Enter |
| Restart whole level | R |
| Pause / sound | Esc / M |

Sheathe before climbing. Step close to amber caches to collect bombs; cyan medical cases restore health automatically when needed. Reinforced blast seals resist bullets and require a nearby bomb explosion. Bomb caches disappear after collection and stay collected after checkpoint recovery. Each supplies three bombs when there is room for the full pickup (capacity six). Clear both seals and all six guards, then reach the cyan furnace portal. The relay after the first breach provides a checkpoint; Enter preserves earned progress after death.

Guards turn toward attacks, return fire and pursue along their current platform, stopping before edges. They also take cover against visible fire, with delayed reactions and a 35% chance of missing each opportunity. Time shots for when they emerge, or use grenades. Hits now produce directional glowing sparks and metal fragments. The two yard jumps now cross real abysses: jump near the lip or hold Shift for extra distance.

## Art and implementation

The generated art is in `assets/cinderworks-background.png`, `assets/cinderworks-platform.png`, `assets/cinderworks-props.png`, and `assets/cinderworks-equipment.png`. Generation used the built-in image tool; prompt specifications are recorded in `assets/CINDERWORKS-PROMPTS.md`. Raster source files are unmodified. Runtime atlas regions provide the platform, exit, cache, seal and relay graphics.

`level_art.gd` renders the environment; `game.gd` owns the route, pickups, combat and checkpoint; `fighter.gd` handles movement and ladder selection. Detailed characters retain cached vector meshes and planted running feet. Blue/red energy rounds and the FPS HUD remain available. Explosions reuse Raptor�s blended atlas and flame texture, leaving cosmetic burning residue that cools and disappears. Destroyed blast doors also leave burning metal wreckage at their own base. Modular raster ladders and detailed grenade/medical-case sprites use the new equipment atlas.

See `LEVEL-DESIGN.md` for route details and `ITERATION-HISTORY.md` for earlier character iterations. This is a complete playable prototype route, not a finished commercial game. Sound effects are synthesized; bombs currently do not hurt the player.

## Verify

Run Godot with `--headless --path . --script res://tests/cinderworks.gd` for the full level regression. `tests/effects_ai.gd` checks reaction, pursuit, edge safety and effect lifetime. `tests/controls.gd`, `tests/gait_display.gd`, and `tests/run_contact.gd` check controls, poses and grounded feet. Use `--script res://tests/cinderworks.gd -- --visual` without headless mode to capture key areas.

## First enemy: Obsidian Drake

The first yard guard now uses a generated dragon helmet inspired by Enemy.png, combined with custom vector armor, spiked skull pauldrons, clawed boots, a swaying plated tail and a purple bayonet rifle. Remaining guards and the hero retain their previous appearance. The variant reuses the existing locomotion, cover, aiming and death behavior; cached meshes keep animation inexpensive. The dropped rifle retains its purple variant.

Body hits now use additive blue/red bloom matching the projectile, a white-hot core and matching sparks. The old orange hit disc has been removed.

`tests/drake_visual.gd` captures idle, stride, turning, cover and death close-ups and verifies the variant's dropped weapon. `tests/enemy_cover.gd` exercises the new enemy in actual combat.

## Hybrid head and rifle artwork

Darkiron now uses a reference-based raster helmet and orange-lit black/red rifle; the Obsidian Drake uses a reference-based scoped purple rifle and bayonet. These sprites are integrated into the existing vector skeleton. Hands remain articulated vector parts; grip and muzzle anchors align the artwork with aiming, recoil, cover and muzzle flashes. Matching weapons are used when sheathed and dropped.

Generated assets: `assets/darkiron-head-hybrid.png`, `assets/darkiron-rifle-hybrid.png`, `assets/drake-rifle-hybrid.png`. Exact built-in image-generation prompts are in `assets/HYBRID-EQUIPMENT-PROMPTS.md`. Original `Darkiron.png` and `Enemy.png` remain unchanged.

`tests/hybrid_equipment.gd` renders both characters in aiming, recoil, turning, cover, sheathed and dropped-weapon states. Controls and full-level regression also pass.

## SVG Darkiron player

The hero now uses `darkiron-body-torso.svg`, `darkiron-body-arms.svg`, `darkiron-body-legs.svg`, `darkiron-body-head.svg`, and `darkiron-rifle.svg`, assembled by `scripts/svg_body.gd` on the existing articulated rig. The corrected body SVGs are used without modifying their paths, preserving their filled armor interiors and transparent backgrounds. Helmet proportions, arm widths, wrist pivots and rear-limb shading have been adjusted for a more coherent silhouette. The coat remains omitted.

Godot imports SVG artwork to cached textures; this is SVG-authored artwork, not runtime tessellation. The rifle uses the same grip/muzzle mapping when held, slung or dropped. `player.hybrid_body = false` still selects the older procedural body for comparison; the SVG helmet and rifle remain consistent. The earlier raster assets are retained as source experiments.

`tests/modular_body.gd` captures walk/run cycles, climbing, idle, aiming, recoil, left-facing, crouch and cover poses, and checks SVG transparency and the procedural fallback. Run with a graphical Godot renderer to capture `preview-body-*.png`.

`tests/svg_joints.gd` checks transparency and captures both walking/running directions, idle, aim and climb on the white `debug_movement.tscn` background. The boot crop excludes its redundant upper cuff and aligns the visible ankle hinge to the shin endpoint. Forearm and glove anchors use the elbow/wrist hinges. Sole height and running contact timing are preserved.

## SVG Obsidian Drake body

The first guard uses `enemy-body-torso.svg`, `drake-body-arms.svg`, `drake-body-legs.svg`, and `drake-body-tail.svg` through `scripts/drake_svg_body.gd`. Four overlapping tail sections sway behind the pelvis. Existing Drake head and rifle assets remain in use. Other guards and Darkiron retain their own renderers. `tests/drake_svg.gd` captures white-background movement poses and checks module selection; `tests/drake_visual.gd` checks the actual first guard, cover, death and dropped weapon.

Player aiming and cover use a fixed-length two-bone arm solve with the elbow behind the shoulder, and the standing rear foot is staggered forward. Walking now uses a distance-driven planted phase shared by Darkiron, Drake and procedural guards. `tests/walk_contact.gd` measures actual world-space foot drift for both enemy types in both directions; `tests/run_contact.gd` covers running.

## Plasma bow debug range

Double-click **Test Bow.cmd**, or open `debug_bow.tscn` in Godot and press F6.
Hold the left mouse button: move up/down to aim, drag left to increase power and right to reduce it, then release to fire. Full draw takes 220 logical pixels of leftward movement; holding still does not increase energy. Right-click cancels the draw. Arrows have gravity, so aim above distant targets. Strength affects launch speed, not damage.

The stationary, unarmed Obsidian Drake never attacks. Its active health bar loses one-third of maximum health per headshot or one-quarter per body hit: three headshots or four body hits defeat it. R resets the target and clears arrows; H displays hit zones; Esc pauses; F11 toggles fullscreen. This isolated prototype uses the existing character art with a bow pose, cyan plasma arrowheads, glow and impact sparks. The abyss/gun pickup and fireball encounter are the subsequent level integration, not part of this range.

Verify with Godot `--headless --path . --script res://tests/bow_range.gd`. Run the same test with a graphical renderer to write `preview-bow-range.png`.


The bow now uses a generated transparent atlas (assets/plasma-bow-hybrid.png): a rigid riser and mesh-deformed limbs. The left hand leads aiming; drawing rotates the right elbow backward with a fixed-length forearm. Both held and flying arrows use feather fletching. Launch speed is 640-2080 units/second, 60% above the original range. Art provenance and the generation prompt are in assets/PLASMA-BOW-PROMPT.md.

## Hunter drone encounter

**Test Bow.cmd** now launches `debug_drones.tscn`: three evasive hunter drones in the Cinderworks backdrop. Hold **Up** to crouch behind a deployable energy shield; release Up before shooting. Orange sensor pulses and targeting lines warn of incoming rounds. Mouse bow controls remain unchanged. Sensor hits remove one-third of full drone health; armor hits remove one-quarter. Five unblocked enemy hits defeat the player. R restarts the encounter; clearing all three drones wins.

The generated `assets/ember-drone.png` is animated with banking, cyan exhaust, flight trails, muzzle pulses, projectile glow, shock rings and falling debris. Destruction reuses the Raptor blast effect. The exact built-in image-generation prompt is recorded in `assets/DRONE-PROMPT.md`. Bow limbs now start at the riser's outer attachment sockets.

The original passive target remains available through `debug_bow.tscn`. Run `--script res://tests/drone_range.gd` for drone movement, live cover protection, damage/death, shot restrictions, pause, reset, sensor/body collisions and victory checks. A graphical run captures `preview-drone-cover.png` and `preview-drone-encounter.png`.

Drone exhaust now emits separately from both rear engine nozzles and follows banking. Enemy projectiles are textured fireballs with ember wakes and small Raptor explosions at the actual armor or cover contact point. Holding Up uses the existing gun-cover stance without the extra crouch.
