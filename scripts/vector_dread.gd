extends RefCounted
## Dread Reaver elite armor — alternate skin matching the spiked
## gunmetal / red / purple reference (horned helm, skull pauldron,
## heavy scoped rifle, clawed reptilian legs, hipped power cells).
## Same part indices and joint anchors as vector_armor.gd so the
## existing rig walk / run / cover / climb animation works unchanged.
var canvas
var tint := Color.WHITE
const INK := Color("07060d")
const DARK := Color("1e1628")
const STEEL := Color("3b2f4c")
const STEEL2 := Color("51313d")
const EDGE := Color("9788a8")
const LIGHT := Color("d8cce0")
const RED := Color("ff2348")
const HOT := Color("ff6a8a")
const PURPLE := Color("a64dff")
const PALE := Color("e2c8ff")
const CLAW := Color("c9c2cf")

func points(values: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for i in range(0, values.size(), 2):
		result.append(Vector2(values[i], values[i + 1]))
	return result

func line(values: Array, color: Color, width := 2.0) -> void:
	canvas.draw_polyline(points(values), color * tint, width, true)

func plate(values: Array, color := STEEL, outline := 2.5) -> void:
	var p := points(values)
	var colors := PackedColorArray()
	for v in p:
		var shine := clampf(0.22 - (v.x + 20) * 0.005 - v.y * 0.0008, -0.3, 0.22)
		colors.append((color.lightened(shine) if shine > 0 else color.darkened(-shine)) * tint)
	canvas.draw_polygon(p, colors)
	p.append(p[0])
	canvas.draw_polyline(p, INK * tint, outline, true)

func circle(at: Vector2, radius: float, color: Color) -> void:
	canvas.draw_circle(at, radius, color * tint)

func bolt(x: float, y: float, r := 2.4) -> void:
	circle(Vector2(x, y), r + 1, INK)
	circle(Vector2(x, y), r, EDGE)
	circle(Vector2(x - 0.5, y - 0.7), r * 0.38, LIGHT)

func energy_red(values: Array, width := 2.3) -> void:
	line(values, Color("5e1020"), width * 3.5)
	line(values, RED, width)
	line(values, Color("ffd0da"), width * 0.4)

func energy_purple(values: Array, width := 2.3) -> void:
	line(values, Color("3d1560"), width * 3.5)
	line(values, PURPLE, width)
	line(values, PALE, width * 0.4)

func glow_dot(at: Vector2, r: float, core: Color) -> void:
	circle(at, r + 2.5, INK)
	circle(at, r, core)
	circle(at + Vector2(-r * 0.25, -r * 0.25), r * 0.4, Color.WHITE)

func paint(target, index: int, color: Color) -> void:
	canvas = target
	tint = color
	match index:
		0: helmet()
		1: torso()
		2: rifle(false)
		3: upper_arm()
		4: forearm()
		5: waist()
		6: thigh()
		7: shin()
		8: boot()
		9: trigger_hand(false)
		10: trigger_hand(true)
		11: rifle(true)

func helmet() -> void:
	# Horned helm, haloed red eyes, tusked jaw, cabled gorget.
	plate([-36, 28, -40, 6, -30, 8, -28, -18, -18, -2, -12, -28, -2, -6, 8, -30, 16, -8, 30, -26, 28, -4, 40, -8, 34, 12, 42, 30, 40, 62, 26, 90, 6, 99, -16, 89, -34, 63], DARK)
	# Long back-swept crown horns (silhouette, like the reference).
	plate([-8, -22, -38, -52, -48, -50, -18, -14], DARK, 2.0)
	line([-12, -22, -40, -50], EDGE, 1.6)
	plate([8, -24, -16, -58, -26, -54, -2, -16], DARK, 2.0)
	line([4, -24, -18, -54], EDGE, 1.4)
	plate([-30, 26, -48, 22, -52, 28, -32, 34], DARK, 1.5)
	plate([-30, 26, -18, 10, -12, 22, -28, 32], Color("2a2138"), 1.2)
	plate([-30, 24, -12, 10, 10, 11, 28, 22, 34, 38, 6, 48, -24, 42], STEEL)
	plate([-24, 26, -12, 12, 2, 14, -2, 40, -20, 43], Color("4a3d5e"), 1.8)
	# Crown ridges running to the forehead core.
	line([-16, -8, -8, 18], Color("6f6480"), 1.3)
	line([0, -10, 0, 18], Color("6f6480"), 1.3)
	line([14, -6, 10, 18], Color("6f6480"), 1.3)
	# Heavy brow ridges above the eyes so the sockets read at distance.
	plate([-26, 34, -6, 36, -4, 42, -24, 41], Color("5c4f70"), 1.5)
	plate([2, 36, 26, 32, 28, 39, 4, 43], Color("5c4f70"), 1.5)
	line([-25, 36, -6, 38], EDGE, 1.6)
	line([4, 38, 25, 34], EDGE, 1.6)
	plate([-4, 38, 2, 38, -1, 46], DARK, 1.0)
	# Eyes: haloed red sockets with hot cores.
	circle(Vector2(-13, 47), 8.5, Color("3d0a18"))
	circle(Vector2(15, 44), 8.5, Color("3d0a18"))
	plate([-24, 41, -4, 43, -2, 52, -22, 51], INK, 1.5)
	energy_red([-21, 45, -5, 46], 6.0)
	circle(Vector2(-8, 45), 2.0, Color.WHITE)
	plate([2, 43, 26, 39, 28, 48, 4, 52], INK, 1.5)
	energy_red([5, 46, 24, 42], 6.0)
	circle(Vector2(21, 43), 2.0, Color.WHITE)
	# Forehead core with retaining ring.
	circle(Vector2(-4, 26), 5.5, INK)
	circle(Vector2(-4, 26), 4.2, Color("3a2c48"))
	glow_dot(Vector2(-4, 26), 3.4, HOT)
	# Nasal ridge + nostril slits + cheek definition.
	line([-4, 30, -4, 40], EDGE, 1.4)
	energy_red([-9, 56, -5, 58], 1.6)
	energy_red([9, 55, 13, 57], 1.6)
	line([-24, 44, -28, 52], Color("6f6480"), 1.4)
	line([28, 40, 30, 50], Color("6f6480"), 1.4)
	# Side comm lens (purple) with halo, bolts and drop cable.
	circle(Vector2(-29, 52), 14, Color("1c0f30"))
	circle(Vector2(-29, 52), 13, INK)
	circle(Vector2(-29, 52), 10, Color("2c2140"))
	circle(Vector2(-29, 52), 6, Color("4a2a7a"))
	glow_dot(Vector2(-29, 52), 3.2, PURPLE)
	circle(Vector2(-33, 44), 1.6, EDGE)
	circle(Vector2(-25, 60), 1.6, EDGE)
	line([-32, 64, -36, 80, -30, 90], INK, 3.0)
	line([-32, 64, -36, 80], Color("6f6480"), 1.2)
	# Fanged snout with mouth grille.
	plate([0, 62, 18, 63, 34, 54, 32, 74, 12, 92, -2, 84], Color("2a2138"))
	plate([-6, 66, 16, 65, 14, 78, -4, 79], INK, 1.2)
	for x in [-1, 4, 9]:
		line([x, 67, x, 78], Color("8a7a9a"), 1.2)
	plate([-30, -18, -26, -30, -22, -18], DARK, 1.5)
	line([-29, -20, -26, -28], EDGE, 1.2)
	plate([-14, -28, -9, -40, -5, -28], DARK, 1.5)
	line([-13, -30, -10, -38], EDGE, 1.2)
	plate([6, -30, 12, -42, 16, -30], DARK, 1.5)
	line([8, -32, 11, -40], EDGE, 1.2)
	# Upper fangs (down) + lower tusks (up) + chin spike.
	plate([-9, 70, -4, 70, -6, 86], CLAW, 1.0)
	line([-8, 71, -6, 84], Color.WHITE, 1.0)
	plate([10, 69, 15, 69, 13, 85], CLAW, 1.0)
	line([11, 70, 13, 83], Color.WHITE, 1.0)
	plate([-18, 86, -13, 86, -16, 70], CLAW, 1.0)
	plate([24, 84, 29, 84, 26, 68], CLAW, 1.0)
	plate([0, 96, 10, 96, 5, 108], DARK, 1.2)
	# Gorget + jaw vents + chin bolt.
	plate([-24, 86, 20, 86, 16, 100, -20, 100], Color("241b30"), 1.5)
	line([-22, 90, 18, 90], EDGE, 1.2)
	energy_purple([-26, 60, -24, 74], 2.0)
	energy_purple([-19, 62, -17, 76], 2.0)
	line([-34, 40, -28, 38, -22, 39], EDGE, 1.8)
	bolt(-11, 27, 1.5)

func torso() -> void:
	# Bulky chest, vertical red core, diagonal purple vents, back dorsal fin.
	plate([30, -18, 44, -34, 46, -12, 58, -28, 52, -2, 60, 8, 40, 16, 38, 40], DARK, 2.0)
	plate([-33, 3, -18, -4, 5, -3, 31, 9, 37, 34, 27, 64, 23, 98, -21, 98, -27, 65, -38, 31], DARK)
	plate([-24, 3, -10, 8, 10, 8, 22, 2, 26, 13, 8, 23, -13, 19, -29, 12], Color("574a6a"), 2.0)
	plate([-29, 18, -9, 22, 3, 34, -2, 56, -24, 48, -35, 29], STEEL)
	plate([4, 27, 23, 18, 33, 25, 26, 48, 8, 56], Color("553845"))
	# Central red power slit.
	plate([-6, 40, 6, 40, 4, 78, -4, 78], INK, 1.2)
	energy_red([-1, 44, -1, 74], 4.5)
	# Purple chest vents.
	energy_purple([-26, 34, -16, 44, -8, 46], 2.2)
	energy_purple([24, 33, 18, 43, 10, 46], 2.2)
	for i in 3:
		var y := 56 + i * 12
		plate([-22, y, -4, y + 5, 19, y - 2, 20, y + 8, -1, y + 16, -22, y + 10], Color("2c2338"), 1.5)
		line([-20, y + 2, -5, y + 8], Color("6f6480"), 1.4)
	# Hip cables.
	line([-30, 0, -42, 8, -45, 27, -40, 49, -29, 61], INK, 6.0)
	line([-31, 1, -39, 10, -41, 27, -37, 45], Color("6f6480"), 2.0)
	energy_red([24, 58, 19, 70, 22, 80], 1.8)
	bolt(-27, 25, 1.5)
	bolt(26, 28, 1.5)

func upper_arm() -> void:
	# Massive spiked pauldron with skull emblem.
	circle(Vector2(0, 22), 24, INK)
	# Back spikes (silhouette).
	plate([18, -16, 44, -38, 34, -10], DARK, 2.0)
	plate([30, 2, 58, -10, 40, 14], DARK, 2.0)
	plate([34, 24, 62, 18, 40, 38], DARK, 2.0)
	plate([-39, 20, -27, 8, -29, -11, -11, 3, -4, -14, 6, 2, 29, -7, 23, 10, 42, 22, 43, 47, 27, 56, -24, 56, -42, 43], DARK)
	plate([-32, 20, -16, 7, 9, 7, 30, 21, 36, 41, 18, 48, -26, 44, -38, 33], STEEL)
	line([-31, 19, -15, 11, 7, 11, 28, 23, 32, 33], EDGE, 2.4)
	# Skull emblem on pauldron.
	circle(Vector2(8, 28), 12, Color("6e1230"))
	circle(Vector2(8, 26), 10, Color("c22a4a"))
	circle(Vector2(2, 27), 3.6, INK)
	circle(Vector2(14, 27), 3.6, INK)
	plate([5, 33, 11, 33, 8, 38], INK, 1.0)
	for t in 3:
		line([1 + t * 5, 38, 1 + t * 5, 42], Color("ffd0da"), 1.2)
	energy_purple([22, 12, 26, 22], 1.6)
	# Lower arm plates + red rim lights.
	plate([-28, 47, 26, 49, 22, 77, 12, 94, -15, 96, -24, 75], DARK)
	plate([-21, 53, 18, 55, 13, 76, -14, 84, -23, 68], Color("3a2c48"))
	energy_red([-18, 60, 16, 60], 1.6)
	for i in 3:
		line([-15, 84 + i * 4, 15, 81 + i * 4], Color("6a5f78"), 1.5)
	glow_dot(Vector2(24, 40), 3.0, RED)

func forearm() -> void:
	circle(Vector2(0, 8), 24, INK)
	circle(Vector2(0, 8), 13, Color("4a3560"))
	plate([-30, 20, -23, 11, 20, 12, 32, 24, 24, 65, 14, 77, -16, 77, -27, 58], DARK)
	plate([-23, 23, -12, 17, 20, 22, 22, 49, 13, 65, -13, 62, -25, 48], STEEL)
	line([-23, 25, -18, 46, -10, 58], EDGE, 2.0)
	# Wrist lens + light bar (purple cells like reference).
	glow_dot(Vector2(8, 20), 4.5, PURPLE)
	plate([-9, 28, 17, 28, 18, 43, -8, 43], INK, 1.5)
	energy_purple([-4, 32, 12, 32], 3.0)
	energy_purple([-4, 38, 12, 38], 3.0)
	plate([-20, 70, 20, 70, 25, 81, 17, 96, -17, 99, -26, 86], Color("241b30"), 2.0)
	for x in [-12, -3, 6]:
		line([x, 81, x + 2, 95], Color("9a90a8"), 1.3)
	line([-16, 73, 13, 74], EDGE, 2.0)
	bolt(-15, 23, 1.7)

func thigh() -> void:
	plate([0, -2, 18, 3, 26, 14, 29, 24, 20, 62, 12, 91, -14, 96, -27, 64, -30, 24, -23, 9, -12, 1], DARK)
	plate([-19, 10, 13, 8, 23, 22, 14, 62, -2, 74, -22, 56, -26, 25], STEEL)
	plate([-16, 12, -5, 10, 2, 34, -10, 59, -23, 48], Color("5a4a6c"), 1.5)
	line([-24, 9, -26, 28, -18, 47], EDGE, 2.0)
	# Knee spike + red slit.
	plate([-8, 68, 8, 68, 0, 88], DARK, 1.5)
	energy_red([15, 24, 7, 43, 10, 51], 2.0)
	energy_red([-16, 40, -12, 52], 1.6)
	bolt(-19, 9, 1.8)
	bolt(17, 10, 1.8)

func shin() -> void:
	circle(Vector2(0, 8), 24, INK)
	circle(Vector2(0, 8), 18, Color("453655"))
	plate([-31, 19, -15, 6, 5, 11, 28, 6, 37, 17, 25, 39, 17, 87, -17, 91, -25, 53], DARK)
	plate([-24, 24, -9, 14, 17, 20, 19, 44, 8, 78, -13, 74, -21, 51], STEEL)
	plate([-17, 30, -5, 23, 4, 39, -7, 68, -14, 58], Color("62547a"), 1.5)
	line([-22, 25, -18, 49, -10, 66], EDGE, 2.0)
	energy_purple([12, 30, 5, 48, 8, 57], 2.2)
	energy_red([-20, 44, -16, 58], 1.6)
	# Ankle status lights.
	glow_dot(Vector2(-10, 82), 2.0, PURPLE)
	glow_dot(Vector2(-2, 82), 2.0, PURPLE)
	plate([-18, 80, 15, 78, 19, 94, 12, 100, -20, 97], Color("272032"))
	bolt(0, 8, 5.0)

func boot() -> void:
	# Clawed reptilian foot: 3 talons forward, heel spur.
	plate([-34, 5, 1, 4, 8, 37, 24, 52, 30, 62, 20, 72, -30, 74, -40, 60, -40, 44], DARK)
	plate([-30, 11, -3, 9, 4, 42, -2, 55, -35, 53], STEEL)
	plate([-32, 59, -5, 59, 17, 57, 28, 64, 24, 74, -30, 76, -39, 70], Color("4a3a58"))
	# Talons.
	plate([18, 64, 38, 70, 48, 82, 30, 78], CLAW, 1.5)
	plate([4, 68, 22, 74, 28, 88, 10, 80], CLAW, 1.5)
	plate([-12, 69, 4, 74, 6, 89, -10, 81], CLAW, 1.5)
	line([20, 66, 38, 72], INK, 1.2)
	# Heel spur.
	plate([-40, 55, -28, 58, -38, 72], DARK, 1.5)
	for y in [21, 39]:
		line([-31, y, 0, y + 2], INK, 6.0)
		line([-29, y - 2, -1, y], EDGE, 2.0)
	glow_dot(Vector2(-17, 44), 3.2, PURPLE)
	plate([-43, 83, 20, 83, 16, 94, -38, 96], INK, 2.0)

func rifle(pulled := false) -> void:
	# Enemy rifle redrawn to match the scoped reference side profile:
	# skeleton stock with red lights, triple-slash receiver, red capsule
	# cell, tubed scope with purple objective, red handguard with angular
	# cutouts, long segmented purple cell, twin muzzle tubes with red slits,
	# bracket-mounted serrated bayonet. Same 100-space anchors as before:
	# butt near x -49, muzzles near x +52, pistol grip on (-24, 79).
	# Skeleton stock: pad, frame, triangular cutout, red lights, button.
	plate([-49, 34, -43, 34, -43, 66, -49, 66], Color("141a26"), 2.0)
	for y in [38, 44, 50, 56, 62]:
		line([-49, y, -45, y], INK, 1.4)
	energy_red([-47, 42, -47, 56], 2.0)
	plate([-43, 36, -26, 38, -22, 44, -26, 52, -40, 56, -43, 52], Color("3b2f4c"), 1.8)
	plate([-40, 40, -28, 41, -26, 45, -38, 46], Color("5a2f3a"), 1.2)
	energy_red([-40, 62, -30, 58], 1.8)
	plate([-36, 46, -28, 46, -30, 56, -38, 58], INK, 1.0)
	glow_dot(Vector2(-27, 48), 2.4, RED)
	energy_red([-42, 44, -40, 44], 1.6)
	bolt(-40, 38, 1.4)
	bolt(-32, 48, 1.3)
	line([-42, 37, -28, 39], Color("8e94a0"), 1.0)
	# Junction with triple red slashes.
	plate([-26, 38, -16, 36, -16, 56, -26, 58], Color("5a2f3a"), 1.4)
	for i in 3:
		var x := -23 + i * 3
		line([x, 50, x + 2, 42], Color("4d0d1c"), 2.6)
		line([x, 50, x + 2, 42], RED, 1.4)
	# Receiver main + bevels + screws.
	plate([-16, 30, 12, 30, 14, 36, 14, 58, 10, 62, -12, 62, -16, 56], DARK, 2.0)
	plate([-14, 32, 10, 32, 12, 36, -12, 36], Color("574a6a"), 1.2)
	line([-13, 34, 9, 34], EDGE, 1.1)
	bolt(-12, 38, 1.3)
	bolt(8, 38, 1.3)
	bolt(-12, 58, 1.3)
	bolt(8, 58, 1.3)
	# Horizontal red bars + red dot lights.
	energy_red([-10, 44, 0, 44], 2.0)
	plate([2, 43, 4, 43, 4, 45, 2, 45], INK, 0.8)
	energy_red([2, 44, 4, 44], 1.2)
	glow_dot(Vector2(-8, 54), 1.8, RED)
	glow_dot(Vector2(4, 54), 1.8, RED)
	# Central red capsule cell with cage.
	plate([-2, 42, 10, 42, 10, 54, -2, 54], INK, 1.4)
	plate([0, 44, 8, 44, 8, 52, 0, 52], Color("2c0d16"), 1.0)
	energy_red([1, 46, 7, 46], 2.6)
	energy_red([1, 50, 7, 50], 2.6)
	line([-2, 42, -2, 54], EDGE, 1.0)
	# Small satellite red cells + triple dots.
	plate([12, 43, 18, 43, 18, 49, 12, 49], INK, 1.0)
	energy_red([13, 46, 17, 46], 1.8)
	for dx in [-2, 0, 2]:
		glow_dot(Vector2(2 + dx, 58), 1.3, RED)
	# Textured pistol grip with red slit (hand anchor (-24, 79) inside).
	plate([-28, 64, -14, 64, -18, 80, -22, 92, -30, 90, -30, 72], Color("241b30"), 1.5)
	for y in [68, 72, 76, 80]:
		line([-27, y, -19, y], INK, 1.3)
	energy_red([-25, 70, -23, 82], 1.8)
	plate([-30, 88, -20, 88, -22, 93, -31, 93], INK, 1.0)
	bolt(-26, 90, 1.3)
	# Rounded trigger guard + curved trigger.
	line([-14, 60, 2, 60, 4, 70, 0, 80, -14, 80], INK, 3.6)
	line([-13, 61, 1, 61, 2, 70, -1, 78, -13, 78], EDGE, 1.3)
	line([-6, 63, -9 if pulled else -5, 71, -12 if pulled else -9, 75], Color("cfd6dc"), 1.6)
	glow_dot(Vector2(-10, 82), 1.6, RED)
	# Fat ribbed magazine with red cell window.
	plate([-8, 62, 6, 62, 4, 86, -10, 86], Color("2c2138"), 1.4)
	plate([-5, 66, 3, 66, 3, 80, -5, 80], INK, 1.0)
	for y in [68, 71, 74, 77]:
		line([-4, y, 2, y], Color("4d0d1c"), 2.2)
		line([-4, y, 2, y], RED, 1.2)
	plate([-11, 84, 5, 84, 4, 89, -12, 89], INK, 1.0)
	bolt(-6, 84, 1.1)
	# Top rail teeth + sights + mount screws.
	line([-12, 28, 40, 28], EDGE, 1.4)
	for x in range(-10, 38, 4):
		plate([x, 24, x + 2, 24, x + 2, 28, x, 28], Color("76838a"), 0.6)
	plate([-8, 20, -2, 20, -2, 28, -8, 28], DARK, 1.2)
	plate([34, 22, 40, 22, 40, 28, 34, 28], DARK, 1.2)
	glow_dot(Vector2(-4, 30), 1.6, RED)
	glow_dot(Vector2(16, 30), 1.6, RED)
	# Scope: tube, mounts, turrets, red slits, purple objective.
	line([-12, 22, -10, 28], EDGE, 2.0)
	line([12, 22, 10, 28], EDGE, 2.0)
	plate([-24, 10, 22, 10, 22, 22, -24, 22], DARK, 1.6)
	line([-24, 13, 22, 13], Color("6f6480"), 1.0)
	plate([-28, 12, -24, 12, -24, 20, -28, 20], Color("1c1428"), 1.2)
	circle(Vector2(-26, 16), 2.6, INK)
	plate([-2, 4, 4, 4, 4, 10, -2, 10], Color("3a2c48"), 1.0)
	line([-2, 6, 4, 6], EDGE, 0.8)
	plate([8, 12, 12, 12, 12, 18, 8, 18], Color("3a2c48"), 1.0)
	circle(Vector2(2, 16), 4.5, INK)
	circle(Vector2(2, 16), 3.2, Color("2c2138"))
	line([1, 14, 3, 18], RED, 1.4)
	energy_red([-20, 16, -14, 16], 1.6)
	energy_red([8, 16, 14, 16], 1.6)
	energy_red([18, 16, 20, 16], 1.2)
	plate([22, 10, 28, 10, 28, 22, 22, 22], Color("4a2a3a"), 1.2)
	circle(Vector2(28, 16), 4.5, INK)
	circle(Vector2(28, 16), 3.4, Color("2c1a4a"))
	glow_dot(Vector2(28, 16), 2.4, PURPLE)
	circle(Vector2(29, 15), 1.0, Color.WHITE)
	# Red handguard top with angular cutouts.
	plate([12, 32, 42, 32, 42, 48, 12, 48], Color("5a2f3a"), 1.5)
	line([13, 34, 41, 34], Color("e09a8a"), 1.0)
	for i in 4:
		var x := 16 + i * 6
		plate([x, 36, x + 4, 36, x + 3, 42, x - 1, 42], INK, 0.9)
	bolt(14, 40, 1.3)
	bolt(32, 44, 1.2)
	# Long segmented purple cell.
	plate([20, 51, 44, 51, 44, 58, 20, 58], INK, 1.2)
	energy_purple([21, 54, 43, 54], 3.0)
	for x in range(24, 42, 4):
		line([x, 51, x, 58], INK, 1.2)
	# Lower handguard with cuts + micro red dots.
	plate([12, 58, 40, 58, 40, 68, 12, 68], Color("4a2530"), 1.4)
	line([14, 60, 26, 60], Color("e09a8a"), 1.0)
	plate([28, 60, 36, 60, 34, 66, 28, 66], INK, 0.9)
	energy_red([16, 64, 20, 64], 1.2)
	energy_red([22, 64, 24, 64], 1.0)
	bolt(36, 62, 1.2)
	# Twin muzzle tubes with red slits.
	plate([42, 34, 52, 34, 52, 48, 42, 48], Color("4a5a66"), 1.4)
	plate([42, 52, 52, 52, 52, 66, 42, 66], Color("3b4a56"), 1.4)
	line([42, 35, 52, 35], LIGHT, 1.0)
	energy_red([44, 41, 48, 41], 1.6)
	energy_red([44, 59, 48, 59], 1.6)
	circle(Vector2(52, 41), 2.4, INK)
	circle(Vector2(52, 59), 2.4, INK)
	line([42, 48, 42, 52], INK, 1.6)
	# Mount bracket + foregrip nub.
	plate([34, 66, 42, 66, 42, 76, 36, 78], DARK, 1.4)
	circle(Vector2(38, 71), 3.0, INK)
	glow_dot(Vector2(38, 71), 1.6, RED)
	plate([30, 74, 36, 74, 34, 82, 30, 80], DARK, 1.2)
	# Serrated bayonet: fuller, scalloped spine, clip-point tip.
	plate([38, 70, 66, 70, 62, 78, 38, 78], Color("b9bec6"), 1.5)
	line([40, 72, 60, 72], Color("f2f4f6"), 1.1)
	line([40, 74, 58, 74], INK, 0.9)
	for i in 5:
		var x := 42 + i * 4
		circle(Vector2(x, 78), 1.6, INK)
	line([38, 77, 62, 77], INK, 1.2)
	bolt(-24, 38, 1.3)
	bolt(20, 60, 1.3)

func waist() -> void:
	# Belt with hipped purple power canisters (right hip, like reference).
	plate([-46, 0, 46, 0, 43, 35, 38, 73, 21, 96, 0, 100, -23, 94, -39, 70, -44, 32], DARK, 1.8)
	plate([-35, 0, 5, 0, 7, 67, -10, 83, -29, 66], Color("2e2438"), 0.8)
	plate([9, 0, 34, 0, 31, 65, 16, 82, 7, 64], Color("3a2c48"), 0.8)
	# Canisters.
	plate([14, 30, 34, 30, 34, 78, 14, 78], Color("241b30"), 1.5)
	plate([16, 48, 26, 48, 26, 72, 16, 72], INK, 1.0)
	energy_purple([21, 50, 21, 70], 3.2)
	plate([27, 48, 35, 48, 35, 72, 27, 72], INK, 1.0)
	energy_purple([31, 50, 31, 70], 3.2)
	energy_red([18, 34, 30, 34], 1.8)
	line([-32, 12, -30, 47, -23, 67], Color("5a4e6c"), 1.2)

func trigger_hand(pulled: bool) -> void:
	# Clawed gauntlet in weapon coordinates.
	plate([-29, 67, -23, 62, -14, 66, -11, 77, -14, 94, -26, 94, -31, 85], Color("3a2c48"), 1.1)
	plate([-28, 69, -23, 65, -18, 69, -18, 80, -28, 82], Color("574a6a"), 0.9)
	# Claw tips.
	plate([-27, 82, -22, 82, -24, 92], CLAW, 0.8)
	plate([-21, 83, -16, 83, -18, 93], CLAW, 0.8)
	plate([-15, 83, -10, 83, -12, 92], CLAW, 0.8)
	var tip := -10.0 if pulled else -6.0
	line([-20, 70, -14, 66, tip, 68, tip - 1, 76, -13, 77], INK, 5.5)
	line([-20, 70, -14, 66, tip, 68, tip - 1, 76, -13, 77], Color("9a90a8"), 3.2)
