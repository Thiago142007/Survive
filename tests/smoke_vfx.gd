extends SceneTree

const SCENES: Array[String] = [
	"res://scenes/effects/dust_burst.tscn",
	"res://scenes/effects/wood_splinters.tscn",
	"res://scenes/effects/stone_sparks.tscn",
	"res://scenes/effects/damage_burst.tscn",
	"res://scenes/effects/slash_burst.tscn",
]

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	for path in SCENES:
		if not _require(ResourceLoader.exists(path), "Missing VFX scene: %s" % path):
			return
		var packed := load(path) as PackedScene
		if not _require(packed != null, "VFX scene must load: %s" % path):
			return
		var instance := packed.instantiate() as Node3D
		root.add_child(instance)
		if not _require(instance.get_script().get_global_name() == &"BurstEffect", "VFX root must use BurstEffect: %s" % path):
			return
		if not _require(instance.find_children("*", "GPUParticles3D", true, false).is_empty(), "VFX must not use GPU particles: %s" % path):
			return
		var emitters := instance.find_children("*", "CPUParticles3D", true, false)
		if not _require(not emitters.is_empty(), "VFX needs a CPU particle emitter: %s" % path):
			return
		var total_amount := 0
		var max_lifetime := 0.0
		for emitter in emitters:
			total_amount += (emitter as CPUParticles3D).amount
			max_lifetime = maxf(max_lifetime, (emitter as CPUParticles3D).lifetime)
		if not _require(total_amount <= 16, "VFX particle budget exceeded: %s" % path):
			return
		if not _require(max_lifetime <= 0.8, "VFX lifetime budget exceeded: %s" % path):
			return
		instance.free()

	var effects := root.get_node_or_null("Effects")
	if not _require(effects != null, "Effects autoload must exist"):
		return
	for index in range(30):
		if not _require(effects.spawn_vfx(&"dust", Vector3(index, 0, 0)), "Known VFX must spawn"):
			return
	if not _require(effects.get_active_vfx_count() > 0 and effects.get_active_vfx_count() <= 24, "VFX pool must remain bounded at 24"):
		return
	await create_timer(1.0).timeout
	if not _require(effects.get_active_vfx_count() == 0, "Completed VFX must return to the inactive pool"):
		return
	print("VFX smoke test: PASS")
	quit()

func _require(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false
