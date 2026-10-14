# The Cinderworks — Chapter 01

An original dark-fantasy refinery escape, built around deliberate movement, cover, vertical routes and demolition. Approximately 6,300 world units across, compared with the previous 2,980-unit test scene.

## Route

1. **Outer yard:** cross rubble, use cover and defeat the first sentinel. No starting bombs.
2. **Demolition gallery:** sheathe and climb at x1250; pick up three bombs at x1550. Clear the gallery guard. Throw from around x1800–1900 to breach the tall seal at x2200. Its full-height collision and bullet resistance make the explosive interaction legible.
3. **Relay yard:** clear the guard beyond the seal and leave the elevated gallery. Reaching x2600 activates the relay checkpoint and grants up to 30 health. Cross another low obstacle and engage the next guard.
4. **Supply detour:** climb at x3400 to an optional upper alcove with bombs and a 40-health medkit. Or stay below and use the cache at x3780. Throw from around x3900 to breach the lower seal at x4300.
5. **Furnace approach:** defeat the yard guard, collect the last medkit and climb at x5100. Clear the final guard and enter the cyan portal near x5940. Both seals and all six guards must be cleared.

## Recovery and pacing

Caches grant three bombs when inventory is below three, then recharge for 12 seconds. This prevents missed throws from creating a permanent dead end. Medkits are automatic, single-use, and only consumed when injured. Bombs do not damage the hero in this iteration. ENTER after death returns to the latest relay with full health while preserving broken seals and defeated guards. R restarts the entire level.

## Visuals

Three generated raster assets supply the gorge/refinery panorama, masonry catwalk modules and a four-prop atlas. Runtime source rectangles select platform and prop regions; source PNGs remain unchanged. Solid platform tops are aligned to the artwork's opaque upper edge. Vector ladders, glowing rounds, blast rings and small signs provide responsive feedback. The character renderer remains the retained vector-mesh implementation.

## Validation

`tests/cinderworks.gd` uses actual movement, combat, ladder and grenade inputs to traverse the complete route, checks pickup progression, bullet-resistant seals, both bomb breaches, the optional route, checkpoint recovery and replenishment. `-- --visual` additionally captures gallery, alcove, yard and gate screenshots. `tests/playthrough.gd` aliases this current-level test. The controls and gait suites remain separate.
