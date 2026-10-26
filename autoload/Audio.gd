extends Node
## Plays the generated sound effects (audio/sfx/*.wav, made by tools/audio/make_sfx.py)
## through pooled players on the SFX and UI buses. Positional sounds use
## AudioStreamPlayer3D so you can hear which lane bugs climb. Missing files are skipped.

const SFX_DIR := "res://audio/sfx/"
const NAMES: Array[StringName] = [&"revolver", &"gatling_1", &"gatling_2", &"gatling_3", &"buffalo",
	&"dynamite", &"skitter", &"beetle_hiss", &"spider_screech", &"bug_pop", &"bell", &"build",
	&"coin", &"acid_spit", &"hit_tick", &"armor_ping", &"homestead_hit", &"reload", &"pluck", &"guitar_smash"]
const POOL_3D := 32
const POOL_UI := 8
const PITCH_VARIATION := 0.08

var _streams: Dictionary = {}
var _players_3d: Array[AudioStreamPlayer3D] = []
var _players_ui: Array[AudioStreamPlayer] = []
var _next_3d := 0
var _next_ui := 0
var _music: Array[AudioStreamPlayer] = []
var _music_on := 0
var _music_name: StringName = &""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for n in NAMES:
		var path := SFX_DIR + String(n) + ".wav"
		if ResourceLoader.exists(path):
			_streams[n] = load(path)
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


## Positional one-shot. Pitch is randomized slightly so repeats don't sound identical.
func play_at(sound: StringName, pos: Vector3, volume_db: float = 0.0) -> void:
	if not _streams.has(sound):
		return
	var p := _players_3d[_next_3d]
	_next_3d = (_next_3d + 1) % _players_3d.size()
	p.stream = _streams[sound]
	p.global_position = pos
	p.volume_db = volume_db
	p.pitch_scale = randf_range(1.0 - PITCH_VARIATION, 1.0 + PITCH_VARIATION)
	p.play()


## Non-positional sound (UI, the wave bell).
func play_ui(sound: StringName, volume_db: float = 0.0) -> void:
	if not _streams.has(sound):
		return
	var p := _players_ui[_next_ui]
	_next_ui = (_next_ui + 1) % _players_ui.size()
	p.stream = _streams[sound]
	p.volume_db = volume_db
	p.pitch_scale = 1.0
	p.play()
