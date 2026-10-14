extends "res://scripts/vector_armor.gd"
## Obsidian drake: dedicated silhouette, articulated plates and magenta reactors.
const SHELL := Color("342638")
const FACET := Color("594052")
const RIM := Color("a58a9d")
const GLOW := Color("ec38ef")
func plate(values: Array,color := SHELL,outline := 2.5) -> void:
	var p := points(values)
	var center := Vector2.ZERO
	for v in p: center += v
	center /= p.size()
	var colors := PackedColorArray()
	for v in p:
		var shine := clampf(0.07-(v.x+15)*0.003-v.y*0.0007,-0.19,0.10)
		colors.append((color.lightened(shine) if shine>0 else color.darkened(-shine))*tint)
	canvas.draw_polygon(p,colors)
	var rim := PackedVector2Array()
	for v in p: rim.append(v.lerp(center,0.14))
	rim.append(rim[0])
	for i in p.size():
		var j := (i+1)%p.size()
		var edge := (p[i]+p[j])*0.5-center
		var lighting := clampf((-edge.x-edge.y)*0.008,-0.22,0.20)
		var bevel := color.lightened(lighting) if lighting>0 else color.darkened(-lighting)
		canvas.draw_colored_polygon(PackedVector2Array([p[i],p[j],rim[j],rim[i]]),bevel*tint)
	canvas.draw_polyline(rim,Color(color.lightened(0.08),0.6)*tint,0.65,true)
	p.append(p[0])
	canvas.draw_polyline(p,INK*tint,outline,true)
	# Fine machined scoring inside the plate, baked once with the geometry.
	if center.y>15 and values.size()>12:
		for i in 3:
			var v: Vector2 = p[(i*2)% (p.size()-1)].lerp(center,0.38+i*0.08)
			canvas.draw_line(v,v+Vector2(2.4,-1.5),Color(RIM,0.30)*tint,0.65,true)

func energy(values: Array,width := 2.3) -> void:
	line(values,Color("572051"),width*3.3)
	line(values,GLOW,width)
	line(values,Color("ffd3ff"),width*0.35)
func reactor(x: float,y: float,r: float) -> void:
	circle(Vector2(x,y),r+3,INK)
	circle(Vector2(x,y),r,FACET)
	circle(Vector2(x,y),r*0.72,Color("34143e"))
	circle(Vector2(x,y),r*0.48,GLOW)
	circle(Vector2(x-1,y-1),r*0.2,Color("ffd2ff"))
func paint(target,index: int,color: Color) -> void:
	if index==12:
		canvas = target
		tint = color
		tail()
	else: super.paint(target,index,color)
func torso() -> void:
	# Rear dorsal fins and broad tapered cuirass.
	plate([-28,12,-42,-22,-17,-5,0,17],SHELL)
	plate([-27,32,-48,5,-34,47,-17,64],FACET)
	plate([-30,3,-10,-6,15,-3,33,18,31,55,19,94,-21,96,-34,50],SHELL)
	plate([-27,12,-10,22,2,42,-5,58,-25,46,-33,27],FACET)
	plate([0,24,22,9,30,26,21,49,6,57,-2,40],FACET)
	line([-28,12,-10,23,-3,36],RIM,1.8)
	line([3,26,20,14,26,24],RIM,1.7)
	energy([-21,31,-11,39],3)
	energy([9,37,23,29],3.5)
	plate([-8,10,2,7,9,14,8,35,0,43,-8,34],INK)
	energy([0,16,0,31],3.5)
	for i in 4:
		var y := 54+i*9
		plate([-25,y,-1,y+6,23,y-2,20,y+9,-1,y+16,-24,y+8],SHELL,1.5)
		line([-22,y+2,-1,y+9,18,y+2],RIM,1)
	bolt(-26,19,1.6)
	bolt(24,20,1.6)
func upper_arm() -> void:
	# Oversized layered pauldron, swept spikes, drake skull insignia.
	plate([-27,5,-40,-22,-13,-9,0,10],FACET)
	plate([0,-5,13,-28,21,-2,25,15],FACET)
	plate([-29,26,-44,17,-34,49,-21,54],SHELL)
	plate([-30,3,-12,-10,14,-5,34,14,31,42,12,56,-18,52,-34,29],SHELL)
	plate([-25,7,-10,-3,13,2,27,16,24,35,7,46,-20,39,-29,22],FACET)
	line([-25,7,-10,-3,13,2,26,16],RIM,2)
	# Angular skull with cheek fangs and swept horn tips.
	plate([-12,12,-18,2,-5,9,6,7,17,0,15,15,21,23,12,31,8,39,2,31,-4,38,-7,29,-15,25],Color("a12c86"),1)
	plate([-10,17,-2,20,-4,24,-11,21],INK,0.8)
	plate([5,18,14,15,12,21,6,24],INK,0.8)
	line([0,25,2,29,4,25],INK,1.5)
	plate([-19,46,18,47,21,67,12,92,-14,95,-25,69],SHELL)
	for y in [56,63,70]: line([-15,y,14,y+2],RIM,1.5)
	energy([-10,80,9,80],2)
	bolt(-24,21,2)
func forearm() -> void:
	reactor(0,8,12)
	plate([-26,20,-15,12,17,16,30,34,19,71,-17,76,-30,53],SHELL)
	plate([-22,27,-11,20,15,26,19,51,8,63,-18,59,-25,43],FACET)
	line([-22,29,-24,44,-17,56],RIM,2)
	reactor(2,35,9)
	plate([-20,62,18,62,23,78,14,98,-18,97,-26,81],SHELL)
	for x in [-12,-3,6]: line([x,76,x+3,91],RIM,1.6)
	energy([-11,55,10,55],2)
func thigh() -> void:
	plate([0,-2,19,4,29,21,23,58,13,88,-8,98,-27,75,-31,30,-20,8],SHELL)
	plate([-22,15,9,8,23,25,14,56,-6,72,-24,59,-27,32],FACET)
	line([-22,18,-25,36,-19,54],RIM,2)
	plate([-18,63,-2,72,17,65,19,87,0,101,-21,86],SHELL)
	reactor(0,83,10)
	energy([16,24,13,47],2.3)
	bolt(-16,15,1.8)
func shin() -> void:
	plate([-22,4,4,0,29,13,23,43,15,88,-21,96,-26,59,-32,24],SHELL)
	plate([-22,21,0,14,19,25,10,66,-10,78,-22,56],FACET)
	plate([-25,30,-42,15,-30,51,-18,61],SHELL)
	line([-20,24,-18,50,-10,63],RIM,2)
	for y in [38,51]: energy([-9,y,7,y-3],2)
	reactor(0,9,9)
	plate([-19,79,14,77,20,93,10,100,-23,97],SHELL)
func boot() -> void:
	plate([-30,0,0,3,6,40,26,49,40,70,36,92,-35,97,-43,77,-37,40],SHELL)
	plate([-24,8,-3,12,0,41,-27,53,-32,33],FACET)
	reactor(-13,29,8)
	for i in 3:
		var x := -25+i*22
		plate([x,56,x+13,49,x+24,65,x+25,83,x+11,99,x-3,96,x+4,82],FACET,2)
		plate([x+9,79,x+22,77,x+27,98,x+13,105,x+5,102],Color("94828f"),1.5)
		line([x+11,83,x+17,94],Color("ddd0d8"),1)
func waist() -> void:
	plate([-42,0,37,0,34,35,22,77,0,97,-25,82,-39,47],SHELL,1.5)
	for y in [15,30,45,60]: line([-30,y,0,y+14,28,y],Color("6e5268"),2)
func shotgun(pulled := false) -> void:
	super.shotgun(pulled)
	# Raised optic, purple induction rail and blade under the muzzle.
	plate([-12,5,15,5,18,13,-15,13],SHELL,1)
	circle(Vector2(15,9),4,GLOW)
	energy([3,48,43,48],2)
	plate([27,58,46,57,70,78,48,73,28,66],Color("8c758a"),1)
	line([32,62,61,74],Color("e2c6e0"),0.8)
func tail() -> void:
	# Authored behind the body; each plate follows a continuous tapering curve.
	var path := [Vector2(0,0),Vector2(-18,10),Vector2(-35,29),Vector2(-52,43),Vector2(-70,44),Vector2(-85,37),Vector2(-96,23),Vector2(-100,5)]
	# Rounded understructure keeps the plated joints connected through the bend.
	for i in range(path.size()-1):
		var a: Vector2 = path[i]
		var b: Vector2 = path[i+1]
		var radius := 13.0-i*1.1
		canvas.draw_line(a,b,INK*tint,radius*2+3,true)
		circle(a,radius+1,INK)
		canvas.draw_line(a,b,SHELL*tint,radius*2,true)
		circle(a,radius,SHELL)
	for i in range(path.size()-1):
		var a: Vector2 = path[i]
		var b: Vector2 = path[i+1]
		var normal := (b-a).normalized().orthogonal()
		var radius := 12.0-i*1.1
		var p := PackedVector2Array([a+normal*radius,b+normal*(radius-1),b-normal*(radius-1),a-normal*radius])
		canvas.draw_colored_polygon(p,FACET.darkened(0.25)*tint)
		canvas.draw_line(a+normal*(radius-2),b+normal*(radius-3),RIM*tint,1.2,true)
		canvas.draw_line(a+normal*radius,a-normal*radius,INK*tint,2,true)
		canvas.draw_line(a+normal*(radius-2)+Vector2(-2,0),a-normal*(radius-2)+Vector2(-2,0),Color("785c78")*tint,1,true)
		if i%2==0:
			var tip := a+normal*(radius+8)
			canvas.draw_colored_polygon(PackedVector2Array([a+normal*radius,tip,b+normal*(radius-1)]),SHELL*tint)
			canvas.draw_line(a+normal*radius,tip,RIM*tint,1,true)
	plate([-107,8,-110,-13,-101,-3,-97,-21,-92,-9,-94,9],FACET,1.5)
