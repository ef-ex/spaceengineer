extends GdUnitTestSuite
## Geometry semantics on ShipDesign: beam is measured across the fixed forward
## axis (+X), and deck span covers the highest occupied deck.

const CAT: ModuleCatalog = preload("res://resources/module_catalog.tres")


func test_beam_is_perpendicular_to_forward() -> void:
	# Forward is +X, so a hull narrow in X (2) but long in Z (5) has beam 5, not 2.
	var m := ShipDesign.new()
	m.bind_catalog(CAT)
	for z in range(5):
		m.set_hull(0, Vector2i(0, z), true)
		m.set_hull(0, Vector2i(1, z), true)
	var cs := m.cross_section()
	assert_int(cs.width).is_equal(5)
	assert_int(cs.decks).is_equal(1)


func test_deck_span_counts_to_highest_deck() -> void:
	var m := ShipDesign.new()
	m.bind_catalog(CAT)
	m.set_hull(0, Vector2i(0, 0), true)
	m.set_hull(2, Vector2i(0, 0), true)
	assert_int(m.deck_span()).is_equal(3)


func test_rotated_module_occupies_swapped_cells() -> void:
	# Engine footprint is 1x2; a quarter-turn makes it 2x1, so it covers (0,0)+(1,0).
	assert_that(ShipDesign.rotated_footprint(Vector2i(1, 2), 1)).is_equal(Vector2i(2, 1))
	var m := ShipDesign.new()
	m.bind_catalog(CAT)
	m.place_module(0, CAT.by_id("engine"), Vector2i(0, 0), 1)
	assert_bool(m.module_at(0, Vector2i(1, 0)).is_empty()).is_false()  # covered
	assert_bool(m.module_at(0, Vector2i(0, 1)).is_empty()).is_true()   # not covered
