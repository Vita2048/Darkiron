extends "res://scripts/rig.gd"
var drawing_bow_arms := false
var bow: Node2D

func _ready() -> void:
	if not fighter.enemy:
		bow = preload("res://scripts/plasma_bow.gd").new()
		bow.fighter = fighter
		add_child(bow)

func part(index: int, at: Vector2, size: Vector2, angle := 0.0, tint := Color.WHITE) -> void:
	if index in [2,9,10,11]: return
	if not fighter.enemy and not drawing_bow_arms and index in [3,4,13,14]: return
	super.part(index, at, size, angle, tint)
	# Far arm stays behind the torso; the near arm is raised explicitly below.
	if drawing_bow_arms: parts[part_cursor-1].z_index = 1

func _draw() -> void:
	super._draw()
	if fighter.enemy or fighter.health <= 0 or not is_instance_valid(bow): return
	drawing_bow_arms = true
	# The extended left arm ends at the riser, not beyond it.
	var shoulder := Vector2(8,-126)
	var wrist: Vector2 = bow.grip()+Vector2(-6,2).rotated(bow.aim_angle())
	var elbow := weapon_elbow(shoulder,wrist)
	segment(3,shoulder,elbow,25,Color(0.75,0.83,0.9))
	segment(4,elbow,wrist,18,Color(0.75,0.83,0.9),false)
	# Near right arm draws back; string overlays chest but passes behind fingers.
	shoulder = Vector2(-11,-126)
	wrist = bow.right_hand()
	elbow = weapon_elbow(shoulder,wrist) if fighter.in_cover else bow.draw_elbow()
	var first := part_cursor
	segment(3,shoulder,elbow,27)
	segment(4,elbow,wrist,19,Color.WHITE,false)
	for i in range(first,part_cursor): parts[i].z_index = 70
	drawing_bow_arms = false
