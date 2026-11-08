class_name TurretFactory
extends RefCounted
## The node class a turret id is built as (BuildManager places them): crewed
## guns, hive amber turrets, the universal crop-fed turrets (and their
## obstructions and crewed guns), or a plain Turret.


static func make(id: StringName) -> Turret:
	var d := Defs.turret(id)
	if d != null and d.universal:
		if d.crewed:
			return UniversalCrewedTurret.new()
		if d.obstruction:
			return UniversalObstruction.new()
		return UniversalTurret.new()
	if Defs.is_crewed(id):
		return CrewedTurret.new()
	if AmberRules.is_amber(id):
		return AmberTurret.new()
	return Turret.new()
