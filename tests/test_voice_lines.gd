extends TestCase
## Every radio line in the story is voiced (tools/audio/voice_lines.py lists
## and voices them; a line whose text changed needs voicing again).


func test_every_story_line_has_a_recording() -> void:
	var missing: Array[String] = []
	for id: String in StoryChapter.IDS:
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/story/%s.json" % id))
		for pair: Array in _lines(data):
			if not ResourceLoader.exists(VoiceLines.path_for(str(pair[0]), str(pair[1]))):
				missing.append("%s: %s" % [pair[0], pair[1]])
	assert_eq(missing, [] as Array[String], "voiced lines (run tools/audio/voice_lines.py)")


func test_key_matches_the_voicing_tool() -> void:
	# sha1("stroud|Hello")[:12], as the Python tool computes it.
	assert_eq(VoiceLines.key("stroud", "Hello"), ("stroud|Hello").sha1_text().substr(0, 12))
	assert_eq(VoiceLines.key("stroud", "Hello").length(), 12)


func _lines(x: Variant) -> Array:
	var out: Array = []
	if x is Array and (x as Array).size() == 2 and x[0] is String and x[1] is String and StoryChapter.SPEAKERS.has(str(x[0])):
		out.append(x)
	elif x is Dictionary:
		for v: Variant in (x as Dictionary).values():
			out.append_array(_lines(v))
	elif x is Array:
		for v: Variant in x:
			out.append_array(_lines(v))
	return out
