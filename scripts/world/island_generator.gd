extends Node3D

## Gera um arquipélago pequeno e determinístico para a primeira versão jogável.
## A mesma seed sempre produz os mesmos centros e tamanhos de ilha.
@export var seed: int = 55960
@export var island_count: int = 6
@export var ring_distance: float = 180.0

const ISLAND_HEIGHT := 2.5
const WATER_SIZE := 900.0

func _ready() -> void:
	_generate_water()
	_generate_islands()

func _generate_water() -> void:
	var water := MeshInstance3D.new()
	water.name = "Ocean"
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(WATER_SIZE, WATER_SIZE)
	water.mesh = mesh
	add_child(water)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#163c58")
	material.roughness = 0.85
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = material
	water.position.y = -0.3

func _generate_islands() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	_create_island(Vector3.ZERO, 48.0, "central")
	for index in range(1, island_count):
		var angle := (TAU / float(island_count - 1)) * float(index - 1)
		angle += rng.randf_range(-0.18, 0.18)
		var distance := rng.randf_range(ring_distance * 0.75, ring_distance * 1.25)
		var radius := rng.randf_range(28.0, 44.0)
		var center := Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)
		_create_island(center, radius, "island_%d" % index)

func _create_island(center: Vector3, radius: float, island_name: String) -> void:
	var island := StaticBody3D.new()
	island.name = island_name
	island.position = center + Vector3(0.0, -ISLAND_HEIGHT * 0.5, 0.0)
	var mesh_instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.92
	mesh.bottom_radius = radius
	mesh.height = ISLAND_HEIGHT
	mesh.radial_segments = 12
	mesh_instance.mesh = mesh
	island.add_child(mesh_instance)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#4c6248") if island_name == "central" else Color("#596d4a")
	material.roughness = 1.0
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = material
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = ISLAND_HEIGHT
	collision.shape = shape
	island.add_child(collision)
	add_child(island)
