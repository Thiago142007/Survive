extends SceneTree

const AUDIO_PATHS: Array[String] = [
	"res://assets/audio/sfx/wood_hit_01.ogg",
	"res://assets/audio/sfx/wood_hit_02.ogg",
	"res://assets/audio/sfx/wood_hit_03.ogg",
	"res://assets/audio/sfx/stone_hit_01.ogg",
	"res://assets/audio/sfx/stone_hit_02.ogg",
	"res://assets/audio/sfx/stone_hit_03.ogg",
	"res://assets/audio/sfx/animal_hit_01.ogg",
	"res://assets/audio/sfx/animal_hit_02.ogg",
	"res://assets/audio/sfx/animal_hit_03.ogg",
	"res://assets/audio/sfx/footstep_grass_01.ogg",
	"res://assets/audio/sfx/footstep_grass_02.ogg",
	"res://assets/audio/sfx/footstep_grass_03.ogg",
	"res://assets/audio/sfx/footstep_grass_04.ogg",
	"res://assets/audio/sfx/build_place_01.ogg",
	"res://assets/audio/sfx/build_place_02.ogg",
	"res://assets/audio/sfx/build_remove_01.ogg",
	"res://assets/audio/sfx/build_remove_02.ogg",
	"res://assets/audio/sfx/player_hurt_01.ogg",
	"res://assets/audio/sfx/player_hurt_02.ogg",
	"res://assets/audio/sfx/player_down.ogg",
	"res://assets/audio/sfx/animal_death.ogg",
	"res://assets/audio/sfx/attack_swing_01.ogg",
	"res://assets/audio/sfx/attack_swing_02.ogg",
	"res://assets/audio/sfx/repair.ogg",
	"res://assets/audio/sfx/upgrade.ogg",
	"res://assets/audio/sfx/collect.ogg",
	"res://assets/audio/ui/ui_click.ogg",
	"res://assets/audio/ui/ui_confirm.ogg",
	"res://assets/audio/ui/ui_error.ogg",
	"res://assets/audio/ambience/ocean_loop.ogg",
	"res://assets/audio/ambience/wind_loop.ogg",
]

const TEXTURE_PATHS: Array[String] = [
	"res://assets/vfx/textures/dirt_01.png",
	"res://assets/vfx/textures/smoke_03.png",
	"res://assets/vfx/textures/spark_05.png",
	"res://assets/vfx/textures/slash_03.png",
]

func _init() -> void:
	for path in AUDIO_PATHS:
		assert(ResourceLoader.exists(path), "Missing curated audio: %s" % path)
		assert(load(path) is AudioStream, "Curated audio must load: %s" % path)
	for path in TEXTURE_PATHS:
		assert(ResourceLoader.exists(path), "Missing curated texture: %s" % path)
		assert(load(path) is Texture2D, "Curated texture must load: %s" % path)
	assert(FileAccess.file_exists("res://docs/THIRD_PARTY_ASSETS.md"), "Asset provenance document is required")
	for bus_name in [&"SFX", &"Ambience", &"UI"]:
		assert(AudioServer.get_bus_index(bus_name) >= 0, "Missing audio bus: %s" % bus_name)
	print("Effect asset preflight: PASS")
	quit()
