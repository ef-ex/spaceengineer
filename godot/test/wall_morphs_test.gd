extends GdUnitTestSuite
## ShipDesign wall-morph weights: per-morph set/get (index = blend-shape index), zero-padding when a
## higher index is set, cleanup when the host hull cell is removed, and survival across an undo
## snapshot roundtrip.

func test_set_and_get_wall_weights() -> void:
	var m := ShipDesign.new()
	m.set_hull(0, Vector2i(2, 2), true)
	assert_array(m.wall_weights(0, Vector2i(2, 2), Vector2i.RIGHT)).is_empty()   # unset = all zero
	m.set_wall_weight(0, Vector2i(2, 2), Vector2i.RIGHT, 0, 0.6)
	m.set_wall_weight(0, Vector2i(2, 2), Vector2i.RIGHT, 1, 0.3)
	var w := m.wall_weights(0, Vector2i(2, 2), Vector2i.RIGHT)
	assert_float(w[0]).is_equal(0.6)
	assert_float(w[1]).is_equal(0.3)


func test_setting_higher_index_pads_with_zero() -> void:
	var m := ShipDesign.new()
	m.set_wall_weight(0, Vector2i(0, 0), Vector2i.LEFT, 2, 0.5)
	var w := m.wall_weights(0, Vector2i(0, 0), Vector2i.LEFT)
	assert_int(w.size()).is_equal(3)
	assert_float(w[0]).is_equal(0.0)
	assert_float(w[2]).is_equal(0.5)


func test_removing_hull_cell_clears_its_wall_weights() -> void:
	var m := ShipDesign.new()
	m.set_hull(0, Vector2i(1, 1), true)
	m.set_wall_weight(0, Vector2i(1, 1), Vector2i(0, -1), 0, 1.0)
	m.set_hull(0, Vector2i(1, 1), false)
	assert_array(m.wall_weights(0, Vector2i(1, 1), Vector2i(0, -1))).is_empty()


func test_wall_weights_survive_undo_roundtrip() -> void:
	var m := ShipDesign.new()
	m.set_wall_weight(2, Vector2i(3, 4), Vector2i.RIGHT, 1, 0.42)
	var m2 := ShipDesign.new()
	m2.from_dict(m.to_dict())
	assert_float(m2.wall_weights(2, Vector2i(3, 4), Vector2i.RIGHT)[1]).is_equal(0.42)
