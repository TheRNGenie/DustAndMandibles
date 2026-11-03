class_name NewspaperFront
extends PanelContainer
## The end-of-run screen's front page: "The Canyon Gazette", with the run's
## result as the headline and its numbers as the stories (RunStats).

const PAPER := Color("#EFE3C6")
const INK := Color("#2B1D12")
const FADED := Color("#5C4A36")

var _headline: Label
var _dateline: Label
var _stories: GridContainer


func _ready() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPER
	sb.border_color = INK.lightened(0.3)
	sb.set_border_width_all(2)
	sb.set_content_margin_all(16)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 6
	add_theme_stylebox_override("panel", sb)
	custom_minimum_size = Vector2(620, 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	add_child(col)
	var mast := UiStyle.title("The Canyon Gazette", 40)
	mast.add_theme_color_override("font_color", INK)
	col.add_child(mast)
	_dateline = UiStyle.label("", 13, FADED)
	col.add_child(_rule(3))
	col.add_child(_dateline)
	col.add_child(_rule(1))
	_headline = UiStyle.title("", 30)
	_headline.add_theme_color_override("font_color", INK)
	_headline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_headline)
	col.add_child(_rule(1))
	_stories = GridContainer.new()
	_stories.columns = 2
	_stories.add_theme_constant_override("h_separation", 24)
	_stories.add_theme_constant_override("v_separation", 10)
	col.add_child(_stories)


## Fill the page for a run that just ended.
func show_run(won: bool, reason: String) -> void:
	var m := WorldLayout.map()
	var map_name: String = m.display_name if m != null else "Canyon"
	var wave := maxi(GameState.wave, 1)
	_dateline.text = "WAVE %d  -  %s EDITION  -  FIVE CENTS" % [wave, map_name.to_upper()]
	_headline.text = RunStats.headline(won, wave, map_name)
	for c in _stories.get_children():
		c.queue_free()
	_story("Bugs Slain", "%d giant bugs went down. %s" % [RunStats.kills,
		"The canyon floor is thick with shells." if RunStats.kills > 200 else "Locals expect worse."])
	var top := RunStats.top_source()
	if int(top[1]) > 0:
		_story("Top Gun", "%s led the town with %s." % [str(top[0]), RunStats.count_of(int(top[1]), "kill")])
	var bosses := RunStats.bosses
	if not bosses.is_empty():
		_story("Biggest Catch", "%s brought down. Bounties paid in full." % ", ".join(PackedStringArray(bosses)))
	else:
		var tb := RunStats.top_bug()
		if int(tb[1]) > 0:
			_story("Pest of the Season", "%s, killed %s." % [str(tb[0]), "once" if int(tb[1]) == 1 else "%d times" % int(tb[1])])
	_story("Scrap Hauled", "%d scrap came off the dead. Smiths report a busy week." % RunStats.scrap)
	if not won and reason != "":
		_story("How It Ended", reason)


## Story: the front page for a chapter that just ended (its headline, what the
## job came to, and what it paid this rider).
func show_chapter(ch: StoryChapter, won: bool, reason: String, result: Dictionary) -> void:
	show_run(won, reason)
	var m := WorldLayout.map()
	_dateline.text = "CHAPTER %d  -  %s EDITION  -  WAVE %d  -  FIVE CENTS" % [ch.number, (m.display_name if m != null else "Canyon").to_upper(), maxi(GameState.wave, 1)]
	_headline.text = ch.headline_win if won else ch.headline_loss
	if won:
		var pay: PackedStringArray = []
		var unlock: Dictionary = result.get("unlock", {})
		if not unlock.is_empty():
			pay.append(str(unlock.get("name", "")))
		if bool(result.get("journal", false)):
			pay.append("a page of Doc Whitlow's journal")
		_story("The Job", "%s: done. %s" % [ch.objective_text(), "The railroad pays on time, for once."])
		if not pay.is_empty():
			_story("Rewards", "Paid out: %s." % ", ".join(pay))
	else:
		_story("The Job", "%s: not done. The Captain says fly it again from the top." % ch.objective_text())


func _story(head: String, body: String) -> void:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(280, 0)
	box.add_theme_constant_override("separation", 2)
	var h := UiStyle.title(head, 17)
	h.add_theme_color_override("font_color", INK)
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(h)
	var b := UiStyle.label(body, 14, FADED)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(b)
	_stories.add_child(box)


func _rule(px: int) -> ColorRect:
	var r := ColorRect.new()
	r.color = INK
	r.custom_minimum_size = Vector2(0, px)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r
