extends Node

const CUES := ["start","score","miss","steal","cross","dunk","win"]
const TENSION = preload("res://art/audio/tension.wav")
const AWARD = preload("res://art/audio/premiacion.wav")
const CHEER = preload("res://art/audio/tribuna.wav")
const CITY_TRACKS := [
	preload("res://art/audio/rap_santiago.wav"),
	preload("res://art/audio/rap_mexico.wav"),
	preload("res://art/audio/rap_nueva_york.wav"),
]
const STREET_LEVEL := -15.0

var effects: Dictionary
var atmosphere: AudioStreamPlayer
var effect_players: Array[AudioStreamPlayer] = []
var clips: Array[Dictionary] = [{},{}]
var dialogue: AudioStreamPlayer
var tension: AudioStreamPlayer
var fanfare: AudioStreamPlayer
var street: AudioStreamPlayer
var crowd: AudioStreamPlayer
var cursor := 0

func _ready() -> void:
	for i in 2:
		for cue in CUES:
			clips[i][cue] = load("res://art/audio/j%d_%s.wav" % [i+1,cue])
	dialogue = _player(-9.0)
	tension = _player(-16.0)
	tension.stream = _loop(TENSION)
	fanfare = _player(-13.0)
	fanfare.stream = AWARD
	street = _player(STREET_LEVEL)
	crowd = _player(-12.0)
	crowd.stream = CHEER
	for type in ["bounce","rim","net","horn","tick","shoe","block"]:
		effects[type] = _synthesize(type, 0.16 if type != "horn" else 0.38)
	effects["bark"] = _synthesize("bark",0.48)
	for i in range(8):
		effect_players.append(_player(-6.0))
	atmosphere = _player(-23.0)
	atmosphere.stream = _synthesize("city",4.0)
	if DisplayServer.get_name() != "headless":
		atmosphere.play()

func _loop(track: AudioStreamWAV) -> AudioStreamWAV:
	var stream: AudioStreamWAV = track.duplicate()
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = roundi(stream.get_length()*stream.mix_rate)
	return stream

func _player(level: float) -> AudioStreamPlayer:
	var source := AudioStreamPlayer.new()
	add_child(source)
	source.volume_db = level
	return source

func speak(slot: int, cue: String) -> void:
	if dialogue.playing and cue != "win":
		return
	dialogue.stop()
	dialogue.stream = clips[slot][cue]
	dialogue.play()

func set_tension(enabled: bool) -> void:
	if enabled and not tension.playing:
		tension.play()
	elif not enabled and tension.playing:
		tension.stop()

func play_street(city: int) -> void:
	street.stream = _loop(CITY_TRACKS[city])
	street.volume_db = STREET_LEVEL
	street.play()

func mix_street(dt: float, late: bool, finishing: bool) -> void:
	var target := -40.0 if finishing else (-29.0 if late else STREET_LEVEL)
	street.volume_db = move_toward(street.volume_db,target,dt*19.0)

func cheer(strength: float) -> void:
	var level := lerpf(-19.0,-8.0,strength)
	if crowd.playing and crowd.get_playback_position()<0.36:
		crowd.volume_db = maxf(level,crowd.volume_db)
		return
	crowd.volume_db = level
	crowd.pitch_scale = lerpf(0.96,1.035,strength)
	crowd.play()

func pause_match_audio(value: bool) -> void:
	dialogue.stream_paused = value
	tension.stream_paused = value
	street.stream_paused = value
	crowd.stream_paused = value
	for fx in effect_players:
		fx.stream_paused = value

func play_award(slot: int) -> void:
	set_tension(false)
	street.stop()
	fanfare.play()
	speak(slot,"win")

func reset_match_audio() -> void:
	dialogue.stop()
	fanfare.stop()
	street.stop()
	crowd.stop()
	for fx in effect_players:
		fx.stop()
	set_tension(false)
	pause_match_audio(false)

func play_effect(type: String, level := -6.0, pitch := 1.0) -> void:
	if not effects.has(type):
		return
	var voice := effect_players[cursor]
	cursor = (cursor+1)%effect_players.size()
	voice.stop()
	voice.stream = effects[type]
	voice.volume_db = level
	voice.pitch_scale = pitch
	voice.play()

func _synthesize(type: String, length: float) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5971
	var rate := 24000
	var samples := roundi(rate*length)
	var audio := AudioStreamWAV.new()
	var bytes := PackedByteArray()
	bytes.resize(samples*2)
	var noise := 0.0
	for i in samples:
		var t := float(i)/rate
		var raw := rng.randf_range(-1.0,1.0)
		noise = lerpf(noise,raw,0.063)
		var sample := 0.0
		match type:
			"bounce":
				sample = (sin(TAU*(87*t-95*t*t))*0.76+raw*0.23+noise*0.46)*exp(-36*t)
			"rim":
				sample = (sin(TAU*475*t)*0.45+sin(TAU*811*t)*0.28+raw*0.25)*exp(-29*t)
			"net":
				sample = (noise*1.75+raw*0.30)*sin(t/length*PI)*exp(-5*t)
			"horn":
				sample = (sin(TAU*320*t)*0.38+sin(TAU*480*t)*0.31+sin(TAU*960*t)*0.10)*minf(1.0,t*115)*(1.0-t/length)
			"tick":
				sample = sin(TAU*514*t)*exp(-55*t)*0.44
			"shoe":
				sample = (sin(TAU*(714*t-1091*t*t))*0.21+raw*0.085)*exp(-33*t)
			"block":
				sample = (sin(TAU*(143*t-350*t*t))*0.46+raw*0.32+noise*0.36)*exp(-48*t)
			"bark":
				var age := t if t<0.25 else t-0.25
				var phase := TAU*(302.0*age-495.0*age*age)
				sample = (sin(phase)*0.39+sin(phase*2.09)*0.24+sin(phase*3.11)*0.15+noise*0.61+raw*0.12)*minf(1.0,age*150.0)*exp(-age*29.0)
				if t>=0.25:
					sample *= 0.72
			"city":
				var freq := (0.30+0.17*cos(TAU*t/length))
				sample = noise*freq+0.035*sin(TAU*48*t)+0.025*sin(TAU*67.5*t)+0.018*sin(TAU*53.25*t)
				sample *= clampf(minf(t,length-t)*18,0.0,1.0)
		bytes.encode_s16(i*2,roundi(clampf(sample,-1.0,1.0)*29000))
	audio.mix_rate = rate
	audio.format = AudioStreamWAV.FORMAT_16_BITS
	audio.data = bytes
	if type == "city":
		audio.loop_mode = AudioStreamWAV.LOOP_FORWARD
		audio.loop_end = samples
	return audio
