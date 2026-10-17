extends Node

signal inventory_changed
signal craft_failed(message: String)

const RECIPES := {
	"stone_axe": {"name": "Machado de pedra", "result": "stone_axe", "amount": 1, "cost": {"wood": 5, "stone": 3}},
	"stone_pickaxe": {"name": "Picareta de pedra", "result": "stone_pickaxe", "amount": 1, "cost": {"wood": 4, "stone": 4}},
	"knife": {"name": "Faca simples", "result": "knife", "amount": 1, "cost": {"wood": 3, "stone": 2}},
	"campfire": {"name": "Fogueira", "result": "campfire", "amount": 1, "cost": {"wood": 10, "stone": 5}}
}

func get_recipes() -> Dictionary:
	return RECIPES

func craft(recipe_id: String) -> bool:
	if not RECIPES.has(recipe_id):
		craft_failed.emit("Receita desconhecida")
		return false
	var recipe: Dictionary = RECIPES[recipe_id]
	var inventory: Node = get_parent().get_node("Inventory")
	for resource_id in recipe["cost"]:
		if inventory.get_count(resource_id) < recipe["cost"][resource_id]:
			craft_failed.emit("Recursos insuficientes")
			return false
	for resource_id in recipe["cost"]:
		inventory.remove_item(resource_id, recipe["cost"][resource_id])
	inventory.add_item(recipe["result"], recipe["amount"])
	inventory_changed.emit()
	return true
