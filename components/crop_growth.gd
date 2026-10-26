class_name CropGrowth
extends RefCounted
## Pure crop logic for one plot (no nodes, so it can be unit-tested):
## plant -> water -> grows while watered -> ripe -> harvest.
## An unwatered crop pauses; it never dies. One watering lasts the whole growth.

enum Stage { EMPTY, PLANTED, GROWING, RIPE }

var crop: CropDef
var stage: Stage = Stage.EMPTY
var progress: float = 0.0 # seconds of watered growth
var watered := false


func plant(def: CropDef) -> bool:
	if stage != Stage.EMPTY:
		return false
	crop = def
	stage = Stage.PLANTED
	progress = 0.0
	watered = false
	return true


func water() -> bool:
	if stage != Stage.PLANTED or watered:
		return false
	watered = true
	stage = Stage.GROWING
	return true


## Advances growth by `seconds` (only while watered). `rain` waters the crop and
## multiplies growth; `frost` (per second) eats progress off growing crops.
func tick(seconds: float, rain: float = 0.0, frost: float = 0.0) -> void:
	if rain > 0.0 and stage == Stage.PLANTED:
		watered = true
		stage = Stage.GROWING
	if stage != Stage.GROWING or not watered:
		return
	if frost > 0.0:
		progress = maxf(progress - frost * seconds, 0.0)
		return
	progress += seconds * (rain if rain > 0.0 else 1.0)
	if progress >= crop.grow_time:
		progress = crop.grow_time
		stage = Stage.RIPE


func fraction() -> float:
	if crop == null:
		return 0.0
	return clampf(progress / maxf(crop.grow_time, 0.001), 0.0, 1.0)


## Returns the harvest (empty if not ripe) and clears the plot.
func harvest() -> Dictionary:
	if stage != Stage.RIPE:
		return {}
	var out := crop.harvest.duplicate()
	clear()
	return out


## A Crop Weevil ate it.
func clear() -> void:
	stage = Stage.EMPTY
	progress = 0.0
	watered = false
