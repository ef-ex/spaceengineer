class_name Rating
extends RefCounted
## Soft delivery quality -> star rating + payout. Assumes the contract is already
## deliverable (DeliveryCheck passed). Meeting every hard requirement earns the
## baseline; spending under budget and clearing the gate with room push it up.
## Pure + data-driven (RatingConfig) so it is unit-testable and tunable in data.

static func evaluate(model: ShipDesign, contract: Contract, cfg: RatingConfig) -> Dictionary:
	var notes: Array[String] = []
	var quality := cfg.baseline_quality

	var cost := model.total_cost()
	var headroom := 0.0
	if contract.budget > 0:
		headroom = float(contract.budget - cost) / float(contract.budget)
	var headroom_q := clampf(headroom / cfg.target_headroom, 0.0, 1.0) if cfg.target_headroom > 0.0 else 0.0
	quality += cfg.headroom_weight * headroom_q
	if headroom_q >= 1.0:
		notes.append("Well under budget")
	elif headroom <= 0.0:
		notes.append("Spent the whole budget")

	var cs := model.cross_section()
	var margin: int = contract.gate_width - int(cs.width)
	var margin_q := clampf(float(margin) / float(cfg.target_gate_margin), 0.0, 1.0) if cfg.target_gate_margin > 0 else 0.0
	quality += cfg.gate_margin_weight * margin_q
	if margin_q >= 1.0:
		notes.append("Threads the gate with ease")
	elif margin <= 0:
		notes.append("Only just fits the gate")

	quality = clampf(quality, 0.0, 1.0)
	var stars := roundi(lerpf(cfg.min_stars, cfg.max_stars, quality))
	stars = clampi(stars, cfg.min_stars, cfg.max_stars)
	var payout := roundi(contract.reward * (cfg.payout_base_frac + cfg.payout_per_star * stars))

	return {"stars": stars, "payout": payout, "quality": quality, "notes": notes}
