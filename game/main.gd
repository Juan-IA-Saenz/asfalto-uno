extends Node3D

const Court = preload("res://game/court.gd")
const Athlete = preload("res://game/athlete.gd")
const Duel = preload("res://game/duel.gd")
const UI = preload("res://game/interface.gd")
const Sound = preload("res://game/sound.gd")
const Stands = preload("res://game/stands.gd")
const Rules = preload("res://game/rules.gd")
const D = preload("res://game/shapes.gd")
const SAVE := "user://vestuario.json"
const MENU_CAM := Vector3(1.15,1.82,8.34)
const MENU_AIM := Vector3(-0.79,1.34,-5.58)
const EDIT_CAM := Vector3(0.20,1.52,6.63)
const EDIT_AIM := Vector3(-1.30,0.97,-3.80)
const AWARD_CAM := Vector3(-0.43,1.60,6.00)
const AWARD_AIM := Vector3(-0.43,1.17,1.76)

var court: Court
var camera: Camera3D
var duel: Duel
var ui: UI
var sound: Sound
var stands: Stands
var profiles: Array[Dictionary]
var city := 0
var edit_slot := 0
var versus_cpu := true
var difficulty := 0
var scene := "menu"
var lens_target := MENU_AIM
var time := 0.0
var paint_pending := false
var rebuild := 0.0
var save_delay := -1.0
var preview := "idle"
var preview_time := 0.0
var angle := -0.16
var settings_path := SAVE
var award_ring: Node3D
var award_slot := 0
var award_time := 0.0

func _ready() -> void:
	DisplayServer.window_set_min_size(Vector2i(920,575))
	_load_settings()
	court = Court.new()
	add_child(court)
	court.build(city)
	camera = Camera3D.new()
	add_child(camera)
	camera.current = true
	camera.far = 220.0
	camera.near = 0.08
	sound = Sound.new()
	add_child(sound)
	stands = Stands.new()
	add_child(stands)
	stands.dog_entered.connect(func(): sound.play_effect("bark",-15))
	duel = Duel.new()
	add_child(duel)
	duel.setup(court,camera,sound)
	duel.ended.connect(_finish_match)
	duel.crowd_reacted.connect(_crowd_reacted)
	ui = UI.new()
	add_child(ui)
	ui.setup(self)
	open_menu()

func _load_settings() -> void:
	profiles = [Athlete.preset(0),Athlete.preset(1)]
	if not FileAccess.file_exists(settings_path):
		return
	var saved = JSON.parse_string(FileAccess.get_file_as_string(settings_path))
	if not saved is Dictionary:
		return
	if saved.get("profiles") is Array:
		for i in mini(2,saved.profiles.size()):
			if saved.profiles[i] is Dictionary:
				profiles[i] = Athlete.clean(saved.profiles[i],i)
	if saved.get("city") is float or saved.get("city") is int:
		city = clampi(int(saved.city),0,Court.CITIES.size()-1)
	if saved.get("cpu") is bool:
		versus_cpu = saved.cpu
	if saved.get("difficulty") is float or saved.get("difficulty") is int:
		difficulty = clampi(int(saved.difficulty),0,Rules.CPU_TIERS.size()-1)

func _save_settings() -> void:
	var file := FileAccess.open(settings_path,FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"profiles":profiles,"city":city,"cpu":versus_cpu,"difficulty":difficulty}))
	save_delay = -1.0

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and save_delay >= 0:
		_save_settings()
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(duel) and scene == "match" and not duel.paused and duel.match_over < 0:
		toggle_pause()

func _lens(p: Vector3, aim: Vector3, focal: float) -> void:
	camera.position = p
	lens_target = aim
	camera.look_at(aim,Vector3.UP)
	camera.fov = focal

func open_menu() -> void:
	_leave_award()
	stands.stop()
	sound.reset_match_audio()
	if save_delay >= 0:
		_save_settings()
	scene = "menu"
	duel.active = false
	duel.paused = false
	duel.roster(profiles)
	_lens(MENU_CAM,MENU_AIM,44.0)
	for i in 2:
		var p := duel.players[i]
		p.show()
		p.position = [Vector3(2.07,0,2.53),Vector3(0.80,0,0.95)][i]
		p.face = [-0.24,0.46][i]
		p.rotation.y = p.face
		p.pose(0.0,0.0,"carry" if i == 0 else "idle",0.13)
		duel.rings[i].hide()
	duel.ball.show()
	duel.ball_shadow.hide()
	ui.show_menu(city,versus_cpu)

func select_city(index: int) -> void:
	if city != index:
		city = index
		court.build(city)
		_save_settings()
		ui.show_menu(city,versus_cpu)
		sound.play_effect("tick",-17)

func select_mode(cpu: bool) -> void:
	if versus_cpu != cpu:
		versus_cpu = cpu
		_save_settings()
		ui.show_menu(city,versus_cpu)

func select_difficulty(tier: int) -> void:
	if tier == difficulty:
		return
	difficulty = clampi(tier,0,Rules.CPU_TIERS.size()-1)
	_save_settings()
	ui.show_menu(city,versus_cpu)
	sound.play_effect("tick",-17)

func open_editor() -> void:
	scene = "editor"
	duel.active = false
	duel.ball.hide()
	duel.ball_shadow.hide()
	_lens(EDIT_CAM,EDIT_AIM,37.0)
	select_player(edit_slot)

func select_player(slot: int) -> void:
	if scene != "editor":
		return
	paint_pending = false
	edit_slot = slot
	angle = -0.16
	preview = "idle"
	preview_time = 0.0
	for i in 2:
		duel.players[i].visible = i == slot
		duel.rings[i].hide()
	var active := duel.players[slot]
	active.position = Vector3(0.74,0,1.91)
	active.face = angle
	active.rotation.y = angle
	active.build(profiles[slot],slot)
	ui.show_editor(slot,profiles[slot])

func update_profile(key: String, value: Variant) -> void:
	if scene != "editor":
		return
	if key == "name" and str(value).strip_edges().is_empty():
		return
	if Rules.APTITUDES.has(key):
		if not (value is int or value is float) or not is_finite(float(value)):
			return
		set_aptitude_points(key,Rules.aptitude_points(key,value))
		return
	_apply_profile_value(key,value)

func set_aptitude_points(key: String, points: int) -> void:
	if scene != "editor" or not Rules.APTITUDES.has(key):
		return
	var profile := profiles[edit_slot]
	var available := Rules.POINT_BUDGET-Rules.spent_points(profile)+Rules.aptitude_points(key,profile[key])
	_apply_profile_value(key,Rules.aptitude_value(key,clampi(points,0,mini(100,available))))

func _apply_profile_value(key: String, value: Variant) -> void:
	if profiles[edit_slot][key] == value:
		ui.update_editor(profiles[edit_slot])
		return
	profiles[edit_slot][key] = value
	ui.update_editor(profiles[edit_slot])
	if key not in ["name","shot","defense","dribble"]:
		paint_pending = true
		rebuild = 0.064
	save_delay = 0.36

func reset_profile() -> void:
	profiles[edit_slot] = Athlete.preset(edit_slot)
	_save_settings()
	select_player(edit_slot)

func preview_move(move: String) -> void:
	if scene != "editor":
		return
	preview = move
	preview_time = 0.0
	if paint_pending:
		duel.players[edit_slot].build(profiles[edit_slot],edit_slot)
		paint_pending = false

func start_match() -> void:
	_leave_award()
	sound.reset_match_audio()
	if save_delay >= 0:
		_save_settings()
	scene = "match"
	duel.roster(profiles)
	_lens(Vector3(8.45,7.25,10.13),Vector3(0,0.56,-1.47),52.0)
	duel.start(versus_cpu,difficulty)
	stands.start(city)
	sound.play_street(city)
	ui.show_match(profiles,city,versus_cpu)

func _crowd_reacted(strength: float) -> void:
	stands.react(strength)
	sound.cheer(strength)

func toggle_pause() -> void:
	if scene != "match" or duel.match_over >= 0:
		return
	duel.paused = not duel.paused
	sound.pause_match_audio(duel.paused)
	if duel.paused:
		ui.show_pause()
	else:
		ui.close_overlay()

func _finish_match(winner: int) -> void:
	if scene != "match":
		return
	scene = "award"
	stands.stop()
	duel.active = false
	duel.ball.hide()
	duel.ball_shadow.hide()
	for marker in duel.rings:
		marker.hide()
	award_slot = winner
	award_time = 0.0
	duel.players[1-winner].position = Vector3(-0.05,0,1.74)
	duel.players[winner].position = Vector3(0.83,0,1.89)
	_lens(AWARD_CAM,AWARD_AIM,34.0)
	_build_award()
	sound.play_award(winner)
	ui.show_award(profiles[winner].name,duel.score,city)
	_animate_award(0.0)

func _build_award() -> void:
	award_ring = Node3D.new()
	award_ring.name = "AnilloDelCircuito"
	add_child(award_ring)
	var gold := D.material("f8c05e",0.30,0.68,0.38)
	var bright := D.material("ffe2a0",0.19,0.50,0.45)
	var stone := D.material("d6fff7",0.15,0.38,0.50)
	var band := D.torus(award_ring,Vector3.ZERO,0.273,0.079,gold)
	band.scale.y = 1.38
	for edge in [-1,1]:
		D.torus(award_ring,Vector3.UP*edge*0.041,0.282,0.021,bright)
	D.oval(award_ring,Vector3(0,0,-0.135),Vector3(0.216,0.143,0.137),gold)
	var jewel := D.box(award_ring,Vector3(0,0,-0.207),Vector3(0.086,0.086,0.041),stone)
	jewel.rotation.z = PI/4.0
	for offset in [-2,-1,1,2]:
		var stud := Vector3(offset*0.038,0,-0.191+absf(offset)*0.011)
		D.oval(award_ring,stud,Vector3.ONE*0.030,bright)

func _animate_award(dt: float) -> void:
	award_time += dt
	var champion := duel.players[award_slot]
	var rival := duel.players[1-award_slot]
	var give := smoothstep(0.55,1.50,award_time)
	var handoff := smoothstep(1.08,1.87,award_time)
	var salute := smoothstep(1.91,2.98,award_time)
	champion.face = lerpf(-0.32,0.02,salute)
	rival.face = 0.55-0.25*salute
	champion.rotation.y = champion.face
	rival.rotation.y = rival.face
	champion.pose(dt,0,"receive",give+salute,0)
	rival.pose(dt,0,"present",give*(1.0-salute),1)
	var ring_center := rival.ball_hand(1).lerp(champion.ball_hand(0),handoff)
	ring_center += Vector3(0,0.105+0.25*sin(PI*handoff),0.105)
	award_ring.position = ring_center
	award_ring.rotation = Vector3(1.25+0.30*salute,0.22*sin(award_time*1.65),-0.26+0.36*handoff)
	var closer := smoothstep(0.0,4.3,award_time)
	_lens(AWARD_CAM+Vector3(0.22,0.06,-0.42)*closer,AWARD_AIM+Vector3(0.13,0.04,0)*closer,34.0)
	ui.sync_award(handoff >= 1.0)

func _leave_award() -> void:
	if is_instance_valid(award_ring):
		award_ring.hide()
		award_ring.queue_free()
		award_ring = null

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		match scene:
			"editor", "award": open_menu()
			"match": toggle_pause()
		get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	if scene == "editor" and event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) and event.position.x > 540 and event.position.y > 146:
		angle -= event.relative.x*0.011

func _process(dt: float) -> void:
	time += dt
	if save_delay >= 0:
		save_delay -= dt
		if save_delay < 0:
			_save_settings()
	match scene:
		"menu":
			duel.players[0].pose(dt,0.0,"carry",0.17)
			duel.players[1].pose(dt*0.72,0.0,"idle")
			duel.ball.position = duel.players[0].ball_hand(1) + Vector3(0.038,-0.028,0.083)
		"editor":
			var p := duel.players[edit_slot]
			if paint_pending:
				rebuild -= dt
				if rebuild < 0:
					p.build(profiles[edit_slot],edit_slot)
					paint_pending = false
			var focus_owner := get_viewport().gui_get_focus_owner()
			if not (focus_owner is LineEdit or focus_owner is Range or focus_owner is OptionButton):
				if Input.is_physical_key_pressed(KEY_LEFT):
					angle -= dt*1.7
				if Input.is_physical_key_pressed(KEY_RIGHT):
					angle += dt*1.7
			p.turn(angle,dt)
			preview_time += dt
			var duration := 0.76 if preview == "shoot" else (2.8 if preview == "carry" else 0.98)
			if preview_time > duration:
				preview = "idle"
			p.pose(dt,0,preview,preview_time*3.2 if preview == "carry" else clampf(preview_time/duration,0,1))
			duel.ball.visible = preview == "carry" or preview == "shoot"
			if preview == "carry":
				var grip := p.ball_hand(p.dominant)
				var f := absf(fposmod(preview_time*3.2,1.0)*2.0-1.0)
				duel.ball.position = Vector3(grip.x,lerpf(0.143,grip.y,f),grip.z)+p.global_basis.z*0.139
				duel.ball.rotate_x(dt*10.0)
			elif preview == "shoot":
				var aim := p.ball_hand(1)+p.global_basis.z*0.155
				if preview_time > duration/2:
					aim += Vector3.UP*(preview_time-duration/2)*2.4+p.global_basis.z*(preview_time-duration/2)*2.4
				duel.ball.position = aim
		"match":
			ui.sync_match(duel)
			var late := Rules.tension(duel.score)
			sound.set_tension(late)
			if not duel.paused and duel.state != "finished":
				sound.mix_street(dt,late,duel.match_over>=0)
				stands.advance(dt,duel.state=="live",duel.players[0].position,duel.players[1].position)
				var focus := (duel.players[0].position+duel.players[1].position)*0.5
				var push := clampf(focus.z*0.26,-1.45,1.0)
				var slide := clampf(focus.x*0.14,-0.75,0.75)
				var target := Vector3(8.45+slide,7.25,10.13+push)
				var look := Vector3(slide,0.56,-1.47+push)
				camera.position = camera.position.lerp(target,minf(dt*2.7,1.0))
				lens_target = lens_target.lerp(look,minf(dt*2.7,1.0))
				camera.look_at(lens_target,Vector3.UP)
		"award":
			_animate_award(dt)
