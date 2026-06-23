class_name Contract
extends Resource
## A client commission: what the ship must satisfy. Data only — edit the .tres.

@export var title: String = ""
@export var client: String = ""
## Spend ceiling (sum of module costs must not exceed this).
@export var budget: int = 0

@export_group("Gate")
## The ship's cross-section (its narrower horizontal extent × deck count) must
## fit through the gate. Rewards long, thin hulls — the threading fantasy.
@export var gate_width: int = 0    # cells
@export var gate_height: int = 0   # decks

@export_group("Requirements")
## Module roles the ship must include (see ModuleDef.role), e.g.
## ["powerplant", "bridge", "propulsion"].
@export var required_roles: Array[String] = []
