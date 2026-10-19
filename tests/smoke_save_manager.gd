extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var manager := root.get_node_or_null("SaveManager")
	if not _expect(manager != null, "SaveManager autoload must be available"):
		return
	for method_name in ["create_save", "write_save", "read_save", "list_saves", "delete_save", "get_thumbnail_path", "write_world_thumbnail", "load_world_thumbnail"]:
		if not _expect(manager.has_method(method_name), "SaveManager must expose %s" % method_name):
			return
	manager.set("save_directory", "user://test_save_manager")
	_cleanup_test_directory()

	var first_snapshot := {"world_name": "Ilha", "seed": 123, "difficulty": "easy", "marker": "first"}
	var first_id: String = manager.create_save(first_snapshot)
	if not _expect(not first_id.is_empty(), "First save must be created"):
		return
	var second_id: String = manager.create_save(first_snapshot)
	if not _expect(not second_id.is_empty() and second_id != first_id, "Same-named worlds need independent IDs"):
		return
	if not _expect(manager.write_save(first_id, first_snapshot.duplicate()), "Existing save must be writable"):
		return

	var loaded: Dictionary = manager.read_save(first_id)
	if not _expect(loaded.get("ok", false) and loaded.get("data", {}).get("marker") == "first", "Save round-trip must retain payload"):
		return
	var saves: Array = manager.list_saves()
	if not _expect(saves.size() == 2, "Listing must return both independent worlds"):
		return
	if not _expect(manager.get_thumbnail_path(first_id) == "user://saves/%s.jpg" % first_id, "Safe IDs must use the canonical thumbnail path"):
		return
	if not _expect(manager.get_thumbnail_path("../../outside") == "", "Unsafe IDs must not produce thumbnail paths"):
		return
	if not _expect(manager.load_world_thumbnail(first_id) == null, "Missing thumbnails must load as null"):
		return
	var generated_image := Image.create(960, 540, false, Image.FORMAT_RGB8)
	generated_image.fill(Color(0.8, 0.35, 0.12))
	if not _expect(manager.write_world_thumbnail(first_id, generated_image), "A valid image must be stored as a thumbnail"):
		return
	var thumbnail := manager.load_world_thumbnail(first_id) as Texture2D
	if not _expect(thumbnail != null and thumbnail.get_width() == 480 and thumbnail.get_height() == 270, "Stored thumbnail must be a decodable 480x270 image"):
		return
	var listed_with_thumbnail: Array = manager.list_saves()
	var first_entry: Dictionary = {}
	var second_entry: Dictionary = {}
	for entry in listed_with_thumbnail:
		if String(entry.get("world_id", "")) == first_id:
			first_entry = entry
		elif String(entry.get("world_id", "")) == second_id:
			second_entry = entry
	if not _expect(String(first_entry.get("thumbnail_path", "")) == manager.get_thumbnail_path(first_id), "Readable thumbnail path must be exposed by save listing"):
		return
	if not _expect(String(second_entry.get("thumbnail_path", "")) == "", "Legacy saves without thumbnails must list an empty thumbnail path"):
		return
	var original_jpeg := FileAccess.get_file_as_bytes(_thumbnail_path(first_id))
	var invalid_image := Image.new()
	if not _expect(not manager.write_world_thumbnail(first_id, invalid_image), "Invalid images must not be written"):
		return
	if not _expect(FileAccess.get_file_as_bytes(_thumbnail_path(first_id)) == original_jpeg, "Invalid image writes must preserve the previous thumbnail"):
		return
	var corrupt_thumbnail := FileAccess.open(_thumbnail_path(second_id), FileAccess.WRITE)
	if not _expect(corrupt_thumbnail != null, "Test must be able to write an isolated corrupt image"):
		return
	corrupt_thumbnail.store_string("not an image")
	corrupt_thumbnail.close()
	if not _expect(manager.load_world_thumbnail(second_id) == null, "Corrupt thumbnails must load as null"):
		return

	var first_path := _save_path(first_id)
	var corrupt_file := FileAccess.open(first_path, FileAccess.WRITE)
	if not _expect(corrupt_file != null, "Test must be able to write isolated corrupt fixture"):
		return
	corrupt_file.store_string("{broken json")
	corrupt_file.close()
	var corrupt_before := FileAccess.get_file_as_string(first_path)
	var recovered: Dictionary = manager.read_save(first_id)
	if not _expect(recovered.get("ok", false) and recovered.get("recovered_from_backup", false), "Valid backup must recover a corrupt primary"):
		return
	if not _expect(FileAccess.get_file_as_string(first_path) == corrupt_before, "Reading a corrupt save must not overwrite it"):
		return

	var second_path := _save_path(second_id)
	var unsupported_file := FileAccess.open(second_path, FileAccess.WRITE)
	if not _expect(unsupported_file != null, "Test must be able to write isolated unsupported fixture"):
		return
	unsupported_file.store_string(JSON.stringify({"save_format_version": 999, "world_generation_version": 1}))
	unsupported_file.close()
	var unsupported_before := FileAccess.get_file_as_string(second_path)
	var unsupported: Dictionary = manager.read_save(second_id)
	if not _expect(not unsupported.get("ok", true), "Unsupported save version must be rejected"):
		return
	if not _expect(FileAccess.get_file_as_string(second_path) == unsupported_before, "Unsupported save must remain unchanged"):
		return
	var listed_after_corruption: Array = manager.list_saves()
	var unsupported_entry: Dictionary = {}
	for entry in listed_after_corruption:
		if String(entry.get("world_id", "")) == second_id:
			unsupported_entry = entry
	if not _expect(not unsupported_entry.is_empty() and not bool(unsupported_entry.get("loadable", true)), "Unsupported saves must remain visible as non-loadable entries so users can remove them"):
		return

	if not _expect(manager.delete_save(first_id), "Selected world must be deletable"):
		return
	if not _expect(not FileAccess.file_exists(first_path) and FileAccess.file_exists(second_path), "Deleting one world must not delete another"):
		return
	if not _expect(not FileAccess.file_exists(_thumbnail_path(first_id)) and FileAccess.file_exists(_thumbnail_path(second_id)), "Deleting a world must remove only its matching thumbnail"):
		return
	DirAccess.remove_absolute(_thumbnail_path(second_id))

	_cleanup_test_directory()
	print("Save manager smoke test: PASS")
	quit()

func _save_path(world_id: String) -> String:
	return ProjectSettings.globalize_path("user://test_save_manager/%s.json" % world_id)

func _thumbnail_path(world_id: String) -> String:
	return ProjectSettings.globalize_path("user://saves/%s.jpg" % world_id)

func _cleanup_test_directory() -> void:
	var directory := DirAccess.open("user://test_save_manager")
	if directory:
		for file_name in directory.get_files():
			directory.remove(file_name)
		directory = null
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save_manager"))

func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false
