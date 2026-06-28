extends GdUnitTestSuite
## ShipDesign wall-morph state: set/get, clear (negative weight), cleanup when the
## host hull cell is removed, and survival across an undo snapshot roundtrip.

func test_set_and_get_wall_morph() -> void:
	var m := ShipDesign.new()
	m.set_hull(0, Vector2i(2, 2), true)
	assert_float(m.wall_morph(0, Vector2i(2, 2), Vector2i.RIGHT)).is_equal(-1.0)   # none = box
	m.set_wall_morph(0, Vector2i(2, 2), Vector2i.RIGHT, 0.6)
	assert_float(m.wall_morph(0, Vector2i(2, 2), Vector2i.RIGHT)).is_equal(0.6)


func test_negative_weight_clears_morph() -> void:
	var m := ShipDesign.new()
	m.set_wall_morph(0, Vector2i(0, 0), Vector2i.LEFT, 0.3)
	m.set_wall_morph(0, Vector2i(0, 0), Vector2i.LEFT, -1.0)
	assert_float(m.wall_morph(0, Vector2i(0, 0), Vector2i.LEFT)).is_equal(-1.0)


func test_removing_hull_cell_clears_its_wall_morph() -> void:
	var m := ShipDesign.new()
	m.set_hull(0, Vector2i(1, 1), true)
	m.set_wall_morph(0, Vector2i(1, 1), Vector2i(0, -1), 1.0)
	m.set_hull(0, Vector2i(1, 1), false)
	assert_float(m.wall_morph(0, Vector2i(1, 1), Vector2i(0, -1))).is_equal(-1.0)


func test_wall_morph_survives_undo_roundtrip() -> void:
	var m := ShipDesign.new()
	m.set_wall_morph(2, Vector2i(3, 4), Vector2i.RIGHT, 0.42)
	var m2 := ShipDesign.new()
	m2.from_dict(m.to_dict())
	assert_float(m2.wall_morph(2, Vector2i(3, 4), Vector2i.RIGHT)).is_equal(0.42)
