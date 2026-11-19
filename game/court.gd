extends Node3D

const D = preload("res://game/shapes.gd")
const FACADE = preload("res://art/facade.gdshader")
const HOOP := Vector3(0, 3.05, -6.25)
const COURT_X := 6.85
const BASELINE := -7.58
const HALFLINE := 6.65
const ARC := 5.25
const CITIES := [
	{"city":"Santiago", "country":"CHILE", "court":"Bajo los Andes", "tag":"STGO", "coords":"33°27′ S   70°40′ O", "time":"18:42", "accent":"eaaa66", "paint":"2b4c43", "line":"ebd0a1", "sky":"435d79", "horizon":"f8ba8f", "sun":"ffd1aa", "story":"La luz cae sobre los Andes y enciende la pintura de la cancha."},
	{"city":"Ciudad de México", "country":"MÉXICO", "court":"Barrio del Sol", "tag":"CDMX", "coords":"19°26′ N   99°08′ O", "time":"17:16", "accent":"f49574", "paint":"623e3d", "line":"f4d8ac", "sky":"606b9c", "horizon":"ffc184", "sun":"ffd7ad", "story":"Muros de color y papel picado junto a la cancha del barrio."},
	{"city":"Nueva York", "country":"ESTADOS UNIDOS", "court":"La Jaula", "tag":"NYC", "coords":"40°44′ N   73°59′ O", "time":"19:37", "accent":"a5bce8", "paint":"303d53", "line":"d9e3e9", "sky":"293853", "horizon":"e5a38f", "sun":"ffc5c5", "story":"Ladrillo, acero y luces encendidas en un patio de la ciudad."},
]

var city := 0
var info: Dictionary
var stage: Node3D
var rng := RandomNumberGenerator.new()
var windows: Array[Transform3D]
var lit: Array[Transform3D]
var fence: Array[Transform3D]

func build(index: int) -> void:
	city = index
	info = CITIES[index]
	rng.seed = 1029 + 277 * index
	if is_instance_valid(stage):
		remove_child(stage)
		stage.queue_free()
	windows.clear()
	lit.clear()
	fence.clear()
	stage = D.pivot(self, Vector3.ZERO)
	_lighting()
	_court()
	_surround()
	D.batch_boxes(stage, windows, Color("243038"))
	D.batch_boxes(stage, lit, D.material(Color("ffce87"), 0.45, 0.0, 0.38))
	D.batch_boxes(stage, fence, D.material(Color("788786"), 0.48, 0.30, 0.0))

func _lighting() -> void:
	var environment := Environment.new()
	var sky := Sky.new()
	var sky_paint := ProceduralSkyMaterial.new()
	sky_paint.sky_top_color = Color(info.sky)
	sky_paint.sky_horizon_color = Color(info.horizon)
	sky_paint.ground_horizon_color = Color(info.horizon)
	sky_paint.ground_bottom_color = Color("444247")
	sky_paint.sky_curve = 0.34
	sky_paint.sun_angle_max = 15.0
	sky.sky_material = sky_paint
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("bccced")
	environment.ambient_light_energy = 0.64
	environment.fog_enabled = true
	environment.fog_light_color = Color(info.horizon).darkened(0.22)
	environment.fog_light_energy = 0.64
	environment.fog_density = 0.0065 if city != 2 else 0.0095
	environment.fog_sky_affect = 0.0
	var world := WorldEnvironment.new()
	stage.add_child(world)
	world.environment = environment
	var sun := DirectionalLight3D.new()
	stage.add_child(sun)
	sun.rotation_degrees = Vector3(-21 if city == 2 else -28, 137 if city == 1 else 121, 0)
	sun.light_color = Color(info.sun)
	sun.light_energy = 1.24 if city != 2 else 0.96
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 34
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	var fill := DirectionalLight3D.new()
	stage.add_child(fill)
	fill.rotation_degrees = Vector3(-46, -31, 0)
	fill.light_color = Color("d1e2ff")
	fill.light_energy = 0.52

func _court() -> void:
	var asphalt := D.surface(Color("343c3d"), 0.58, 0.31, 95)
	var paint := D.surface(Color(info.paint), 0.59, 0.19, 120)
	var key_paint := D.surface(Color(info.accent).darkened(0.35), 0.53, 0.24, 125)
	var chalk := D.surface(Color(info.line), 0.43, 0.38, 144)
	D.box(stage, Vector3(0,-0.27,0), Vector3(290,0.22,280), asphalt, false)
	D.box(stage, Vector3(0,-0.115,-0.6), Vector3(21.7,0.20,19.7), D.surface(Color("454648"),0.55,0.28), false)
	D.box(stage, Vector3(0,-0.009,(BASELINE+HALFLINE)*0.5), Vector3(COURT_X*2,0.026,HALFLINE-BASELINE), paint, false)
	D.box(stage, Vector3(0,0.003,(BASELINE-2.70)*0.5), Vector3(4.26,0.013,-2.70-BASELINE), key_paint, false)
	var y := 0.014
	for z in [BASELINE, HALFLINE, -2.7]:
		var half_width := 2.13 if z == -2.7 else COURT_X
		_stripe(Vector3(-half_width,y,z), Vector3(half_width,y,z), chalk, 0.055)
	for x in [-COURT_X,COURT_X,-2.13,2.13]:
		_stripe(Vector3(x,y,BASELINE), Vector3(x,y,HALFLINE if abs(x)>3 else -2.7), chalk, 0.055)
	_arc(0, HOOP.z, ARC, 0.0, PI, chalk, 55)
	for x in [-ARC, ARC]:
		_stripe(Vector3(x,y,BASELINE),Vector3(x,y,HOOP.z),chalk,0.055)
	_arc(0,-2.7,1.65,0.0,TAU,chalk,48)
	_arc(0,HALFLINE,1.52,PI,TAU,chalk,36)
	_arc(0,HOOP.z,1.17,0.0,PI,chalk,32)
	for side in [-1,1]:
		for z in [-4.9,-4.0,-3.5]:
			_stripe(Vector3(side*2.13,y,z),Vector3(side*2.35,y,z),chalk,0.04)
	for i in 4:
		var edge := D.box(stage, Vector3(0,0.028,-8.11+i*0.14), Vector3(13.7,0.018,0.044), Color(info.accent).darkened(0.27), false)
		edge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var nameplate := D.words(stage, Vector3(0,0.029,4.76), info.tag + "  /  01", 1.03, Color(info.line).darkened(0.10))
	nameplate.rotation.x = -PI/2
	var stamp := D.words(stage, Vector3(0,0.028,5.66), "C I R C U I T O   C A L L E J E R O", 0.30, Color(info.line))
	stamp.rotation.x = -PI/2
	for x in [-8.05, 8.05]:
		for i in 10:
			D.box(stage, Vector3(x,0.003,-6.9+i*1.51), Vector3(0.022,0.014,0.85), Color("928476"), false)
	_hoop()

func _stripe(a: Vector3, b: Vector3, ink: Variant, width: float) -> void:
	var part := D.box(stage, (a+b)*0.5, Vector3(a.distance_to(b)+0.009,0.012,width), ink, false)
	part.rotation.y = -atan2(b.z-a.z,b.x-a.x)

func _arc(x: float, z: float, radius: float, a: float, b: float, ink: Material, segments: int) -> void:
	for i in segments:
		var alpha := lerpf(a,b,float(i)/segments)
		var beta := lerpf(a,b,float(i+1)/segments)
		_stripe(Vector3(x+radius*cos(alpha),0.015,z+radius*sin(alpha)),Vector3(x+radius*cos(beta),0.015,z+radius*sin(beta)),ink,0.053)

func _hoop() -> void:
	var frame := D.material(Color("253130"),0.39,0.28)
	var rail := D.material(Color("dad3bd"),0.52,0.21)
	var orange := D.material(Color("f07837"),0.42,0.22)
	D.box(stage,Vector3(0,0.08,-8.88),Vector3(0.91,0.18,0.93),Color("a6a099"))
	D.pipe(stage,Vector3(0,0.1,-8.88),Vector3(0,3.96,-8.88),0.103,frame,0.089,12)
	D.pipe(stage,Vector3(0,3.96,-8.88),Vector3(0,4.02,-7.05),0.082,frame)
	for sign_x in [-1,1]:
		D.pipe(stage,Vector3(0,2.50,-8.88),Vector3(sign_x*0.49,3.62,-6.76),0.041,frame)
	D.box(stage,Vector3(0,0.95,-8.88),Vector3(0.38,1.65,0.37),D.surface(Color(info.paint).darkened(0.25),0.33,0.02))
	var glass := StandardMaterial3D.new()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(0.51,0.69,0.69,0.24)
	glass.metallic = 0.16
	glass.roughness = 0.21
	D.box(stage,Vector3(0,3.51,-6.77),Vector3(1.83,1.08,0.045),glass,false)
	for y in [2.966,4.05]:
		D.box(stage,Vector3(0,y,-6.74),Vector3(1.87,0.034,0.07),rail)
	for x in [-0.931,0.931]:
		D.box(stage,Vector3(x,3.51,-6.74),Vector3(0.032,1.10,0.071),rail)
	for y in [3.09,3.51]:
		D.box(stage,Vector3(0,y,-6.735),Vector3(0.60,0.024,0.069),rail)
	for x in [-0.29,0.29]:
		D.box(stage,Vector3(x,3.30,-6.735),Vector3(0.024,0.44,0.069),rail)
	D.box(stage,Vector3(0,3.045,-6.59),Vector3(0.19,0.061,0.22),orange)
	D.torus(stage, HOOP, 0.49, 0.021, orange)
	var twine := Color("e9dec9")
	for i in 12:
		var a := i*TAU/12.0
		var b := a+TAU/24.0
		var point := HOOP+Vector3(0.237*cos(a),0.0,0.237*sin(a))
		for n in [-1,1]:
			var c: float = a+n*TAU/24.0
			D.pipe(stage,point,HOOP+Vector3(0.18*cos(c),-0.205,0.18*sin(c)),0.004,twine,-1,5,false)
			D.pipe(stage,HOOP+Vector3(0.18*cos(b),-0.205,0.18*sin(b)),HOOP+Vector3(0.137*cos(a),-0.39,0.137*sin(a)),0.004,twine,-1,5,false)
	D.torus(stage,HOOP-Vector3(0,0.39,0),0.275,0.009,twine)

func _surround() -> void:
	if city != 2:
		_mountains()
	_buildings()
	_skyline()
	D.box(stage,Vector3(0,0.02,-10.50),Vector3(34,0.25,0.22),Color("736b64"))
	for side in [-1,1]:
		_fence_run(Vector3(side*10.12,0,-10.45),Vector3(side*10.12,0,8.9), 2.5)
		for z in [-6.7,1.45,6.85]:
			_bench(Vector3(side*9.18,0,z),-side*PI/2)
		_light(Vector3(side*10.10,0,-8.70),Vector3(side*5,0,-3))
		_light(Vector3(side*10.10,0,5.90),Vector3(side*5,0,1))
		_flag(Vector3(side*7.33,0,-11.12))
		_bin(Vector3(side*9.27,0,-2.4))
		for i in 5:
			_tree(Vector3(side*(12.0+rng.randf()*5),0,6.5-i*4.7))
	_fence_run(Vector3(-10.12,0,-10.45),Vector3(10.12,0,-10.45),2.48)
	var mural := D.pivot(stage,Vector3(0,0,-11.33))
	var concrete := D.surface(Color("4a4544"),0.38,0.06,110)
	D.box(mural,Vector3(0,0.89,0),Vector3(12.8,1.81,0.36),concrete)
	D.box(mural,Vector3(0,1.82,0),Vector3(13.04,0.10,0.46),Color("8b857a"))
	for i in 3:
		var x := -4.45+i*4.45
		var ink := Color(info.accent).darkened(0.18)
		for j in 3:
			var plank := D.box(mural,Vector3(x-0.57-j*0.18,0.95,0.194),Vector3(0.082,0.96,0.012),ink,false)
			plank.rotation.z = -0.40
		D.words(mural,Vector3(x+0.62,1.11,0.204),[info.country,"ASFALTO UNO",info.tag][i],0.49,ink.lightened(0.30))
		D.words(mural,Vector3(x+0.62,0.58,0.204),["LOCAL  /  01","CIRCUITO CALLEJERO","EST. 2026"][i],0.22,Color("dfd5c7"))
	if city == 1:
		_bunting()
	if city == 2:
		_train()
	_street_details()

func _fence_run(a: Vector3, b: Vector3, height: float) -> void:
	var axis := (b-a).normalized()
	var dist := a.distance_to(b)
	var panels := ceili(dist / 2.5)
	var across := Vector3(-axis.z,0,axis.x)
	var steel := D.material(Color("515b59"),0.50,0.33)
	for i in range(panels+1):
		var p := a.lerp(b,float(i)/panels)
		D.pipe(stage,p,p+Vector3.UP*(height+0.055),0.049,steel,0.033,9)
	for y in [0.16,height]:
		D.pipe(stage,a+Vector3.UP*y,b+Vector3.UP*y,0.027,steel,0.027,8)
	for i in [-1,1]:
		var step := 0.27
		var offset := 0.0
		while offset < dist+height:
			var start_x := maxf(0.0,offset-height)
			var end_x := minf(dist,offset)
			if end_x-start_x > 0.02:
				var y1 := clampf(offset-start_x,0,height)
				var y2 := clampf(offset-end_x,0,height)
				if i == 1:
					y1 = height-y1
					y2 = height-y2
				var p1: Vector3 = a+axis*start_x+Vector3.UP*y1+across*(i*0.004)
				var p2: Vector3 = a+axis*end_x+Vector3.UP*y2+across*(i*0.004)
				var direction := (p2-p1).normalized()
				var basis := Basis(direction, across, direction.cross(across))
				fence.append(Transform3D(basis*Basis.from_scale(Vector3(p1.distance_to(p2),0.013,0.013)),(p1+p2)*0.5))
			offset += step

func _flag(p: Vector3) -> void:
	var pole := D.material(Color("b1a9a0"),0.4,0.40)
	D.pipe(stage,p,p+Vector3.UP*5.57,0.035,pole,0.026,10)
	D.oval(stage,p+Vector3.UP*5.59,Vector3.ONE*0.10,Color("e9c27b"))
	var flags: Array[Texture2D] = [preload("res://art/cl.svg"),preload("res://art/mx.svg"),preload("res://art/us.svg")]
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = flags[city]
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.91
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 20:
		var u := i/20.0
		var v := (i+1)/20.0
		for uv in [Vector2(u,0),Vector2(u,1),Vector2(v,0),Vector2(v,0),Vector2(u,1),Vector2(v,1)]:
			builder.set_uv(uv)
			builder.add_vertex(Vector3(uv.x*1.66,-uv.y*1.08-uv.x*0.13,sin(uv.x*TAU*1.5)*uv.x*0.24))
	builder.generate_normals()
	D.mesh(stage,builder.commit(),p+Vector3(0.023,5.41,0),Vector3.ONE,mat)

func _bench(p: Vector3, angle: float) -> void:
	var stand := D.pivot(stage,p)
	stand.rotation.y = angle
	var wood := D.surface(Color("816952"),0.41,0.11)
	for x in [-0.83,0.83]:
		D.box(stand,Vector3(x,0.22,0),Vector3(0.095,0.44,0.44),Color("333c39"))
		D.box(stand,Vector3(x,0.63,-0.21),Vector3(0.07,0.45,0.068),Color("333c39"))
	for z in [-0.16,-0.05,0.06,0.17]:
		D.box(stand,Vector3(0,0.445,z),Vector3(2.14,0.07,0.096),wood)
	for y in [0.66,0.80]:
		D.box(stand,Vector3(0,y,-0.20),Vector3(2.14,0.10,0.058),wood)

func _light(p: Vector3, aim: Vector3) -> void:
	var frame := D.material(Color("393e43"),0.41,0.30)
	D.pipe(stage,p,p+Vector3.UP*6.52,0.082,frame,0.053,10)
	var head := D.pivot(stage,p+Vector3.UP*6.44)
	head.look_at(aim)
	for x in [-0.32,0.32]:
		D.box(head,Vector3(x,0,0),Vector3(0.54,0.32,0.17),frame)
		D.box(head,Vector3(x,0,-0.092),Vector3(0.43,0.22,0.025),D.material(Color("fff5d9"),0.43,0.0,1.5))
	var beam := SpotLight3D.new()
	head.add_child(beam)
	beam.light_color = Color("ecedff")
	beam.light_energy = 1.85 if city == 2 else 0.68
	beam.spot_range = 23
	beam.spot_angle = 48
	beam.spot_attenuation = 0.68

func _bin(p: Vector3) -> void:
	D.pipe(stage,p+Vector3.UP*0.039,p+Vector3.UP*0.71,0.26,Color("214442"),0.29,12)
	D.pipe(stage,p+Vector3.UP*0.705,p+Vector3.UP*0.77,0.295,Color("353b39"),0.31,14)
	D.pipe(stage,p+Vector3.UP*0.771,p+Vector3.UP*0.78,0.208,Color("161e1c"),0.208,14)

func _mountains() -> void:
	var palette := [Color("9b9aa9"),Color("7a8192"),Color("626778")] if city == 0 else [Color("b28794"),Color("a27884"),Color("836477")]
	for layer in 3:
		var z := -93.0+float(layer)*16
		var top: Array[Vector3] = []
		for i in range(35):
			var point := float(i-17)
			var height := 6.0+absf(sin(i*0.61+layer*0.78))*5.3+pow(absf(sin(i*0.20+layer*0.45)),4)*14.4+rng.randf()*4
			height += 12.0*exp(-pow((point-1.8)/2.7,2.0))
			top.append(Vector3(point*6.5,height*(1.0-layer*0.16),z+rng.randf_range(-5,5)))
		var builder := SurfaceTool.new()
		builder.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in range(top.size()-1):
			var a := top[i]
			var b := top[i+1]
			var c := Vector3((a.x+b.x)*0.5,(a.y+b.y)*0.23,z+7)
			var base1 := Vector3(a.x,-2,z+12)
			var base2 := Vector3(b.x,-2,z+12)
			for trig in [[a,b,c],[a,c,base1],[c,b,base2],[c,base2,base1]]:
				var tint: Color = palette[layer].lightened(rng.randf_range(-0.12,0.14))
				for vertex in trig:
					builder.set_color(tint)
					builder.add_vertex(vertex)
			if city == 0 and a.y > 16:
				var snow := Color("d6c9c5").darkened(layer*0.08)
				for vertex in [a,a.lerp(b,0.62),a.lerp(c,0.27)]:
					builder.set_color(snow)
					builder.add_vertex(vertex+Vector3(0,0,0.12))
		builder.generate_normals()
		var material := StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		D.mesh(stage,builder.commit(),Vector3.ZERO,Vector3.ONE,material,false)

func _buildings() -> void:
	var palette: Array = [
		["715f58","a88873","595556","898385","a5a3a0","766e6a"],
		["ad7562","b6946a","5c746f","976e68","cf9c77","806b83"],
		["5b4846","765245","695b5a","4d5059","665151","58494c"]
	][city]
	for row in range(3):
		var x := -67.0
		while x < 72:
			var width := rng.randf_range(4.0,9.2)
			var depth := rng.randf_range(4.0,9.5)
			var h := rng.randf_range(3.0,10.3)+row*rng.randf_range(2.2,6.5)
			if city == 2:
				h *= 1.2+row*0.45
			elif city == 0 and x > -14 and x < 21:
				h = minf(h,3.3+row*1.06)
			elif city == 1 and row == 0:
				h = minf(h,5.3) if x>-23 and x<18 else h
			var pos := Vector3(x+width*0.5,0,-16.0-row*15.0-rng.randf_range(0,4))
			_building(pos,Vector3(width,h,depth),Color(palette[rng.randi_range(0,5)]),row == 0)
			x += width+rng.randf_range(0.7,3.9)
	for side in [-1,1]:
		for j in 4:
			var pos := Vector3(side*rng.randf_range(20,25),0,1.0+j*7)
			_building(pos,Vector3(rng.randf_range(5,8.5),rng.randf_range(6,14),rng.randf_range(5,8)),Color(palette[j]),true)

func _building(p: Vector3, s: Vector3, tone: Color, close: bool) -> void:
	var brick: Material = D.material(tone)
	if close:
		var stucco := ShaderMaterial.new()
		stucco.shader = FACADE
		stucco.set_shader_parameter("tint",tone)
		stucco.set_shader_parameter("brick_amount",[0.38,0.18,0.94][city])
		brick = stucco
	D.box(stage,p+Vector3.UP*s.y*0.5,s,brick,close)
	D.box(stage,p+Vector3.UP*(s.y+0.10),Vector3(s.x+0.23,0.19,s.z+0.23),tone.darkened(0.31),close)
	var levels := maxi(1,int((s.y-0.55)/1.57))
	var columns := maxi(2,int(s.x/1.22))
	for level in levels:
		var y := 0.98+level*1.52
		for col in columns:
			var x := -s.x*0.5+(col+0.5)*s.x/columns
			var pos := p+Vector3(x,y,s.z/2+0.024)
			var glass := D.xf(pos,Vector3(0.57,0.82,0.062))
			if rng.randf() < (0.35 if city == 2 else 0.15):
				lit.append(glass)
			else:
				windows.append(glass)
			if close:
				windows.append(D.xf(pos+Vector3(0,-0.43,0.042),Vector3(0.68,0.09,0.15)))
				windows.append(D.xf(pos+Vector3(0,0.03,0.037),Vector3(0.032,0.81,0.028)))
				if (col+level)%3 != 0:
					windows.append(D.xf(pos+Vector3(0,0.18,0.038),Vector3(0.56,0.030,0.030)))
		if close and (city == 2 or (level==1 and city==1)):
			D.box(stage,p+Vector3(0,y-0.55,s.z/2+0.03),Vector3(s.x,0.095,0.11),tone.darkened(0.34),false)
	var n := maxi(2, int(s.z/1.45))
	for side in [-1,1]:
		for level in levels:
			for i in n:
				var location := p+Vector3(side*(s.x*0.5+0.024),0.98+level*1.52,(-0.5+(i+0.5)/n)*s.z)
				var xf := D.xf(location,Vector3(0.063,0.73,0.55))
				if rng.randf() < 0.15:
					lit.append(xf)
				else:
					windows.append(xf)
	if close and city == 2 and rng.randf()<0.65:
		var base := p+Vector3(0,s.y,0)
		for x in [-0.55,0.55]:
			for z in [-0.55,0.55]:
				D.pipe(stage,base+Vector3(x,0,z),base+Vector3(x,1.13,z),0.05,Color("3c3535"))
		D.pipe(stage,base+Vector3.UP*0.86,base+Vector3.UP*2.25,0.77,Color("594d46"),0.77,16)
		D.pipe(stage,base+Vector3.UP*2.25,base+Vector3.UP*2.66,0.83,Color("3c373b"),0.08,16)
	elif close:
		D.box(stage,p+Vector3.UP*(s.y+0.40),Vector3(s.x*0.42,0.78,s.z*0.39),tone.darkened(0.20))

func _skyline() -> void:
	if city == 0:
		var base := Vector3(10.7,0,-44)
		var glass := D.material(Color("6e8d97"),0.38,0.23)
		D.box(stage,base+Vector3.UP*9.14,Vector3(3.1,18.28,3.2),glass,false)
		D.box(stage,base+Vector3(-0.38,18.79,-0.15),Vector3(2.24,1.11,2.73),glass,false)
		for i in range(28):
			var y := 0.40+i*0.64
			windows.append(D.xf(base+Vector3(0,y,1.61),Vector3(3.1,0.063,0.025)))
			windows.append(D.xf(base+Vector3(-1.57,y,0),Vector3(0.025,0.063,3.2)))
		for x in [-1.34,-0.71,0.18,1.17]:
			D.box(stage,base+Vector3(x,9.13,1.64),Vector3(0.058,18.35,0.042),Color("b6b1a7"),false)
	elif city == 1:
		var warm := Color("d5ac86")
		var base := Vector3(7.5,0,-30.7)
		_building(base,Vector3(5.6,6.7,4.0),warm,true)
		D.pipe(stage,base+Vector3.UP*6.6,base+Vector3.UP*8.23,1.46,warm,1.45,10,false)
		D.oval(stage,base+Vector3.UP*8.19,Vector3(3.06,2.3,3.06),Color("aa684f"))
		D.pipe(stage,base+Vector3.UP*9.22,base+Vector3.UP*10.17,0.095,Color("614b3d"),0.023,8,false)
	else:
		var base := Vector3(13,0,-49)
		var h := Color("756660")
		_building(base,Vector3(6.8,20.1,6.7),h,false)
		_building(base+Vector3.UP*20.1,Vector3(4.5,5.0,4.4),h.lightened(0.08),false)
		_building(base+Vector3.UP*25.1,Vector3(2.4,2.3,2.4),h.lightened(0.17),false)
		D.pipe(stage,base+Vector3.UP*27.4,base+Vector3.UP*31.3,0.20,Color("9f9186"),0.057,9,false)

func _tree(p: Vector3) -> void:
	var h := rng.randf_range(2.15,4.65)
	var canopy: Color = [Color("3c5140"),Color("656440"),Color("374841")][city]
	D.pipe(stage,p,p+Vector3(0.17,h,0.07),0.13,Color("5f5144"),0.033,9)
	for i in 8:
		var a := i*2.40
		var end := p+Vector3(cos(a)*rng.randf_range(0.45,1.25),h+rng.randf_range(-1.08,0.68),sin(a)*1.0)
		D.pipe(stage,p+Vector3.UP*(h-1.58),end,0.045,Color("5b4d41"),0.013,7)
		var size := Vector3(rng.randf_range(0.73,1.58),rng.randf_range(0.68,1.44),rng.randf_range(0.75,1.44))
		for j in range(5):
			var d := Vector3(sin(j*2.4)*0.46,cos(j*1.5)*0.32,cos(j*2.4)*0.44)
			var leaves := D.oval(stage,end+d,size*(0.65+0.30*((j%3)/2.0)),canopy.lightened(rng.randf_range(-0.12,0.13)))
			leaves.rotation.y = j*2.4

func _bunting() -> void:
	for row in 2:
		var z := -12.22 - 1.95 * row
		for i in 32:
			var x := -12.0+i*0.77
			var y := 4.01+pow(x/12.0,2.0)*1.78
			var next := 4.01+pow((x+0.77)/12.0,2.0)*1.78
			D.pipe(stage,Vector3(x,y,z),Vector3(x+0.77,next,z),0.009,Color("4d4140"),0.009,5,false)
			var tones := ["e7a048","c85661","56a593","9680a8","e3c6a3"]
			var cloth := D.box(stage, Vector3(x+0.34,(y+next)*0.5-0.20,z),Vector3(0.49,0.41,0.021),Color(tones[i%5]))
			cloth.rotation.x = sin(i*2.4)*0.20
			cloth.rotation.z = atan2(next-y,0.77)

func _train() -> void:
	var iron := D.material(Color("373e49"),0.57,0.27)
	D.box(stage,Vector3(0,4.42,-13.51),Vector3(100,0.31,2.50),iron)
	for i in range(-8,9):
		var x := i*5.8
		D.box(stage,Vector3(x,2.15,-13.86),Vector3(0.34,4.37,0.44),iron)
		var brace := D.box(stage,Vector3(x+0.50,3.61,-13.86),Vector3(0.22,1.84,0.33),iron)
		brace.rotation.z = -0.62
	for j in 3:
		var car := D.pivot(stage,Vector3(-17.0+j*8.12,5.27,-13.48))
		D.box(car,Vector3.ZERO,Vector3(7.94,1.36,1.74),Color("949896"))
		D.box(car,Vector3(0,-0.32,0.88),Vector3(7.94,0.18,0.018),Color("818993"))
		for i in range(9):
			D.box(car,Vector3((i-4)*0.79,0.19,0.881),Vector3(0.56,0.46,0.021),D.material(Color("b4c7d0"),0.41,0.09,0.33))

func _street_details() -> void:
	var gravel: Array[Transform3D] = []
	for i in 185:
		var x := rng.randf_range(-10.02,10.02)
		var z := rng.randf_range(-10.23,8.5)
		if absf(x)<COURT_X+0.35 and z>BASELINE-0.6 and z<HALFLINE+0.3:
			continue
		gravel.append(D.xf(Vector3(x,0.011,z),Vector3(rng.randf_range(0.024,0.15),0.012,rng.randf_range(0.012,0.073)),rng.randf_range(0,TAU)))
	D.batch_boxes(stage,gravel,Color("817661"))
