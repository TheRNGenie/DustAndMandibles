extends Node
## Plays the generated sound effects (audio/sfx/*.wav, made by tools/audio/make_sfx.py)
## through pooled players on the SFX and UI buses. Positional sounds use
## AudioStreamPlayer3D so you can hear which lane bugs climb. Missing files are skipped.

const SFX_DIR := "res://audio/sfx/"
const NAMES: Array[StringName] = [&"revolver", &"gatling_1", &"gatling_2", &"gatling_3", &"buffalo",
	&"dynamite", &"skitter", &"beetle_hiss", &"spider_screech", &"bug_pop", &"bell", &"build",
	&"coin", &"acid_spit", &"hit_tick", &"armor_ping", &"homestead_hit", &"reload", &"pluck", &"guitar_smash", &"thunder",
	&"lever_rifle", &"shotgun", &"repeater", &"sharpshooter", &"harpoon", &"scattergun", &"water_blast",
	&"mortar", &"lobber", &"cannon", &"rustle", &"water_pour", &"zippo_open", &"zippo_close", &"zippo_strike", &"blunderbuss", &"whip_crack_1", &"whip_crack_2", &"whip_crack_3",
	# Foley pass (tools/audio/make_foley.py): reloads, movement, hands-on work.
	&"revolver_open", &"revolver_load", &"revolver_close", &"lever_rifle_open", &"lever_rifle_load", &"lever_rifle_close",
	&"coach_shotgun_open", &"coach_shotgun_load", &"coach_shotgun_close", &"shell_eject", &"blunderbuss_open", &"blunderbuss_load",
	&"blunderbuss_close", &"crank_gatling_open", &"crank_gatling_load", &"crank_gatling_close",
	&"step_dirt", &"step_wood", &"land_dirt", &"land_wood", &"jump", &"slide", &"equip", &"throw",
	&"harvest_pull", &"plant_dig", &"pump", &"salvage", &"loot_crack", &"chest_open", &"scribble", &"hammer_hit",
	&"slot_lever", &"card_flick", &"roulette_spin", &"wheel_tick", &"dice", &"register", &"zip_grab", &"zip_start",
	&"herb_eat", &"cig_light", &"hook_bite", &"spur",
	# Waterworks (recorded, CC0; see audio/CREDITS.txt).
	&"generator_start", &"generator_stop", &"ground_rumble",
	# Recorded (tools/audio/import_crunch.py): the light shell crack when a bug dies.
	&"bug_crunch"]
## Most sounds have several takes (name.wav, name__2.wav, ...); one is picked at random.
const MAX_TAKES := 6
const POOL_3D := 32
const POOL_UI := 8
const PITCH_VARIATION := 0.08
## Bug death crunches: their own small pool so a wave never steals gunfire's players,
## a steep falloff (soft at 15 m, gone past 38 m) and a cap per 100 ms (SoundLimiter).
const CRUNCH_POOL := 6
const CRUNCH_MAX_DISTANCE := 38.0
const CRUNCH_UNIT_SIZE := 5.0

var _streams: Dictionary = {}
var _takes: Dictionary = {}
var _log := false
var _players_3d: Array[AudioStreamPlayer3D] = []
var _players_ui: Array[AudioStreamPlayer] = []
var _next_3d := 0
var _next_ui := 0
var _players_crunch: Array[AudioStreamPlayer3D] = []
var _crunch_limit := SoundLimiter.new(CRUNCH_POOL, 4, 100)
var _music: Array[AudioStreamPlayer] = []
var _music_on := 0
var _music_name: StringName = &""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_log = "--audiolog" in OS.get_cmdline_user_args()
	for n in NAMES:
		# Each sound is a .wav (made by our scripts) or an .ogg (recorded, imported).
		var ext := ".wav" if ResourceLoader.exists(SFX_DIR + String(n) + ".wav") else ".ogg"
		var path := SFX_DIR + String(n) + ext
		if ResourceLoader.exists(path):
			_streams[n] = load(path)
			var takes: Array = [_streams[n]]
			for k in range(2, MAX_TAKES + 1):
				var alt := SFX_DIR + "%s__%d%s" % [n, k, ext]
				if ResourceLoader.exists(alt):
					takes.append(load(alt))
			_takes[n] = takes
	# Keep stacked gunfire from clipping: gentle glue on effects, a brick wall on the master.
	var sfx_i := AudioServer.get_bus_index("SFX")
	if sfx_i >= 0 and AudioServer.get_bus_effect_count(sfx_i) == 0:
		var comp := AudioEffectCompressor.new()
		comp.threshold = -10.0
		comp.ratio = 3.0
		comp.attack_us = 2000.0
		comp.release_ms = 180.0
		AudioServer.add_bus_effect(sfx_i, comp)
	if AudioServer.get_bus_effect_count(0) == 0:
		var lim := AudioEffectHardLimiter.new()
		lim.ceiling_db = -0.5
		AudioServer.add_bus_effect(0, lim)
	var sfx_bus := &"SFX" if AudioServer.get_bus_index("SFX") >= 0 else &"Master"
	var ui_bus := &"UI" if AudioServer.get_bus_index("UI") >= 0 else &"Master"
	for i in POOL_3D:
		var p := AudioStreamPlayer3D.new()
		p.bus = sfx_bus
		p.unit_size = 12.0
		p.max_distance = 160.0
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(p)
		_players_3d.append(p)
	for i in CRUNCH_POOL:
		var c := AudioStreamPlayer3D.new()
		c.bus = sfx_bus
		# Inverse square: 0 dB at 5 m, -12 dB at 10 m, -24 dB at 20 m, then a hard stop.
		c.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_SQUARE_DISTANCE
		c.unit_size = CRUNCH_UNIT_SIZE
		c.max_distance = CRUNCH_MAX_DISTANCE
		c.max_db = 0.0
		add_child(c)
		_players_crunch.append(c)
	for i in POOL_UI:
		var u := AudioStreamPlayer.new()
		u.bus = ui_bus
		add_child(u)
		_players_ui.append(u)
	var music_bus := &"Music" if AudioServer.get_bus_index("Music") >= 0 else &"Master"
	for i in 2:
		var m := AudioStreamPlayer.new()
		m.bus = music_bus
		m.volume_db = -80.0
		add_child(m)
		_music.append(m)


## Crossfades to a music loop from audio/music/ ("" fades music out).
func play_music(track: StringName, fade: float = 2.5) -> void:
	if track == _music_name:
		return
	_music_name = track
	var old := _music[_music_on]
	_music_on = 1 - _music_on
	var new_player := _music[_music_on]
	var tw := create_tween().set_parallel(true)
	tw.tween_property(old, "volume_db", -80.0, fade)
	if track == &"":
		return
	var path := "res://audio/music/%s.wav" % track
	if not ResourceLoader.exists(path):
		return
	var stream := load(path) as AudioStreamWAV
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = int(stream.get_length() * stream.mix_rate)
	new_player.stream = stream
	new_player.volume_db = -40.0
	new_player.play()
	tw.tween_property(new_player, "volume_db", -6.0, fade)


func has_sound(sound: StringName) -> bool:
	return _streams.has(sound)


## Positional one-shot. Pitch is randomized slightly so repeats don't sound identical;
## `pitch` shifts it on top (the bosses reuse recordings higher or lower).
func play_at(sound: StringName, pos: Vector3, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not _streams.has(sound):
		return
	if _log:
		print("[audio] %s at %s %.0f dB" % [sound, str(pos.snapped(Vector3.ONE * 0.1)), volume_db])
	var p := _players_3d[_next_3d]
	_next_3d = (_next_3d + 1) % _players_3d.size()
	p.stream = _pick(sound)
	p.global_position = pos
	p.volume_db = volume_db
	p.pitch_scale = randf_range(1.0 - PITCH_VARIATION, 1.0 + PITCH_VARIATION) * pitch
	p.play()


## A bug's death crunch at `pos`, on whichever peer calls it. Deaths beyond earshot
## cost nothing; when many die at once only the nearest few are heard.
func play_crunch(pos: Vector3, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not _streams.has(&"bug_crunch"):
		return
	var cam: Camera3D = get_viewport().get_camera_3d()
	var dist := cam.global_position.distance_to(pos) if cam != null else 0.0
	if dist > CRUNCH_MAX_DISTANCE:
		return
	var slot := _crunch_limit.admit(Time.get_ticks_msec(), dist)
	if slot < 0:
		return
	if _log:
		print("[audio] bug_crunch at %s %.0f m slot %d" % [str(pos.snapped(Vector3.ONE * 0.1)), dist, slot])
	var p := _players_crunch[slot]
	p.stream = _pick(&"bug_crunch")
	p.global_position = pos
	p.volume_db = volume_db
	p.pitch_scale = randf_range(1.0 - PITCH_VARIATION, 1.0 + PITCH_VARIATION) * pitch
	p.play()


func _pick(sound: StringName) -> AudioStream:
	var takes: Array = _takes.get(sound, [])
	if takes.size() > 1:
		return takes[randi() % takes.size()]
	return _streams[sound]


## Non-positional sound (UI, the wave bell).
func play_ui(sound: StringName, volume_db: float = 0.0) -> void:
	if not _streams.has(sound):
		return
	var p := _players_ui[_next_ui]
	_next_ui = (_next_ui + 1) % _players_ui.size()
	p.stream = _pick(sound)
	p.volume_db = volume_db
	p.pitch_scale = 1.0
	p.play()
