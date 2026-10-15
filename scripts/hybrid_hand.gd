extends "res://scripts/vector_armor.gd"
## Articulated hand aligned to the generated rifles' pistol grip and trigger guard.
func trigger_hand(pulled: bool) -> void:
	plate([-30,69,-24,62,-19,65,-17,78,-20,98,-29,96,-33,83],Color("344957"),1.2)
	plate([-29,70,-24,65,-20,68,-21,79,-30,81],STEEL,0.9)
	for y in [83,89,94]: line([-29,y,-20,y+1],EDGE,1.2)
	var tip := -18.0 if pulled else -15.0
	line([-24,70,-21,63,tip,62,tip,69,-21,73],INK,4.8)
	line([-24,70,-21,63,tip,62,tip,69,-21,73],Color("8a9da5"),2.7)
	line([-28,68,-24,72],LIGHT,1)
