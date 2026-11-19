extends Node3D

const D = preload("res://game/shapes.gd")
const Court = preload("res://game/court.gd")
const BEATS := [92.0,96.0,88.0]
const CREWS := ["RIMA ANDINA","BARRIO DEL SOL","CAGE CYPHER"]
const TRACKS := ["BOOM BAP ANDINO","HIP HOP + CUMBIA","BOOM BAP EAST COAST"]
const HAIR := ["211915","38251e","693d28","4c2a21"]
const SKINS := ["c58262","b06e48","8b5138","e4a084","613b2d"]
const STREET := ["e37154","7188bc","ded7bd","4d967e","a96591","dcae54"]
const LANES := [-3.3,-0.9,1.6,3.8]

signal dog_entered
var stage: Node3D
var city := -1
var figures: Array[Dictionary] = []
var dog: Node3D
var dog_body: Node3D
var dog_head: Node3D
var dog_tail: Node3D
var dog_legs: Array[Node3D] = []
var rng := RandomNumberGenerator.new()
var seconds := 0.0
var cheer := 0.0
var dog_wait := 0.0
var dog_progress := 0.0
var dog_side := 1
var dog_lane := 0.0

func start(index: int) -> void:
	if city != index:
		_build(index)
	rng.randomize()
	stage.show()
	seconds = 0.0
	cheer = 0.0
	dog.hide()
	dog_wait = rng.randf_range(12.0,20.0)

func stop() -> void:
	if is_instance_valid(stage):
		stage.hide()
		dog.hide()

func react(strength: float) -> void:
	cheer = maxf(cheer,strength)

func advance(dt: float, live: bool, a: Vector3, b: Vector3) -> void:
	seconds += dt
	cheer = maxf(0.0,cheer-dt*0.48)
	var beat := seconds*TAU*float(BEATS[city])/60.0
	for i in figures.size():
		_animate_figure(figures[i],beat,i)
	if dog.visible:
		dog_progress = minf(1.0,dog_progress+dt/3.65)
		_run_dog()
		if dog_progress >= 1.0:
			dog.hide()
			dog_wait = rng.randf_range(26.0,40.0)
	elif live:
		dog_wait -= dt
		if dog_wait <= 0.0:
			_send_dog(a,b)

func _build(index: int) -> void:
	if is_instance_valid(stage):
		remove_child(stage)
		stage.queue_free()
	city = index
	figures.clear()
	dog_legs.clear()
	stage = D.pivot(self,Vector3.ZERO)
	var accent := Color(Court.CITIES[index].accent)
	var deck := D.pivot(stage,Vector3(-5.72,0,-8.47))
	deck.rotation.y = 0.34
	D.box(deck,Vector3(0,0.11,0),Vector3(3.37,0.24,1.54),"38413f")
	D.box(deck,Vector3(0,0.24,0),Vector3(3.43,0.045,1.60),accent.darkened(0.31))
	D.box(deck,Vector3(0,0.155,0.81),Vector3(3.26,0.039,0.044),D.material(accent,0.52,0,0.32),false)
	D.words(deck,Vector3(0,0.13,0.837),CREWS[index],0.16,Color("f2e6cf"))
	_speaker(deck,Vector3(-1.34,0.26,0.22),accent)
	_speaker(deck,Vector3(1.34,0.26,0.22),accent)
	_figure(deck,Vector3(-0.58,0.27,0.23),Vector3(0.8,0,2.3),0,"rapper","dfb853")
	_figure(deck,Vector3(0.53,0.27,-0.18),Vector3(1.18,0,2.3),1,"rapper","799eac")
	for i in 6:
		var back := Vector3(1.55+i*0.96,0,-8.49-0.32*float(i%2))
		var variant := "swim" if i==1 or i==4 else "fan"
		_figure(stage,back,Vector3(1.35,0,-1.0),i+2,variant,["1fa9a5","ec6854","657dc2","e2b348","7956af","e3d1a9"][i])
	for i in 6:
		var side := Vector3(-7.6-0.35*float(i%2),0,-5.75+i*1.42)
		_figure(stage,side,Vector3(1.5,0,-2),i+8,"swim" if i==2 else "fan",STREET[(i+index)%STREET.size()])
	_build_dog()

func _speaker(parent: Node3D, p: Vector3, tint: Color) -> void:
	D.box(parent,p+Vector3.UP*0.42,Vector3(0.44,0.84,0.49),"1c2121")
	D.box(parent,p+Vector3(0,0.41,0.255),Vector3(0.39,0.75,0.035),"313a3b",false)
	for y in [0.28,0.57]:
		D.oval(parent,p+Vector3(0,y,0.28),Vector3(0.28,0.28,0.035),tint.darkened(0.47))
		D.oval(parent,p+Vector3(0,y,0.30),Vector3(0.19,0.19,0.039),"1e2728")
	D.oval(parent,p+Vector3(0.13,0.71,0.28),Vector3.ONE*0.030,D.material(tint,0.30,0,0.44),false)

func _figure(parent: Node3D, position_in: Vector3, look: Vector3, index: int, style: String, outfit: String) -> void:
	var p := D.pivot(parent,position_in)
	var face := look-position_in
	p.rotation.y = atan2(face.x,face.z)
	var rig := D.pivot(p,Vector3.ZERO)
	var swim := style=="swim"
	var artist := style=="rapper"
	var width := 0.83 if swim else 1.0+0.025*(index%4)
	rig.scale = Vector3(width,0.94+0.035*(index%5),width)
	var tint := Color(outfit)
	var skin := D.material(SKINS[index%SKINS.size()],0.76)
	var hair := D.material(HAIR[index%HAIR.size()],0.90)
	var cloth := D.material(tint,0.83)
	var shade := D.material(tint.darkened(0.28),0.84)
	var legs := skin if swim else D.material(Color("4d5861") if index%2 == 0 else Color("343b48"),0.87)
	var shoe := D.material("cfc6b7",0.85)
	D.oval(p,Vector3(0,0.024,0),Vector3(0.59,0.014,0.44),D.material(Color(0.16,0.17,0.17)),false)
	D.oval(rig,Vector3(0,0.95,0),Vector3(0.39,0.31,0.25),cloth if swim else legs,false)
	D.oval(rig,Vector3(0,1.16,0.006),Vector3(0.32,0.47,0.23),skin if swim else cloth,false)
	D.oval(rig,Vector3(0,1.37,0.003),Vector3(0.49,0.34,0.28),skin if swim else cloth,false)
	if swim:
		D.oval(rig,Vector3(0,1.33,0.069),Vector3(0.46,0.19,0.26),cloth,false)
		for s in [-1.0,1.0]:
			D.pipe(rig,Vector3(s*0.115,1.31,0.172),Vector3(s*0.145,1.495,0.027),0.015,shade,0.015,6,false)
		D.box(rig,Vector3(0,0.999,0.116),Vector3(0.27,0.03,0.026),shade,false)
	else:
		D.oval(rig,Vector3(0,1.27,0.142),Vector3(0.29,0.078,0.017),shade,false)
		D.box(rig,Vector3(0,1.34,0.15),Vector3(0.14,0.023,0.022),"e6d9b8",false)
	D.oval(rig,Vector3(0,1.52,0),Vector3(0.12,0.19,0.14),skin,false)
	var head := D.pivot(rig,Vector3(0,1.65,0.019))
	D.oval(head,Vector3.ZERO,Vector3(0.23,0.29,0.229),skin,false)
	D.oval(head,Vector3(0.001,0.085,-0.025),Vector3(0.244,0.17,0.231),hair,false)
	if swim:
		D.oval(head,Vector3(0,0.014,-0.099),Vector3(0.24,0.32,0.13),hair,false)
		D.oval(head,Vector3(0.048,-0.13,-0.122),Vector3(0.12,0.20,0.14),hair,false)
	elif artist or index%3==0:
		D.oval(head,Vector3(0,0.103,-0.006),Vector3(0.275,0.152,0.26),shade,false)
		D.oval(head,Vector3(0,0.077,0.145),Vector3(0.19,0.027,0.20),shade,false)
	for s in [-1.0,1.0]:
		D.oval(head,Vector3(s*0.044,0.001,0.097),Vector3(0.04,0.023,0.022),"eee0d0",false)
		D.oval(head,Vector3(s*0.044,0.001,0.108),Vector3(0.018,0.019,0.009),"252224",false)
	D.oval(head,Vector3(0,-0.029,0.106),Vector3(0.044,0.057,0.048),skin,false)
	D.oval(head,Vector3(0,-0.068,0.101),Vector3(0.067,0.020,0.025),"673d38",false)
	var arms: Array[Node3D] = []
	var elbows: Array[Node3D] = []
	for s in [-1.0,1.0]:
		var arm := D.pivot(rig,Vector3(0.238*s,1.42,0))
		D.oval(arm,Vector3(0,-0.126,0),Vector3(0.125,0.32,0.13),skin,false)
		if not swim:
			D.oval(arm,Vector3(0,-0.044,0),Vector3(0.155,0.18,0.145),shade,false)
		var elbow := D.pivot(arm,Vector3(0,-0.26,0))
		D.oval(elbow,Vector3(0,-0.11,0),Vector3(0.093,0.265,0.103),skin,false)
		D.oval(elbow,Vector3(0,-0.247,0.022),Vector3(0.092,0.12,0.064),skin,false)
		arms.append(arm)
		elbows.append(elbow)
		D.oval(rig,Vector3(0.112*s,0.64,0),Vector3(0.18,0.59,0.19),legs,false)
		D.oval(rig,Vector3(0.117*s,0.25,-0.02),Vector3(0.139,0.53,0.152),legs,false)
		D.oval(rig,Vector3(0.119*s,0.054,0.043),Vector3(0.145,0.097,0.27),shoe,false)
	if artist:
		var mic := D.pivot(elbows[1],Vector3(0,-0.23,0.07))
		D.pipe(mic,Vector3(0,0,-0.054),Vector3(0,0,0.106),0.026,"262b2c",0.028,7,false)
		D.oval(mic,Vector3(0,0,0.104),Vector3(0.074,0.070,0.070),"a0a09a",false)
	figures.append({"rig":rig,"head":head,"arms":arms,"elbows":elbows,"artist":artist})

func _animate_figure(f: Dictionary, beat: float, index: int) -> void:
	var rig: Node3D = f.rig
	var head: Node3D = f.head
	var arms: Array[Node3D] = f.arms
	var elbows: Array[Node3D] = f.elbows
	var phase := beat+index*0.92
	var wave := sin(phase)
	var jump := maxf(0.0,sin(phase*0.8))
	rig.position.y = (0.017+cheer*0.09)*jump
	rig.rotation.z = wave*(0.025+0.035*cheer)
	head.rotation.y = sin(phase*0.31)*0.17
	head.rotation.x = sin(phase)*0.12
	if f.artist:
		arms[1].rotation = Vector3(-0.85,-0.19,-0.14)
		elbows[1].rotation.x = -1.67
		arms[0].rotation = Vector3(-1.07+wave*0.49,0,-0.42+wave*0.30)
		elbows[0].rotation.x = -0.55+wave*0.40
		return
	for a in 2:
		var side := float(a*2-1)
		var react_pose := cheer*1.25
		if index%3 == 0:
			arms[a].rotation = Vector3(-0.31-react_pose*(1.45+0.22*wave),0,side*(0.14+0.29*cheer))
			elbows[a].rotation.x = -0.25-0.42*cheer
		else:
			arms[a].rotation = Vector3(-0.16-react_pose,0,side*(0.23-0.39*cheer+0.20*wave*(0.3+cheer)))
			elbows[a].rotation.x = -0.34-cheer*(0.73+wave*0.12)

func _build_dog() -> void:
	dog = D.pivot(stage,Vector3.ZERO)
	dog_body = D.pivot(dog,Vector3.ZERO)
	var coat := D.material("a06438",0.95)
	var light := D.material("d8ac75",0.84)
	var dark := D.material("63412f",0.88)
	var nose := D.material("28201c",0.48)
	D.oval(dog_body,Vector3(0,0.40,-0.029),Vector3(0.35,0.39,0.77),coat)
	D.oval(dog_body,Vector3(0,0.43,0.18),Vector3(0.34,0.39,0.39),light)
	D.oval(dog_body,Vector3(0,0.47,-0.11),Vector3(0.32,0.26,0.48),dark)
	dog_head = D.pivot(dog_body,Vector3(0,0.55,0.32))
	D.oval(dog_head,Vector3(0,0.048,0.02),Vector3(0.295,0.27,0.34),coat)
	D.oval(dog_head,Vector3(0,-0.005,0.19),Vector3(0.209,0.154,0.30),light)
	D.oval(dog_head,Vector3(0,0.016,0.31),Vector3(0.125,0.08,0.064),nose)
	D.oval(dog_body,Vector3(0,0.501,0.252),Vector3(0.286,0.29,0.094),D.material("bf4937",0.55))
	for side in [-1.0,1.0]:
		var ear := D.oval(dog_head,Vector3(side*0.142,0.122,-0.043),Vector3(0.091,0.21,0.103),dark)
		ear.rotation.z = side*0.46
		D.oval(dog_head,Vector3(side*0.111,0.077,0.132),Vector3.ONE*0.047,nose)
		for z in [-0.265,0.21]:
			var leg := D.pivot(dog_body,Vector3(side*0.111,0.31,z))
			dog_legs.append(leg)
			D.oval(leg,Vector3(0,-0.12,0),Vector3(0.10,0.28,0.106),coat)
			D.oval(leg,Vector3(0,-0.238,0.021),Vector3(0.108,0.089,0.156),light)
	dog_tail = D.pivot(dog_body,Vector3(0,0.485,-0.37))
	D.pipe(dog_tail,Vector3.ZERO,Vector3(0,0.15,-0.24),0.058,coat,0.036,9)
	D.pipe(dog_tail,Vector3(0,0.15,-0.24),Vector3(0,0.23,-0.36),0.039,dark,0.018,9)
	dog.hide()

func _send_dog(a: Vector3, b: Vector3) -> void:
	var choice := -INF
	for lane in LANES:
		var score := minf(absf(lane-a.z),absf(lane-b.z))+rng.randf_range(0.0,0.8)
		if score > choice:
			dog_lane = lane
			choice = score
	dog_side = -1 if rng.randf()<0.5 else 1
	dog_progress = 0.0
	dog.show()
	_run_dog()
	dog_entered.emit()

func _run_dog() -> void:
	var extent := Court.COURT_X+1.45
	var cycle := dog_progress*TAU*10.0
	dog.position = Vector3(lerpf(extent,-extent,dog_progress)*dog_side,0,dog_lane+0.46*sin(PI*dog_progress))
	dog.rotation.y = atan2(-dog_side*extent*2.0,0.46*PI*cos(PI*dog_progress))
	dog_body.position.y = 0.023+0.081*absf(sin(cycle))
	dog_head.rotation.x = 0.075*sin(cycle)
	dog_tail.rotation.y = 0.42*sin(cycle*0.64)
	for i in dog_legs.size():
		dog_legs[i].rotation.x = 0.68*sin(cycle+PI*float(i==1 or i==2))
