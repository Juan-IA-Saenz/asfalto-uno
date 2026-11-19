extends Node3D

const Court = preload("res://game/court.gd")
const Athlete = preload("res://game/athlete.gd")
const D = preload("res://game/shapes.gd")
const Rules = preload("res://game/rules.gd")
const Sound = preload("res://game/sound.gd")
const MARKS := [Color("ee9f57"),Color("a9d2fa")]
const KEYS := [[KEY_A,KEY_D,KEY_W,KEY_S,KEY_F,KEY_G],[KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN,KEY_O,KEY_P]]
const CHECK_TIME := 0.92
const SHOT_COOLDOWN := 0.50
const FLOOR := 0.138
const CROSS_TIME := 0.31
const DUNK_TIME := 0.83
const DUNK_RELEASE := 0.70
const BLOCK_KEYS := [KEY_H,KEY_I]
const BLOCK_DURATION := 0.56
const BLOCK_RECOVERY := 1.17
const BLOCK_WINDOW := Vector2(0.06,0.36)

signal ended(winner: int)
signal crowd_reacted(strength: float)
var players: Array[Athlete] = []
var score: Array[int] = [0,0]
var velocity: Array[Vector3] = [Vector3.ZERO,Vector3.ZERO]
var rings: Array[MeshInstance3D] = []
var cooldown: Array[float] = [0.0,0.0]
var prev_key: Array[bool] = [false,false]
var stances: Array[bool] = [false,false]
var timers: Array[float] = [0.0,0.0]
var ball: MeshInstance3D
var ball_shadow: MeshInstance3D
var sfx: Sound
var rng := RandomNumberGenerator.new()
var court: Court
var camera: Camera3D
var active := false
var paused := false
var cpu := true
var difficulty := 0
var possession := 0
var state := "check"
var clock := Rules.SHOT_CLOCK
var check_left := CHECK_TIME
var meter := 0.0
var charge := false
var dribble_phase := 0.0
var flight_time := 0.0
var flight_duration := 0.0
var release := Vector3.ZERO
var destination := Vector3.ZERO
var arc_height := 0.0
var made := false
var points := 0
var shot_ended := false
var fallout := Vector3.ZERO
var fallout_time := 0.0
var shot_slot := 0
var celebration := -1
var next_player := 0
var commentary := ""
var thought := 0.0
var ai_shooting := false
var ai_charge := 0.0
var ai_target := Vector3.ZERO
var ai_side := 1
var ai_steal := 0.0
var ai_guard_target := Vector3.ZERO
var ai_reaction := 0.0
var prev_bounce := -1
var match_over := -1
var cross_left := 0.0
var cross_direction := Vector3.ZERO
var cross_cooldown := 0.0
var cross_hand := 1
var manual_hand := -1
var prev_cross := false
var prev_dunk := false
var dunk_origin := Vector3.ZERO
var dunk_landing := Vector3.ZERO
var dunk_entry := Vector3.ZERO
var dunk_is_live := false
var introductions: Array[bool] = [false,false]
var block_slot := -1
var block_age := BLOCK_DURATION
var block_held: Array[bool] = [false,false]

func setup(world: Court, lens: Camera3D, sound: Sound) -> void:
	court = world
	camera = lens
	sfx = sound
	rng.randomize()
	for i in 2:
		var player := Athlete.new()
		add_child(player)
		players.append(player)
		var mat := D.material(MARKS[i],0.52,0.0,0.38)
		var indicator := D.torus(self,Vector3.ZERO,0.73,0.034,mat)
		indicator.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		rings.append(indicator)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://art/ball.gdshader")
	ball = D.oval(self,Vector3.ZERO,Vector3.ONE*(FLOOR*2.0),mat)
	var shadow_material := StandardMaterial3D.new()
	shadow_material.albedo_color = Color(0.042,0.047,0.048,0.30)
	shadow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ball_shadow = D.oval(self,Vector3.ZERO,Vector3(0.26,0.009,0.24),shadow_material)
	ball_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func roster(profiles: Array[Dictionary]) -> void:
	for i in 2:
		players[i].build(profiles[i],i)

func start(vs_cpu: bool, tier := 0) -> void:
	cpu = vs_cpu
	difficulty = clampi(tier,0,Rules.CPU_TIERS.size()-1)
	active = true
	paused = false
	score = [0,0]
	match_over = -1
	celebration = -1
	introductions = [false,false]
	for i in 2:
		players[i].show()
		rings[i].show()
	ball.show()
	ball_shadow.show()
	_check(0,"Primera posesión")

func _check(new_owner: int, note: String) -> void:
	possession = new_owner
	state = "check"
	check_left = CHECK_TIME
	clock = Rules.SHOT_CLOCK
	commentary = note
	charge = false
	meter = 0.0
	dribble_phase = 0.0
	prev_bounce = -1
	cooldown = [0.0,0.0]
	timers = [0.0,0.0]
	velocity = [Vector3.ZERO,Vector3.ZERO]
	prev_key = [false,false]
	stances = [false,false]
	celebration = -1
	block_slot = -1
	block_age = BLOCK_RECOVERY
	for i in 2:
		block_held[i] = Input.is_physical_key_pressed(BLOCK_KEYS[i])
	_reset_moves()
	_ai_reset()
	players[new_owner].position = Vector3(0.20,0,2.96)
	players[1-new_owner].position = Vector3(-0.15,0,1.29)
	ball.position = Vector3(0,0.92,2.70)
	ball.rotation = Vector3.ZERO

func _reset_moves() -> void:
	cross_left = 0.0
	cross_cooldown = 0.0
	cross_direction = Vector3.ZERO
	manual_hand = -1
	prev_cross = _cross_pressed()
	prev_dunk = Input.is_physical_key_pressed(KEY_SPACE)
	dunk_is_live = false

func _cross_pressed() -> bool:
	return Input.is_physical_key_pressed(KEY_PERIOD) or Input.is_physical_key_pressed(KEY_KP_PERIOD)

func charge_time(i: int) -> float:
	return Rules.CPU_TIERS[difficulty].charge_time if cpu and i == 0 else Rules.CHARGE_TIME

func green_width(i: int) -> float:
	var bonus: float = Rules.CPU_TIERS[difficulty].green_bonus if cpu and i == 0 else 0.0
	return Rules.green_width(players[i].profile.shot)+bonus

func can_dunk(i: int) -> bool:
	if state != "live" or i != possession or (cpu and i == 1) or charge or cross_left > 0.0:
		return false
	var p := players[i]
	return p.position.z >= Court.HOOP.z-0.11 and _range(i) <= Rules.dunk_range(p.profile.height,p.profile.muscle)

func _block_defender() -> int:
	return 1-shot_slot if state == "flight" or state == "dunk" else 1-possession

func can_block(i: int) -> bool:
	if paused or (cpu and i == 1) or i != _block_defender() or block_age < BLOCK_RECOVERY:
		return false
	return state == "live" or (state == "flight" and _early_shot()) or (state == "dunk" and flight_time < DUNK_TIME*DUNK_RELEASE)

func block_hint() -> String:
	var defender := _block_defender()
	if not can_block(defender) or (state == "live" and not charge):
		return ""
	var opponent := players[1-defender]
	if players[defender].position.distance_to(opponent.position) > 1.80:
		return ""
	return "[ %s ] TAPÓN" % OS.get_keycode_string(BLOCK_KEYS[defender])

func _update_block(dt: float) -> void:
	block_age = minf(BLOCK_RECOVERY,block_age+dt)
	for i in 2:
		var pressed := Input.is_physical_key_pressed(BLOCK_KEYS[i])
		if pressed and not block_held[i] and can_block(i):
			block_slot = i
			block_age = 0.0
			sfx.play_effect("shoe",-13,1.13)
		block_held[i] = pressed

func _jumping(i: int) -> bool:
	return block_slot == i and block_age < BLOCK_DURATION

func _pose_defender(i: int, dt: float, fallback: String, speed := 0.0) -> void:
	var p := players[i]
	if _jumping(i):
		var focus := ball.position-p.position
		if state == "flight" or state == "dunk":
			p.turn(atan2(focus.x,focus.z),dt*1.6)
		p.pose(dt,0,"block",block_age/BLOCK_DURATION)
	else:
		p.pose(dt,speed,fallback)

func _early_shot() -> bool:
	var ascending := (destination.y-release.y+arc_height*4.0*(1.0-2.0*flight_time/flight_duration)) > 0.0
	return ascending and flight_time <= 0.42 and flight_time/flight_duration <= 0.45

func _try_block() -> bool:
	var i := 1-shot_slot
	if block_slot != i or block_age < BLOCK_WINDOW.x or block_age > BLOCK_WINDOW.y:
		return false
	var p := players[i]
	var offset := ball.position-p.position
	var reach: float = 0.79 + p.profile.defense*0.0035 + (p.profile.height-1.85)*0.32
	var jump := Rules.block_lift(block_age/BLOCK_DURATION)
	var ceiling: float = p.profile.height+0.34+jump
	var horizontal := Vector2(offset.x,offset.z)
	if horizontal.length() > reach or offset.y < p.profile.height-0.38 or offset.y > ceiling:
		return false
	var push := Vector3(horizontal.x,0,horizontal.y).normalized()
	if push.is_zero_approx():
		push = (players[shot_slot].position-p.position).normalized()
	made = false
	shot_ended = true
	state = "dead"
	check_left = 0.79
	fallout_time = 0.0
	fallout = push*4.1 + Vector3.UP*0.65
	next_player = i
	commentary = "¡Tapón! · "+p.profile.name
	sfx.play_effect("block",-7)
	crowd_reacted.emit(0.95)
	return true

func _ai_reset() -> void:
	thought = 0.0
	ai_shooting = false
	ai_charge = 0.0
	ai_side = -1 if rng.randf()<0.5 else 1
	ai_target = Vector3(ai_side*rng.randf_range(2.0,5.3),0,rng.randf_range(-4.6,-2.6))
	var tuning: Dictionary = Rules.CPU_TIERS[difficulty]
	ai_steal = rng.randf_range(tuning.steal.x,tuning.steal.y)
	ai_reaction = float(tuning.reaction)*0.5
	ai_guard_target = Vector3(-0.15,0,1.29)

func _human(i: int) -> Array:
	var k: Array = KEYS[i]
	var direction := Vector2(
		float(Input.is_physical_key_pressed(k[1]))-float(Input.is_physical_key_pressed(k[0])),
		float(Input.is_physical_key_pressed(k[3]))-float(Input.is_physical_key_pressed(k[2]))
	).normalized()
	var right := camera.global_transform.basis.x
	right.y = 0
	var down := right.cross(Vector3.UP)
	return [right.normalized()*direction.x+down.normalized()*direction.y,Input.is_physical_key_pressed(k[4]),Input.is_physical_key_pressed(k[5])]

func _opponent(dt: float) -> Array:
	var tuning: Dictionary = Rules.CPU_TIERS[difficulty]
	var own := players[1]
	var other := players[0]
	var distance := own.position.distance_to(other.position)
	thought += dt
	ai_steal -= dt
	var want := Vector3.ZERO
	var action := false
	var guard := false
	if possession == 1:
		var moved := own.position.distance_to(ai_target)
		var range_to_rim := _range(1)
		if not ai_shooting and (moved < 0.58 or clock < 2.5 or (thought>2.0 and range_to_rim<2.8 and distance>0.9)):
			ai_shooting = true
			ai_charge = clampf(rng.randfn(tuning.aim,tuning.spread),0.22,0.96)
		if ai_shooting:
			action = not charge or meter < ai_charge
		else:
			want = (ai_target-own.position).normalized()
			if distance < 1.13:
				want = (want+want.cross(Vector3.UP)*ai_side*0.77).normalized()
			guard = moved > 2.0 and difficulty > 0
	else:
		ai_reaction -= dt
		if ai_reaction <= 0.0:
			ai_reaction = tuning.reaction
			var to_rim := (Vector3(Court.HOOP.x,0,Court.HOOP.z)-other.position).normalized()
			ai_guard_target = other.position+to_rim*float(tuning.gap)
		var direction := ai_guard_target-own.position
		want = direction.normalized()*clampf(direction.length()*1.58,0.0,1.0)
		guard = distance < (1.2 if difficulty == 0 else 1.85)
		if ai_steal <= 0.0:
			ai_steal = rng.randf_range(tuning.steal.x,tuning.steal.y)
			action = distance < 1.27 and (not charge or rng.randf()<0.46)
	return [want,action,guard]

func _physics_process(dt: float) -> void:
	if not active or paused:
		return
	_update_block(dt)
	match state:
		"check":
			check_left -= dt
			for i in 2:
				var delta := players[1-i].position-players[i].position
				players[i].turn(atan2(delta.x,delta.z),dt)
				players[i].pose(dt,0,"idle")
			if check_left <= 0:
				state = "live"
				commentary = ""
				if not introductions[possession]:
					introductions[possession] = true
					sfx.speak(possession,"start")
		"live":
			_live(dt)
		"flight":
			_flying(dt)
		"dunk":
			_dunking(dt)
		"dead":
			check_left -= dt
			_fall(dt)
			if check_left <= 0:
				if match_over >= 0:
					state = "finished"
					ended.emit(match_over)
				else:
					_check(next_player,"Cambio de posesión")
	for i in 2:
		rings[i].global_position = players[i].global_position + Vector3.UP*0.031
		rings[i].visible = (not cpu or i == 0 or possession == i) and state != "finished"
	ball_shadow.position = Vector3(ball.position.x,0.026,ball.position.z)

func _live(dt: float) -> void:
	clock = maxf(0.0,clock-dt)
	if clock <= 0:
		sfx.play_effect("horn",-11.0)
		_check(1-possession,"Se agotó el reloj")
		return
	var owner := possession
	var visitor := 1-owner
	var inputs := [_human(0),_opponent(dt) if cpu else _human(1)]
	var cross_button := _cross_pressed()
	var dunk_button := Input.is_physical_key_pressed(KEY_SPACE)
	var local_owner := not cpu or owner == 0
	cross_cooldown = maxf(0.0,cross_cooldown-dt)
	cross_left = maxf(0.0,cross_left-dt)
	if local_owner and dunk_button and not prev_dunk:
		prev_dunk = true
		if can_dunk(owner):
			_start_dunk(owner)
			return
		if not charge and cross_left <= 0.0:
			commentary = "Acércate al aro para clavar"
	if local_owner and cross_button and not prev_cross and not charge and cross_cooldown <= 0.0:
		_start_cross(owner,inputs[owner][0])
	prev_cross = cross_button
	prev_dunk = dunk_button
	for i in 2:
		timers[i] = maxf(0.0,timers[i]-dt)
		cooldown[i] = maxf(0.0,cooldown[i]-dt)
		var action: Array = inputs[i]
		var profile := players[i].profile
		var running: bool = action[2]
		stances[i] = running and i != owner
		var pace := Rules.pace(profile.dribble,profile.weight,i==owner,running)
		if cpu and i == 1:
			pace *= float(Rules.CPU_TIERS[difficulty].pace)
		if stances[i]:
			pace *= lerpf(0.67,0.87,profile.defense/100.0)
		if charge and owner == i:
			pace *= 0.29
		var target: Vector3 = action[0] * pace
		if _jumping(i):
			target = Vector3.ZERO
		if i == owner and cross_left > 0.0:
			target = cross_direction*(5.15+float(profile.dribble)*0.021)
		velocity[i] = velocity[i].move_toward(target,dt*(16.0+float(profile.dribble)*0.09))
		players[i].position = _bounded(players[i].position + velocity[i]*dt)
	_separate()
	for i in 2:
		var moving := velocity[i].length()
		var direction := velocity[i]
		if i != owner and (stances[i] or moving < 0.3 or _jumping(i)):
			direction = players[owner].position-players[i].position
		elif i == owner and (charge or moving < 0.3 or inputs[owner][1]):
			direction = Vector3(Court.HOOP.x,0,Court.HOOP.z)-players[i].position
		players[i].turn(atan2(direction.x,direction.z),dt)
	var defend: bool = inputs[visitor][1]
	if defend and not prev_key[visitor] and cooldown[visitor] <= 0 and not _jumping(visitor):
		cooldown[visitor] = 0.82
		timers[visitor] = 0.28
		if _steal(visitor,owner):
			return
	var held: bool = inputs[owner][1]
	if held and not prev_key[owner] and cooldown[owner] <= 0 and cross_left <= 0.0:
		charge = true
		meter = 0.0
	if charge:
		if held:
			meter = minf(1.0,meter+dt/charge_time(owner))
		if not held or meter >= 1.0:
			_shoot(owner)
			prev_key[owner] = held
			prev_key[visitor] = defend
			return
	prev_key[owner] = held
	prev_key[visitor] = defend
	dribble_phase += dt * (2.40+players[owner].profile.dribble*0.010 + velocity[owner].length()*0.15)
	if cross_left > 0.0:
		players[owner].pose(dt,velocity[owner].length(),"cross",1.0-cross_left/CROSS_TIME,cross_hand)
	else:
		players[owner].pose(dt,velocity[owner].length(),"aim" if charge else "carry",meter if charge else dribble_phase,manual_hand)
	_pose_defender(visitor,dt,"steal" if timers[visitor]>0 else ("guard" if stances[visitor] else "idle"),velocity[visitor].length())
	_carry_ball(owner,dt)

func _bounded(p: Vector3) -> Vector3:
	return Vector3(clampf(p.x,-Court.COURT_X+0.28,Court.COURT_X-0.28),0.0,clampf(p.z,Court.BASELINE+0.38,Court.HALFLINE-0.26))

func _start_cross(owner: int, input_direction: Vector3) -> void:
	var p := players[owner]
	var defender := players[1-owner]
	var lead := input_direction
	if lead.length_squared() < 0.01:
		lead = velocity[owner].normalized()
	if lead.length_squared() < 0.01:
		lead = (Vector3(Court.HOOP.x,0,Court.HOOP.z)-p.position).normalized()
	if lead.length_squared() < 0.01:
		lead = Vector3.FORWARD
	var best_score := -INF
	for side in [-1.0,1.0]:
		var candidate := lead.rotated(Vector3.UP,side*1.14)
		var landing := _bounded(p.position+candidate*1.42)
		var value := landing.distance_to(defender.position)+0.6*landing.distance_to(p.position)
		if (side > 0.0) == (p.dominant == 1):
			value += 0.08
		if value > best_score:
			best_score = value
			cross_direction = candidate
	cross_hand = 1-p.dominant
	manual_hand = cross_hand
	cross_left = CROSS_TIME
	cross_cooldown = 0.81
	velocity[owner] = cross_direction*maxf(3.9,velocity[owner].length()*0.94)
	dribble_phase = floorf(dribble_phase)
	commentary = "Cambio de mano"
	sfx.play_effect("shoe",-12)
	sfx.speak(owner,"cross")

func _separate() -> void:
	var delta := players[0].position-players[1].position
	var min_gap: float = 0.56 + (players[0].profile.weight+players[1].profile.weight)*0.00072
	var gap := delta.length()
	if gap >= min_gap:
		return
	var normal := Vector3.RIGHT if gap < 0.001 else delta/gap
	var push := normal*(min_gap-gap)*0.52
	players[0].position = _bounded(players[0].position+push)
	players[1].position = _bounded(players[1].position-push)

func _steal(defender: int, owner: int) -> bool:
	var delta := players[owner].position-players[defender].position
	var gap := delta.length()
	var facing := delta.normalized().dot(players[defender].global_basis.z)
	var reach: float = 1.19 + (players[defender].profile.height-1.85)*0.36
	var crossing := cross_left > 0.0
	if gap > reach or facing < -0.05 or (crossing and gap > 0.83):
		sfx.play_effect("shoe",-17)
		return false
	var probability := Rules.steal_probability(players[defender].profile.defense,players[owner].profile.dribble,gap,facing)
	if crossing:
		probability *= 0.56
	if cpu and defender == 1:
		probability *= float(Rules.CPU_TIERS[difficulty].reach)
	if rng.randf() >= probability:
		return false
	sfx.play_effect("tick",-12)
	possession = defender
	charge = false
	meter = 0.0
	clock = Rules.SHOT_CLOCK
	dribble_phase = 0.0
	cooldown[defender] = SHOT_COOLDOWN
	prev_key = [true,true]
	_reset_moves()
	_ai_reset()
	commentary = players[defender].profile.name+" roba el balón"
	sfx.speak(defender,"steal")
	crowd_reacted.emit(0.52)
	return true

func _carry_ball(owner: int, dt: float) -> void:
	var p := players[owner]
	if cross_left > 0.0:
		var progress := 1.0-cross_left/CROSS_TIME
		var blend := smoothstep(0.0,1.0,progress)
		var path := p.ball_hand(1-cross_hand).lerp(p.ball_hand(cross_hand),blend)
		path.y = lerpf(FLOOR,path.y,absf(2.0*progress-1.0))
		ball.position = path+p.global_basis.z*0.14
		ball.rotate_x(dt*16.0)
		return
	if charge:
		ball.position = p.ball_hand(1).lerp(p.ball_hand(0),0.36)+p.global_basis.z*0.081
		return
	var grip := p.ball_hand(p.dominant)
	var f := fposmod(dribble_phase,1.0)
	var travel := absf(2.0*f-1.0)
	ball.position = Vector3(grip.x,lerpf(FLOOR,grip.y+0.03,pow(travel,0.73)),grip.z)+p.global_basis.z*(0.09+0.16*(1-travel))
	ball.rotate_x(dt*11.4)
	ball.rotate_z(dt*(2.1 if p.dominant == 1 else -2.1))
	var idx := int(dribble_phase+0.5)
	if f >= 0.46 and f < 0.65 and idx != prev_bounce:
		prev_bounce = idx
		sfx.play_effect("bounce",-14.0,1.02+0.08*cos(dribble_phase))

func _range(i: int) -> float:
	var delta := players[i].position-Court.HOOP
	return Vector2(delta.x,delta.z).length()

func _start_dunk(owner: int) -> void:
	var p := players[owner]
	var defender := players[1-owner]
	var front := Vector3(Court.HOOP.x,0,Court.HOOP.z+0.46)
	var direction := (front-p.position).normalized()
	var defender_delta := defender.position-p.position
	var along := direction.dot(defender_delta)
	var dist_to_path := (defender_delta-direction*along).length()
	var between := along > 0.14 and along < p.position.distance_to(front)+0.24
	var block := 0.0
	if between and dist_to_path < 0.72 and defender_delta.length() < 1.26:
		block = (0.28 if stances[1-owner] else 0.11)+float(defender.profile.defense)*0.0024+(float(defender.profile.height)-float(p.profile.height))*0.25-float(p.profile.muscle)*0.0017
		if cpu and owner == 0:
			block *= float(Rules.CPU_TIERS[difficulty].contest)
	made = block <= 0.0 or rng.randf() >= clampf(block,0.045,0.60)
	state = "dunk"
	dunk_is_live = true
	dunk_origin = p.position
	dunk_landing = front+Vector3(clampf(p.position.x*0.26,-0.43,0.43),0,0.05)
	dunk_entry = ball.position
	points = 1
	shot_slot = owner
	flight_time = 0.0
	shot_ended = false
	release = p.position
	destination = Court.HOOP
	velocity = [Vector3.ZERO,Vector3.ZERO]
	commentary = "Clavada"
	sfx.play_effect("shoe",-11,0.90)

func _dunking(dt: float) -> void:
	flight_time += dt
	var t := clampf(flight_time/DUNK_TIME,0.0,1.0)
	var p := players[shot_slot]
	var approach := smoothstep(0.0,0.71,t)
	p.position = dunk_origin.lerp(dunk_landing,approach)
	var rim := Vector3(Court.HOOP.x,0,Court.HOOP.z)-p.position
	p.turn(atan2(rim.x,rim.z),dt*1.7)
	p.pose(dt,0,"dunk",t)
	var contact := DUNK_RELEASE
	if t < contact:
		var hand := p.ball_hand(1)+p.global_basis.z*0.06
		var locate := dunk_entry.lerp(hand,smoothstep(0.0,0.23,t))
		ball.position = locate.lerp(Court.HOOP+Vector3(0,0.12,0),smoothstep(0.54,contact,t))
	else:
		var exit := Court.HOOP+ (Vector3(0,-0.74,0.035) if made else Vector3(0.52,0.20,0.29))
		ball.position = (Court.HOOP+Vector3.UP*0.12).lerp(exit,smoothstep(contact,1.0,t))
	ball.rotate_x(dt*(4.8 if t<contact else 17.0))
	_pose_defender(1-shot_slot,dt,"guard" if t<0.85 else "idle")
	if t >= 0.22 and t < contact and _try_block():
		return
	if t >= 1.0:
		_resolve_shot()

func _shoot(owner: int) -> void:
	var shooter := players[owner]
	var defender := players[1-owner]
	var distance := _range(owner)
	var gap := defender.position.distance_to(shooter.position)
	var rim_direction := (Vector3(Court.HOOP.x,0,Court.HOOP.z)-shooter.position).normalized()
	var defender_direction := (defender.position-shooter.position).normalized()
	var reach: float = (1.54 if stances[1-owner] else 1.22)+(defender.profile.height-shooter.profile.height)*0.74
	var cover: float = clampf((reach-gap)/0.95,0.0,1.0) * (0.58+0.42*maxf(0.0,rim_direction.dot(defender_direction))) * (0.51+defender.profile.defense/170.0)
	var tuning: Dictionary = Rules.CPU_TIERS[difficulty]
	if cpu and owner == 0:
		cover *= float(tuning.contest)
	var chance := Rules.shot_probability(meter,shooter.profile.shot,distance,cover,shooter.profile.shot_style)
	if cpu:
		chance = clampf(chance+float(tuning.cpu_bonus if owner == 1 else tuning.human_bonus),0.045,0.99)
	made = rng.randf() < chance
	dunk_is_live = false
	var scoring_range := absf(shooter.position.x) if shooter.position.z < Court.HOOP.z else distance
	points = Rules.shot_points(scoring_range,Court.ARC)
	shot_slot = owner
	release = shooter.ball_hand(1).lerp(shooter.ball_hand(0),0.28)+rim_direction*0.22+Vector3.UP*0.20
	destination = Court.HOOP+Vector3(0,0,0.044)
	if not made:
		var side := 1 if rng.randf() < 0.5 else -1
		destination += Vector3(side*rng.randf_range(0.25,0.54),rng.randf_range(-0.10,0.13),rng.randf_range(-0.13,0.40))
	flight_time = 0.0
	flight_duration = clampf(0.58+distance*0.080,0.62,1.59)
	arc_height = 0.82+distance*0.085
	charge = false
	state = "flight"
	shot_ended = false
	ball.position = release
	var accuracy := "A tiempo" if absf(meter-Rules.GREEN) <= green_width(owner) else ("Corto" if meter<Rules.GREEN else "Tarde")
	commentary = accuracy + (" · Punteado" if cover>0.37 else " · Libre")
	sfx.play_effect("shoe",-19)

func _flying(dt: float) -> void:
	flight_time += dt
	var t := minf(flight_time/flight_duration,1.0)
	players[shot_slot].pose(dt,0,"shoot",minf(1.0,flight_time/0.53))
	ball.position = Rules.trajectory(release,destination,arc_height,t)
	_pose_defender(1-shot_slot,dt,"guard" if flight_time<0.45 else "idle")
	if _early_shot() and _try_block():
		return
	ball.rotate_x(dt*15.0)
	ball.rotate_z(dt*7.0)
	if t < 1.0 or shot_ended:
		return
	_resolve_shot()

func _resolve_shot() -> void:
	shot_ended = true
	state = "dead"
	check_left = 1.18 if made else 0.76
	fallout_time = 0.0
	fallout = Vector3((destination.x-release.x)*0.16,-2.2,(destination.z-release.z)*0.11) if made else Vector3(signf(destination.x)*1.67,1.08,2.01)
	if dunk_is_live:
		fallout = Vector3(0,-3.6,0.06) if made else Vector3(1.81,0.69,1.83)
	next_player = 1-shot_slot
	if made:
		score[shot_slot] += points
		celebration = shot_slot
		match_over = Rules.winner(score)
		commentary = "+%d · %s%s" % [points,players[shot_slot].profile.name," clava el balón" if dunk_is_live else ""]
		sfx.play_effect("net",-6)
		sfx.play_effect("tick",-15,1.37)
		if match_over < 0:
			sfx.speak(shot_slot,"dunk" if dunk_is_live else "score")
		if dunk_is_live:
			sfx.play_effect("rim",-8,0.85)
		crowd_reacted.emit(1.0 if dunk_is_live or match_over>=0 else (0.86 if points==2 else 0.72))
	else:
		commentary = "Clavada tapada" if dunk_is_live else "No entra"
		sfx.play_effect("rim",-8)
		sfx.speak(shot_slot,"miss")

func _fall(dt: float) -> void:
	fallout_time += dt
	fallout.y -= 9.8*dt
	ball.position += fallout*dt
	if ball.position.y < FLOOR:
		ball.position.y = FLOOR
		if fallout.y < -1.1:
			sfx.play_effect("bounce",-14)
		fallout.y *= -0.46
		fallout.x *= 0.76
		fallout.z *= 0.76
	ball.rotate_x(dt*12.0)
	for i in 2:
		if _jumping(i):
			_pose_defender(i,dt,"idle")
		elif celebration == i:
			players[i].pose(dt,0,"celebrate",clampf(fallout_time/Athlete.DUR_CELEBRATE,0.0,1.0))
		elif dunk_is_live and i == shot_slot and flight_time < DUNK_TIME:
			flight_time = minf(DUNK_TIME,flight_time+dt)
			players[i].pose(dt,0,"dunk",flight_time/DUNK_TIME)
		else:
			players[i].pose(dt,0,"idle")
