extends Node
## Plays the generated sound effects (audio/sfx/*.wav, made by tools/audio/make_sfx.py)
## through pooled players on the SFX and UI buses. Positional sounds use
## AudioStreamPlayer3D so you can hear which lane bugs climb. Missing files are skipped.

const SFX_DIR := "res://audio/sfx/"
const NAMES: Array[StringName] = [&"revolver", &"gatling_1", &"gatling_2", &"gatling_3", &"buffalo",
	&"dynamite", &"skitter", &"beetle_hiss", &"spider_screech", &"bug_pop", &"bell", &"build",
	&"coin", &"acid_spit", &"hit_tick", &"armor_ping", &"homestead_hit", &"reload", &"pluck"]
const POOL_3D := 32
const POOL_UI := 8
const PITCH_VARIATION := 0.08

var _streams: Dictionary = {}
var _players_3d: Array[AudioStreamPlayer3D] = []
var _players_ui: Array[AudioStreamPlayer] = []
var _next_3d := 0
var _next_ui := 0


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
