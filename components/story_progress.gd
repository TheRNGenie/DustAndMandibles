class_name StoryProgress
extends RefCounted
## Story mode progress, one per player (saved to user://story.json): which
## chapters are won, the Doc Whitlow journal pages earned, Silas's blueprints
## and the chapter to play next. Pure apart from read / write; unit-tested.
## A chapter is unlocked once the one before it is won (the first always is).

## chapter id -> {"wins": int, "best_wave": int}
var done: Dictionary = {}
## Journal pages earned (chapter ids, in the order they came).
var journal: Array[String] = []
## Crafted turret designs Silas's blueprints give at every chapter's start.
var blueprints: Array[String] = []
## Chapters tried, won or not (the chapter screen marks the rest New).
var tried: Array[String] = []


func is_done(chapter_id: String) -> bool:
	return done.has(chapter_id)


func is_unlocked(chapter_id: String) -> bool:
	var i := StoryChapter.IDS.find(chapter_id)
	if i < 0:
		return false
	return i == 0 or is_done(StoryChapter.IDS[i - 1])


## The first chapter not yet won (the last one when they all are).
func next_up() -> String:
	for cid in StoryChapter.IDS:
		if not is_done(cid):
			return cid
	return StoryChapter.IDS[StoryChapter.IDS.size() - 1]


func note_tried(chapter_id: String) -> void:
	if not tried.has(chapter_id):
		tried.append(chapter_id)


## Books a won chapter. Returns what it paid: {"first": bool, "notches": int,
## "unlock": {} (only the first time), "journal": bool}. A replay pays a tip.
func win(ch: StoryChapter) -> Dictionary:
	var first := not is_done(ch.id)
	var rec: Dictionary = done.get(ch.id, {"wins": 0, "best_wave": 0})
	rec["wins"] = int(rec["wins"]) + 1
	rec["best_wave"] = maxi(int(rec["best_wave"]), ch.last_wave)
	done[ch.id] = rec
	note_tried(ch.id)
	var got_page := false
	if not journal.has(ch.id):
		journal.append(ch.id)
		got_page = true
	var unlock: Dictionary = ch.unlock() if first else {}
	if str(unlock.get("kind", "")) == "blueprint" and not blueprints.has(str(unlock["id"])):
		blueprints.append(str(unlock["id"]))
	return {"first": first, "notches": ch.notches() if first else replay_tip(ch), "unlock": unlock, "journal": got_page}


## What a chapter pays when it's won again.
static func replay_tip(ch: StoryChapter) -> int:
	return maxi(ch.notches() / 5, 1)


func to_dict() -> Dictionary:
	return {"done": done, "journal": journal, "blueprints": blueprints, "tried": tried}


static func from_dict(d: Variant) -> StoryProgress:
	var p := StoryProgress.new()
	if not d is Dictionary:
		return p
	var dd := d as Dictionary
	var raw_done: Variant = dd.get("done", {})
	if raw_done is Dictionary:
		for k: Variant in raw_done:
			if StoryChapter.IDS.has(str(k)) and raw_done[k] is Dictionary:
				p.done[str(k)] = {"wins": int((raw_done[k] as Dictionary).get("wins", 1)), "best_wave": int((raw_done[k] as Dictionary).get("best_wave", 0))}
	for key: String in ["journal", "blueprints", "tried"]:
		var arr: Variant = dd.get(key, [])
		if arr is Array:
			for v: Variant in arr:
				var target: Array[String] = p.get(key)
				if not target.has(str(v)):
					target.append(str(v))
	return p


static func read(path: String) -> StoryProgress:
	if not FileAccess.file_exists(path):
		return StoryProgress.new()
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return StoryProgress.new()
	return from_dict(JSON.parse_string(f.get_as_text()))


func write(path: String) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(to_dict(), "\t"))
	return true
