extends Node
## Autoload singleton (registered as `Career`). The run state that survives scene
## changes: money, the contract queue, modules unlocked in the shop, the rating
## history, and the in-flight delivery handed from the designer to the delivery
## scene. Start a fresh run with new_game(); the loop advances via record_delivery().

const CONTRACT_SET: ContractSet = preload("res://resources/contract_set.tres")
const CATALOG: ModuleCatalog = preload("res://resources/module_catalog.tres")
const STARTING_MONEY := 30000
const SAVE_PATH := "user://career.cfg"

var money: int = STARTING_MONEY
var contract_index: int = 0
var unlocked_ids: Array[String] = []   # extra module ids bought in the shop
var ratings: Array[int] = []           # stars per completed delivery

# Handoff between scenes: the designer fills these before changing to delivery.
var pending_design: ShipDesign = null
var pending_result: Dictionary = {}    # {stars, payout, notes, ...}


func new_game() -> void:
	money = STARTING_MONEY
	contract_index = 0
	unlocked_ids = []
	ratings = []
	pending_design = null
	pending_result = {}


func contracts() -> Array:
	return CONTRACT_SET.contracts


func current_contract() -> Contract:
	var list := contracts()
	if contract_index < 0 or contract_index >= list.size():
		return null
	return list[contract_index]


func is_run_complete() -> bool:
	return contract_index >= contracts().size()


func is_module_unlocked(def: ModuleDef) -> bool:
	return def.unlock_price <= 0 or unlocked_ids.has(def.id)


func locked_modules() -> Array:
	var out: Array = []
	for def in CATALOG.modules:
		if not is_module_unlocked(def):
			out.append(def)
	return out


func buy_module(def: ModuleDef) -> bool:
	if is_module_unlocked(def) or money < def.unlock_price:
		return false
	money -= def.unlock_price
	unlocked_ids.append(def.id)
	return true


## Bank the result the delivery scene computed and advance to the next contract.
func record_delivery(stars: int, payout: int) -> void:
	money += payout
	ratings.append(stars)
	contract_index += 1
	pending_design = null


# --- Save / load (run progress only — not the in-progress ship) -------------

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_run() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("run", "money", money)
	cfg.set_value("run", "contract_index", contract_index)
	cfg.set_value("run", "unlocked_ids", unlocked_ids)
	cfg.set_value("run", "ratings", ratings)
	cfg.save(SAVE_PATH)


func load_run() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return false
	money = cfg.get_value("run", "money", STARTING_MONEY)
	contract_index = cfg.get_value("run", "contract_index", 0)
	unlocked_ids.clear()
	for id in cfg.get_value("run", "unlocked_ids", []):
		unlocked_ids.append(str(id))
	ratings.clear()
	for r in cfg.get_value("run", "ratings", []):
		ratings.append(int(r))
	pending_design = null
	return true
