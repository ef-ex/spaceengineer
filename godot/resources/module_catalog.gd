class_name ModuleCatalog
extends Resource
## The set of module types available in the designer. Edit module_catalog.tres.

@export var modules: Array[ModuleDef] = []


func by_id(id: String) -> ModuleDef:
	for m in modules:
		if m.id == id:
			return m
	return null
