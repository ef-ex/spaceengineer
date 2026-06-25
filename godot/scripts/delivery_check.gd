class_name DeliveryCheck
extends RefCounted
## Pure pass/fail gate: can this design be delivered for this contract? Checks the
## hard requirements only (required roles present, within budget, power+heat
## satisfied, fits the gate). Soft quality lives in rating.gd. No engine state, so
## it is unit-testable in isolation. `results` is network -> NetworkSolver result.

static func validate(model: ShipDesign, contract: Contract, results: Dictionary) -> Dictionary:
	var reasons: Array[String] = []

	var filled := model.filled_roles()
	for role in contract.required_roles:
		if filled.get(role, 0) <= 0:
			reasons.append("Missing required module: %s" % role)

	var cost := model.total_cost()
	if cost > contract.budget:
		reasons.append("Over budget by ¤%d" % (cost - contract.budget))

	for net in ["power", "heat"]:
		if results.has(net) and not results[net].ok:
			reasons.append("%s network is not satisfied" % net.capitalize())

	var cs := model.cross_section()
	if cs.width == 0:
		reasons.append("No hull built")
	elif cs.width > contract.gate_width or cs.decks > contract.gate_height:
		reasons.append("Does not fit the gate: %d×%d vs %d×%d" % [
			cs.width, cs.decks, contract.gate_width, contract.gate_height])

	return {"ok": reasons.is_empty(), "reasons": reasons}
