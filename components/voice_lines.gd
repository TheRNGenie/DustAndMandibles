class_name VoiceLines
extends RefCounted
## Recorded radio lines (voiced through tools/audio/voice_lines.py; cast in
## tools/audio/voice_cast.json). A line's recording lives at
## res://audio/voice/<speaker>_<key>.ogg, key = the first 12 hex of the SHA-1
## of "speaker|line", so a line whose text changed simply plays unvoiced (the
## radio card then holds it long enough to read) until it's voiced again.

const DIR := "res://audio/voice/"

static var _cache: Dictionary = {}


static func key(who: String, line: String) -> String:
	return (who + "|" + line).sha1_text().substr(0, 12)


static func path_for(who: String, line: String) -> String:
	return DIR + "%s_%s.ogg" % [who, key(who, line)]


## The recording for this line, or null if it hasn't been voiced.
static func stream_for(who: String, line: String) -> AudioStream:
	var p := path_for(who, line)
	if _cache.has(p):
		return _cache[p]
	var s: AudioStream = load(p) if ResourceLoader.exists(p) else null
	_cache[p] = s
	return s


## Seconds the recording runs (0 when unvoiced).
static func length_of(who: String, line: String) -> float:
	var s := stream_for(who, line)
	return s.get_length() if s != null else 0.0
