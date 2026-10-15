extends RefCounted
## Source pixels are mapped through muzzle and grip anchors into the rig's weapon space.
const HERO_HEAD = preload("res://assets/darkiron-body-head.svg")
const HERO_RIFLE = preload("res://assets/darkiron-rifle.svg")
const DRAKE_RIFLE = preload("res://assets/drake-rifle-hybrid.png")
const GRIP := Vector2(-24,79)
const MUZZLE := Vector2(46,38)
static func source(drake: bool) -> Rect2:
	return Rect2(58,178,1685,537) if drake else Rect2(34,248,1706,432)
static func pixel_grip(drake: bool) -> Vector2:
	return Vector2(550,580) if drake else Vector2(500,550)
static func pixel_muzzle(drake: bool) -> Vector2:
	return Vector2(1640,383) if drake else Vector2(1735,365)
static func rifle_rect(drake: bool) -> Rect2:
	var stretch := (MUZZLE-GRIP)/(pixel_muzzle(drake)-pixel_grip(drake))
	var region := source(drake)
	return Rect2(GRIP+(region.position-pixel_grip(drake))*stretch,region.size*stretch)
static func support_grip(drake: bool) -> Vector2:
	var pixel := Vector2(1180,498) if drake else Vector2(1250,490)
	var stretch := (MUZZLE-GRIP)/(pixel_muzzle(drake)-pixel_grip(drake))
	return GRIP+(pixel-pixel_grip(drake))*stretch
