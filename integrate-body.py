from pathlib import Path
p=Path('scripts/fighter.gd');s=p.read_text().replace('var drake := false','var drake := false\n# Reversible rendering choice; does not change collision or animation bones.\nvar hybrid_body := true');p.write_text(s)
p=Path('scripts/vector_part.gd');s=p.read_text().replace('var hero := false','var hero := false\nvar hybrid_body := false\nconst Body = preload("res://scripts/hybrid_body.gd")').replace('hero_variant := false)','hero_variant := false,body_variant := false)').replace('or hero != hero_variant:','or hero != hero_variant or hybrid_body != body_variant:').replace('hero = hero_variant','hero = hero_variant\n\t\thybrid_body = body_variant').replace('\t\tif not meshes.has(mesh_key):','\t\tif hero and hybrid_body and Body.supports(index):\n\t\t\tqueue_redraw()\n\t\t\treturn\n\t\tif not meshes.has(mesh_key):').replace('\tif (drake or hero) and index in [2,11]:','\tif hero and hybrid_body and Body.supports(index):\n\t\tBody.draw(self,index)\n\telif (drake or hero) and index in [2,11]:');p.write_text(s)
p=Path('scripts/rig.gd');s=p.read_text().replace('node.configure(index,fighter.drake,not fighter.enemy)','node.configure(index,fighter.drake,not fighter.enemy,fighter.hybrid_body and not fighter.enemy)');a=s.index('func segment(');b=s.index('\nfunc knee(',a);s=s[:a]+'''func segment(index: int, a: Vector2, b: Vector2, width: float, tint := Color.WHITE,glove := true) -> void:
	var hybrid: bool = not fighter.enemy and fighter.hybrid_body
	var length := a.distance_to(b)
	var angle := (b-a).angle()-PI/2
	part(index,a,Vector2(width,length if hybrid and index in [3,4,6,7] else length+7),angle,tint)
	if hybrid and index==4 and glove:
		part(13,b,Vector2(12,16),angle,tint)
'''+s[b:];s=s.replace('segment(4,elbow,grip,19)','segment(4,elbow,grip,19,Color.WHITE,false)');s=s.replace('segment(4,elbow,hand,19)\n\t\tif hybrid and equipped>0:', 'segment(4,elbow,hand,19,Color.WHITE,false)\n\t\tif hybrid and equipped>0:');p.write_text(s)
