extends RefCounted

## Stable conversion independent of Godot's Variant hash implementation.
static func parse(value: String) -> int:
	var normalized := value.strip_edges()
	if normalized.is_valid_int():
		return int(normalized)
	var result: int = 2166136261
	for byte in normalized.to_utf8_buffer():
		result = ((result ^ int(byte)) * 16777619) & 0xffffffff
	return result

static func derive(world_seed: int, system: String, index: int = 0) -> int:
	return parse("%d:%s:%d" % [world_seed, system, index])
