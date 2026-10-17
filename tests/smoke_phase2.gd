extends SceneTree

func _init() -> void:
	var player := Node.new()
	var inventory: Node = load("res://scripts/inventory/inventory.gd").new()
	var crafting: Node = load("res://scripts/crafting/crafting_system.gd").new()
	var research: Node = load("res://scripts/progression/research_system.gd").new()
	inventory.name = "Inventory"
	crafting.name = "CraftingSystem"
	research.name = "ResearchSystem"
	player.add_child(inventory)
	player.add_child(crafting)
	player.add_child(research)

	inventory.add_item("wood", 10)
	inventory.add_item("stone", 10)
	assert(inventory.get_count("wood") == 10)
	assert(inventory.get_count("stone") == 10)
	assert(crafting.craft("stone_axe"))
	assert(inventory.get_count("stone_axe") == 1)
	assert(inventory.get_count("wood") == 5)
	assert(inventory.get_count("stone") == 7)
	research.add_experience(25)
	assert(research.level == 2)
	assert(research.research_points == 1)
	assert(not research.unlock("stone_building"))
	print("Phase 2 smoke test: PASS")
	player.free()
	quit()
