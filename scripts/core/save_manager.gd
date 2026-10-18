extends Node

signal save_finished(world_id: String, success: bool, message: String)

const SAVE_FORMAT_VERSION := 1
const WORLD_GENERATION_VERSION := 1
const DEFAULT_SAVE_DIRECTORY := "user://saves"

var save_directory: String = DEFAULT_SAVE_DIRECTORY
var active_world_id: String = ""

func set_active_world(world_id: String) -> void:
	active_world_id = world_id if _is_safe_world_id(world_id) else ""

func save_active_world() -> bool:
	var main := get_node_or_null("/root/Main")
	if not main or not bool(main.get("game_started")) or not main.has_method("capture_save_snapshot"):
		return false
	var snapshot: Dictionary = main.capture_save_snapshot()
	var world_id := active_world_id
	if world_id.is_empty():
		world_id = create_save(snapshot)
		if world_id.is_empty():
			save_finished.emit("", false, "Não foi possível criar o save do mundo")
			return false
		active_world_id = world_id
		main.set("world_id", world_id)
		return true
	var success := write_save(world_id, snapshot)
	if not success:
		save_finished.emit(world_id, false, "Não foi possível salvar o mundo")
	return success

func handle_world_generator_version(saved_version: int) -> Dictionary:
	if saved_version == WORLD_GENERATION_VERSION:
		return {"status": "supported", "message": "Versão de mundo compatível"}
	return {"status": "incompatible", "message": "Versão de geração incompatível; o save original foi preservado"}

func create_save(snapshot: Dictionary) -> String:
	if not _ensure_save_directory():
		return ""
	for _attempt in range(5):
		var world_id := _generate_world_id()
		if FileAccess.file_exists(_save_path(world_id)):
			continue
		if write_save(world_id, snapshot):
			return world_id
	return ""

func write_save(world_id: String, snapshot: Dictionary) -> bool:
	if not _is_safe_world_id(world_id) or not _ensure_save_directory():
		return false
	var path := _save_path(world_id)
	var backup_path := _backup_path(world_id)
	var temp_path := path + ".tmp"
	if FileAccess.file_exists(path):
		var existing := _decode_file(path)
		if not existing.get("ok", false):
			save_finished.emit(world_id, false, String(existing.get("error", "Save inválido")))
			return false

	var payload := snapshot.duplicate(true)
	payload["save_format_version"] = SAVE_FORMAT_VERSION
	payload["world_generation_version"] = WORLD_GENERATION_VERSION
	payload["world_id"] = world_id
	if not payload.has("created_at"):
		payload["created_at"] = Time.get_datetime_string_from_system(true, true)
	payload["saved_at"] = Time.get_datetime_string_from_system(true, true)
	if not payload.has("name"):
		payload["name"] = String(payload.get("world_name", "Meu mundo"))
	if not payload.has("playtime_seconds"):
		payload["playtime_seconds"] = 0.0

	var encoded := JSON.stringify(payload)
	if encoded.is_empty():
		return false
	var temp_file := FileAccess.open(temp_path, FileAccess.WRITE)
	if temp_file == null:
		return false
	temp_file.store_string(encoded)
	temp_file.flush()
	var write_error := temp_file.get_error()
	temp_file.close()
	if write_error != OK:
		DirAccess.remove_absolute(temp_path)
		return false
	var verified := _decode_file(temp_path)
	if not verified.get("ok", false):
		DirAccess.remove_absolute(temp_path)
		return false

	if FileAccess.file_exists(path):
		if FileAccess.file_exists(backup_path):
			DirAccess.remove_absolute(backup_path)
		if DirAccess.rename_absolute(path, backup_path) != OK:
			DirAccess.remove_absolute(temp_path)
			return false
	if DirAccess.rename_absolute(temp_path, path) != OK:
		if FileAccess.file_exists(backup_path) and not FileAccess.file_exists(path):
			DirAccess.rename_absolute(backup_path, path)
		DirAccess.remove_absolute(temp_path)
		return false
	save_finished.emit(world_id, true, "Salvo")
	return true

func read_save(world_id: String) -> Dictionary:
	if not _is_safe_world_id(world_id):
		return _result(false, "Identificador de mundo inválido")
	var path := _save_path(world_id)
	if not FileAccess.file_exists(path):
		return _result(false, "Save não encontrado")
	var primary := _decode_file(path)
	if primary.get("ok", false):
		return _result(true, "", primary["data"])
	if String(primary.get("error_code", "")) == "unsupported_version":
		return primary
	var backup_path := _backup_path(world_id)
	if FileAccess.file_exists(backup_path):
		var backup := _decode_file(backup_path)
		if backup.get("ok", false):
			var recovered := _result(true, "Save recuperado do backup; o arquivo principal foi preservado", backup["data"])
			recovered["recovered_from_backup"] = true
			return recovered
	return primary

func list_saves() -> Array[Dictionary]:
	var saves: Array[Dictionary] = []
	if not _ensure_save_directory():
		return saves
	var directory := DirAccess.open(save_directory)
	if directory == null:
		return saves
	for file_name in directory.get_files():
		if not file_name.ends_with(".json"):
			continue
		var world_id := file_name.trim_suffix(".json")
		if not _is_safe_world_id(world_id):
			continue
		var loaded := read_save(world_id)
		if loaded.get("ok", false):
			var data: Dictionary = loaded["data"]
			saves.append({
				"world_id": world_id,
				"name": String(data.get("name", data.get("world_name", "Meu mundo"))),
				"description": String(data.get("description", "")),
				"seed": int(data.get("seed", 0)),
				"difficulty": String(data.get("difficulty", "normal")),
				"character_id": String(data.get("character_id", "male")),
				"saved_at": String(data.get("saved_at", "")),
				"playtime_seconds": float(data.get("playtime_seconds", 0.0)),
				"recovered_from_backup": bool(loaded.get("recovered_from_backup", false)),
				"loadable": true,
				"error": String(loaded.get("error", ""))
			})
		else:
			saves.append({
				"world_id": world_id,
				"name": "Save indisponível",
				"description": "",
				"seed": 0,
				"difficulty": "",
				"character_id": "",
				"saved_at": "",
				"playtime_seconds": 0.0,
				"recovered_from_backup": false,
				"loadable": false,
				"error": String(loaded.get("error", "Save incompatível"))
			})
	saves.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a.get("saved_at", "")) > String(b.get("saved_at", "")))
	return saves

func delete_save(world_id: String) -> bool:
	if not _is_safe_world_id(world_id):
		return false
	var path := _save_path(world_id)
	var backup_path := _backup_path(world_id)
	var temp_path := path + ".tmp"
	var existed := FileAccess.file_exists(path) or FileAccess.file_exists(backup_path)
	for target in [path, backup_path, temp_path]:
		if FileAccess.file_exists(target) and DirAccess.remove_absolute(target) != OK:
			return false
	return existed

func _decode_file(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _result(false, "Não foi possível abrir o save", {}, "io_error")
	var text := file.get_as_text()
	file.close()
	var parser := JSON.new()
	var parse_error := parser.parse(text)
	if parse_error != OK or not parser.data is Dictionary:
		return _result(false, "Arquivo de save corrompido", {}, "corrupt")
	var data: Dictionary = parser.data
	var format_version := int(data.get("save_format_version", -1))
	if format_version != SAVE_FORMAT_VERSION:
		return _result(false, "Versão de save incompatível: %d" % format_version, {}, "unsupported_version")
	var generator_version := int(data.get("world_generation_version", -1))
	if generator_version != WORLD_GENERATION_VERSION:
		return _result(false, "Versão de geração incompatível: %d" % generator_version, {}, "unsupported_version")
	if not data.has("world_id") or not data.has("seed") or not data.has("difficulty"):
		return _result(false, "Save incompleto", {}, "corrupt")
	return _result(true, "", data)

func _result(ok: bool, error: String, data: Dictionary = {}, error_code: String = "") -> Dictionary:
	return {"ok": ok, "error": error, "error_code": error_code, "data": data}

func _ensure_save_directory() -> bool:
	var absolute_path := ProjectSettings.globalize_path(save_directory)
	return DirAccess.make_dir_recursive_absolute(absolute_path) == OK or DirAccess.dir_exists_absolute(absolute_path)

func _save_path(world_id: String) -> String:
	return ProjectSettings.globalize_path("%s/%s.json" % [save_directory.trim_suffix("/"), world_id])

func _backup_path(world_id: String) -> String:
	return _save_path(world_id) + ".bak"

func _is_safe_world_id(world_id: String) -> bool:
	if world_id.length() != 36:
		return false
	for index in range(world_id.length()):
		var character := world_id.substr(index, 1)
		if index in [8, 13, 18, 23]:
			if character != "-":
				return false
		elif not character in "0123456789abcdef":
			return false
	return true

func _generate_world_id() -> String:
	var bytes := Crypto.new().generate_random_bytes(16)
	if bytes.size() != 16:
		return ""
	var hex := bytes.hex_encode()
	return "%s-%s-%s-%s-%s" % [hex.substr(0, 8), hex.substr(8, 4), hex.substr(12, 4), hex.substr(16, 4), hex.substr(20, 12)]
