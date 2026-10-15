extends Node2D
var world: Node2D
var drake := false
var azure := false
var hero := false
var velocity := Vector2.ZERO
var settled := false
func _ready() -> void:
	var art := preload("res://scripts/vector_part.gd").new()
	art.configure(2,drake,hero,false,azure)
	art.scale = Vector2(0.99,0.29)
	# Put the sprite's bottom on the physics resting line instead of inside the floor.
	if drake or hero or azure:
		art.position.y = -preload("res://scripts/hybrid_sprites.gd").rifle_rect(drake).end.y*0.29
	else:
		art.position.y = -29
	add_child(art)
func _physics_process(dt: float) -> void:
	if settled or world.paused:
		return
	var previous := position
	velocity.y += 1100*dt
	position += velocity*dt
	rotation += dt*5
	if position.y>1150:
		queue_free()
		return
	for platform in world.platforms:
		if position.x >= platform.position.x and position.x <= platform.end.x and previous.y <= platform.position.y and position.y >= platform.position.y:
			position.y = platform.position.y
			rotation = 0
			settled = true
			break
