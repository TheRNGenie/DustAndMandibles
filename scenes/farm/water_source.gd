class_name WaterSource
extends StaticBody3D
## A well or rain catcher: fills a trough over time; E empties up to a bucket's
## worth (5) into your stockpile. The Homestead's well starts broken and costs
## 80 scrap to fix. Rain catchers fill fast during storms and slowly from dew.
## Dragonfly Bandits steal from here.

const BUCKET := 5

var cliff_id: int = 0
var display_name := "Well"
var radius: float = 1.2
## Seconds per unit of water: [normal, storm].
var rates: Vector2 = Vector2(8.0, 8.0)
var capacity: int = 10
var fix_cost: int = 0
## Set when built by a player (rain catcher): its grid cell and build id.
var cell: Vector2i = Vector2i(-1, -1)
var build_id: StringName = &""
var working := true
var stored: int = 0
var _t := 0.0


func _ready() -> void:
	add_to_group("water_sources")


func _process(delta: float) -> void:
	if not multiplayer.is_server() or not working or stored >= capacity:
		return
	var rate := rates.y if GameState.storm else rates.x
	_t += delta * GameState.growth_scale()
	if _t >= rate:
		_t = 0.0
		stored += 1
		_sync.rpc(stored, working)


func interact_prompt() -> String:
	if not working:
		return "%s is broken - E: fix it (%d scrap)" % [display_name, fix_cost]
	if stored <= 0:
		return "%s: empty, filling up..." % display_name
	return "%s: %d water - E: fill your bucket (up to %d)" % [display_name, stored, BUCKET]


func local_interact(_holding: bool) -> void:
	if multiplayer.is_server():
		_use(multiplayer.get_unique_id())
	else:
		_request_use.rpc_id(1)


@rpc("any_peer", "reliable")
func _request_use() -> void:
	if multiplayer.is_server():
		_use(multiplayer.get_remote_sender_id())


func _use(peer_id: int) -> void:
	var payer := Economy.payer_cliff(peer_id, cliff_id)
	if not working:
		if Economy.spend(payer, {&"scrap": fix_cost}):
			working = true
			_sync.rpc(stored, working)
		else:
			Economy.notify(peer_id, "Not enough scrap to fix the %s." % display_name.to_lower())
		return
	var take := mini(stored, BUCKET)
	if take <= 0:
		return
	stored -= take
	Economy.earn(payer, {&"water": take})
	_sync.rpc(stored, working)
	_fx.rpc()


## Host: a Dragonfly Bandit drinks from it. Returns what it got.
func steal(amount: int) -> int:
	var take := mini(stored, amount)
	if take > 0:
		stored -= take
		_sync.rpc(stored, working)
	return take


@rpc("authority", "call_local", "reliable")
func _sync(value: int, is_working: bool) -> void:
	stored = value
	working = is_working


@rpc("authority", "call_local", "unreliable")
func _fx() -> void:
	Audio.play_at(&"pluck", global_position)
