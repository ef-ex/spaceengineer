class_name ModuleDef
extends Resource
## One placeable interior module type. Data only — edited in module_catalog.tres.
## Networks read supply/demand off these fields by name (see network_solver.gd):
##   power: supply = power_produced, demand = power_consumed
##   heat:  supply = heat_dissipated (radiators), demand = heat_produced

@export var id: String = ""
@export var display_name: String = ""
## Footprint in grid cells (width X, depth Z). Occupies a w×d rectangle of hull.
@export var footprint: Vector2i = Vector2i.ONE
@export var color: Color = Color(0.6, 0.65, 0.75)
@export var cost: int = 0
## One-time shop price to unlock this module. 0 = available from the start.
## Modules with unlock_price > 0 stay hidden in the designer until bought.
@export var unlock_price: int = 0

@export_group("Power network")
@export var power_produced: float = 0.0
@export var power_consumed: float = 0.0

@export_group("Heat network")
@export var heat_produced: float = 0.0
@export var heat_dissipated: float = 0.0

## Contract role this module satisfies (e.g. "powerplant", "bridge", "crew").
## Empty = satisfies no required-module slot.
@export var role: String = ""
