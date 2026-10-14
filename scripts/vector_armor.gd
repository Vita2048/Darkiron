extends RefCounted
## All character surfaces are authored geometry. No texture or image sampling.
## Reference cues: black steel, orange visor, ridged mask, spiked pauldrons,
## articulated plates, lit gauntlets, ammunition belt and a heavy shotgun.
var canvas
var tint := Color.WHITE
const INK := Color("080e16")
const DARK := Color("172330")
const STEEL := Color("3b5062")
const EDGE := Color("839baa")
const LIGHT := Color("c0ccd0")
const ORANGE := Color("ff702c")

func points(values: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for i in range(0,values.size(),2):
		result.append(Vector2(values[i],values[i+1]))
	return result

func line(values: Array,color: Color,width := 2.0) -> void:
	canvas.draw_polyline(points(values),color*tint,width,true)

func plate(values: Array,color := STEEL,outline := 2.5) -> void:
	var p := points(values)
	var colors := PackedColorArray()
	for v in p:
		var shine := clampf(0.22-(v.x+20)*0.005-v.y*0.0008,-0.3,0.22)
		colors.append((color.lightened(shine) if shine>0 else color.darkened(-shine))*tint)
	canvas.draw_polygon(p,colors)
	p.append(p[0])
	canvas.draw_polyline(p,INK*tint,outline,true)

func circle(at: Vector2,radius: float,color: Color) -> void:
	canvas.draw_circle(at,radius,color*tint)

func bolt(x: float,y: float,r := 2.4) -> void:
	circle(Vector2(x,y),r+1,INK)
	circle(Vector2(x,y),r,EDGE)
	circle(Vector2(x-0.5,y-0.7),r*0.38,LIGHT)

func energy(values: Array,width := 2.3) -> void:
	line(values,Color("793924"),width*3.5)
	line(values,ORANGE,width)
	line(values,Color("ffe0a1"),width*0.4)

func paint(target,index: int,color: Color) -> void:
	canvas = target
	tint = color
	match index:
		0: helmet()
		1: torso()
		2: shotgun()
		3: upper_arm()
		4: forearm()
		5: waist()
		6: thigh()
		7: shin()
		8: boot()
		9: trigger_hand(false)
		10: trigger_hand(true)
		11: shotgun(true)

func helmet() -> void:
	# Crown and backward swept horns, a broad visor and segmented jaw.
	plate([-34,27,-39,7,-23,14,-16,-9,-5,10,15,-6,13,12,34,22,42,39,39,64,24,90,5,99,-17,89,-34,63],DARK)
	plate([-31,23,-13,9,9,10,27,20,34,37,7,49,-23,42],STEEL)
	plate([-25,26,-14,12,-2,14,-5,39,-21,43],Color("526776"),1.8)
	line([-25,20,-13,12,7,13,23,22],EDGE,1.6)
	line([-4,14,0,34,8,43],INK,2.5)
	plate([-20,47,7,49,38,37,40,49,17,64,-17,61],INK,1.8)
	energy([-11,51,8,54,34,44],5)
	plate([2,63,19,64,35,55,33,75,13,92,-1,84],Color("293b4b"))
	plate([15,69,33,60,26,78,14,87],Color("546878"),1.5)
	line([14,87,15,68,31,59],EDGE,1.5)
	line([-3,67,3,86,10,95],INK,3)
	plate([-27,54,-10,61,-9,84,-20,83,-32,65],STEEL,2)
	for i in 3:
		line([-23+i*7,64,-20+i*7,77],INK,2)
	circle(Vector2(-27,49),13,INK)
	circle(Vector2(-27,49),10,STEEL)
	circle(Vector2(-27,49),6,DARK)
	energy([-28,44,-25,49,-28,54],1.5)
	line([-34,40,-29,38,-23,39],EDGE,1.8)
	bolt(-11,27,1.5)

func torso() -> void:
	# Armored rib cage, beveled breastplate and overlapping abdominal lames.
	plate([-33,3,-18,-4,5,-3,31,9,37,34,27,64,23,98,-21,98,-27,65,-38,31],DARK)
	plate([-24,3,-10,8,10,8,22,2,26,13,8,23,-13,19,-29,12],Color("556878"),2)
	plate([-29,18,-9,22,3,34,-2,56,-24,48,-35,29],STEEL)
	plate([4,27,23,18,33,25,26,48,8,56],Color("4c6070"))
	line([-28,20,-11,25,-4,35],EDGE,1.8)
	line([11,31,25,24,29,28],EDGE,1.8)
	energy([-25,35,-17,44,-7,46],1.9)
	energy([23,34,18,43,11,46],1.9)
	for i in 3:
		var y := 54+i*12
		plate([-20,y,-4,y+5,19,y-2,20,y+8,-1,y+16,-20,y+10],Color("2c3e4d"),1.5)
		line([-18,y+2,-3,y+8,17,y+1],Color("607382"),1.4)
	energy([23,57,18,69,22,79,13,89],2)
	energy([-23,59,-18,69,-20,81],1.8)
	# Rear flexible cable; stays against the body, with no cloth appendage.
	line([-30,0,-42,8,-45,27,-40,49,-29,61],INK,6)
	line([-31,1,-39,10,-41,27,-37,45],Color("667583"),2)
	for y in [14,25,36]:
		line([-44,y,-39,y+2],DARK,2)
	bolt(-27,25,1.5)
	bolt(26,28,1.5)

func upper_arm() -> void:
	circle(Vector2(0,22),24,INK)
	plate([-39,20,-27,8,-29,-11,-11,3,-4,-14,6,2,29,-7,23,10,42,22,43,47,27,56,-24,56,-42,43],DARK)
	plate([-32,20,-16,7,9,7,30,21,36,41,18,48,-26,44,-38,33],STEEL)
	line([-31,19,-15,11,7,11,28,23,32,33],EDGE,2.4)
	energy([-14,23,-21,21,-18,30],1.8)
	energy([2,21,9,27,5,34,-1,27,2,21],1.8)
	plate([-28,47,26,49,22,77,12,94,-15,96,-24,75],DARK)
	plate([-21,53,18,55,13,76,-14,84,-23,68],Color("334957"))
	line([-19,57,14,59],EDGE,1.7)
	for i in 3:
		line([-15,84+i*4,15,81+i*4],Color("596777"),1.5)
	bolt(24,40)

func forearm() -> void:
	circle(Vector2(0,8),24,INK)
	circle(Vector2(0,8),13,STEEL)
	plate([-30,20,-23,11,20,12,32,24,24,65,14,77,-16,77,-27,58],DARK)
	plate([-23,23,-12,17,20,22,22,49,13,65,-13,62,-25,48],STEEL)
	line([-23,25,-18,46,-10,58],EDGE,2)
	plate([-9,28,17,28,18,43,-8,43],INK,1.5)
	energy([-3,35,12,35],4)
	plate([-20,70,20,70,25,81,17,96,-17,99,-26,86],Color("25313b"),2)
	for x in [-12,-3,6]:
		line([x,81,x+2,95],Color("869097"),1.3)
	line([-16,73,13,74],EDGE,2)
	bolt(-15,23,1.7)

func thigh() -> void:
	# Rounded proximal joint nests beneath the pelvis instead of projecting a
	# rectangular thigh corner above the belt during an extended stride.
	plate([0,-2,18,3,26,14,29,24,20,62,12,91,-14,96,-27,64,-30,24,-23,9,-12,1],DARK)
	plate([-19,10,13,8,23,22,14,62,-2,74,-22,56,-26,25],STEEL)
	plate([-16,12,-5,10,2,34,-10,59,-23,48],Color("536c7c"),1.5)
	line([-24,9,-26,28,-18,47],EDGE,2)
	plate([-16,66,1,74,17,65,17,87,3,100,-17,89],Color("2c3e4e"))
	line([-13,70,0,79,14,70],EDGE,1.5)
	energy([15,24,7,43,10,51],2)
	line([-26,18,-15,27],Color("a0a8a8"),1)
	bolt(-19,9,1.8)
	bolt(17,10,1.8)

func shin() -> void:
	circle(Vector2(0,8),24,INK)
	circle(Vector2(0,8),18,Color("3c5161"))
	plate([-31,19,-15,6,5,11,28,6,37,17,25,39,17,87,-17,91,-25,53],DARK)
	plate([-24,24,-9,14,17,20,19,44,8,78,-13,74,-21,51],STEEL)
	plate([-17,30,-5,23,4,39,-7,68,-14,58],Color("597282"),1.5)
	line([-22,25,-18,49,-10,66],EDGE,2)
	energy([12,30,5,48,8,57],2.4)
	plate([-18,80,15,78,19,94,12,100,-20,97],Color("273744"))
	line([-16,84,14,82],EDGE,1.5)
	bolt(0,8,5)

func boot() -> void:
	plate([-34,5,1,4,8,37,24,52,43,62,47,83,34,94,-36,96,-46,79,-40,44],DARK)
	plate([-30,11,-3,9,4,42,-2,55,-35,53],STEEL)
	plate([-32,59,-5,59,17,57,36,67,39,79,-33,82,-39,70],Color("405562"))
	line([-32,63,-7,64,17,62,33,70],EDGE,2)
	for y in [21,39]:
		line([-31,y,0,y+2],INK,6)
		line([-29,y-2,-1,y],EDGE,2)
	plate([-43,83,44,83,41,95,-39,100,-46,94],INK,2)
	line([-39,86,39,86],Color("768491"),1.8)
	for x in range(-35,40,12):
		line([x,90,x,98],Color("3c4750"),2)
	bolt(-17,44,3)

func shotgun(pulled := false) -> void:
	# Long two-barrel firearm; width is normalized to 100 and height to 100.
	plate([-49,43,-28,36,-23,16,29,18,32,29,49,29,49,54,29,55,21,67,-10,65,-15,92,-27,88,-24,63,-46,65],DARK,2)
	plate([-22,23,27,24,27,58,-18,60],Color("36464f"),1.4)
	plate([-17,28,0,28,0,51,-17,51],INK,1)
	energy([-13,43,-3,43],3)
	plate([2,29,21,29,23,51,2,51],Color("64717a"),1)
	for x in [5,11,17]:
		line([x,31,x-1,48],INK,2)
	line([-18,20,25,20],EDGE,2)
	plate([28,31,48,31,48,49,28,49],Color("52616a"),1.3)
	for x in [33,39,45]:
		circle(Vector2(x,37),2.5,INK)
	line([28,57,44,57],INK,5)
	line([28,56,44,56],EDGE,1.4)
	plate([-42,46,-26,41,-27,58,-44,59],Color("3b2827"),1)
	bolt(-20,29,1.4)
	# Receiver, ejector, fasteners, serrated rail and twin muzzle channels.
	plate([-16,30,-1,30,-1,41,-16,41],Color("111c25"),0.8)
	line([-14,32,-4,32,-4,38],EDGE,1)
	line([-7,47,-2,47],Color("ffe2a1"),1)
	for x in range(-20,26,5):
		plate([x,16,x+3,16,x+3,20,x,20],Color("76838a"),0.6)
	line([-24,24,-24,53,-18,58],EDGE,1)
	for x in [-19,0,25]:
		bolt(x,54,1.4)
	plate([27,44,47,44,47,50,27,50],Color("18242d"),0.7)
	line([29,45,45,45],EDGE,0.8)
	line([47,30,47,52],INK,2)
	line([-43,49,-30,45],EDGE,0.7)
	for x in range(5,23,3):
		line([x,53,x-1,61],Color("17232c"),1.4)
	# Exposed trigger guard and curved trigger below the receiver.
	line([-15,61,0,62,3,72,-1,83,-15,83],INK,4)
	line([-14,62,-1,63,1,72,-2,81,-14,81],EDGE,1.5)
	line([-6,63,-9 if pulled else -5,71,-12 if pulled else -9,75],Color("bbc7cc"),1.6)

func waist() -> void:
	# Soft-sided continuation of the torso: no belt rim or floating pelvic plate.
	plate([-46,0,46,0,43,35,38,73,21,96,0,100,-23,94,-39,70,-44,32],DARK,1.8)
	plate([-35,0,5,0,7,67,-10,83,-29,66],Color("293b49"),0.8)
	plate([9,0,34,0,31,65,16,82,7,64],Color("344957"),0.8)
	line([-32,12,-30,47,-23,67],Color("526776"),1.2)

func trigger_hand(pulled: bool) -> void:
	# Authored in weapon coordinates, so the grip never separates under recoil.
	plate([-29,67,-23,62,-16,66,-13,77,-16,94,-26,94,-31,85],Color("344957"),1.1)
	plate([-28,69,-23,65,-18,69,-18,80,-28,82],STEEL,0.9)
	line([-27,83,-17,84],EDGE,1.2)
	line([-26,88,-18,89],EDGE,1.2)
	line([-24,93,-18,93],EDGE,1.0)
	# Curled index finger goes inside the guard and pulls toward the palm.
	var tip := -10.0 if pulled else -6.0
	line([-20,70,-14,66,tip,68,tip-1,76,-13,77],INK,5.5)
	line([-20,70,-14,66,tip,68,tip-1,76,-13,77],Color("8a9da5"),3.2)
	line([-25,68,-20,73],LIGHT,1.2)
