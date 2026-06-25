extends GdUnitTestSuite
## Rating + payout maths against the default RatingConfig. Meeting hard reqs is
## 3 stars; budget headroom + gate clearance push toward 5.

const CATALOG: ModuleCatalog = preload("res://resources/module_catalog.tres")


func _model_2x2() -> ShipDesign:
	# Smallest useful design: a 2x2 hull (cross-section width 2) with one reactor (¤12k).
	var m := ShipDesign.new()
	m.bind_catalog(CATALOG)
	for x in range(2):
		for z in range(2):
			m.set_hull(0, Vector2i(x, z), true)
	m.place_module(0, CATALOG.by_id("reactor"), Vector2i(0, 0))
	return m


func test_thrifty_roomy_build_earns_five_stars() -> void:
	var c := Contract.new()
	c.budget = 100000        # ¤12k spent -> huge headroom
	c.reward = 10000
	c.gate_width = 10        # width 2 -> margin 8
	c.gate_height = 2
	var res := Rating.evaluate(_model_2x2(), c, RatingConfig.new())
	assert_int(res.stars).is_equal(5)
	assert_int(res.payout).is_equal(11000)   # 10000 * (0.6 + 0.1*5)


func test_just_meeting_spec_earns_three_stars() -> void:
	var c := Contract.new()
	c.budget = 12000         # exactly the build cost -> no headroom
	c.reward = 10000
	c.gate_width = 2         # width 2 -> no margin
	c.gate_height = 2
	var res := Rating.evaluate(_model_2x2(), c, RatingConfig.new())
	assert_int(res.stars).is_equal(3)
	assert_int(res.payout).is_equal(9000)    # 10000 * (0.6 + 0.1*3)
