# The Cinderworks — Chapter 01

An original dark-fantasy refinery escape, built around deliberate movement, cover, vertical routes and demolition. Approximately 6,300 world units across, compared with the previous 2,980-unit test scene.

## Route

1. **Outer yard:** jump the first abyss (x410–525), use cover and defeat the first sentinel. No starting bombs.
2. **Demolition gallery:** sheathe and climb at x1250; pick up three bombs at x1550. Clear the gallery guard. Throw from around x1800–1900 to breach the tall seal at x2200. Its full-height collision and bullet resistance make the explosive interaction legible.
3. **Relay yard:** clear the guard beyond the seal and leave the elevated gallery. Reaching x2600 activates the relay checkpoint and grants up to 30 health. Jump the second abyss (x2920–3030) and engage the next guard.
4. **Supply detour:** climb at x3400 to an optional upper alcove with bombs and a 40-health medkit. Or stay below and use the cache at x3780. Throw from around x3900 to breach the lower seal at x4300.
5. **Furnace approach:** defeat the yard guard, collect the last medkit and climb at x5100. Clear the final guard and enter the cyan portal near x5940. Both seals and all six guards must be cleared.

## Recovery and pacing

Caches grant three bombs when inventory is at most three (capacity six), then disappear permanently until a full restart. Collection persists through checkpoint recovery. Medkits are automatic, single-use, and only consumed when injured. Bombs do not damage the hero in this iteration. ENTER after death returns to the latest relay with full health while preserving broken seals and defeated guards. R restarts the entire level.

## Visuals

Three generated raster assets supply the gorge/refinery panorama, masonry catwalk modules and a four-prop atlas. Runtime source rectangles select platform and prop regions; source PNGs remain unchanged. Solid platform tops are aligned to the artwork's opaque upper edge. Modular raster ladders, glowing rounds, Raptor explosion frames and small signs provide responsive feedback. The character renderer remains the retained vector-mesh implementation.

## Validation

`tests/cinderworks.gd` uses actual movement, combat, ladder and grenade inputs to traverse the complete route, checks pickup progression, bullet-resistant seals, both bomb breaches, the optional route, checkpoint recovery and single-use pickup persistence. `-- --visual` additionally captures gallery, alcove, yard and gate screenshots. `tests/playthrough.gd` aliases this current-level test. The controls and gait suites remain separate.

## Edition 14 — reactive guards and demolition effects

Guards react to attacks from behind immediately, remember the player for eight seconds and advance to a 180-unit firing distance. They brake before platform edges; intact blast seals block sight. Pursuit stays on connected platforms (guards do not climb ladders). An initial reaction can shorten the firing delay, but repeated frontal hits cannot bypass the 1.15-second weapon cooldown.

Grenades use a rotating amber-core raster sprite. The medical pickup uses a ceramic case with cyan lighting. Ladders repeat a weathered steel/bronze raster segment, with a clipped final module. Original atlas alpha is preserved.

Explosions adapt Raptor's blended 16-frame atlas and procedural flame texture. Grounded blasts leave cosmetic scorch marks, glowing debris, flickering flames, smoke and embers; flames cool over eight seconds and residue fades by twelve. Air blasts over an abyss leave no floating fire. Effects pause with the game and active effect count is bounded.

Walk-jump near each lip (around x385 and x2895), or use Shift for a longer running jump. Falling into a shaft is fatal; Enter restores the checkpoint.

`tests/effects_ai.gd` checks rear-hit reaction, return fire, pursuit, edge braking, falling, anchored residue, pause and cleanup. `tests/cinderworks.gd` completes both jumps and the entire combat/bomb route using gameplay inputs.

Gun drawn + Up takes cover even beside a ladder; sheathed + Up climbs. Destroyed blast doors spawn burning metal wreckage at the door base independently of the grenade impact location.

## Enemy cover and impact feedback

A visible shot toward a guard within 620 units triggers a cover decision: 65% success, 35% missed reaction. Successful decisions have a 0.12–0.24-second reaction delay, then 0.45–0.85 seconds in cover. Guards cannot move or fire in cover, emerge to return fire and remain exposed for at least 1.2 seconds before another decision. Shots from behind and blocked lines of sight do not trigger anticipatory cover. Close-range rounds can arrive before the guard reacts. Grenade damage still bypasses cover.

Bullet impacts are placed at the contact surface, with a brief white flash, colored glow, directional sparks and glowing metal fragments. Armor favors warm sparks; scenery retains the projectile energy color. Effects pause with gameplay, expire after 0.42 seconds and are capped at 24 active bursts.

`tests/enemy_cover.gd` exercises delayed reactions, successful and missed cover, vulnerability windows, return fire, shots from behind, bullet passage, impact pause/expiry and bullet-resistant doors. Add `-- --visual` to capture cover and impact screenshots.
