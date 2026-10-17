"""One-time migration of existing SVG modules into editable native Godot nodes.
Do not rerun over hand-authored animation edits without backing up the scene.
"""
from pathlib import Path
import math
V=complex
pi=math.pi
def rot(v,a): return v*complex(math.cos(a),math.sin(a))
def ang(v): return math.atan2(v.imag,v.real)
def vec(v): return f'Vector2({v.real:.7f}, {v.imag:.7f})'
def num(v): return f'{v:.7f}'
def knee(h,f):
 d=f-h; m=(h+f)/2
 return m+V(d.imag,-d.real)/abs(d)*math.sqrt(max(0,1600-min(abs(d),79.5)**2/4))
def elbow(s,w):
 d=w-s; n=min(max(abs(d),.01),65.9); a=(1296-900+n*n)/(2*n)
 return s+d/abs(d)*a+rot(d/abs(d),pi/2)*math.sqrt(max(0,1296-a*a))
# name, parent, artwork index, art width/height, layer
bones=[('Hip',None,None,None,0),('Torso','Hip',1,(56,58),20),('Head','Torso',0,(34,37),21),
('LeftShoulder','Torso',3,(27*.83,36),4),('LeftForearm','LeftShoulder',4,(18*1.18,30),5),('LeftHand','LeftForearm',14,(10,12),6),
('RightShoulder','Torso',3,(31*.83,36),30),('RightForearm','RightShoulder',4,(19*1.18,30),31),('RightHand','RightForearm',13,(12,13),33),('Weapon','RightHand',2,(99,29),29),
('LeftThigh','Hip',6,(33*.87,40),1),('LeftShin','LeftThigh',7,(27*.9,40),2),('LeftFoot','LeftShin',8,(34,19),3),
('RightThigh','Hip',6,(38*.87,40),10),('RightShin','RightThigh',7,(31*.9,40),11),('RightFoot','RightShin',8,(34,19),12)]
paths={}
for n,p,*_ in bones: paths[n]=(paths[p] if p else 'Skeleton2D')+'/'+n

def pose(t):
 hip=V(-4,-90)*(1-t)+V(-9,-76)*t
 torso=hip+V(2-5*t,-47); lean=-.11*t
 gun=torso+V(32*(1-t),13-6*t); ga=-1.4*t
 grip=gun+rot(V(-24*.99,79*.29),ga)
 rs=torso+V(-9,9); re=elbow(rs,grip)
 # Support hand follows the fore-end in both end poses.
 support=V(-24,79)+V((1250-500)*70/1235,(490-550)*(-41)/(-185))
 lw=gun+rot(V(support.real*.99,support.imag*.29),ga)
 ls=torso+V(10,9); le=elbow(ls,lw)
 d={'Hip':(hip,0),'Torso':(torso,lean),'Head':(torso+V(4,-29),lean-.04),
 'RightShoulder':(rs,ang(re-rs)-pi/2),'RightForearm':(re,ang(grip-re)-pi/2),'RightHand':(grip,ga+1.5),'Weapon':(gun,ga),
 'LeftShoulder':(ls,ang(le-ls)-pi/2),'LeftForearm':(le,ang(lw-le)-pi/2),'LeftHand':(lw,ga+1.5)}
 for side,x in [('Left',-17),('Right',14)]:
  standing_hip=V(6 if side=='Left' else -4,-90)
  standing_knee=standing_hip+V(0 if side=='Left' else math.sin(math.radians(3))*40,40)
  standing_foot=V(2 if side=='Left' else -4+math.sin(math.radians(3))*40,-10)
  h=standing_hip*(1-t)+hip*t; f=standing_foot*(1-t)+V(x,-3)*t
  k=standing_knee*(1-t)+knee(hip,V(x,-3))*t
  d[side+'Thigh']=(h,ang(k-h)-pi/2); d[side+'Shin']=(k,ang(f-k)-pi/2);d[side+'Foot']=(f,0)
 out={}
 for n,p,*_ in bones:
  pos,a=d[n]; pp,pa=d[p] if p else (0j,0)
  out[n]=(rot(pos-pp,-pa), (a-pa+pi)%(2*pi)-pi)
 return out

textures={'head':'darkiron-body-head.svg','torso':'darkiron-body-torso.svg','arms':'darkiron-body-arms.svg','legs':'darkiron-body-legs.svg','weapon':'darkiron-rifle.svg'}
header='[gd_scene format=3]\n\n'+''.join(f'[ext_resource type="Texture2D" path="res://assets/{f}" id="{k}"]\n' for k,f in textures.items())+'\n'
# All body parts have position/rotation keys, available without creating tracks first.
poses=[pose(t) for t in [0,.5,1,.5,0]]
res=''
for aid,times,ps in [('RESET',[0],[poses[0]]),('cover',[0,.2,.4,.6,.8],poses)]:
 res+=f'[sub_resource type="Animation" id="{aid}"]\nresource_name = "{aid}"\nlength = {0.001 if aid=="RESET" else .8}\nstep = 0.033333333\n'
 tracks=[]
 for n,*_ in bones:
  tracks.extend([(paths[n]+':position',[vec(p[n][0]) for p in ps]),(paths[n]+':rotation',[num(p[n][1]) for p in ps])])
 weights=[0] if aid=='RESET' else [0,.5,1,.5,0]
 tracks.extend([('Skeleton2D:scale',[vec(V(1-.17*t,1-.04*t)) for t in weights]),('Skeleton2D:modulate',[f'Color({1-.42*t}, {1-.32*t}, {1-.18*t}, 1)' for t in weights])])
 for i,(path,vals) in enumerate(tracks):
  res+=f'tracks/{i}/type = "value"\ntracks/{i}/path = NodePath("{path}")\ntracks/{i}/interp = 1\ntracks/{i}/keys = {{"times": PackedFloat32Array({", ".join(map(str,times))}), "transitions": PackedFloat32Array({", ".join("1" for _ in times)}), "update": 0, "values": [{", ".join(vals)}]}}\n'
 res+='\n'
res+='[sub_resource type="AnimationLibrary" id="Library"]\n_data = {&"RESET": SubResource("RESET"), &"cover": SubResource("cover")}\n\n'
scene='[node name="Darkiron" type="Node2D"]\n\n[node name="Skeleton2D" type="Skeleton2D" parent="."]\n\n'
def poly(name,parent,tex,points,uv,z,tint=False):
 global scene
 packed=lambda vv: 'PackedVector2Array('+', '.join(f'{p.real:.6f}, {p.imag:.6f}' for p in vv)+')'
 scene+=f'[node name="{name}" type="Polygon2D" parent="{parent}"]\ntexture = ExtResource("{tex}")\npolygon = {packed(points)}\nuv = {packed(uv)}\nz_index = {z}\nz_as_relative = false\nmetadata/_edit_lock_ = true\n'
 if tint: scene+='modulate = Color(0.62,0.65,0.70,1)\n'
 scene+='\n'
def rect(x,y,w,h): return [V(x,y),V(x+w,y),V(x+w,y+h),V(x,y+h)]
def art(n,i,size,z):
 if i is None:return
 parent=paths[n]; sx,sy=[v/100 for v in size]
 scale=lambda ps:[V(p.real*sx,p.imag*sy) for p in ps]
 tint=n.startswith('Left')
 def put(tex,pts,uv,suffix='Art'): poly(suffix,parent,tex,scale(pts),uv,z,tint)
 if i in [3,6,7,13,14]:
  tex,region,a,b,width={3:('arms',(298,54,400,556),V(510,245),V(453,603),105),6:('legs',(253,9,324,694),V(415,72),V(456,620),72),7:('legs',(926,12,286,685),V(1045,103),V(1087,634),75),13:('arms',(1613,232,348,422),V(1740,300),V(1790,620),100),14:('arms',(1613,232,348,422),V(1740,300),V(1790,620),100)}[i]
  uv=rect(*region); axis=(b-a)/abs(b-a); side=V(axis.imag,-axis.real)
  dot=lambda a,b:a.real*b.real+a.imag*b.imag
  extent=max(dot(p-a,side) for p in uv)-min(dot(p-a,side) for p in uv)
  pts=[V(dot(p-a,side)*width/extent*(-1 if i==14 else 1),dot(p-a,axis)*100/abs(b-a)) for p in uv]
  put(tex,pts,uv)
 elif i==4:
  rows=[(1010,110),(1010,198),(1090,300),(1140,420),(1145,520),(1123,593),(1123,676)]
  for j in range(len(rows)-1):
   uv=rect(950,rows[j][1],305,rows[j+1][1]-rows[j][1]); pts=[]
   for c in uv:
    center=rows[j][0] if c.imag==rows[j][1] else rows[j+1][0]
    y=(c.imag-198)*100/395; y=y*.4 if y<0 else y
    pts.append(V((c.real-center)*78/350,y))
   put('arms',pts,uv,'Art'+str(j))
 elif i in [0,1]:
  tex,source,target={0:('head',(273,124,739,936),(-45,-3,90,103)),1:('torso',(323,53,724,1108),(-46,-5,92,111))}[i]
  put(tex,rect(*target),rect(*source))
 elif i==8:
  uv=rect(1537,460,531,234); pts=[V(-5/.34+(p.real-1648)*100/531,8/.19+(p.imag-508)*(100-8/.19)/(694-508)) for p in uv]
  # Rig positions foot art at ankle+(5,-8); preserve this pivot correction.
  pts=[p+V(5/sx,-8/sy) for p in pts]; put('legs',pts,uv)
 elif i==2:
  uv=rect(34,248,1706,432);pts=[V(-24+(p.real-500)*70/1235,79+(p.imag-550)*(-41)/(-185)) for p in uv];put('weapon',pts,uv)

for n,p,i,size,z in bones:
 pos,a=poses[0][n];parent=paths[p] if p else 'Skeleton2D'
 # Bone display points along local Y for limbs, up for trunk/head, right for feet/weapon.
 ba=pi/2 if any(x in n for x in ['Shoulder','Forearm','Thigh','Shin','Hand']) else (-pi/2 if n in ['Hip','Torso','Head'] else 0)
 length=36 if 'Shoulder' in n else 30 if 'Forearm' in n else 40 if 'Thigh' in n or 'Shin' in n else 47 if n=='Hip' else 24
 scene+=f'[node name="{n}" type="Bone2D" parent="{parent}"]\nposition = {vec(pos)}\nrotation = {num(a)}\nrest = Transform2D({num(math.cos(a))}, {num(math.sin(a))}, {num(-math.sin(a))}, {num(math.cos(a))}, {pos.real:.7f}, {pos.imag:.7f})\nauto_calculate_length_and_angle = false\nlength = {length}\nbone_angle = {math.degrees(ba)}\n\n'
 art(n,i,size,z)
scene+='[node name="AnimationPlayer" type="AnimationPlayer" parent="."]\nlibraries = {&"": SubResource("Library")}\n'
Path('characters/darkiron.tscn').write_text(header+res+scene)


