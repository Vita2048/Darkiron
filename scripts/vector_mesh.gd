extends RefCounted
## Bake ordered vector primitives into one colored triangle mesh per armor part.
## Geometry stays vector at every window size; no texture downsampling.
var vertices := PackedVector3Array()
var colors := PackedColorArray()
func triangle(a: Vector2,b: Vector2,c: Vector2,ca: Color,cb: Color,cc: Color) -> void:
	vertices.append(Vector3(a.x,a.y,0))
	vertices.append(Vector3(b.x,b.y,0))
	vertices.append(Vector3(c.x,c.y,0))
	colors.append(ca)
	colors.append(cb)
	colors.append(cc)
func draw_polygon(p: PackedVector2Array,c: PackedColorArray) -> void:
	var indices := Geometry2D.triangulate_polygon(p)
	for i in range(0,indices.size(),3):
		var a := indices[i]
		var b := indices[i+1]
		var d := indices[i+2]
		triangle(p[a],p[b],p[d],c[a],c[b],c[d])
func draw_colored_polygon(p: PackedVector2Array,c: Color) -> void:
	var shades := PackedColorArray()
	shades.resize(p.size())
	shades.fill(c)
	draw_polygon(p,shades)
func draw_rect(r: Rect2,c: Color) -> void:
	draw_colored_polygon(PackedVector2Array([r.position,Vector2(r.end.x,r.position.y),r.end,Vector2(r.position.x,r.end.y)]),c)
func draw_circle(at: Vector2,radius: float,c: Color) -> void:
	var count := maxi(24,ceili(radius*3))
	for i in count:
		triangle(at,at+Vector2.from_angle(TAU*i/count)*radius,at+Vector2.from_angle(TAU*(i+1)/count)*radius,c,c,c)
func draw_line(a: Vector2,b: Vector2,c: Color,width: float,aa := false) -> void:
	draw_polyline(PackedVector2Array([a,b]),c,width,aa)
func draw_polyline(p: PackedVector2Array,c: Color,width: float,aa := false) -> void:
	var normals: Array[Vector2] = []
	var closed := p[0].is_equal_approx(p[-1])
	for i in p.size():
		var previous := p[maxi(0,i-1)]
		var next := p[mini(p.size()-1,i+1)]
		if closed and (i==0 or i==p.size()-1):
			previous = p[-2]
			next = p[1]
		var incoming := (p[i]-previous).normalized().orthogonal()
		var outgoing := (next-p[i]).normalized().orthogonal()
		if incoming==Vector2.ZERO: incoming = outgoing
		if outgoing==Vector2.ZERO: outgoing = incoming
		var normal := (incoming+outgoing).normalized()
		normals.append(normal/maxf(0.4,normal.dot(outgoing)))
	var clear := Color(c,0)
	for i in p.size()-1:
		var a := p[i]
		var b := p[i+1]
		var n := normals[i]*width*0.5
		var m := normals[i+1]*width*0.5
		triangle(a+n,a-n,b+m,c,c,c)
		triangle(a-n,b-m,b+m,c,c,c)
		if aa:
			for side: int in [-1,1]:
				var x := a+n*side
				var y := b+m*side
				var u := x+normals[i]*0.65*side
				var v := y+normals[i+1]*0.65*side
				triangle(x,u,y,c,clear,c)
				triangle(u,v,y,clear,clear,c)
func build() -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh

