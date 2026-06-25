class_name ContractBrief
extends RefCounted
## Human-readable descriptions of a contract's requirements, shared by the
## briefing screen and the designer so they speak the same language. Role ids
## (ModuleDef.role) map to player-facing labels here.

const ROLE_LABELS := {
	"powerplant": "Power plant (reactor)",
	"propulsion": "Propulsion (engine)",
	"bridge": "Bridge",
	"crew": "Crew quarters",
	"cargo": "Cargo hold",
	"mining": "Mining drill",
	"sensor": "Sensor array",
}


static func role_label(role: String) -> String:
	return ROLE_LABELS.get(role, role.capitalize())


static func required_labels(contract: Contract) -> Array[String]:
	var out: Array[String] = []
	for role in contract.required_roles:
		out.append(role_label(role))
	return out
