extends RefCounted
## Flame texture baker reused from Raptor BossParticleFlames.gd.
const TEX_SIZE := 128

static var _flame_tex: Texture2D
static var _spark_tex: Texture2D
static var _glow_tex: Texture2D

static func flame_texture() -> Texture2D:
	if _flame_tex == null:
		_flame_tex = _bake_flame_tex()
	return _flame_tex

static func spark_texture() -> Texture2D:
	if _spark_tex == null:
		var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		for y in range(16):
			for x in range(16):
				var d := Vector2(x - 7.5, y - 7.5).length() / 8.0
				var a := clampf(1.0 - d, 0.0, 1.0)
				img.set_pixel(x, y, Color(1.0, 0.95, 0.85, a * a))
		_spark_tex = ImageTexture.create_from_image(img)
	return _spark_tex

static func glow_texture() -> Texture2D:
	if _glow_tex == null:
		var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		for y in range(64):
			for x in range(64):
				var d := Vector2(x - 31.5, y - 31.5).length() / 32.0
				var a := clampf(1.0 - d, 0.0, 1.0)
				a = pow(a, 1.6)
				img.set_pixel(x, y, Color(1, 1, 1, a))
		_glow_tex = ImageTexture.create_from_image(img)
	return _glow_tex

static func _bake_flame_tex() -> Texture2D:
	# Natural teardrop: round bulb seated low on the breach, tapering tongue
	# rising to a wispy tip. Achieved with an asymmetric falloff — stretched
	# upward above center, compressed below — plus ridged noise breakup and
	# vertical streaks. Warm root core cooling to a sienna shroud.
	var noise := FastNoiseLite.new()
	noise.seed = 20240
	noise.frequency = 0.045
	noise.fractal_octaves = 3
	var img := Image.create(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGBA8)
	var c := float(TEX_SIZE) * 0.5
	for y in range(TEX_SIZE):
		for x in range(TEX_SIZE):
			# Teardrop mapping around a low bulb center: slim the sides,
			# elongate upward into the tongue, keep the base round and full.
			var dx := (float(x) - c) / c * 1.18
			var dy := (float(y) - c * 1.30) / c
			if dy < 0.0:
				dy *= 0.60 # long tapering rise toward the tip
			else:
				dy *= 1.30 # round seated bulb at the breach
			var r := sqrt(dx * dx + dy * dy)
			var fall := clampf(1.0 - r, 0.0, 1.0)
			fall = fall * fall * (3.0 - 2.0 * fall)
			var n := noise.get_noise_2d(float(x), float(y)) * 0.5 + 0.5
			var ridge := 1.0 - absf(n * 2.0 - 1.0)
			var a := fall * (0.30 + 0.70 * ridge)
			# Vertical tongue stretch: brighter rising streaks above the bulb.
			var tongue := noise.get_noise_2d(float(x) * 2.4, float(y) * 0.55) * 0.5 + 0.5
			var height := clampf(1.0 - float(y) / float(TEX_SIZE), 0.0, 1.0)
			var heat := clampf(a * 1.25 + tongue * 0.30 * fall * height - r * 0.35, 0.0, 1.2)
			var col := Color(0.62, 0.20, 0.05, 1.0).lerp(Color(0.96, 0.48, 0.13), smoothstep(0.05, 0.45, heat))
			col = col.lerp(Color(1.0, 0.78, 0.38), smoothstep(0.40, 0.80, heat))
			col = col.lerp(Color(1.0, 0.99, 0.93), smoothstep(0.78, 1.10, heat))
			img.set_pixel(x, y, Color(col.r, col.g, col.b, clampf(a, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)

