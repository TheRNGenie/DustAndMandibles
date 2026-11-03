extends Node
## Story mode: which chapter this lobby plays (the host picks it, everyone is
## told), and this player's own progress (StoryProgress, saved to
## user://story.json): chapters won, journal pages, blueprints. The chapter
## itself runs in the world (StoryDirector). Debug launches keep their own
## progress file so tests never touch a real one.
##
## Debug: --story=N plays chapter N on a --debug launch (no menu); --storyall
## unlocks every chapter on the chapter screen.

signal changed

## The chapter being played ("" = a normal run). Every peer.
var chapter_id := ""
var progress := StoryProgress.new()
## The last chapter result for the end screen ({} before one ends).
var last_result: Dictionary = {}
var _no_save := false


func _ready() -> void:
	progress = StoryProgress.read(path())
	# --storydemo (debug screenshots): chapters 1 and 2 won, 3 tried. Never saved.
	if GameState.has_flag("--storydemo") and GameState.has_flag("--debug"):
		_no_save = true
		progress = StoryProgress.new()
		progress.win(StoryChapter.load_id("ch1"))
		progress.win(StoryChapter.load_id("ch2"))
		progress.note_tried("ch3")
	NetworkManager.players_changed.connect(_on_players_changed)


func path() -> String:
	return "user://story_debug.json" if GameState.has_flag("--debug") else "user://story.json"


func save() -> void:
	if not _no_save:
		progress.write(path())


func active() -> bool:
	return chapter_id != ""


func chapter() -> StoryChapter:
	return StoryChapter.load_id(chapter_id) if chapter_id != "" else null


## The map chapter `ch` plays on for `riders` (Debug: --storymap=<id> forces one,
## as a 3-4 rider lobby moves a Canyon chapter to the Mesa or the Buttes).
func map_for(ch: StoryChapter, riders: int) -> StringName:
	var forced := GameState.flag_value("--storymap")
	if forced != "" and GameState.debug_enabled() and MapDef.IDS.has(StringName(forced)):
		return StringName(forced)
	return ch.map_for_players(riders)


## Hive amber (host; story chapters 7, 9 and 10 call it when the job finds the
## plans): the team may craft amber turret `id` (AmberRules.KILN / BELL / LANCE:
## &"amber_kiln", &"queens_bell", &"mandible_lance") from now on, and every
## rider keeps the blueprint in their saved progress. See the Amber autoload.
func unlock_amber_blueprint(id: StringName, announce: bool = true) -> bool:
	return Amber.unlock_blueprint(id, announce)


func is_unlocked(cid: String) -> bool:
	return progress.is_unlocked(cid) or (GameState.has_flag("--storyall") and GameState.debug_enabled())


## Host (or offline): picks the chapter ("" = a normal run), sets its map and
## turns CPU teammates off (story is played solo or with real riders only).
func select(cid: String) -> void:
	chapter_id = cid
	if cid != "":
		NetworkManager.set_cpu(-1)
		NetworkManager.cpu_quality = -1
		var ch := chapter()
		if ch != null:
			NetworkManager.set_map(map_for(ch, maxi(NetworkManager.players.size(), 1)))
			if not NetworkManager.is_online():
				NetworkManager.map_id = map_for(ch, 1)
			_seat_four()
	if multiplayer.is_server() and NetworkManager.is_online():
		_sync.rpc(cid)
	changed.emit()


## Host: right before the game starts, the map that fits everyone who came.
func fit_map() -> void:
	var ch := chapter()
	if ch == null or not multiplayer.is_server():
		return
	var want := map_for(ch, maxi(NetworkManager.players.size(), 1))
	if want != NetworkManager.map_id:
		NetworkManager.set_map(want)
	_seat_four()


## Host: an online chapter lobby keeps room for four riders whatever its map.
func _seat_four() -> void:
	var backend: Variant = NetworkManager.get("_backend")
	if backend != null and not bool(NetworkManager.get("_started")):
		(backend as Object).call("set_max_players", NetworkManager.MAX_PLAYERS)


func _on_players_changed() -> void:
	if active() and multiplayer.is_server() and NetworkManager.is_online() and not bool(NetworkManager.get("_started")):
		fit_map() # a third rider joined a canyon chapter's lobby: off to the Mesa
	if multiplayer.is_server() and NetworkManager.is_online() and not multiplayer.get_peers().is_empty():
		_sync.rpc(chapter_id)


@rpc("authority", "call_remote", "reliable")
func _sync(cid: String) -> void:
	if cid != "" and StoryChapter.load_id(cid) == null:
		cid = "" # a newer host's chapter this build doesn't have: play it as a run
	if cid != chapter_id:
		chapter_id = cid
		changed.emit()


## Host: plays chapter `cid` again from its start (retry), or the next one,
## with everyone still connected: every peer reloads the world.
func restart(cid: String) -> void:
	if not multiplayer.is_server():
		return
	select(cid)
	fit_map()
	GameState.menu_open = false
	_restart_world.rpc(cid, String(NetworkManager.map_id))


@rpc("authority", "call_local", "reliable")
func _restart_world(cid: String, map: String) -> void:
	chapter_id = cid
	GameState.menu_open = false
	GameState.reset()
	NetworkManager.map_id = StringName(map)
	MapDef.select(NetworkManager.map_id)
	get_tree().change_scene_to_file.call_deferred(NetworkManager.WORLD_SCENE)


## Every peer, when a chapter ends: books it in this player's own progress and
## pays this player's Notches (debug runs pay nothing). Returns the result.
func record(ch: StoryChapter, won: bool) -> Dictionary:
	progress.note_tried(ch.id)
	var res := {"won": won, "chapter": ch.id, "notches": 0, "unlock": {}, "journal": false, "first": false}
	if won:
		res.merge(progress.win(ch), true)
		var test_run := GameState.has_flag("--debug") and not GameState.has_flag("--perkearn")
		res["banked"] = not test_run
		if not test_run:
			Perks.profile.brands += int(res["notches"])
			Perks.profile.lifetime_brands += int(res["notches"])
			var unlock: Dictionary = res["unlock"]
			if str(unlock.get("kind", "")) == "cosmetic" and not Perks.profile.cosmetics.has(str(unlock["id"])):
				Perks.profile.cosmetics.append(str(unlock["id"]))
			Perks.save()
			Perks.profile_changed.emit()
	save()
	last_result = res
	changed.emit()
	return res
