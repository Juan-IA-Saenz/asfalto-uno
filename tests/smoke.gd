extends SceneTree

const Main = preload("res://game/main.gd")
const Athlete = preload("res://game/athlete.gd")
const Court = preload("res://game/court.gd")
const Duel = preload("res://game/duel.gd")
const Rules = preload("res://game/rules.gd")
const GameScene = preload("res://game/main.tscn")
var failed := 0
var output := ""
var audible := DisplayServer.get_name() != "headless"

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--render-dir="):
			output = arg.trim_prefix("--render-dir=")
	call_deferred("_run")

func check(condition: bool, description: String) -> void:
	if not condition:
		push_error(description)
		failed += 1
	else:
		print("OK  ",description)

func _capture(name: String) -> void:
	if not output.is_empty():
		await process_frame
		await RenderingServer.frame_post_draw
		var err := root.get_texture().get_image().save_png(output.path_join(name+".png"))
		check(err == OK,"Se guardó la captura "+name)

func _key(key_code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = key_code
	event.physical_keycode = key_code
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _run() -> void:
	var match_score: Array[int] = [11,10]
	check(Rules.winner(match_score)==-1,"11–10 no gana sin ventaja de dos")
	match_score = [11,9]
	check(Rules.winner(match_score)==0,"11–9 sí gana")
	check(not Rules.tension([8,8]) and Rules.tension([9,6]) and Rules.tension([12,12]) and not Rules.tension([11,9]),"La tensión comienza en 9, sigue en el empate y termina al ganar")
	check(Rules.shot_points(4.0,Court.ARC)==1 and Rules.shot_points(6.0,Court.ARC)==2,"El arco separa lanzamientos de uno y dos puntos")
	check(Rules.shot_probability(0.68,78,3,0,0)>Rules.shot_probability(0.32,78,3,0,0),"El tiro a tiempo aumenta el acierto")
	check(Rules.shot_probability(0.68,70,3,0,0)>Rules.shot_probability(0.68,70,3,0.8,0),"La presión defensiva dificulta el tiro")
	check(Rules.shot_probability(0.68,88,3,0,0)>Rules.shot_probability(0.68,22,3,0,0),"El nivel de lanzamiento afecta el acierto")
	check(Rules.pace(85,80,true,true)>Rules.pace(20,80,true,true),"El dribbling afecta la velocidad con pelota")
	check(Rules.steal_probability(90,50,0.75,0.9)>Rules.steal_probability(20,50,0.75,0.9),"La defensa afecta los robos")
	var clean := Athlete.clean({"name":"  A  ","height":2.99,"weight":30,"hair":999,"shot":60},0)
	check(clean.name=="A" and is_equal_approx(clean.height,2.22) and clean.weight==58 and clean.hair==3,"Los valores guardados se validan")
	var app: Main = GameScene.instantiate()
	app.settings_path = "user://prueba-%d-%d.json" % [OS.get_process_id(), Time.get_ticks_usec()]
	root.add_child(app)
	check(app.scene=="menu" and app.duel.players.size()==2,"El circuito arranca con dos jugadores")
	check(app.difficulty==0,"La dificultad inicial es Fácil")
	check(_button(app,"FÁCIL")!=null and _button(app,"NORMAL")!=null and _button(app,"DIFÍCIL")!=null,"El menú presenta las tres dificultades")
	app.select_city(0)
	await _capture("01-circuito")
	app.select_city(1)
	check(app.court.city==1 and app.court.info.city=="Ciudad de México","Ciudad de México cambia el escenario")
	await _capture("02-cdmx")
	app.select_city(2)
	check(app.court.city==2 and app.court.info.city=="Nueva York","Nueva York cambia el escenario")
	await _capture("03-nueva-york")
	app.select_city(0)
	app.open_editor()
	for tab in 3:
		app.ui._switch_tab(tab)
		check(app.ui.edit_tab==tab,"Se creó la pestaña %d del vestuario" % tab)
	app.ui._switch_tab(1)
	await _capture("04-vestuario")
	await _test_budget(app)
	app.update_profile("name","Centella")
	app.update_profile("shot",25)
	app.update_profile("height",2.13)
	app.update_profile("beard",2)
	app.update_profile("shot_style",2)
	app.preview_move("shoot")
	check(app.preview=="shoot" and app.duel.players[0].profile.shot_style==2 and app.duel.players[0].profile.beard==2,"La vista previa usa el aspecto y el estilo elegidos")
	app.select_player(1)
	app.update_profile("name","Atlético")
	app.update_profile("team",5)
	app.select_player(0)
	check(app.profiles[0].name=="Centella" and app.profiles[1].name=="Atlético","Se editan los dos jugadores de forma independiente")
	app.open_menu()
	app._load_settings()
	check(app.profiles[0].name=="Centella" and is_equal_approx(app.profiles[0].height,2.13) and app.profiles[1].team==5,"Las dos fichas se guardan y recuperan")
	app.reset_profile()
	app.select_mode(false)
	check(_button(app,"FÁCIL")==null,"La dificultad no se muestra en el duelo local")
	await _test_cities(app)
	app.start_match()
	var game := app.duel
	game.set_physics_process(false)
	check(not game.cpu and game.active and game.state=="check","Se inicia un partido local")
	game._physics_process(1.0)
	check(game.state=="live","La posesión entra en juego después del saque")
	check(app.sound.dialogue.stream == app.sound.clips[0]["start"],"El primer jugador habla al tomar posesión")
	await _capture("05-partido")
	await _test_dog(app)
	_test_moves(app)
	await _test_blocks(app)
	var location := game.players[0].position
	_key(KEY_D,true)
	for i in 14:
		game._physics_process(1.0/60.0)
	_key(KEY_D,false)
	check(game.players[0].position.distance_to(location)>0.3,"El teclado desplaza al jugador uno")
	location = game.players[1].position
	_key(KEY_LEFT,true)
	for i in 14:
		game._physics_process(1.0/60.0)
	_key(KEY_LEFT,false)
	check(game.players[1].position.distance_to(location)>0.3,"Las flechas desplazan al jugador dos")
	_key(KEY_F,true)
	for i in 43:
		game._physics_process(1.0/60.0)
	check(game.charge and absf(game.meter-Rules.GREEN)<0.03,"Mantener F carga el tiro hasta el verde")
	_key(KEY_F,false)
	game._physics_process(1.0/60.0)
	check(game.state=="flight" and game.shot_slot==0,"Soltar F lanza la pelota")
	game._check(0,"")
	game._physics_process(1.0)
	app.toggle_pause()
	var before := game.clock
	game._physics_process(0.25)
	check(game.paused and game.clock==before and is_instance_valid(app.ui.overlay),"La pausa congela el reloj")
	app.toggle_pause()
	game.clock = 0.001
	game._physics_process(0.02)
	check(game.possession==1 and game.state=="check" and game.clock==Rules.SHOT_CLOCK,"El reloj vencido cambia la posesión")
	game._physics_process(1.0)
	if audible:
		app.sound.dialogue.stop()
		app.sound.speak(1,"start")
		check(app.sound.dialogue.playing and app.sound.dialogue.stream != app.sound.clips[0]["start"],"El otro jugador reproduce una voz distinta")
		await create_timer(0.1).timeout
	game.players[1].position = Vector3(0,0,Court.HOOP.z+2)
	game.meter = Rules.GREEN
	game._shoot(1)
	check(game.state=="flight" and game.points==1,"El tiro inicia vuelo y calcula su valor")
	game.made = true
	game._flying(game.flight_duration+0.01)
	check(game.score[1]==1 and game.state=="dead" and game.celebration==1,"La conversión actualiza el marcador y celebra")
	check(app.stands.cheer>=0.70 and (not audible or app.sound.crowd.playing),"Una canasta anima al público y activa el aplauso")
	game._physics_process(1.3)
	check(game.state=="check" and game.possession==0 and game.score[1]==1,"La posesión cambia tras anotar")
	game._physics_process(1.0)
	game.meter = 0.3
	game._shoot(0)
	game.made = false
	game._flying(game.flight_duration+0.01)
	check(game.score[0]==0 and game.commentary=="No entra","El fallo no suma")
	game._physics_process(0.85)
	game.score = [7,10]
	app._process(0.25)
	check(app.ui.late_game.visible,"El marcador avisa al comenzar el tramo final")
	check(app.sound.street.volume_db<app.sound.STREET_LEVEL,"El rap baja de volumen para dar paso a la tensión")
	if audible:
		check(app.sound.tension.playing and app.sound.tension.stream.loop_mode==AudioStreamWAV.LOOP_FORWARD,"La música de tensión comienza y se repite")
		app.toggle_pause()
		check(app.sound.tension.stream_paused and app.sound.dialogue.stream_paused and app.sound.street.stream_paused and app.sound.crowd.stream_paused,"La pausa detiene la música del duelo, la voz y el público")
		app.toggle_pause()
		check(not app.sound.tension.stream_paused and not app.sound.street.stream_paused,"Continuar reanuda la música")
	await _capture("06-tramo-final")
	game._physics_process(1.0)
	game.players[1].position = Vector3(0,0,Court.HOOP.z+2)
	game.meter = Rules.GREEN
	game._shoot(1)
	game.made = true
	game._flying(game.flight_duration+0.01)
	app._process(0)
	check(not app.sound.tension.playing,"La música de tensión se corta con la canasta de victoria")
	game._physics_process(1.3)
	check(game.state=="finished" and game.match_over==1 and app.scene=="award" and _button(app,"REVANCHA  ↗")!=null,"La victoria muestra la premiación y permite la revancha")
	check(not app.stands.stage.visible and not app.stands.dog.visible and not app.sound.street.playing,"La tribuna, el perro y la música local no interfieren con la premiación")
	if app.scene == "award":
		var initial := app.award_ring.position
		app._animate_award(3.0)
		var winner_hand := game.players[1].ball_hand(0)
		check(initial.distance_to(app.award_ring.position)>0.30 and app.award_ring.position.distance_to(winner_hand)<0.20,"El anillo pasa de la mano del rival a la del ganador")
		check(app.camera.is_position_in_frustum(app.award_ring.global_position) and app.ui.award_note.text.ends_with("ENTREGADO"),"La cámara muestra el anillo y anuncia la entrega")
		check(app.sound.dialogue.stream == app.sound.clips[1]["win"],"La frase de premiación corresponde al ganador")
		if audible:
			check(app.sound.fanfare.playing and app.sound.dialogue.playing,"La premiación activa la fanfarria y la frase del ganador")
		await _capture("07-premiacion")
	var replay := _button(app,"REVANCHA  ↗")
	if replay != null:
		replay.pressed.emit()
	check(app.scene=="match" and game.score==[0,0] and app.award_ring==null and not app.sound.fanfare.playing,"La revancha reinicia marcador, anillo y música")
	app.open_menu()
	check(not app.stands.stage.visible and not app.sound.street.playing,"Volver al menú limpia el ambiente del duelo")
	app.select_mode(true)
	_test_cpu(app)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(app.settings_path))
	app.open_menu()
	await create_timer(0.18).timeout
	app.queue_free()
	await create_timer(0.18).timeout
	print("Resultado: %d fallos" % failed)
	quit(1 if failed else 0)

func _button(app: Main, label: String) -> Button:
	for node in app.ui.root.find_children("*","Button",true,false):
		if node.text == label:
			return node
	return null

func _test_budget(app: Main) -> void:
	var keys := Rules.APTITUDES.keys()
	check(keys.size()==6 and Rules.spent_points(Athlete.preset(0))==400 and Rules.spent_points(Athlete.preset(1))==400,"Las dos fichas iniciales asignan 400 puntos entre seis aptitudes")
	var over: Dictionary = Athlete.preset(0)
	for key in keys:
		over[key] = Rules.aptitude_value(key,100)
	var migrated := Athlete.clean(over,0)
	check(Rules.spent_points(migrated)==400 and Athlete.clean(migrated,0)==migrated,"La normalización de fichas previas deja un total válido y estable")
	app.ui._switch_tab(0)
	var height: HSlider = app.ui.aptitude_controls.height[0]
	var defense: HSlider = app.ui.aptitude_controls.defense[0]
	var initial_height := height.value
	height.value = 100
	check(height.value==initial_height and app.ui.budget_text.text.ends_with("0 LIBRES"),"El deslizador no excede el presupuesto sin puntos libres")
	defense.value -= 15
	check(app.ui.budget_text.text.ends_with("15 LIBRES"),"Bajar Defensa libera puntos en el contador")
	height.value = 100
	check(height.value==initial_height+15 and Rules.spent_points(app.profiles[0])==400,"Subir Altura usa solo los puntos liberados")
	check(Rules.spent_points(app.profiles[1])==400 and app.profiles[1]==Athlete.preset(1),"El presupuesto es independiente para cada ficha")
	app._save_settings()
	app._load_settings()
	check(Rules.aptitude_points("height",app.profiles[0].height)==int(initial_height)+15 and Rules.spent_points(app.profiles[0])==400,"La distribución de puntos se conserva al volver a cargar")
	await _capture("09-presupuesto")
	app.reset_profile()

func _test_cities(app: Main) -> void:
	var lengths: Dictionary = {}
	for city in [1,2,0]:
		app.select_city(city)
		app.start_match()
		if audible:
			await process_frame
			await RenderingServer.frame_post_draw
		var track: AudioStreamWAV = app.sound.street.stream
		var expected := 32.0*60.0/float(app.stands.BEATS[city])
		lengths[track.get_length()] = true
		check(app.stands.city==city and app.stands.stage.visible and app.stands.figures.size()==14 and app.duel.players.size()==2,"Público y raperos no cuentan como jugadores en "+str(Court.CITIES[city].city))
		check(absf(track.get_length()-expected)<0.001 and track.loop_mode==AudioStreamWAV.LOOP_FORWARD and (not audible or app.sound.street.playing),"La pista local se reproduce en bucle en "+str(Court.CITIES[city].city))
		app.open_menu()
	check(lengths.size()==3,"Cada ciudad tiene una pista distinta")

func _test_dog(app: Main) -> void:
	var stands := app.stands
	var game := app.duel
	var a := game.players[0].position
	var b := game.players[1].position
	var rig: Node3D = stands.figures[4].rig
	var pose := rig.rotation
	stands.advance(0.25,false,a,b)
	check(rig.rotation!=pose,"Los espectadores se mueven durante el duelo")
	stands.dog_wait = 0.14
	stands.advance(0.5,false,a,b)
	check(not stands.dog.visible and is_equal_approx(stands.dog_wait,0.14),"El perro no empieza un cruce fuera de juego")
	stands.advance(0.2,true,a,b)
	var entry := stands.dog.position.x
	check(stands.dog.visible and absf(entry)>Court.COURT_X and not stands.dog is CollisionObject3D,"El perro entra desde fuera de la cancha sin colisión")
	app.toggle_pause()
	app._process(0.5)
	check(is_equal_approx(stands.dog.position.x,entry),"La pausa congela el cruce del perro")
	app.toggle_pause()
	stands.advance(1.72,true,a,b)
	check(absf(stands.dog.position.x)<1.0 and game.players[0].position==a and game.players[1].position==b and game.state=="live","El perro atraviesa la cancha sin cambiar el duelo")
	await _capture("10-perro")
	stands.advance(2.1,true,a,b)
	check(not stands.dog.visible and signf(stands.dog.position.x)==-signf(entry) and stands.dog_wait>=26.0,"El perro sale por el lado opuesto y espera antes de volver")

func _test_moves(app: Main) -> void:
	var game := app.duel
	var dt := 1.0/60.0
	_key(KEY_D,true)
	for step in 12:
		game._physics_process(dt)
	var prior := game.velocity[0].normalized()
	var prior_hand := game.players[0].dominant
	_key(KEY_PERIOD,true)
	game._physics_process(dt)
	check(game.cross_left>0 and game.cross_hand!=prior_hand and prior.dot(game.velocity[0].normalized())<0.65,"Punto cambia la mano y desvía el movimiento")
	_key(KEY_D,false)
	for step in 59:
		game._physics_process(dt)
	check(game.cross_left<=0 and game.players[0].dominant!=prior_hand,"Mantener punto no repite el cruce; el bote queda en la mano nueva")
	_key(KEY_PERIOD,false)
	game._check(0,"")
	game._physics_process(1.0)
	_key(KEY_SPACE,true)
	game._physics_process(dt)
	check(game.state=="live" and game.commentary.begins_with("Acércate"),"Espacio fuera de rango no ejecuta la clavada")
	_key(KEY_SPACE,false)
	game._physics_process(dt)
	game.players[0].position = Vector3(0.25,0,Court.HOOP.z+1.40)
	game.players[1].position = Vector3(1.92,0,Court.HOOP.z+2.1)
	app.ui.sync_match(game)
	check(game.can_dunk(0) and not app.ui.move_hint.text.is_empty(),"La HUD indica que la clavada está al alcance")
	_key(KEY_SPACE,true)
	game._physics_process(dt)
	_key(KEY_SPACE,false)
	check(game.state=="dunk" and game.shot_slot==0 and game.made,"Espacio inicia una clavada sin oposición")
	for step in 51:
		game._physics_process(dt)
	check(game.state=="dead" and game.score==[1,0],"La clavada convierte y suma un punto")
	check(is_equal_approx(app.stands.cheer,1.0),"La clavada provoca la reacción más fuerte")
	game._check(1,"")
	game._physics_process(1.0)
	game.players[1].position = Vector3(0,0,Court.HOOP.z+1.42)
	game.players[0].position = Vector3(0,0,Court.HOOP.z+0.74)
	game.stances[0] = true
	var random_seed := 1
	while true:
		game.rng.seed = random_seed
		if game.rng.randf() < 0.10:
			break
		random_seed += 1
	game.rng.seed = random_seed
	_key(KEY_SPACE,true)
	game._physics_process(dt)
	_key(KEY_SPACE,false)
	check(game.state=="dunk" and game.shot_slot==1 and not game.made,"El jugador 2 puede clavar y el defensor puede taparlo")
	for step in 51:
		game._physics_process(dt)
	check(game.score==[1,0] and game.commentary=="Clavada tapada","La clavada tapada no suma")
	app.start_match()
	game._physics_process(1.0)

func _test_cpu(app: Main) -> void:
	var game := app.duel
	var max_speed := 0.0
	var last_window := INF
	for tier in Rules.CPU_TIERS.size():
		var label: String = Rules.CPU_TIERS[tier].label
		app.open_menu()
		var selector := _button(app,label.to_upper())
		if selector != null:
			selector.pressed.emit()
		app.start_match()
		check(game.cpu and game.difficulty==tier,"El menú aplica la dificultad "+label)
		var timing := game.green_width(0)*game.charge_time(0)
		check(timing<last_window,"La ventana de acierto decrece en dificultad "+label)
		last_window = timing
		game.rng.seed = 891251
		game._check(1,"CPU")
		game._physics_process(1.0)
		_key(KEY_SPACE,true)
		game._physics_process(1.0/60.0)
		_key(KEY_SPACE,false)
		check(game.state=="live","Espacio no controla a la CPU en "+label)
		var speed := 0.0
		for n in range(720):
			game._physics_process(1.0/60.0)
			speed = maxf(speed,game.velocity[1].length())
			if game.state=="flight":
				break
		check(speed>max_speed and game.state=="flight" and game.shot_slot==1,"La CPU aumenta el ritmo y lanza en "+label)
		max_speed = speed
	app._load_settings()
	check(app.difficulty==2,"La dificultad se recupera al cargar los ajustes")

func _test_blocks(app: Main) -> void:
	var game := app.duel
	var dt := 1.0/60.0

	_prepare_block_shot(game,1,0.93)
	app.ui.sync_match(game)
	check(app.ui.move_hint.text=="[ H ] TAPÓN","El HUD avisa que el jugador 1 puede taponar un tiro cercano")
	_key(KEY_I,true)
	game._physics_process(dt)
	_key(KEY_I,false)
	check(game.block_slot==-1,"El atacante no puede usar el tapón")
	_key(KEY_H,true)
	for frame in 20:
		game._physics_process(dt)
		if game.state=="dead":
			break
	check(game.state=="dead" and game.commentary.begins_with("¡Tapón!") and game.next_player==0 and not game.made,"H tapona un tiro ascendente para el jugador 1")
	check(game.score==[0,0] and Vector2(game.fallout.x,game.fallout.z).length()>3.0,"El tapón desvía el balón y no suma puntos")
	check(app.stands.cheer>=0.95,"El tapón también despierta a la tribuna")
	await _capture("08-tapon")
	for frame in 60:
		game._physics_process(dt)
	check(game.state=="check" and game.possession==0,"El defensor gana la siguiente posesión")
	_key(KEY_H,false)

	_prepare_block_shot(game,1,3.2)
	_key(KEY_H,true)
	for frame in 22:
		game._physics_process(dt)
	_key(KEY_H,false)
	check(game.state=="flight" and game.made,"Saltar fuera de alcance no bloquea")

	_prepare_block_shot(game,1,0.93)
	for frame in 35:
		game._physics_process(dt)
	_key(KEY_H,true)
	game._physics_process(dt)
	check(game.block_slot==-1 and game.state=="flight" and game.made,"No se puede taponar un tiro tardío")
	_key(KEY_H,false)

	game._check(0,"")
	game._physics_process(1.0)
	_key(KEY_I,true)
	for frame in 37:
		game._physics_process(dt)
	check(not game._jumping(1) and not game.can_block(1),"Un salto fallido deja un tiempo de recuperación")
	for frame in 46:
		game._physics_process(dt)
	check(not game._jumping(1) and game.can_block(1),"Mantener I no repite el salto cuando termina la recuperación")
	_key(KEY_I,false)
	game._physics_process(dt)

	game.players[0].position = Vector3(0.24,0,Court.HOOP.z+1.43)
	game.players[1].position = Vector3(-0.72,0,Court.HOOP.z+0.63)
	_key(KEY_SPACE,true)
	game._physics_process(dt)
	_key(KEY_SPACE,false)
	check(game.state=="dunk" and game.made,"El atacante inicia una clavada que entraría sin tapón")
	for frame in 10:
		game._physics_process(dt)
	_key(KEY_I,true)
	for frame in 27:
		game._physics_process(dt)
		if game.state=="dead":
			break
	_key(KEY_I,false)
	check(game.state=="dead" and game.commentary.begins_with("¡Tapón!") and game.next_player==1 and game.score==[0,0],"I tapona una clavada antes del aro para el jugador 2")
	app.versus_cpu = true
	app.start_match()
	_prepare_block_shot(game,1,0.93)
	game.score = [7,10]
	_key(KEY_H,true)
	for frame in 53:
		game._physics_process(dt)
	_key(KEY_H,false)
	check(game.score==[7,10] and game.match_over==-1 and game.possession==0,"El tapón contra la CPU evita la canasta ganadora y recupera la posesión")
	app.versus_cpu = false
	app.start_match()
	game._physics_process(1.0)

func _prepare_block_shot(game: Duel, shooter: int, gap: float) -> void:
	game._check(shooter,"")
	game._physics_process(1.0)
	game.players[shooter].position = Vector3(0,0,1.0)
	game.players[1-shooter].position = Vector3(0,0,1.0-gap)
	game.players[shooter].rotation.y = PI
	game.players[shooter].pose(0,0,"aim",Rules.GREEN)
	game.meter = Rules.GREEN
	game._shoot(shooter)
	game.made = true
	game.destination = Court.HOOP+Vector3(0,0,0.044)
