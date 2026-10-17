extends Node2D
## Skeleton2D pilot: the same Darkiron archer, posed through bones.
## Existing code is untouched. All joint numbers mirror scripts/rig.gd,
## scripts/plasma_bow.gd and scripts/bow_range_rig.gd (incl. the tuned
## cover tucks), so this scene is a 1:1 technique comparison.
##
## Textured parts are baked ONCE in _ready as rigid snapshots of the
## svg_body module math (valid because every bone length is constant:
## legs 40/40, arms 36/30 and 33/44 enforced by the IK). Cover tucks
## compress bones, so bones carry a fit scale (documented below).
##
## Controls: mouse aims | hold LMB to draw | hold UP for cover |
## T cycles procedural/clip/tune(frozen) | C prints the pose for pasting |
## B white background | P screenshot.
## CLI: --cover --clip --pilot-shot (captures frame 30 and quits).

const ARMS = preload("res://assets/darkiron-body-arms.svg")
const TORSO = preload("res://assets/darkiron-body-torso.svg")
const LEGS = preload("res://assets/darkiron-body-legs.svg")
const HEAD = preload("res://assets/darkiron-body-head.svg")
const BOWPNG = preload("res://assets/plasma-bow-hybrid.png")

const REST_LEN := {"L_Shoulder": 36.0, "L_Elbow": 30.0, "R_Shoulder": 33.0, "R_Elbow": 44.0}
const CoverPose = preload("res://scripts/cover_pose.gd")

## Pose numbers live in scripts/cover_pose.gd (single source of truth).
## Live discovery: TUNE mode (T) freezes the rig, drag bones freely in
## Remote, press C to print the joints, paste the block into cover_pose.gd.

var aim := 0.0
var charge := 0.0
var cover := false
var coverw := 0.0
var mode := 0 # 0 procedural, 1 clip, 2 tune (all drivers frozen)
var clip_aim := 0.0
var white_bg := false
var frames := 0
var shot_done := false
var font: Font = ThemeDB.fallback_font

@onready var puppet: Node2D = $Puppet
@onready var skel: Skeleton2D = $Puppet/PilotSkeleton
@onready var camera: Camera2D = $Camera
@onready var sweep: AnimationPlayer = $SweepPlayer
@onready var bones := {
	"Hips": $"Puppet/PilotSkeleton/Hips",
	"L_Shoulder": $"Puppet/PilotSkeleton/L_Shoulder",
	"L_Elbow": $"Puppet/PilotSkeleton/L_Shoulder/L_Elbow",
	"L_Hand": $"Puppet/PilotSkeleton/L_Shoulder/L_Elbow/L_Hand",
	"R_Shoulder": $"Puppet/PilotSkeleton/R_Shoulder",
	"R_Elbow": $"Puppet/PilotSkeleton/R_Shoulder/R_Elbow",
	"R_Hand": $"Puppet/PilotSkeleton/R_Shoulder/R_Elbow/R_Hand",
	"Bow": $"Puppet/PilotSkeleton/Bow",
}
var far_art: Array[Node2D] = []
var near_art: Array[Node2D] = []
var far_glove: Array[CanvasItem] = []
var string_glove: Array[CanvasItem] = []
var string_wide: Line2D
var string_core: Line2D
var arrow_shaft: Line2D
var arrow_tip: Polygon2D


# --- pure pose math (mirrors rig.weapon_elbow / plasma_bow) ---
static func solve_elbow(shoulder: Vector2, wrist: Vector2) -> Vector2:
	var delta := wrist - shoulder
	var d := clampf(delta.length(), 0.01, 65.9)
	var axis := delta / delta.length()
	var along := (36.0 * 36.0 - 30.0 * 30.0 + d * d) / (2 * d)
	var height := sqrt(maxf(0, 36.0 * 36.0 - along * along))
	return shoulder + axis * along + Vector2(-axis.y, axis.x) * height


static func draw_elbow_at(bow_charge: float, aim_angle: float, shoulder: Vector2) -> Vector2:
	var angle: float = lerpf(0.85, 3.05, bow_charge) + aim_angle
	return shoulder + Vector2.from_angle(angle) * 33


static func nock_at(grip: Vector2, aim_angle: float, elbow: Vector2) -> Vector2:
	var axis := Vector2.from_angle(aim_angle)
	var delta := elbow - grip
	var along := delta.dot(axis)
	var perpendicular := delta.dot(Vector2(-axis.y, axis.x))
	return grip + axis * (along + sqrt(maxf(0, 44.0 * 44.0 - perpendicular * perpendicular)))


# --- rigid art baking (snapshots of svg_body / plasma_bow mapping) ---
static func mod_quad(tex: Texture2D, region: Rect2, ja: Vector2, jb: Vector2, w_param: float, sx: float, sy: float) -> Array:
	var axis := (jb - ja).normalized()
	var side := Vector2(axis.y, -axis.x)
	var corners := PackedVector2Array([region.position, Vector2(region.end.x, region.position.y), region.end, Vector2(region.position.x, region.end.y)])
	var left := INF
	var right := -INF
	for p in corners:
		left = minf(left, (p - ja).dot(side))
		right = maxf(right, (p - ja).dot(side))
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	var dist := ja.distance_to(jb)
	for p in corners:
		pts.append(Vector2((p - ja).dot(side) * w_param / (right - left) * sx, (p - ja).dot(axis) * 100.0 / dist * sy))
		uvs.append(p)
	return [pts, uvs]


static func fore_quads(tex: Texture2D, sx: float, sy: float) -> Array:
	# Same row mesh as svg_body.forearm(), split into rigid quads.
	var rows := [Vector2(1010, 110), Vector2(1010, 198), Vector2(1090, 300), Vector2(1140, 420), Vector2(1145, 520), Vector2(1123, 593), Vector2(1123, 676)]
	var out := []
	for i in range(rows.size() - 1):
		var pts := PackedVector2Array()
		var uvs := PackedVector2Array()
		for corner in [Vector2(950, rows[i].y), Vector2(1255, rows[i].y), Vector2(1255, rows[i + 1].y), Vector2(950, rows[i + 1].y)]:
			var center: float = rows[i].x if corner.y == rows[i].y else rows[i + 1].x
			var along: float = (corner.y - 198.0) * 100.0 / 395.0
			if along < 0:
				along *= 0.40
			pts.append(Vector2((corner.x - center) * 78.0 / 350.0 * sx, along * sy))
			uvs.append(corner)
		out.append([pts, uvs])
	return out


static func tex_quad(tex: Texture2D, dst: Rect2, src: Rect2) -> Polygon2D:
	var poly := Polygon2D.new()
	poly.texture = tex
	poly.polygon = PackedVector2Array([dst.position, Vector2(dst.end.x, dst.position.y), dst.end, Vector2(dst.position.x, dst.end.y)])
	# Polygon2D UVs are texture pixels (unlike draw_polygon's normalized UVs).
	poly.uv = PackedVector2Array([src.position, Vector2(src.end.x, src.position.y), src.end, Vector2(src.position.x, src.end.y)])
	return poly


static func limb_bend(t: float) -> float:
	return 7 * sin(PI * t) - 23 * t * t


static func limb_strip(side: float) -> Array:
	# Rest-shape (charge 0) bow limb ribbon, after plasma_bow.rebuild_limb().
	var left_pts := PackedVector2Array()
	var left_uv := PackedVector2Array()
	var right_pts := PackedVector2Array()
	var right_uv := PackedVector2Array()
	for i in 13:
		var t := i / 12.0
		var bend := limb_bend(t)
		var y := side * (-20 - 67 * t)
		left_pts.append(Vector2(-17 + bend, y))
		left_uv.append(Vector2(240, 1238 - 1224 * t))
		right_pts.append(Vector2(2 + bend, y))
		right_uv.append(Vector2(430, 1238 - 1224 * t))
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	for i in 13:
		pts.append(left_pts[i])
		uvs.append(left_uv[i])
	for i in range(12, -1, -1):
		pts.append(right_pts[i])
		uvs.append(right_uv[i])
	return [pts, uvs]


func _poly(tex: Texture2D, baked: Array, z: int) -> Polygon2D:
	var poly := Polygon2D.new()
	poly.texture = tex
	poly.polygon = baked[0]
	poly.uv = baked[1]
	poly.z_index = z
	return poly


func _build_glove() -> Array:
	# Same gauntlet linework as plasma_bow._draw_hands, in hand-bone space.
	var outline := PackedVector2Array([Vector2(-9, -5), Vector2(-3, -8), Vector2(4, -6), Vector2(5, 4), Vector2(0, 8), Vector2(-8, 5)])
	var fill := Polygon2D.new()
	fill.polygon = outline
	fill.color = Color("0b121c")
	var loop := Line2D.new()
	var closed := PackedVector2Array(outline)
	closed.append(outline[0])
	loop.points = closed
	loop.width = 1.0
	loop.default_color = Color("668194")
	loop.antialiased = true
	var thumb := Line2D.new()
	thumb.points = PackedVector2Array([Vector2(-8, -3), Vector2(-2, 3)])
	thumb.width = 2.0
	thumb.default_color = Color("c1905d")
	thumb.antialiased = true
	return [fill, loop, thumb]


func _ready() -> void:
	camera.make_current()
	get_viewport().size_changed.connect(_fit)
	_fit()
	if "--closeup" in OS.get_cmdline_user_args():
		camera.position = Vector2(270, 610)
		camera.zoom = Vector2(4.0, 4.0)
	_build_body()
	_build_bow()
	print("PILOT ready bones=", bones.size())
	if "--clip" in OS.get_cmdline_user_args():
		mode = 1
		_apply_mode()
	if "--tune" in OS.get_cmdline_user_args():
		mode = 2
		_apply_mode()


func _fit() -> void:
	camera.zoom = get_viewport_rect().size / Vector2(1100, 620)


func _build_body() -> void:
	var hips: Bone2D = bones["Hips"]
	# Legs: static standing quads. Mapping uses the true atlas joints; the
	# baked verts are then shifted so the atlas joint lands on the bone anchor.
	var leg_specs := [
		[0, Rect2(253, 9, 324, 694), Vector2(415, 72), Vector2(456, 620), 72.0, Vector2(0, -14), Vector2(2.09, 25.94), 38.0, 0.87],
		[3, Rect2(253, 9, 324, 694), Vector2(415, 72), Vector2(456, 620), 72.0, Vector2(10, -14), Vector2(10, 25.93), 33.0, 0.87],
		[1, Rect2(926, 12, 286, 685), Vector2(1045, 103), Vector2(1087, 634), 75.0, Vector2(2.09, 25.94), Vector2(2.09, 65.94), 31.0, 0.90],
		[4, Rect2(926, 12, 286, 685), Vector2(1045, 103), Vector2(1087, 634), 75.0, Vector2(10, 25.93), Vector2(5.3, 65.99), 27.0, 0.90],
	]
	for spec in leg_specs:
		var anchor_a: Vector2 = spec[5]
		var anchor_b: Vector2 = spec[6]
		var baked: Array = mod_quad(LEGS, spec[1], spec[2], spec[3], spec[4], spec[7] * spec[8] / 100.0, anchor_a.distance_to(anchor_b) / 100.0)
		var shifted: PackedVector2Array = baked[0]
		for i in range(shifted.size()):
			shifted[i] += anchor_a
		var poly := _poly(LEGS, [shifted, baked[1]], spec[0])
		hips.add_child(poly)
	# Boots.
	for ankle: Vector2 in [Vector2(2.09, 65.94), Vector2(5.3, 65.99)]:
		var pos: Vector2 = ankle + Vector2(5, -8)
		var dst := Rect2(pos + Vector2(-46 * 0.34, 0), Vector2(100 * 0.34, 100 * 0.19))
		var boot := tex_quad(LEGS, dst, Rect2(1537, 336, 531, 358))
		boot.z_index = 2
		hips.add_child(boot)
	# Torso + head: plain rect mapping like svg_body.draw, BUT scaled by the
	# part scale the rig applies (torso 56x58 * breadth 0.80, head 34x37).
	var torso := tex_quad(TORSO, Rect2(-18.6, -49.9, 40.3, 64.4), Rect2(323, 53, 724, 1108))
	torso.z_index = 6
	hips.add_child(torso)
	var head := tex_quad(HEAD, Rect2(-6.2, -77.1, 24.5, 38.1), Rect2(273, 124, 739, 936))
	head.z_index = 7
	hips.add_child(head)
	# Far (bow) arm: textured upper + row-mesh forearm, baked at rest.
	var upper: Array = mod_quad(ARMS, Rect2(298, 54, 400, 556), Vector2(510, 245), Vector2(453, 603), 105.0, 25.0 * 0.83 / 100.0, 36.0 / 100.0)
	var upoly := _poly(ARMS, upper, 1)
	bones["L_Shoulder"].add_child(upoly)
	far_art.append(upoly)
	for q in fore_quads(ARMS, 18.0 * 1.18 / 100.0, 30.0 / 100.0):
		var fpoly := _poly(ARMS, q, 1)
		bones["L_Elbow"].add_child(fpoly)
		far_art.append(fpoly)
	# Near (string) arm.
	upper = mod_quad(ARMS, Rect2(298, 54, 400, 556), Vector2(510, 245), Vector2(453, 603), 105.0, 27.0 * 0.83 / 100.0, 33.0 / 100.0)
	upoly = _poly(ARMS, upper, 70)
	bones["R_Shoulder"].add_child(upoly)
	near_art.append(upoly)
	for q in fore_quads(ARMS, 19.0 * 1.18 / 100.0, 44.0 / 100.0):
		var fpoly := _poly(ARMS, q, 70)
		bones["R_Elbow"].add_child(fpoly)
		near_art.append(fpoly)
	# Gloves ride the hand bones.
	for node in _build_glove():
		node.z_index = 80
		bones["L_Hand"].add_child(node)
		far_glove.append(node)
	for node in _build_glove():
		node.z_index = 80
		bones["R_Hand"].add_child(node)
		string_glove.append(node)


func _build_bow() -> void:
	var bow: Bone2D = bones["Bow"]
	bow.z_index = 60
	var riser := tex_quad(BOWPNG, Rect2(-12.6, -24.5, 22.4, 49), Rect2(825, 260, 225, 850))
	bow.add_child(riser)
	for side in [1.0, -1.0]:
		var limb := Polygon2D.new()
		limb.texture = BOWPNG
		var baked: Array = limb_strip(side)
		limb.polygon = baked[0]
		limb.uv = baked[1]
		bow.add_child(limb)
	string_wide = Line2D.new()
	string_wide.width = 4.0
	string_wide.default_color = Color(0.1, 0.65, 1, 0.13)
	string_wide.antialiased = true
	bow.add_child(string_wide)
	string_core = Line2D.new()
	string_core.width = 1.0
	string_core.default_color = Color("a3eaff")
	string_core.antialiased = true
	bow.add_child(string_core)
	arrow_shaft = Line2D.new()
	arrow_shaft.width = 1.5
	arrow_shaft.default_color = Color("d4e8f1")
	arrow_shaft.antialiased = true
	bow.add_child(arrow_shaft)
	arrow_tip = Polygon2D.new()
	arrow_tip.polygon = PackedVector2Array([Vector2(3, 0), Vector2(-14, -5), Vector2(-10, 0), Vector2(-14, 5)])
	arrow_tip.color = Color("85eaff")
	bow.add_child(arrow_tip)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_T:
				_cycle_mode()
			KEY_B:
				white_bg = not white_bg
			KEY_C:
				_print_pose()
			KEY_P:
				_save_shot("pilot_key.png")


func _cycle_mode() -> void:
	mode = (mode + 1) % 3
	_apply_mode()


func _apply_mode() -> void:
	if mode == 1:
		sweep.play("AimSweep")
	else:
		sweep.stop()


func _joint(bone_name: String) -> Vector2:
	var b: Bone2D = bones[bone_name]
	return skel.to_local(b.global_position)


func _print_pose() -> void:
	# Puppet-space joints, rounded for pasting. In tune mode these are YOUR
	# remote edits; otherwise the currently driven pose. aim/bow included.
	var r := func(v: Vector2) -> Vector2: return Vector2(snappedf(v.x, 0.1), snappedf(v.y, 0.1))
	print("POSE far  shoulder=", r.call(_joint("L_Shoulder")), " elbow=", r.call(_joint("L_Elbow")), " wrist=", r.call(_joint("L_Hand")))
	print("POSE near shoulder=", r.call(_joint("R_Shoulder")), " elbow=", r.call(_joint("R_Elbow")), " string=", r.call(_joint("R_Hand")))
	print("POSE bow grip=", r.call(_joint("Bow")), " aim=", snappedf(aim, 0.01))


func _place(bone: Bone2D, a: Vector2, b: Vector2, rest: float) -> float:
	# Bone +Y convention (same angles as rig.segment). Returns the fit scale.
	var d := a.distance_to(b)
	var s := d / rest
	bone.global_position = skel.to_global(a)
	bone.global_rotation = (skel.to_global(b) - skel.to_global(a)).angle() - PI / 2
	bone.scale = Vector2(1, s)
	return s


func _process(dt: float) -> void:
	frames += 1
	if mode != 2:
		cover = Input.is_physical_key_pressed(KEY_UP) or "--cover" in OS.get_cmdline_user_args()
		coverw = move_toward(coverw, 1.0 if cover else 0.0, dt * 9)
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			charge = minf(1.0, charge + dt / 0.9)
		else:
			charge = maxf(0.0, charge - dt * 1.2)
		var mouse := get_global_mouse_position()
		var origin := puppet.position + Vector2(0, -126)
		var mouse_aim := clampf((mouse.y - origin.y) * 0.0035, -1.0, 0.6)
		if mode == 1:
			_pose_clip()
		else:
			_pose_procedural(mouse_aim)
		puppet.scale.x = lerpf(1.0, 0.83, coverw)
		puppet.modulate = Color.WHITE.lerp(Color(0.58, 0.68, 0.82), coverw)
		for n in far_art:
			n.z_index = 65 if cover else 1
		for n in near_art:
			n.z_index = 70
		for n in string_glove:
			n.z_index = 5 if cover else 80
	queue_redraw()
	if "--pilot-shot" in OS.get_cmdline_user_args() and frames >= 30 and not shot_done:
		shot_done = true
		var tag := "clip" if mode == 1 else ("cover" if cover else "aim")
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://" + "pilot_" + tag + ".png")
		print("PILOT saved pilot_" + tag + ".png at frame ", frames)
		get_tree().quit()


func _pose_procedural(mouse_aim: float) -> void:
	var g: Vector2
	var f_sh := CoverPose.FAR_BASE
	var f_el: Vector2
	var n_sh := CoverPose.DRAW_SHOULDER
	var n_el: Vector2
	var nock: Vector2
	if cover:
		aim = CoverPose.AIM
		g = CoverPose.GRIP
		f_sh = CoverPose.FAR_SHOULDER
		f_el = CoverPose.FAR_ELBOW
		n_sh = CoverPose.NEAR_SHOULDER
		n_el = CoverPose.NEAR_ELBOW
		nock = g + CoverPose.NOCK_OFFSET
		_pose_bones(f_sh, f_el, g + Vector2(-6, 2).rotated(aim), n_sh, n_el, nock, aim)
	else:
		aim = mouse_aim
		g = CoverPose.AIM_SHOULDER + Vector2.from_angle(aim) * 65
		var f_wr: Vector2 = g + Vector2(-6, 2).rotated(aim)
		f_el = solve_elbow(f_sh, f_wr)
		n_el = draw_elbow_at(charge, aim, CoverPose.DRAW_SHOULDER)
		nock = nock_at(g, aim, n_el)
		_pose_bones(f_sh, f_el, f_wr, n_sh, n_el, nock, aim)
	_update_bow(g, nock, aim, cover)


func _pose_clip() -> void:
	# Rotations come from the AnimationPlayer; script only roots the chain
	# and drives the bow prop from the clipped aim value.
	var g := CoverPose.AIM_SHOULDER + Vector2.from_angle(clip_aim) * 65
	var f_wr: Vector2 = g + Vector2(-6, 2).rotated(clip_aim)
	bones["L_Shoulder"].global_position = skel.to_global(CoverPose.AIM_SHOULDER)
	bones["R_Shoulder"].global_position = skel.to_global(CoverPose.DRAW_SHOULDER)
	bones["L_Shoulder"].scale = Vector2.ONE
	bones["R_Shoulder"].scale = Vector2.ONE
	var n_el_global: Vector2 = bones["R_Elbow"].global_position
	var n_el := skel.to_local(n_el_global)
	var nock := nock_at(g, clip_aim, n_el)
	_pose_hand(bones["L_Hand"], f_wr, clip_aim, 1.0)
	_pose_hand(bones["R_Hand"], nock, clip_aim, 1.0)
	_update_bow(g, nock, clip_aim, false)


func _pose_bones(f_sh: Vector2, f_el: Vector2, f_wr: Vector2, n_sh: Vector2, n_el: Vector2, nock: Vector2, ang: float) -> void:
	var s1 := _place(bones["L_Shoulder"], f_sh, f_el, REST_LEN["L_Shoulder"])
	var s2 := _place(bones["L_Elbow"], f_el, f_wr, REST_LEN["L_Elbow"])
	var s3 := _place(bones["R_Shoulder"], n_sh, n_el, REST_LEN["R_Shoulder"])
	var n_el_global: Vector2 = bones["R_Elbow"].global_position
	var s4 := _place(bones["R_Elbow"], skel.to_local(n_el_global), nock, REST_LEN["R_Elbow"])
	# Gloves stay rigid: counter the inherited fit squash (exact at scale 1).
	_pose_hand(bones["L_Hand"], f_wr, ang, s1 * s2)
	_pose_hand(bones["R_Hand"], nock, ang, s3 * s4)


func _pose_hand(hand: Bone2D, wrist: Vector2, ang: float, inherited: float) -> void:
	hand.global_position = skel.to_global(wrist)
	hand.global_rotation = (skel.to_global(wrist + Vector2.from_angle(ang)) - skel.to_global(wrist)).angle()
	hand.scale = Vector2(1, 1.0 / maxf(0.2, inherited))


func _update_bow(grip: Vector2, nock: Vector2, ang: float, hidden_arrow: bool) -> void:
	var bow: Bone2D = bones["Bow"]
	bow.global_position = skel.to_global(grip)
	bow.global_rotation = (skel.to_global(grip + Vector2.from_angle(ang)) - skel.to_global(grip)).angle()
	bow.scale = Vector2.ONE
	var pull := (nock - grip).rotated(-ang)
	var tips := [Vector2(-33.7, -87), Vector2(-33.7, 87)]
	string_wide.points = PackedVector2Array([tips[0], pull, tips[1]])
	string_core.points = PackedVector2Array([tips[0], pull, tips[1]])
	arrow_shaft.visible = not hidden_arrow
	arrow_tip.visible = not hidden_arrow
	if not hidden_arrow:
		var tip := pull + Vector2(110, 0)
		arrow_shaft.points = PackedVector2Array([pull, tip - Vector2(12, 0)])
		arrow_tip.position = tip


func _save_shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://" + path)


func _draw() -> void:
	var ink := Color("0b1c2c") if white_bg else Color("d5deea")
	var cyan := Color("0b5a78") if white_bg else Color("8de3ff")
	if white_bg:
		draw_rect(Rect2(-500, -500, 2200, 1700), Color.WHITE)
	else:
		draw_rect(Rect2(-500, -500, 2200, 1700), Color("090f1c"))
		for x in range(0, 1200, 100):
			draw_line(Vector2(x, 310), Vector2(x, 720), Color("142236"), 1)
		draw_rect(Rect2(-500, 720, 2200, 200), Color("172334"))
	draw_line(Vector2(-500, 720), Vector2(1600, 720), Color("43788a") if not white_bg else Color("0b2a3a"), 2)
	draw_string(font, Vector2(45, 250), "DARKIRON  /  SKELETON2D PILOT", HORIZONTAL_ALIGNMENT_LEFT, -1, 27, cyan)
	draw_string(font, Vector2(45, 282), "PROCEDURAL BONES  vs  KEYFRAMED CLIP", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, cyan)
	draw_string(font, Vector2(45, 311), "MODE: " + ["PROCEDURAL", "CLIP / AimSweep", "TUNE (frozen)"][mode] + "   aim %.2f   draw %d%%" % [clip_aim if mode == 1 else aim, int(charge * 100)], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, cyan)
	draw_string(font, Vector2(45, 754), "MOUSE aim  |  LMB draw  |  UP cover  |  T proc/clip/tune  |  C print pose  |  B background  |  P screenshot", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, ink)
