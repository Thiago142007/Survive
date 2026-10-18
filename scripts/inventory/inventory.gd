extends Node
class_name Inventory

var slots: Array[Dictionary] = []  # [{ "id": String, "qty": int, "data": ItemData }]
const MAX_STACK := 100
signal changed

func add_item(id: String, qty: int, data: Resource = null) -> bool:
	# First, try to stack into existing slots
	for slot in slots:
		if slot["id"] == id and slot["qty"] < MAX_STACK:
			var space: int = MAX_STACK - slot["qty"]
			var to_add := mini(qty, space)
			slot["qty"] += to_add
			qty -= to_add
			if qty <= 0:
				changed.emit()
				return true
	# Then create new slots
	while qty > 0:
		var to_add := mini(qty, MAX_STACK)
		slots.append({"id": id, "qty": to_add, "data": data})
		qty -= to_add
	changed.emit()
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
				changed.emit()
				return true
	changed.emit()
	return true

func clear() -> void:
	slots.clear()
	changed.emit()

func get_count(id: String) -> int:
	var total := 0
	for slot in slots:
		if slot["id"] == id:
			total += slot["qty"]
	return total

func get_all() -> Array[Dictionary]:
	return slots.duplicate()

func get_save_state() -> Array[Dictionary]:
	var saved_slots: Array[Dictionary] = []
	for slot in slots:
		var saved_slot := {
			"id": String(slot.get("id", "")),
			"qty": int(slot.get("qty", 0))
		}
		var item_state: Variant = slot.get("state", {})
		if item_state is Dictionary or item_state is Array:
			saved_slot["state"] = item_state.duplicate(true)
		saved_slots.append(saved_slot)
	return saved_slots

func apply_save_state(saved_slots: Array[Dictionary]) -> void:
	slots.clear()
	for saved_slot in saved_slots:
		var item_id := String(saved_slot.get("id", ""))
		var quantity := int(saved_slot.get("qty", 0))
		if item_id.is_empty() or quantity <= 0:
			continue
		var slot := {"id": item_id, "qty": quantity, "data": null}
		var item_state: Variant = saved_slot.get("state", {})
		if item_state is Dictionary or item_state is Array:
			slot["state"] = item_state.duplicate(true)
		slots.append(slot)
	changed.emit()
