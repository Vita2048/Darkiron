extends Node2D
## Retained vector meshes and textured modules; animation updates transforms.
const Armor = preload("res://scripts/vector_armor.gd")
const Baker = preload("res://scripts/vector_mesh.gd")
static var meshes: Dictionary = {}
static var azure_shader: Shader
static var azure_material: ShaderMaterial
var index := -1
var drake := false
var hero := false
var hybrid_body := false
var azure := false
const SvgBody = preload("res://scripts/svg_body.gd")
const Hybrid = preload("res://scripts/hybrid_sprites.gd")
const HybridHand = preload("res://scripts/hybrid_hand.gd")
var mesh_key := -1
const DrakeSvg = preload("res://scripts/drake_svg_body.gd")
const Drake = preload("res://scripts/drake_armor.gd")
const DrakeHead = preload("res://assets/drake-head.png")
func configure(value: int,variant := false,hero_variant := false,body_variant := false,azure_variant := false) -> void:
	if index != value or drake != variant or hero != hero_variant or hybrid_body != body_variant or azure != azure_variant:
		index = value
		drake = variant
		hero = hero_variant
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS if (hero or drake or azure_variant) else CanvasItem.TEXTURE_FILTER_PARENT_NODE
		hybrid_body = body_variant
		azure = azure_variant
		material = _azure_material() if azure else null
		mesh_key = index+(100 if drake else (200 if hero else (300 if azure else 0)))
		if drake and DrakeSvg.supports(index):
			queue_redraw()
			return
		if azure and SvgBody.supports(index):
			queue_redraw()
			return
		if hero and ((hybrid_body and SvgBody.supports(index)) or index in [0,2,11]):
			queue_redraw()
			return
		if not meshes.has(mesh_key):
			var baker := Baker.new()
			var painter = HybridHand.new() if (drake or hero or azure) and index in [9,10] else (Drake.new() if drake else Armor.new())
			painter.paint(baker,index,Color.WHITE)
			# Shape the chest and lower thigh without widening the hip socket.
			for i in baker.vertices.size():
				var vertex: Vector3 = baker.vertices[i]
				if index == 1:
					vertex.x *= lerpf(0.90,1.0,clampf(vertex.y/65.0,0,1))
				elif index == 6:
					vertex.x *= 1.0+0.16*smoothstep(15.0,65.0,vertex.y)
				baker.vertices[i] = vertex
			if drake:
				for i in baker.colors.size():
					var c: Color = baker.colors[i]
					if c.r>c.g*1.4 and c.g>c.b*1.3:
						baker.colors[i] = Color(c.r,c.g*0.45,c.r,c.a)
					elif c.b>c.r and c.g>c.r:
						var light := c.v
						baker.colors[i] = Color(light*0.78,light*0.58,light*0.81,c.a)
			meshes[mesh_key] = baker.build()
		queue_redraw()
func _draw() -> void:
	if drake and DrakeSvg.supports(index):
		DrakeSvg.draw(self,index)
	elif azure and SvgBody.supports(index):
		SvgBody.draw(self,index)
	elif hero and ((hybrid_body and SvgBody.supports(index)) or index in [0,2,11]):
		SvgBody.draw(self,index)
	elif drake and index in [2,11]:
		draw_texture_rect_region(Hybrid.DRAKE_RIFLE,Hybrid.rifle_rect(drake),Hybrid.source(drake))
	elif drake and index==0:
		draw_texture_rect_region(DrakeHead,Rect2(-54,-8,108,108),Rect2(55,115,1100,1035))
	else:
		draw_mesh(meshes[mesh_key],null)

# Azure recolor: vivid v1 neon blue, computed on the unmodulated texel so the
# same texel always maps to the same blue (consistent front/rear). Steel is a
# bit-exact passthrough: fragment input COLOR already equals texel * vmod, so
# non-warm pixels output COLOR unchanged, identical to no-shader rendering.
static func _azure_material() -> ShaderMaterial:
	if azure_material != null:
		return azure_material
	azure_shader = Shader.new()
	azure_shader.code = "shader_type canvas_item;\nvarying vec4 vmod;\nvoid vertex() {\n\tvmod = COLOR;\n}\nvoid fragment() {\n\tvec4 base = COLOR;\n\tvec3 vrgb = max(vmod.rgb, vec3(0.0039));\n\tvec3 texel = clamp(base.rgb / vrgb, 0.0, 1.0);\n\tfloat mx = max(texel.r, max(texel.g, texel.b));\n\tfloat mn = min(texel.r, min(texel.g, texel.b));\n\tfloat sat = mx - mn;\n\tvec3 out_rgb = texel;\n\tif (base.a > 0.01 && texel.r > 0.32 && texel.r > texel.b + 0.08 && texel.r >= texel.g * 0.80 && sat > 0.16) {\n\t\tfloat lum = dot(texel, vec3(0.299, 0.587, 0.114));\n\t\tvec3 deep = vec3(0.04, 0.22, 0.95);\n\t\tvec3 neon = vec3(0.15, 0.88, 1.0);\n\t\tvec3 ramp = mix(deep, neon, clamp(lum * 1.7, 0.0, 1.0));\n\t\tout_rgb = ramp * (0.45 + mx * 1.15);\n\t\tif (lum > 0.75) {\n\t\t\tout_rgb = mix(out_rgb, vec3(0.75, 0.98, 1.0), (lum - 0.75) * 2.0);\n\t\t}\n\t}\n\tCOLOR = vec4(out_rgb * vmod.rgb, base.a);\n}\n"
	azure_material = ShaderMaterial.new()
	azure_material.shader = azure_shader
	return azure_material
