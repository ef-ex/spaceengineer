extends GdUnitTestSuite
## ShipDesign wall-skin state: set/clear, cleanup when the host hull cell is removed,
## and survival across an undo snapshot roundtrip.

func test_set_and_get_wall_skin() -> void:
	var m := ShipDesign.new()
	m.set_hull(0, Vector2i(2, 2), true)
	assert_str(m.wall_skin(0, Vector2i(2, 2), Vector2i.RIGHT)).is_equal("")
	m.set_wall_skin(0, Vector2i(2, 2), Vector2i.RIGHT, "armor")
	assert_str(m.wall_skin(0, Vector2i(2, 2), Vector2i.RIGHT)).is_equal("armor")


func test_empty_id_clears_skin() -> void:
	var m := ShipDesign.new()
	m.set_wall_skin(0, Vector2i(0, 0), Vector2i.LEFT, "window")
	m.set_wall_skin(0, Vector2i(0, 0), Vector2i.LEFT, "")
	assert_str(m.wall_skin(0, Vector2i(0, 0), Vector2i.LEFT)).is_equal("")


func test_removing_hull_cell_clears_its_wall_skins() -> void:
	var m := ShipDesign.new()
	m.set_hull(0, Vector2i(1, 1), true)
	m.set_wall_skin(0, Vector2i(1, 1), Vector2i(0, -1), "vent")
	m.set_hull(0, Vector2i(1, 1), false)
	assert_str(m.wall_skin(0, Vector2i(1, 1), Vector2i(0, -1))).is_equal("")


func test_wall_skins_survive_undo_roundtrip() -> void:
	var m := ShipDesign.new()
	m.set_wall_skin(2, Vector2i(3, 4), Vector2i.RIGHT, "armor")
	var m2 := ShipDesign.new()
	m2.from_dict(m.to_dict())
	assert_str(m2.wall_skin(2, Vector2i(3, 4), Vector2i.RIGHT)).is_equal("armor")
