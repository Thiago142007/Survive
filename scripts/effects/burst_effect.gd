extends Node3D
class_name BurstEffect

signal burst_finished(effect: Node3D)

var active := false
var _lifetime_timer: Timer

func _ready() -> void:
	visible = false
	_lifetime_timer = Timer.new()
	_lifetime_timer.one_shot = true
	_lifetime_timer.timeout.connect(deactivate)
	add_child(_lifetime_timer)

func restart_at(world_position: Vector3) -> void:
	active = true
	global_position = world_position
	visible = true
	var longest_lifetime := 0.0
	for node in find_children("*", "CPUParticles3D", true, false):
		var emitter := node as CPUParticles3D
		longest_lifetime = maxf(longest_lifetime, emitter.lifetime)
		emitter.restart()
		emitter.emitting = true
	_lifetime_timer.start(longest_lifetime)

func deactivate() -> void:
	if not active:
		return
	active = false
	_lifetime_timer.stop()
	for node in find_children("*", "CPUParticles3D", true, false):
		var emitter := node as CPUParticles3D
		emitter.emitting = false
	visible = false
	burst_finished.emit(self)
