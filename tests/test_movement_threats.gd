extends TestCase
## Movement threats (MovementThreats): nothing a wave leaves behind lingers into
## the build phase (playtest fixes, Nov 11: acid nests kept eating turrets).


func test_build_phase_clears_nests_and_glints() -> void:
	var mt := MovementThreats.new()
	var nest := MovementThreats.AcidNest.new()
	nest.add_to_group("bug_hazards")
	mt.add_child(nest)
	var glint := MovementThreats.GlintBeetle.new()
	mt.add_child(glint)
	var keep := Node.new()
	mt.add_child(keep)
	mt._clear_hazards()
	assert_true(nest.is_queued_for_deletion(), "the nest goes")
	assert_true(glint.is_queued_for_deletion(), "the glint goes")
	assert_false(keep.is_queued_for_deletion(), "nothing else does")
	mt.free()
