class_name EndlessStart
extends RefCounted
## Endless can start at a later wave (the lobby's Starting Wave slider, up to
## MAX_WAVE). The riders arrive with BONUS times what a team would have earned
## by then: the starting team pot, every bug of every earlier wave killed
## (EconomyLedger.kill_pay; a pulse only ever lets max_active_bugs out), each
## held wave's town bounty, and for each cliff
## its junk heap salvaged before every wave. Shell heaps and crop sales are
## left out, so it's on the lean side of a real run. Pure (unit tested).

const MAX_WAVE := 50
const BONUS := 1.25


## {"team": team pot, "personal": each cliff's own stock} to start wave `wave` with.
static func resources(wave: int, cliffs: int, cfg: WaveConfig = Defs.WAVE_CONFIG) -> Dictionary:
	var team := float(cfg.start_scrap)
	var personal := 0.0
	if wave > 1:
		var defs: Array[BugDef] = []
		for id: StringName in Defs.active_bug_ids():
			defs.append(Defs.bug(id))
		var planner := WavePlanner.new(cfg, defs, 1234)
		for w in range(1, wave):
			# Bugs only come out while fewer than max_active_bugs are alive (the rest
			# of a pulse never spawns), so a pulse pays for at most that many kills.
			var plan := planner.plan(w)
			var pay := {}
			var count := {}
			for g: Dictionary in plan["groups"]:
				var d := Defs.bug(StringName(g["bug"]))
				if d != null:
					var k := int(g["pulse"])
					pay[k] = float(pay.get(k, 0.0)) + int(EconomyLedger.kill_pay(d.scrap_drop, d.chitin_drop)[&"scrap"]) * int(g["count"])
					count[k] = int(count.get(k, 0)) + int(g["count"])
			for k: int in pay:
				team += float(pay[k]) * minf(1.0, float(cfg.max_active_bugs) / maxf(float(count[k]), 1.0))
			team += EconomyLedger.wave_pay(w) * cliffs
			personal += EconomyLedger.heap_pay(w - 1, cfg)
	return {"team": roundi(team * (BONUS if wave > 1 else 1.0)), "personal": roundi(personal * (BONUS if wave > 1 else 1.0))}
