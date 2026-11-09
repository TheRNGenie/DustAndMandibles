extends SceneTree
## Prints each code-built weapon's bounding box in gun space (whole gun and
## each part), its muzzle, hands and part pivots as JSON, for fitting the fal
## models into the same space (tools/rig/prep_armory.py). No window needed.
##
##   Godot --headless --path . -s res://tools/armory/dump_boxes.gd -- --ids=a,b,c --out=<file.json>


func _initialize() -> void:
	var ids: Array = []
	var out := ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--ids="):
			ids = Array(a.substr(6).split(",", false))
		elif a.begins_with("--out="):
			out = a.substr(6)
	var res := {}
	for s: String in ids:
		var id := StringName(s)
		var p := ArmoryGuns.parts(id)
		if p.is_empty():
			continue
		var whole := AABB()
		var first := true
		var boxes := {}
		for part: String in p:
			var mesh: Mesh = p[part]
			if mesh == null:
				continue
			var b := mesh.get_aabb()
			boxes[part] = [_v(b.position), _v(b.end), _v(ArmoryGuns.pivot(id, part))]
			if part in ["glow", "ring", "trim1", "trim2"]:
				continue
			whole = b if first else whole.merge(b)
			first = false
		var hands: Array = []
		for h: Vector3 in ArmoryGuns.hands(id):
			hands.append(_v(h))
		res[s] = {"min": _v(whole.position), "max": _v(whole.end), "muzzle": _v(ArmoryGuns.muzzle(id)),
			"hands": hands, "parts": boxes}
	var txt := JSON.stringify(res, " ")
	if out != "":
		var f := FileAccess.open(out, FileAccess.WRITE)
		f.store_string(txt)
	else:
		print(txt)
	quit()


func _v(v: Vector3) -> Array:
	return [snappedf(v.x, 0.0001), snappedf(v.y, 0.0001), snappedf(v.z, 0.0001)]
