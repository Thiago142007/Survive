extends Node
class_name Inventory

var slots: Array[Dictionary] = []  # [{ "id": String, "qty": int, "data": ItemData }]
const MAX_STACK := 100

func add_item(id: String, qty: int, data: Resource = null) -> bool:
	# First, try to stack into existing slots
	for slot in slots:
		if slot["id"] == id and slot["qty"] < MAX_STACK:
			var space: int = MAX_STACK - slot["qty"]
			var to_add := mini(qty, space)
			slot["qty"] += to_add
			qty -= to_add
			if qty <= 0:
				return true
	# Then create new slots
	while qty > 0:
		var to_add := mini(qty, MAX_STACK)
		slots.append({"id": id, "qty": to_add, "data": data})
		qty -= to_add
	return true

func remove_item(id: String, qty: int) -> bool:
	if get_count(id) < qty:
		return false
	var remaining := qty
	for i in range(slots.size() - 1, -1, -1):
		if slots[i]["id"] == id:
			var to_remove := mini(remaining, slots[i]["qty"])
			slots[i]["qty"] -= to_remove
			remaining -= to_remove
			if slots[i]["qty"] <= 0:
				slots.remove_at(i)
			if remaining <= 0:
				return true
	return true

func get_count(id: String) -> int:
	var total := 0
	for slot in slots:
		if slot["id"] == id:
			total += slot["qty"]
	return total

func get_all() -> Array[Dictionary]:
	return slots.duplicate()
