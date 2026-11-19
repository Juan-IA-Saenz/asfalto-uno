extends Node3D

const D = preload("res://game/shapes.gd")
const Rules = preload("res://game/rules.gd")
const FABRIC = preload("res://art/jersey.gdshader")
const SKIN := ["e4ad8e","cd8f6b","b97957","995d45","754533","563024"]
const HAIR_COLOR := ["201918","50362a","85553e","c78f5d","a1a09b"]
const TEAM := ["dc7449","6a9c83","e3d6bb","667fbe","683e55","272f36"]
const SHOES := ["e7dfcd","2e363b","be513d","c3da7b","646fac"]
const BASE_HEIGHT := 1.90
const DUR_CELEBRATE := 0.92

var profile: Dictionary
var rig: Node3D
var trunk: Node3D
var dress: Node3D
var head: Node3D
var arms: Array[Node3D] = []
var forearms: Array[Node3D] = []
var legs: Array[Node3D] = []
var shins: Array[Node3D] = []
var grips: Array[Node3D] = []
var shadow: MeshInstance3D
var height_factor := 1.0
var anim := 0.0
var face := 0.0
var dominant := 1
var number := 1

static func preset(slot: int) -> Dictionary:
	if slot == 0:
		return {"name":"Vega", "height":1.92, "weight":87.6, "muscle":73, "shot":88, "defense":62, "dribble":87, "skin":2, "hair":2, "hair_color":0, "beard":1, "tattoo":1, "team":0, "shoe":0, "accessory":1, "shot_style":0, "celebrate":0, "dribble_style":0}
	return {"name":"Rojas", "height":2.028, "weight":103.88, "muscle":74, "shot":59, "defense":80, "dribble":57, "skin":4, "hair":1, "hair_color":0, "beard":2, "tattoo":2, "team":3, "shoe":1, "accessory":2, "shot_style":1, "celebrate":1, "dribble_style":1}

static func clean(raw: Dictionary, slot: int) -> Dictionary:
	var data := preset(slot)
	var options := {"skin":6,"hair":4,"hair_color":5,"beard":3,"tattoo":3,"team":6,"shoe":5,"accessory":4,"shot_style":3,"celebrate":3,"dribble_style":3}
	for k in options:
		if raw.get(k) is float or raw.get(k) is int:
			data[k] = clampi(int(raw[k]),0,options[k]-1)
	for k in Rules.APTITUDES:
		if (raw.get(k) is float or raw.get(k) is int) and is_finite(float(raw[k])):
			data[k] = Rules.aptitude_value(k,Rules.aptitude_points(k,raw[k]))
	Rules.fit_budget(data)
	if raw.get("name") is String and not raw.name.strip_edges().is_empty():
		data.name = raw.name.strip_edges().substr(0,14)
	return data

func build(data: Dictionary, slot: int) -> void:
	profile = clean(data,slot)
	number = 7 if slot == 0 else 21
	if is_instance_valid(rig):
		remove_child(rig)
		rig.queue_free()
	if not is_instance_valid(shadow):
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(0.039,0.047,0.051,0.32)
		shadow = D.oval(self,Vector3(0,0.031,0),Vector3(0.69,0.014,0.56),mat)
		shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rig = D.pivot(self,Vector3.ZERO)
	height_factor = profile.height/BASE_HEIGHT
	rig.scale = Vector3.ONE*height_factor
	var breadth := lerpf(0.88,1.18,(float(profile.weight)-58.0)/74.0)
	var muscle := lerpf(0.82,1.26,float(profile.muscle)/100.0)
	var shoulder := 0.217*breadth*(0.92+muscle*0.10)
	var waist := (0.146+(breadth-0.88)*0.10)
	var sk := Color(SKIN[profile.skin])
	var skin := D.material(sk,0.66)
	var dark_skin := D.material(sk.darkened(0.22),0.69)
	var shirt := Color(TEAM[profile.team])
	var trim := Color("f0dfb8") if shirt.get_luminance()<0.52 else Color("334c44")
	var outfit := _fabric(shirt)
	var cloth_dark := _fabric(shirt.darkened(0.45))
	var shoe := Color(SHOES[profile.shoe])
	var sole := Color("e0d5c2") if shoe.get_luminance()<0.5 else Color("495150")
	arms.clear()
	forearms.clear()
	legs.clear()
	shins.clear()
	grips.clear()
	trunk = D.pivot(rig,Vector3(0,0.96,0))
	dress = D.pivot(trunk,Vector3.ZERO)
	_shell(dress,[
		Vector4(0.03,waist,0.095*breadth,0.0),
		Vector4(0.15,waist*0.91,0.093*breadth,0.0),
		Vector4(0.31,shoulder*0.88,0.123*breadth,0.0),
		Vector4(0.46,shoulder,0.111*breadth,0.004),
		Vector4(0.54,shoulder*0.80,0.088*breadth,0.0),
		Vector4(0.575,0.086,0.072,0.0)
	],outfit)
	_shell(dress,[Vector4(0.035,waist*1.02,0.098*breadth,0),Vector4(0.082,waist,0.098*breadth,0)],cloth_dark)
	_shell(dress,[Vector4(0.532,0.093,0.071,0),Vector4(0.576,0.069,0.059,0),Vector4(0.637,0.060,0.052,-0.005),Vector4(0.678,0.064,0.057,0)],skin)
	_shell(dress,[Vector4(0.552,0.091,0.078,0.0),Vector4(0.572,0.092,0.075,0.0)],trim)
	D.words(dress,Vector3(0,0.409,0.126*breadth),"ASFALTO",0.038,trim)
	D.words(dress,Vector3(0,0.271,0.129*breadth),str(number),0.151,trim)
	var back := D.words(dress,Vector3(0,0.302,-0.126*breadth),str(number),0.177,trim)
	back.rotation.y = PI
	D.oval(dress,Vector3(0,-0.032,-0.003),Vector3(waist*1.93,0.145,0.193*breadth),outfit)
	head = D.pivot(dress,Vector3(0,0.65,0.008))
	_head(skin,dark_skin,sk,trim)
	for s in [-1,1]:
		var arm := D.pivot(dress,Vector3(shoulder*s,0.468,0.003))
		var top_w := 0.131*muscle
		D.oval(arm,Vector3(0,-0.043,0),Vector3(top_w*1.12,0.164,0.137*muscle),skin)
		_shell(arm,[Vector4(-0.265,top_w*0.34,0.052,0),Vector4(-0.13,top_w*0.50,0.062*muscle,0),Vector4(-0.037,top_w*0.45,0.066*muscle,0)],skin)
		_jacket_edge(dress,s,shoulder,trim)
		var fore := D.pivot(arm,Vector3(0,-0.268,0))
		D.oval(fore,Vector3.ZERO,Vector3(0.092,0.093,0.093),skin)
		_shell(fore,[Vector4(-0.242,0.032,0.026,0),Vector4(-0.16,0.035*muscle,0.038*muscle,0),Vector4(-0.087,0.046*muscle,0.049*muscle,0),Vector4(-0.023,0.048*muscle,0.049,0)],skin)
		var hand := D.oval(fore,Vector3(0,-0.272,0.009),Vector3(0.075,0.128,0.059),skin)
		hand.rotation.x = -0.16
		var thumb := D.oval(fore,Vector3(-s*0.033,-0.26,0.021),Vector3(0.031,0.067,0.026),skin)
		thumb.rotation.z = -s*0.35
		var grip := D.pivot(fore,Vector3(0,-0.285,0.067))
		if profile.tattoo > 0 and (s == -1 or profile.tattoo == 2):
			_tattoo(arm,top_w*0.50,0.062*muscle,sk.darkened(0.59))
		if profile.accessory == 1 and s == 1:
			_shell(fore,[Vector4(-0.233,0.039,0.035,0),Vector4(-0.198,0.042,0.039,0)],trim)
		if (profile.accessory == 2 or profile.accessory == 3) and s == 1:
			_shell(arm,[Vector4(-0.283,top_w*0.40,0.056,0),Vector4(-0.159,top_w*0.51,0.064*muscle,0),Vector4(-0.10,top_w*0.51,0.068*muscle,0)],cloth_dark)
			_shell(fore,[Vector4(-0.222,0.039,0.036,0),Vector4(-0.09,0.05*muscle,0.054*muscle,0),Vector4(0.022,0.048*muscle,0.052,0)],cloth_dark)
			_shell(fore,[Vector4(-0.224,0.041,0.038,0),Vector4(-0.213,0.042,0.039,0)],trim)
		arms.append(arm)
		forearms.append(fore)
		grips.append(grip)
		var leg := D.pivot(trunk,Vector3(s*waist*0.61,-0.035,0))
		_shell(leg,[
			Vector4(-0.309,0.092*breadth,0.096*breadth,0),
			Vector4(-0.200,0.105*breadth,0.108*breadth,0),
			Vector4(-0.052,0.104*breadth,0.113*breadth,0),
			Vector4(0.045,0.105*breadth,0.104*breadth,0)
		],outfit)
		D.box(leg,Vector3(s*0.097*breadth,-0.162,0.016),Vector3(0.017,0.264,0.028),trim)
		_shell(leg,[Vector4(-0.306,0.093*breadth,0.097*breadth,0),Vector4(-0.286,0.097*breadth,0.101*breadth,0)],cloth_dark)
		_shell(leg,[Vector4(-0.424,0.062,0.058,0),Vector4(-0.29,0.078*breadth,0.079*breadth,0)],skin)
		var shin := D.pivot(leg,Vector3(0,-0.419,0.0))
		D.oval(shin,Vector3(0,-0.018,0.009),Vector3(0.127,0.14,0.127),skin)
		_shell(shin,[Vector4(-0.415,0.044,0.043,0),Vector4(-0.306,0.045,0.043,-0.004),Vector4(-0.138,0.071*muscle,0.068,-0.019),Vector4(-0.031,0.062,0.056,-0.004)],skin)
		_shell(shin,[Vector4(-0.414,0.048,0.046,0),Vector4(-0.292,0.052,0.047,0)],trim)
		_shell(shin,[Vector4(-0.309,0.054,0.050,0),Vector4(-0.294,0.054,0.050,0)],cloth_dark)
		_sneaker(shin,shoe,sole,s)
		legs.append(leg)
		shins.append(shin)
	pose(0.0,0.0,"idle")

func _fabric(dye: Color) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = FABRIC
	mat.set_shader_parameter("dye",dye)
	mat.set_shader_parameter("pattern",profile.team)
	return mat

func _jacket_edge(parent: Node3D, side: int, width: float, trim: Color) -> void:
	var coords := [Vector3(side*width*0.68,0.532,0.043),Vector3(side*width*0.75,0.518,0.067),Vector3(side*width*0.79,0.494,0.082),Vector3(side*width*0.82,0.467,0.082),Vector3(side*width*0.85,0.434,0.066),Vector3(side*width*0.88,0.412,0.057)]
	for face_side in [-1,1]:
		for i in range(coords.size()-1):
			var a: Vector3 = coords[i]
			var b: Vector3 = coords[i+1]
			a.z *= face_side
			b.z *= face_side
			D.pipe(parent,a,b,0.004,trim,0.004,6,false)

func _shell(parent: Node3D, rings: Array, ink: Variant, sides := 24) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in range(rings.size()-1):
		for i in sides:
			for pos in [Vector2i(j,i),Vector2i(j+1,i),Vector2i(j,i+1),Vector2i(j,i+1),Vector2i(j+1,i),Vector2i(j+1,i+1)]:
				var r: Vector4 = rings[pos.x]
				var u: float = TAU*pos.y/sides
				st.add_vertex(Vector3(r.y*sin(u),r.x,r.z*cos(u)+r.w))
	for cap in [0,rings.size()-1]:
		var r: Vector4 = rings[cap]
		for i in sides:
			var a := TAU*i/sides
			var b := TAU*(i+1)/sides
			var rim_a := Vector3(r.y*sin(a),r.x,r.z*cos(a)+r.w)
			var rim_b := Vector3(r.y*sin(b),r.x,r.z*cos(b)+r.w)
			st.add_vertex(Vector3(0,r.x,r.w))
			st.add_vertex(rim_a if cap == 0 else rim_b)
			st.add_vertex(rim_b if cap == 0 else rim_a)
	st.index()
	st.generate_normals()
	return D.mesh(parent,st.commit(),Vector3.ZERO,Vector3.ONE,ink)

func _head(skin: Material, dark_skin: Material, sk: Color, trim: Color) -> void:
	_shell(head,[
		Vector4(0.004,0.036,0.055,0.028),
		Vector4(0.030,0.066,0.075,0.018),
		Vector4(0.071,0.081,0.080,0.007),
		Vector4(0.118,0.091,0.084,0.005),
		Vector4(0.148,0.092,0.085,0.003),
	Vector4(0.181,0.092,0.086,0.0),
		Vector4(0.222,0.076,0.076,-0.011),
		Vector4(0.245,0.031,0.040,-0.014),
		Vector4(0.251,0.003,0.003,-0.014)
	],skin,32)
	for side in [-1,1]:
		D.oval(head,Vector3(side*0.088,0.109,0.002),Vector3(0.044,0.063,0.032),skin)
		D.oval(head,Vector3(side*0.106,0.106,0.013),Vector3(0.013,0.029,0.011),dark_skin)
		D.oval(head,Vector3(side*0.0375,0.129,0.082),Vector3(0.045,0.024,0.013),dark_skin)
		var eye := D.oval(head,Vector3(side*0.0362,0.130,0.088),Vector3(0.028,0.008,0.008),Color("beb5ab"))
		eye.rotation.y = side*0.17
		D.oval(head,Vector3(side*0.035,0.130,0.0924),Vector3(0.013,0.011,0.003),Color("382f2b"))
		D.oval(head,Vector3(side*0.0325,0.133,0.0941),Vector3(0.003,0.003,0.002),Color("e7dece"))
		var brow := D.oval(head,Vector3(side*0.039,0.148,0.082),Vector3(0.044,0.009,0.012),Color(HAIR_COLOR[profile.hair_color]).darkened(0.22))
		brow.rotation.z = side*0.06
		D.oval(head,Vector3(side*0.014,0.088,0.101),Vector3(0.020,0.015,0.021),skin)
		D.oval(head,Vector3(side*0.013,0.084,0.107),Vector3(0.008,0.005,0.004),dark_skin)
	var bridge := D.oval(head,Vector3(0,0.109,0.099),Vector3(0.027,0.053,0.031),skin)
	bridge.rotation.x = -0.24
	D.oval(head,Vector3(0,0.095,0.112),Vector3(0.033,0.025,0.025),skin)
	var hair := Color(HAIR_COLOR[profile.hair_color])
	if profile.beard > 0:
		var beard := hair.lerp(sk,0.42 if profile.beard == 1 else 0.13)
		D.oval(head,Vector3(0,0.023,0.061),Vector3(0.099,0.041,0.083),beard)
		for s in [-1,1]:
			var jaw := D.oval(head,Vector3(s*0.053,0.045,0.051),Vector3(0.064,0.046,0.075),beard)
			jaw.rotation.z = s*0.44
			if profile.beard == 2:
				D.oval(head,Vector3(s*0.017,0.067,0.092),Vector3(0.034,0.015,0.021),beard)
	D.oval(head,Vector3(0,0.058,0.094),Vector3(0.052,0.013,0.015),sk.darkened(0.27))
	D.oval(head,Vector3(0,0.052,0.095),Vector3(0.049,0.012,0.014),sk.lerp(Color("b77370"),0.38))
	D.oval(head,Vector3(0,0.057,0.102),Vector3(0.045,0.0038,0.003),sk.darkened(0.51))
	if profile.hair > 0:
		_shell(head,[Vector4(0.147,0.076,0.066,-0.021),Vector4(0.181,0.093,0.083,-0.009),Vector4(0.224,0.086,0.084,-0.01),Vector4(0.251,0.051,0.058,-0.017),Vector4(0.259,0.004,0.006,-0.016)],hair)
	if profile.hair == 2:
		for i in 36:
			var a := i*2.39996
			var r := sqrt(i/36.0)
			var q := Vector3(cos(a)*r*0.081,0.256-r*r*0.048,sin(a)*r*0.080-0.016)
			D.oval(head,q,Vector3(0.039,0.037,0.045),hair.lightened((i%5-2)*0.028))
	elif profile.hair == 3:
		for i in 9:
			var x := (i-4)*0.019
			var y := 0.245-absf(x)*0.38
			for j in 5:
				var z := (j-2)*0.034
				D.oval(head,Vector3(x,y-absf(z)*0.26,z),Vector3(0.026,0.027,0.057),hair.lightened(i%3*0.033))
		for i in 4:
			D.oval(head,Vector3(-0.035+i*0.024,0.176,-0.083),Vector3(0.026,0.133,0.032),hair)
	if profile.accessory == 3:
		_shell(head,[Vector4(0.169,0.099,0.093,0.0),Vector4(0.195,0.099,0.091,0.0)],trim)

func _tattoo(arm: Node3D, rx: float, rz: float, ink: Color) -> void:
	for row in 4:
		var y := -0.116-row*0.019
		for j in 9:
			var a := lerpf(-1.18,1.29,j/8.0)
			var taper := 1.0 - maxf(0.0,float(row-1))*0.07
			var line := D.box(arm,Vector3(sin(a)*rx*taper,y,cos(a)*rz*taper+0.003),Vector3(0.017,0.005,0.006),ink,false)
			line.rotation.y = a
			line.rotation.z = (1 if (j+row)%2 == 0 else -1)*0.57

func _sneaker(shin: Node3D, shoe: Color, sole: Color, side: int) -> void:
	D.oval(shin,Vector3(0,-0.461,0.069),Vector3(0.141,0.081,0.292),D.material(sole,0.66))
	D.oval(shin,Vector3(0,-0.435,0.069),Vector3(0.133,0.093,0.281),D.material(shoe,0.48))
	D.oval(shin,Vector3(0,-0.393,0.001),Vector3(0.121,0.124,0.143),D.material(shoe.darkened(0.12),0.55))
	D.oval(shin,Vector3(0,-0.448,0.169),Vector3(0.120,0.053,0.094),shoe.lightened(0.16))
	for i in 4:
		var lace := D.box(shin,Vector3(0,-0.391-i*0.008,0.049+i*0.023),Vector3(0.073,0.005,0.005),sole,false)
		lace.rotation.y = (i%2*2-1)*0.19
	var mark := D.box(shin,Vector3(side*0.065,-0.429,0.067),Vector3(0.012,0.013,0.073),sole,false)
	mark.rotation.x = -0.18

func turn(towards: float, dt: float) -> void:
	face = lerp_angle(face,towards,minf(1.0,dt*11.0))
	rotation.y = face

func pose(dt: float, speed: float, state: String, phase := 0.0, hand_override := -1) -> void:
	if not is_instance_valid(rig):
		return
	anim += dt*(2.25+speed*1.32)
	var wave := sin(anim)
	var steps := clampf(speed/5.5,0.0,1.0)
	trunk.position.y = 0.949-steps*0.055+sin(anim*2.0)*0.022*steps+sin(anim*1.0)*0.010
	trunk.rotation = Vector3(steps*0.16,0.035*wave*steps,cos(anim)*0.06*steps)
	head.rotation = Vector3(-steps*0.11,0.065*sin(anim*0.43),0.035*sin(anim*0.81))
	rig.position.y = 0.0
	for i in 2:
		var side := float(i*2-1)
		arms[i].rotation = Vector3(wave*steps*0.66*side - 0.12,0,side*0.16)
		forearms[i].rotation.x = -0.20-steps*0.59
		legs[i].rotation = Vector3(-wave*steps*0.77*side,0,side*0.085)
		shins[i].rotation.x = maxf(0.0,wave*steps*0.9*side)+0.078
	match state:
		"carry":
			var style: int = profile.dribble_style
			var preferred := 1 if hand_override < 0 else hand_override
			dominant = (preferred if sin(phase*PI) >= 0.0 else 1-preferred) if style == 1 and hand_override < 0 else preferred
			var hand := dominant
			var bounce := absf(sin(phase*PI))
			arms[hand].rotation.x = -0.42-bounce*0.40
			arms[hand].rotation.z = (hand*2-1)*0.32
			forearms[hand].rotation.x = -0.39-bounce*0.35
			if style == 2:
				trunk.position.y -= 0.09
				legs[0].rotation.x -= 0.26
				legs[1].rotation.x -= 0.26
				shins[0].rotation.x += 0.31
				shins[1].rotation.x += 0.31
		"cross":
			dominant = hand_override
			var side := float(dominant*2-1)
			var bend := sin(phase*PI)
			trunk.rotation = Vector3(0.31,-side*0.33*bend,-side*0.17*bend)
			trunk.position.y -= 0.15*bend
			for i in 2:
				var spread := float(i*2-1)
				arms[i].rotation = Vector3(-0.41-bend*0.17,0,spread*(0.23+0.38*bend))
				forearms[i].rotation.x = -0.18-bend*0.14
				legs[i].rotation.x -= 0.33*bend
				shins[i].rotation.x += 0.52*bend
			arms[dominant].rotation.z *= 1.2
		"dunk":
			var raise_arm := smoothstep(0.12,0.58,phase)*(1.0-smoothstep(0.76,1.0,phase))
			var jump_progress := clampf((phase-0.11)/0.88,0,1)
			var apex := pow(maxf(0.0,sin(jump_progress*PI)),1.36)
			rig.position.y = apex*maxf(0.65,3.00-height_factor*2.04)
			trunk.rotation = Vector3(-0.21*raise_arm,-0.21*raise_arm,0.10*raise_arm)
			arms[1].rotation = Vector3(-0.36-2.53*raise_arm,0,0.13+0.18*raise_arm)
			forearms[1].rotation.x = -0.56+0.44*raise_arm
			arms[0].rotation = Vector3(-0.41-0.64*raise_arm,0,-0.35-0.38*raise_arm)
			forearms[0].rotation.x = -0.36
			legs[0].rotation.x = -0.65*apex
			shins[0].rotation.x = 0.72*apex+0.14
			legs[1].rotation.x = 0.15*apex
			shins[1].rotation.x = 0.39*apex+0.11
		"aim", "shoot":
			var style: int = profile.shot_style
			var up := 0.75+phase*0.65 if state == "aim" else 1.0+sin(phase*PI)*0.34
			var lift: float = 0.0 if state == "aim" else sin(phase*PI)*[0.27,0.47,0.19][style]
			rig.position.y = lift
			trunk.rotation.x = -0.14 if style == 2 else -0.065
			for i in 2:
				arms[i].rotation.x = -1.28-up*(0.89 if style != 2 else 0.58)
				arms[i].rotation.z = (i*2-1)*(0.19 if style == 0 else (0.33 if style == 1 else 0.29))
				forearms[i].rotation.x = -0.81 if state == "aim" else -0.68*(1.0-phase)
				legs[i].rotation.x = -0.25*(1.0-up*0.55)
				shins[i].rotation.x = 0.32*(1.0-up*0.55)
			if style == 2:
				arms[0].rotation.x = -1.00-up*0.45
		"guard", "steal":
			trunk.position.y -= 0.12 if state == "guard" else 0.08
			trunk.rotation.x = 0.26
			for i in 2:
				arms[i].rotation = Vector3(-0.56 if state == "guard" else -1.27,0,(i*2-1)*(0.79 if state == "guard" else 0.35))
				forearms[i].rotation.x = -0.27
				legs[i].rotation.x -= 0.27
				shins[i].rotation.x += 0.31
		"block":
			var extension := smoothstep(0.0,0.12,phase)*(1.0-smoothstep(0.64,1.0,phase))
			rig.position.y = Rules.block_lift(phase)
			trunk.rotation.x = -0.10*extension
			arms[1].rotation = Vector3(-0.30-2.45*extension,0,0.13+0.11*extension)
			forearms[1].rotation.x = -0.41+0.25*extension
			arms[0].rotation = Vector3(-0.42-1.64*extension,0,-0.22-0.23*extension)
			legs[0].rotation.x -= 0.35*extension
			shins[0].rotation.x += 0.53*extension
			shins[1].rotation.x += 0.21*extension
		"present", "receive":
			var reach := minf(phase,1.0)
			var lift := maxf(phase-1.0,0.0)
			var side := hand_override*2-1
			arms[hand_override].rotation = Vector3(-0.63-0.73*reach-0.74*lift,0,side*(0.29+0.63*reach+0.37*lift))
			forearms[hand_override].rotation.x = -0.99+0.25*lift
			trunk.rotation.y = side*0.11*reach
			head.rotation.x = 0.11*reach-0.19*lift
		"celebrate":
			var style: int = profile.celebrate
			var pulse := sin(phase*PI)
			if style == 0:
				rig.position.y = maxf(0,sin(phase*TAU))*0.16
				arms[1].rotation = Vector3(-2.51-pulse*0.37,0,0.46)
				forearms[1].rotation.x = -0.44-pulse*0.26
			elif style == 1:
				trunk.rotation.y = sin(phase*TAU)*0.27
				arms[0].rotation = Vector3(-1.13,0,-0.30)
				arms[1].rotation = Vector3(-1.13,0,0.30)
				forearms[0].rotation.x = -1.12-pulse*0.5
				forearms[1].rotation.x = -1.12-pulse*0.5
			else:
				rig.position.y = pulse*0.29
				arms[0].rotation.z = -1.77-pulse*0.46
				arms[1].rotation.z = 1.77+pulse*0.46

func ball_hand(side: int) -> Vector3:
	return grips[side].global_position
