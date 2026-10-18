extends Node

signal progress_changed
signal level_up(level: int, points: int)

var level: int = 1
var experience: int = 0
var research_points: int = 0
var unlocked: Dictionary = {"basic_tools": true}

const NODES := {
	"stone_building": {"name": "Construção de pedra", "cost": 2, "description": "Libera receitas de pedra."},
	"agriculture": {"name": "Agricultura", "cost": 3, "description": "Libera sementes e cultivo."},
	"metalworking": {"name": "Metalurgia", "cost": 5, "description": "Libera ferramentas e peças de metal."}
}

func add_experience(amount: int) -> void:
	experience += maxi(0, amount)
	var required := level * 25
	while experience >= required:
		experience -= required
		level += 1
		research_points += 1
		required = level * 25
		level_up.emit(level, research_points)
	progress_changed.emit()

func can_unlock(node_id: String) -> bool:
	return NODES.has(node_id) and not unlocked.has(node_id) and research_points >= NODES[node_id]["cost"]

func unlock(node_id: String) -> bool:
	if not can_unlock(node_id):
		return false
	research_points -= NODES[node_id]["cost"]
	unlocked[node_id] = true
	progress_changed.emit()
	return true

func get_nodes() -> Dictionary:
	return NODES

func get_save_state() -> Dictionary:
	return {
		"level": level,
		"experience": experience,
		"research_points": research_points,
		"unlocked": unlocked.duplicate(true)
	}

func apply_save_state(state: Dictionary) -> void:
	level = maxi(1, int(state.get("level", 1)))
	experience = maxi(0, int(state.get("experience", 0)))
	research_points = maxi(0, int(state.get("research_points", 0)))
	var saved_unlocks: Variant = state.get("unlocked", {"basic_tools": true})
	unlocked = saved_unlocks.duplicate(true) if saved_unlocks is Dictionary else {"basic_tools": true}
	if not unlocked.has("basic_tools"):
		unlocked["basic_tools"] = true
	progress_changed.emit()
