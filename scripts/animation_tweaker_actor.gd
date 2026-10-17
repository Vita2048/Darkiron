@tool
extends CharacterBody2D
## Render state only. No gameplay, collisions, world, input or physics callbacks.
var enemy := false
var drake := false
var azure := false
var hybrid_body := true
var health := 100.0
var facing := 1.0
var climbing := false
var crouching := false
var in_cover := true
var weapon_blend := 1.0
var running := false
var recoil := 0.0
var gait := 0.0
var dead_time := 0.0

var bow_angle := 0.0
var bow_charge := 0.0
var world = null
