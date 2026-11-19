extends CanvasLayer

const Court = preload("res://game/court.gd")
const Athlete = preload("res://game/athlete.gd")
const Rules = preload("res://game/rules.gd")
const Duel = preload("res://game/duel.gd")
const Stands = preload("res://game/stands.gd")
const TITLE = preload("res://art/BarlowCondensed-ExtraBoldItalic.ttf")
const INK := Color("f6f3e9")
const LIME := Color("e5fa92")
const SILVER := Color("c5c9bf")
const MUTED := Color("a4aba4")
const BASE := Color("121a1b")
const WIDTH := 1440
const HEIGHT := 900

var host
var root: Control
var overlay: Control
var page := "menu"
var edit_tab := 0
var game_type := true
var score_a: Label
var score_b: Label
var clock_label: Label
var score_name: Array[Label] = []
var note_label: Label
var move_hint: Label
var late_game: Control
var award_note: Label
var meter_box: Control
var meter_fill: ColorRect
var meter_good: ColorRect
var h_meter := 13
var attr_name: Label
var attr_stats: Label
var player_tabs: Array[Button] = []
var aptitude_controls: Dictionary = {}
var budget_text: Label
var budget_hint: Label
var default_font: Font
var theme_ui: Theme

func setup(manager) -> void:
	host = manager
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	default_font = ThemeDB.fallback_font
	theme_ui = Theme.new()
	theme_ui.default_font = default_font
	theme_ui.default_font_size = 15
	var panel := _style(Color("172222"),Color("405052"),1,5)
	theme_ui.set_stylebox("normal","OptionButton",panel)
	theme_ui.set_stylebox("hover","OptionButton",_style(Color("253333"),Color("6b827c"),1,5))
	theme_ui.set_stylebox("focus","OptionButton",_style(Color.TRANSPARENT,LIME,1,5))
	theme_ui.set_stylebox("pressed","OptionButton",_style(Color("253333"),LIME.darkened(0.38),1,5))
	theme_ui.set_stylebox("panel","PopupMenu",_style(Color("192625"),Color("607672"),1,6))
	theme_ui.set_stylebox("hover","PopupMenu",_style(Color("37483a"),Color.TRANSPARENT,0,2))
	theme_ui.set_stylebox("normal","LineEdit",panel)
	theme_ui.set_stylebox("focus","LineEdit",_style(Color("192625"),LIME,1,5))
	root.theme = theme_ui

func _style(fill: Color, border: Color, thick: int, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = border
	s.set_border_width_all(thick)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 13
	s.content_margin_right = 13
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	return s

func _clear(next: String) -> void:
	page = next
	overlay = null
	for child in root.get_children():
		root.remove_child(child)
		child.queue_free()

func _rect(control: Control, x: float, y: float, w: float, h: float) -> Control:
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.position = Vector2(x,y)
	control.size = Vector2(w,h)
	return control

func _label(parent: Node, value: String, x: float, y: float, w: float, h: float, px: int, color := INK, display := false, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var n := Label.new()
	parent.add_child(n)
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	n.text = value
	n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	n.horizontal_alignment = align
	n.add_theme_color_override("font_color",color)
	n.add_theme_font_override("font",TITLE if display else default_font)
	n.add_theme_font_size_override("font_size",px)
	n.clip_text = true
	_rect(n,x,y,w,h)
	return n

func _line(parent: Node, x: float, y: float, w: float, h: float, tint: Color) -> ColorRect:
	var n := ColorRect.new()
	parent.add_child(n)
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	n.color = tint
	_rect(n,x,y,w,h)
	return n

func _panel(parent: Node, x: float, y: float, w: float, h: float, tint := Color("121b1c"), edge := Color("354142"), corner := 7) -> Panel:
	var n := Panel.new()
	parent.add_child(n)
	n.add_theme_stylebox_override("panel",_style(tint,edge,1,corner))
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect(n,x,y,w,h)
	return n

func _button(parent: Node, caption: String, x: float, y: float, w: float, h: float, callback: Callable, selected := false, primary := false, compact := false) -> Button:
	var b := Button.new()
	parent.add_child(b)
	b.text = caption
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size",15 if compact else 17)
	b.add_theme_stylebox_override("normal",_style(LIME if primary else (Color("314139") if selected else Color("152022")),LIME if primary else (LIME.darkened(0.45) if selected else Color("435253")),1,5))
	b.add_theme_stylebox_override("hover",_style(LIME.lightened(0.16) if primary else Color("334541"),LIME,1,5))
	b.add_theme_stylebox_override("pressed",_style(LIME.darkened(0.18) if primary else Color("475c46"),LIME.darkened(0.14),1,5))
	b.add_theme_stylebox_override("focus",_style(Color.TRANSPARENT,INK,1,5))
	for key in ["font_color","font_hover_color","font_focus_color","font_pressed_color"]:
		b.add_theme_color_override(key,BASE if primary else (LIME if selected else INK))
	_rect(b,x,y,w,h)
	b.pressed.connect(callback)
	return b

func _gradient(parent: Node, stops: Array[float], tones: Array[Color], from: Vector2, to: Vector2, x := 0, y := 0, w := WIDTH, h := HEIGHT) -> void:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array(stops)
	grad.colors = PackedColorArray(tones)
	var image := GradientTexture2D.new()
	image.gradient = grad
	image.width = 288
	image.height = 288
	image.fill_from = from
	image.fill_to = to
	var n := TextureRect.new()
	n.texture = image
	n.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(n)
	_rect(n,x,y,w,h)

func _icon(parent: Node, asset: Texture2D, x: float, y: float, w: float, h: float) -> void:
	var n := TextureRect.new()
	n.texture = asset
	n.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	n.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(n)
	_rect(n,x,y,w,h)

func _masthead(section: String) -> void:
	_icon(root,preload("res://art/marca.svg"),54,32,40,40)
	_label(root,"ASFALTO UNO",104,30,218,44,28,INK,true)
	_label(root,section,960,32,425,40,13,INK,false,HORIZONTAL_ALIGNMENT_RIGHT)
	_line(root,55,84,1330,1,Color(0.84,0.89,0.82,0.22))

func show_menu(city: int, cpu: bool) -> void:
	_clear("menu")
	game_type = cpu
	_gradient(root,[0.0,0.31,0.68,1.0],[Color("101819"),Color(0.06,0.09,0.10,0.89),Color(0.05,0.11,0.11,0.14),Color(0.06,0.09,0.10,0.0)],Vector2.ZERO,Vector2.RIGHT)
	_gradient(root,[0.0,0.21,0.64,1.0],[Color(0.04,0.07,0.08,0.79),Color.TRANSPARENT,Color.TRANSPARENT,Color("101819")],Vector2.ZERO,Vector2.DOWN)
	_masthead("01 / CIRCUITO CALLEJERO   •   EDICIÓN 0.4")
	var info: Dictionary = Court.CITIES[city]
	_line(root,61,167,32,3,LIME)
	_label(root,"EL CIRCUITO   /   %02d" % (city+1),108,154,302,27,14,LIME)
	_label(root,"ASFALTO",51,169,737,156,148,INK,true)
	_label(root,"UNO.",51,271,515,158,158,LIME,true)
	_label(root,"LA CALLE ES TU CANCHA.",62,440,515,52,37,INK,true)
	_label(root,"Dos jugadores. Una canasta. A 11 puntos.",64,495,502,35,18,SILVER)
	_label(root,"MODO DE DUELO",64,551,380,21,12,MUTED)
	_button(root,"VS CPU",62,577,126,39,host.select_mode.bind(true),cpu,false,true)
	_button(root,"2 JUGADORES",197,577,166,39,host.select_mode.bind(false),not cpu,false,true)
	if cpu:
		_label(root,"DIFICULTAD DE LA CPU",64,628,380,21,12,MUTED)
		for i in Rules.CPU_TIERS.size():
			var caption: String = Rules.CPU_TIERS[i].label.to_upper()
			var tier := _button(root,caption,62+i*104,656,96,38,host.select_difficulty.bind(i),host.difficulty==i,false,true)
			tier.tooltip_text = ["Más tiempo para apuntar y menos presión","Presión y ritmo moderados","Marca cerrada, robos y tiros más precisos"][i]
	var row := 717 if cpu else 654
	_button(root,"JUGAR DUELO   ↗",62,row,237,56,host.start_match,true,true)
	_button(root,"VESTUARIO   /   02",312,row,205,56,host.open_editor)
	_label(root,"[ . ] CRUCE   [ ESPACIO ] CLAVADA   [ H / I ] TAPÓN",64,row+69,560,26,13,SILVER)
	_panel(root,829,672,555,151,Color(0.067,0.103,0.105,0.96),Color("44534f"))
	var flags: Array[Texture2D] = [preload("res://art/cl.svg"),preload("res://art/mx.svg"),preload("res://art/us.svg")]
	_icon(root,flags[city],849,693,57,39)
	_label(root,"%02d  /  %s    ·    %s" % [city+1,info.country,info.time],920,681,439,22,12,LIME)
	_label(root,info.city+"  /  "+info.court,918,701,442,40,31,INK,true)
	for i in 3:
		_button(root,["SANTIAGO","CDMX","NUEVA YORK"][i],849+i*172,760,160,39,host.select_city.bind(i),city==i,false,true)
	_line(root,55,853,1330,1,Color(0.84,0.89,0.82,0.20))
	_label(root,"LOCAL   /   SIN CONEXIÓN",58,859,452,28,12,MUTED)
	_label(root,info.coords+"   /   "+info.tag,900,859,483,28,12,SILVER,false,HORIZONTAL_ALIGNMENT_RIGHT)

func show_editor(slot: int, profile: Dictionary) -> void:
	_clear("editor")
	aptitude_controls.clear()
	budget_text = null
	budget_hint = null
	_gradient(root,[0.0,0.34,0.67,1.0],[Color("11191b"),Color("11191b"),Color(0.06,0.10,0.11,0.12),Color.TRANSPARENT],Vector2.ZERO,Vector2.RIGHT)
	_gradient(root,[0.0,0.18,0.68,1.0],[Color(0.045,0.07,0.08,0.76),Color.TRANSPARENT,Color.TRANSPARENT,Color("101819")],Vector2.ZERO,Vector2.DOWN)
	_masthead("02 / VESTUARIO   •   DOS PLAZAS")
	_label(root,"02 / EQUIPACIÓN",58,95,456,25,13,LIME)
	_label(root,"VESTUARIO",53,119,634,84,77,INK,true)
	_button(root,"←   VOLVER",1250,101,135,41,host.open_menu,false,false,true)
	player_tabs.clear()
	for i in 2:
		var given: String = host.profiles[i].name
		player_tabs.append(_button(root,("%02d  /  %s" % [[7,21][i],given.to_upper()]),57+i*226,212,215,46,host.select_player.bind(i),slot==i,false,true))
	for i in 3:
		_button(root,["APTITUDES","APARIENCIA","ANIMACIONES"][i],57+i*151,275,143,39,_switch_tab.bind(i),edit_tab==i,false,true)
	var sc := ScrollContainer.new()
	root.add_child(sc)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var top := 385 if edit_tab == 0 else 330
	_rect(sc,57,top,451,775-top)
	var settings := VBoxContainer.new()
	settings.custom_minimum_size.x = 427
	settings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings.add_theme_constant_override("separation",11)
	sc.add_child(settings)
	if edit_tab == 0:
		var budget := _panel(root,57,329,442,46,Color("233029"),Color("62754b"),5)
		budget_text = _label(budget,"",10,0,421,23,15,LIME)
		budget_hint = _label(budget,"",10,22,421,21,12,SILVER)
		settings.add_theme_constant_override("separation",8)
		_name_entry(settings,profile.name)
		for key in Rules.APTITUDES:
			_aptitude_slider(settings,key)
	elif edit_tab == 1:
		_swatch(settings,profile,"skin","Tono de piel",Athlete.SKIN,["Claro","Cálido claro","Cobrizo","Canela","Moreno","Oscuro"])
		_option(settings,profile,"hair","Cabello",["Rapado","Corte bajo","Rizos","Trenzas"])
		_swatch(settings,profile,"hair_color","Color de cabello",Athlete.HAIR_COLOR,["Negro","Castaño","Avellana","Rubio","Gris"])
		_option(settings,profile,"beard","Barba",["Afeitado","Sombra","Completa"])
		_option(settings,profile,"tattoo","Tatuajes",["Ninguno","Un brazo","Ambos brazos"])
		_swatch(settings,profile,"team","Uniforme",Athlete.TEAM,["Arcilla","Verde","Hueso","Cobalto","Ciruela","Asfalto"])
		_swatch(settings,profile,"shoe","Calzado",Athlete.SHOES,["Marfil","Carbón","Rojo","Lima","Índigo"])
		_option(settings,profile,"accessory","Accesorios",["Sin accesorios","Muñequera","Manga","Manga + banda"])
	else:
		_option(settings,profile,"shot_style","Estilo de tiro",["Clásico","En suspensión","A una mano"],"shoot")
		_button(settings,"PROBAR TIRO",0,0,0,38,host.preview_move.bind("shoot"),false,false,true).custom_minimum_size.y = 38
		_option(settings,profile,"dribble_style","Forma de driblar",["Ritmo alto","Cruce de manos","Bote bajo"],"carry")
		_button(settings,"PROBAR DRIBBLING",0,0,0,38,host.preview_move.bind("carry"),false,false,true).custom_minimum_size.y = 38
		_option(settings,profile,"celebrate","Celebración",["Puño al cielo","Golpe de pecho","Salto doble"],"celebrate")
		_button(settings,"PROBAR CELEBRACIÓN",0,0,0,38,host.preview_move.bind("celebrate"),false,false,true).custom_minimum_size.y = 38
	_line(root,58,781,442,1,Color("415050"))
	_button(root,"RESTABLECER",57,801,151,45,host.reset_profile,false,false,true)
	_button(root,"LISTO   ↗",226,801,273,45,host.open_menu,true,true)
	_label(root,"Cambios guardados en este equipo.",59,850,442,30,13,MUTED)
	_label(root,"JUGADOR %02d    /    MODELO 3D" % (slot+1),705,700,666,25,13,LIME)
	attr_name = _label(root,profile.name.to_upper(),696,720,700,82,77,INK,true)
	attr_stats = _label(root,"",705,803,673,30,16,INK)
	update_editor(profile)
	_label(root,"← / →   O ARRASTRA PARA GIRAR",705,844,665,30,12,SILVER)

func _switch_tab(next: int) -> void:
	edit_tab = next
	show_editor(host.edit_slot,host.profiles[host.edit_slot])

func _field(parent: Node, caption: String) -> Control:
	var field := Control.new()
	field.custom_minimum_size = Vector2(414,45)
	parent.add_child(field)
	_label(field,caption,0,0,198,23,15,SILVER)
	return field

func _name_entry(parent: Node, value: String) -> void:
	var field := _field(parent,"Nombre")
	var namebox := LineEdit.new()
	field.add_child(namebox)
	namebox.max_length = 14
	namebox.text = value
	namebox.placeholder_text = "Nombre del jugador"
	_rect(namebox,200,0,218,35)
	namebox.text_changed.connect(func(val: String): host.update_profile("name",val))
	namebox.text_submitted.connect(func(_val: String): namebox.release_focus())

func _aptitude_slider(parent: Node, key: String) -> void:
	var names := {"height":"Altura","weight":"Peso","muscle":"Musculatura","shot":"Lanzamiento","defense":"Defensa","dribble":"Dribbling"}
	var field := _field(parent,names[key])
	var stat := _label(field,"",200,0,218,23,14,LIME,false,HORIZONTAL_ALIGNMENT_RIGHT)
	var range_control := HSlider.new()
	range_control.name = "Aptitud_"+key
	field.add_child(range_control)
	range_control.min_value = 0
	range_control.max_value = 100
	range_control.step = 1
	range_control.add_theme_stylebox_override("slider",_style(Color("394748"),Color.TRANSPARENT,0,2))
	range_control.add_theme_stylebox_override("grabber_area",_style(Color("89994f"),Color.TRANSPARENT,0,2))
	range_control.add_theme_stylebox_override("grabber_area_highlight",_style(LIME,Color.TRANSPARENT,0,2))
	_rect(range_control,0,24,414,17)
	aptitude_controls[key] = [range_control,stat]
	range_control.value_changed.connect(func(next: float):
		host.set_aptitude_points(key,roundi(next))
	)

func _option(parent: Node, data: Dictionary, key: String, caption: String, options: Array, preview := "") -> void:
	var field := _field(parent,caption)
	var select := OptionButton.new()
	field.add_child(select)
	for choice in options:
		select.add_item(choice)
	select.selected = data[key]
	select.fit_to_longest_item = false
	select.clip_text = true
	select.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_rect(select,187,0,231,38)
	select.item_selected.connect(func(pick: int):
		host.update_profile(key,pick)
		if not preview.is_empty():
			host.preview_move(preview)
	)

func _swatch(parent: Node, data: Dictionary, key: String, caption: String, colors: Array, names: Array) -> void:
	var field := _field(parent,caption)
	var group := ButtonGroup.new()
	for i in colors.size():
		var choice := Button.new()
		field.add_child(choice)
		choice.toggle_mode = true
		choice.button_group = group
		choice.set_pressed_no_signal(i==data[key])
		choice.tooltip_text = names[i]
		choice.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var c := Color(colors[i])
		choice.add_theme_stylebox_override("normal",_style(c,Color("5a6663"),1,5))
		choice.add_theme_stylebox_override("hover",_style(c.lightened(0.19),INK,1,5))
		choice.add_theme_stylebox_override("pressed",_style(c,LIME,3,5))
		choice.add_theme_stylebox_override("hover_pressed",_style(c,LIME,3,5))
		choice.add_theme_stylebox_override("focus",_style(Color.TRANSPARENT,INK,1,5))
		_rect(choice,186+i*39,0,31,31)
		choice.pressed.connect(host.update_profile.bind(key,i))

func update_editor(profile: Dictionary) -> void:
	if page != "editor" or not is_instance_valid(attr_stats):
		return
	attr_name.text = profile.name.to_upper()
	for i in player_tabs.size():
		player_tabs[i].text = "%02d  /  %s" % [[7,21][i],host.profiles[i].name.to_upper()]
	attr_stats.text = "%.2f m   /   %.0f kg      •      TIRO %02d     DEF %02d     DRB %02d" % [profile.height,profile.weight,profile.shot,profile.defense,profile.dribble]
	if not is_instance_valid(budget_text):
		return
	var spent := Rules.spent_points(profile)
	budget_text.text = "%d / %d ASIGNADOS   ·   %d LIBRES" % [spent,Rules.POINT_BUDGET,Rules.POINT_BUDGET-spent]
	budget_hint.text = "Baja una aptitud para liberar puntos." if spent==Rules.POINT_BUDGET else "Puedes repartir los puntos libres entre las seis aptitudes."
	for key in aptitude_controls:
		var points := Rules.aptitude_points(key,profile[key])
		var physical := "%.2f m  ·  " % profile[key] if key=="height" else ("%.1f kg  ·  " % profile[key] if key=="weight" else "")
		aptitude_controls[key][0].set_value_no_signal(points)
		aptitude_controls[key][1].text = physical+"%d pts" % points

func show_match(profiles: Array[Dictionary], city: int, cpu: bool) -> void:
	_clear("match")
	game_type = cpu
	_gradient(root,[0.0,0.22,0.74,1.0],[Color(0.04,0.08,0.08,0.76),Color.TRANSPARENT,Color.TRANSPARENT,Color(0.045,0.08,0.085,0.87)],Vector2.ZERO,Vector2.DOWN)
	_panel(root,443,30,554,101,Color(0.07,0.10,0.11,0.95),Color("626c5e"))
	var mode := "CPU "+str(Rules.CPU_TIERS[host.difficulty].label).to_upper() if cpu else "2 JUGADORES"
	_label(root,"%s   /   %s   /   A 11 · VENTAJA DE 2" % [Court.CITIES[city].tag,mode],444,34,552,21,11,SILVER,false,HORIZONTAL_ALIGNMENT_CENTER)
	score_name = []
	score_name.append(_label(root,profiles[0].name.to_upper(),461,89,139,27,15,Duel.MARKS[0],false,HORIZONTAL_ALIGNMENT_CENTER))
	score_name.append(_label(root,profiles[1].name.to_upper()+("  ·  CPU" if cpu else ""),839,89,139,27,15,Duel.MARKS[1],false,HORIZONTAL_ALIGNMENT_CENTER))
	score_a = _label(root,"00",571,50,116,75,60,INK,true,HORIZONTAL_ALIGNMENT_CENTER)
	score_b = _label(root,"00",751,50,116,75,60,INK,true,HORIZONTAL_ALIGNMENT_CENTER)
	clock_label = _label(root,"15",681,60,78,42,33,LIME,true,HORIZONTAL_ALIGNMENT_CENTER)
	_label(root,"POSESIÓN",678,98,84,14,9,MUTED,false,HORIZONTAL_ALIGNMENT_CENTER)
	_button(root,"ESC  /  PAUSA",1219,35,169,43,host.toggle_pause,false,false,true).focus_mode = Control.FOCUS_NONE
	var on_air := _panel(root,1219,84,169,39,Color(0.07,0.10,0.11,0.88),Color("626c5e"),4)
	_label(on_air,Stands.CREWS[city],6,2,157,19,13,LIME,false,HORIZONTAL_ALIGNMENT_CENTER)
	_label(on_air,Stands.TRACKS[city],6,21,157,16,10,SILVER,false,HORIZONTAL_ALIGNMENT_CENTER)
	late_game = _panel(root,55,39,194,40,Color("33271c"),Color("e5ae65"),5)
	_label(late_game,"TRAMO FINAL",10,1,174,38,14,Color("f6c97e"),false,HORIZONTAL_ALIGNMENT_CENTER)
	late_game.hide()
	note_label = _label(root,"Primera posesión",356,144,728,43,26,INK,true,HORIZONTAL_ALIGNMENT_CENTER)
	note_label.add_theme_color_override("font_shadow_color",Color("172020"))
	note_label.add_theme_constant_override("shadow_offset_x",2)
	note_label.add_theme_constant_override("shadow_offset_y",3)
	meter_box = Control.new()
	meter_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(meter_box)
	_rect(meter_box,508,724,424,87)
	_panel(meter_box,0,0,424,72,Color(0.058,0.09,0.093,0.95),Color("5f7160"))
	_label(meter_box,"SUELTA EN VERDE",0,7,424,27,13,INK,false,HORIZONTAL_ALIGNMENT_CENTER)
	_line(meter_box,23,41,378,h_meter,Color("354141"))
	meter_good = _line(meter_box,265,41,38,h_meter,LIME.darkened(0.37))
	meter_fill = _line(meter_box,23,44,0,h_meter-6,INK)
	meter_box.hide()
	move_hint = _label(root,"",508,745,424,47,17,LIME,true,HORIZONTAL_ALIGNMENT_CENTER)
	move_hint.add_theme_color_override("font_shadow_color",Color("152020"))
	move_hint.add_theme_constant_override("shadow_offset_y",2)
	_line(root,54,824,1332,1,Color(0.84,0.89,0.82,0.25))
	_label(root,"J1   WASD mover   F tiro / robo   G sprint / defensa   H tapón",56,830,729,29,14,INK)
	if not cpu:
		_label(root,"J2   Flechas mover   O tiro / robo   P sprint / defensa   I tapón",794,830,592,29,14,INK,false,HORIZONTAL_ALIGNMENT_RIGHT)
	else:
		_label(root,"PARA TAPONAR, ACÉRCATE Y SALTA CUANDO EL RIVAL LANCE",795,830,590,29,12,SILVER,false,HORIZONTAL_ALIGNMENT_RIGHT)
	_label(root,"CON BALÓN    [ . ] CAMBIO DE MANO   /   [ ESPACIO ] CLAVADA CERCA DEL ARO",55,860,1330,23,12,SILVER,false,HORIZONTAL_ALIGNMENT_CENTER)

func sync_match(game: Duel) -> void:
	if page != "match":
		return
	score_a.text = "%02d" % game.score[0]
	score_b.text = "%02d" % game.score[1]
	clock_label.text = "%02d" % ceili(game.clock)
	clock_label.add_theme_color_override("font_color",Color("f69880") if game.clock<4.0 else LIME)
	for i in 2:
		score_name[i].add_theme_color_override("font_color",Duel.MARKS[i] if i==game.possession else MUTED)
	note_label.text = game.commentary
	note_label.add_theme_color_override("font_color",LIME if game.commentary.begins_with("+") or game.commentary.begins_with("¡Tapón!") else INK)
	late_game.visible = Rules.tension(game.score)
	move_hint.text = game.block_hint()
	if move_hint.text.is_empty() and game.can_dunk(game.possession):
		move_hint.text = "[ ESPACIO ] CLAVAR"
	meter_box.visible = game.charge and (not game.cpu or game.possession == 0)
	if meter_box.visible:
		var green := game.green_width(game.possession)
		meter_good.position.x = 23+(Rules.GREEN-green)*378
		meter_good.size.x = green*2.0*378
		meter_fill.size.x = game.meter*378
		meter_fill.color = LIME if absf(game.meter-Rules.GREEN)<green else INK

func close_overlay() -> void:
	if is_instance_valid(overlay):
		root.remove_child(overlay)
		overlay.queue_free()
		overlay = null

func show_pause() -> void:
	close_overlay()
	overlay = Control.new()
	root.add_child(overlay)
	_rect(overlay,0,0,WIDTH,HEIGHT)
	_line(overlay,0,0,WIDTH,HEIGHT,Color(0.03,0.06,0.07,0.82))
	_panel(overlay,430,218,580,464,Color("142022"),Color("64766a"),12)
	_label(overlay,"MENÚ DEL PARTIDO",475,254,490,25,13,LIME,false,HORIZONTAL_ALIGNMENT_CENTER)
	_label(overlay,"PAUSA.",459,286,522,109,93,INK,true,HORIZONTAL_ALIGNMENT_CENTER)
	_label(overlay,"A 11 con ventaja de 2 · 1 dentro / 2 fuera del arco",460,408,520,32,16,SILVER,false,HORIZONTAL_ALIGNMENT_CENTER)
	_button(overlay,"CONTINUAR  ↗",488,466,464,53,host.toggle_pause,true,true)
	_button(overlay,"REINICIAR DUELO",488,531,464,44,host.start_match)
	_button(overlay,"VOLVER AL CIRCUITO",488,596,464,43,host.open_menu)

func show_award(winner_name: String, score: Array[int], city: int) -> void:
	_clear("award")
	var gold := Color("f6c97e")
	_gradient(root,[0.0,0.31,0.65,1.0],[Color("111717"),Color(0.06,0.09,0.10,0.93),Color(0.05,0.09,0.09,0.12),Color.TRANSPARENT],Vector2.ZERO,Vector2.RIGHT)
	_gradient(root,[0.0,0.22,0.71,1.0],[Color(0.04,0.06,0.06,0.71),Color.TRANSPARENT,Color.TRANSPARENT,Color("131b1b")],Vector2.ZERO,Vector2.DOWN)
	_masthead("03 / PREMIACIÓN   •   "+Court.CITIES[city].tag)
	_line(root,60,256,36,3,gold)
	_label(root,"GANADOR DEL DUELO",109,241,490,31,15,gold)
	_label(root,winner_name.to_upper(),55,276,570,112,mini(98,825/maxi(winner_name.length(),8)),INK,true)
	_label(root,"%02d  —  %02d" % [score[0],score[1]],58,400,498,76,64,INK,true)
	_label(root,"MARCADOR FINAL   /   J1 · J2",64,479,490,27,13,SILVER)
	_button(root,"REVANCHA  ↗",60,605,212,53,host.start_match,true,true)
	_button(root,"VOLVER AL CIRCUITO",285,605,251,53,host.open_menu)
	_line(root,57,802,1327,1,Color(0.96,0.78,0.49,0.46))
	award_note = _label(root,"ENTREGA DEL ANILLO",865,817,519,43,22,gold,true,HORIZONTAL_ALIGNMENT_RIGHT)

func sync_award(received: bool) -> void:
	award_note.text = "ANILLO DEL CIRCUITO  /  ENTREGADO" if received else "ENTREGA DEL ANILLO"
