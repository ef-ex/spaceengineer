class_name RatingConfig
extends Resource
## Tunables for delivery rating + payout (rating.gd). Feel lives in DATA — edit
## rating_config.tres, never hard-code these. A delivery that meets every hard
## requirement starts at `baseline_quality`; soft wins (budget headroom, gate
## clearance) push quality toward 1.0, which maps to more stars and more pay.

@export var min_stars: int = 1
@export var max_stars: int = 5

## Quality (0..1) awarded just for meeting all hard requirements. 0.5 -> 3 stars.
@export var baseline_quality: float = 0.5

@export_group("Soft bonuses")
## Spend this fraction under budget (or more) to earn the full headroom bonus.
@export var target_headroom: float = 0.30
@export var headroom_weight: float = 0.25
## Clear the gate by this many cells (or more) to earn the full clearance bonus.
@export var target_gate_margin: int = 2
@export var gate_margin_weight: float = 0.25

@export_group("Payout")
## payout = reward * (payout_base_frac + payout_per_star * stars).
@export var payout_base_frac: float = 0.6
@export var payout_per_star: float = 0.1
