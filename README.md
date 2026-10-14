# Darkiron — The Cinderworks

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

`level_art.gd` renders the environment; `game.gd` owns the route, pickups, combat and checkpoint; `fighter.gd` handles movement and ladder selection. Detailed characters retain cached vector meshes and planted running feet. Blue/red energy rounds and the FPS HUD remain available. Explosions reuse Raptor’s blended atlas and flame texture, leaving cosmetic burning residue that cools and disappears. Destroyed blast doors also leave burning metal wreckage at their own base. Modular raster ladders and detailed grenade/medical-case sprites use the new equipment atlas.

See `LEVEL-DESIGN.md` for route details and `ITERATION-HISTORY.md` for earlier character iterations. This is a complete playable prototype route, not a finished commercial game. Sound effects are synthesized; bombs currently do not hurt the player.

## Verify

Run Godot with `--headless --path . --script res://tests/cinderworks.gd` for the full level regression. `tests/effects_ai.gd` checks reaction, pursuit, edge safety and effect lifetime. `tests/controls.gd`, `tests/gait_display.gd`, and `tests/run_contact.gd` check controls, poses and grounded feet. Use `--script res://tests/cinderworks.gd -- --visual` without headless mode to capture key areas.

## First enemy: Obsidian Drake

The first yard guard now uses a generated dragon helmet inspired by Enemy.png, combined with custom vector armor, spiked skull pauldrons, clawed boots, a swaying plated tail and a purple bayonet rifle. Remaining guards and the hero retain their previous appearance. The variant reuses the existing locomotion, cover, aiming and death behavior; cached meshes keep animation inexpensive. The dropped rifle retains its purple variant.

Body hits now use additive blue/red bloom matching the projectile, a white-hot core and matching sparks. The old orange hit disc has been removed.

`tests/drake_visual.gd` captures idle, stride, turning, cover and death close-ups and verifies the variant's dropped weapon. `tests/enemy_cover.gd` exercises the new enemy in actual combat.
