extends GdUnitTestSuite
## The hard-requirement deliver gate. Network results are fabricated here so the
## test isolates DeliveryCheck's own logic from the solver (covered separately).

const CATALOG: ModuleCatalog = preload("res://resources/module_catalog.tres")
const GOOD := {"power": {"ok": true}, "heat": {"ok": true}}


func _contract() -> Contract:
	var c := Contract.new()
	c.budget = 50000
	c.gate_width = 6
	c.gate_height = 2
	c.required_roles = ["powerplant", "propulsion"] as Array[String]
	return c


func _deliverable() -> ShipDesign:
	# 4x2 hull (cross-section 2x1), reactor + engine -> both required roles, ¤20k.
	var m := ShipDesign.new()
	m.bind_catalog(CATALOG)
	for x in range(4):
		for z in range(2):
			m.set_hull(0, Vector2i(x, z), true)
	m.place_module(0, CATALOG.by_id("reactor"), Vector2i(0, 0))
	m.place_module(0, CATALOG.by_id("engine"), Vector2i(2, 0))
	return m


func test_complete_design_is_deliverable() -> void:
	var res := DeliveryCheck.validate(_deliverable(), _contract(), GOOD)
	assert_bool(res.ok).is_true()
	assert_array(res.reasons).is_empty()


func test_missing_required_role_blocks() -> void:
	var m := _deliverable()
	m.remove_module_at(0, Vector2i(2, 0))    # drop the engine -> no propulsion
	var res := DeliveryCheck.validate(m, _contract(), GOOD)
	assert_bool(res.ok).is_false()


func test_over_budget_blocks() -> void:
	var c := _contract()
	c.budget = 10000                          # below the ¤20k build cost
	assert_bool(DeliveryCheck.validate(_deliverable(), c, GOOD).ok).is_false()


func test_too_big_for_gate_blocks() -> void:
	var c := _contract()
	c.gate_width = 1                          # cross-section is 2 wide
	assert_bool(DeliveryCheck.validate(_deliverable(), c, GOOD).ok).is_false()


func test_failing_network_blocks() -> void:
	var bad := {"power": {"ok": false}, "heat": {"ok": true}}
	assert_bool(DeliveryCheck.validate(_deliverable(), _contract(), bad).ok).is_false()
