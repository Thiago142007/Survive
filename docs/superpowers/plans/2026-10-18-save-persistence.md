# Save Persistence Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Persist independently named procedural single-player worlds and restore all existing persistent player/world state safely.

**Architecture:** Keep seeded generation as the base world, then overlay a versioned registry of stable-ID changes for resources and animals. A SaveManager autoload owns versioned JSON files and atomic backup writes; the Main/autoload and world/player components expose capture/restore APIs.

**Tech Stack:** Godot 4.3, GDScript, `FileAccess`, `DirAccess`, JSON, Godot `SceneTree` smoke scripts.

**Spec:** `docs/superpowers/specs/2026-10-18-save-system-main-menu-and-player-models-design.md`

## Global Constraints

- Do not serialize the live scene tree; deterministic procedural generation is the base world and a versioned snapshot overlays persistent changes.
- Store each world independently under `user://saves/<world-id>.json` with `save_format_version` and `world_generation_version`.
- Write a temporary file in the same directory, retain a previous `.bak`, and never silently overwrite a corrupt or unsupported save.
- Save player position/body yaw/camera pitch and mode, survival attributes, ordered inventory/tool state, research, buildings, harvestable resource states, and animal states.
- Resource and animal IDs must be deterministic from the world seed/generator version and island/spawn index.
- Autosave every 120 seconds while a world is active; also save on return to menu and normal application shutdown.
- Preserve existing bindings including `C` for interaction, and preserve pre-existing working-tree changes.

## Review Focus

- Corrupt, truncated, or unsupported JSON must remain untouched and produce a recoverable error; pin in Task 1's file-service smoke test.
- Two saves with the same display name must remain independent, and deleting one must not affect the other; pin in Task 1's CRUD smoke test.
- Generated IDs must remain stable across chunk unload/reload for the same seed and generator version; pin in Task 2's world-registry smoke test.
- A harvested resource must not reappear before its saved respawn time, and a saved animal must not duplicate; pin in Task 2's restore smoke test.
- Unknown inventory item IDs must survive round-trip without deleting slots; pin in Task 3's snapshot round-trip smoke test.

---

### Task 1: Versioned Save File Service

**Files:**
- Create: `scripts/core/save_manager.gd`
- Modify: `project.godot` (register `SaveManager` autoload)
- Create: `tests/smoke_save_manager.gd`

**Interfaces:**
- Produces `create_save(snapshot: Dictionary) -> String`, returning the new stable world ID or an empty string on failure.
- Produces `write_save(world_id: String, snapshot: Dictionary) -> bool`.
- Produces `read_save(world_id: String) -> Dictionary`, shaped as `{"ok": bool, "error": String, "data": Dictionary}`.
- Produces `list_saves() -> Array[Dictionary]` and `delete_save(world_id: String) -> bool`.
- Stores schema version 1, generator version 1, timestamps, seed, difficulty, name, description, and playtime metadata.

- [ ] **Step 1: Write smoke assertions** for independent IDs, create/write/read/list/delete, corrupt-file rejection without mutation, unsupported-version rejection, and backup recovery.
- [ ] **Step 2: Run the save-manager smoke script** with `./run_survive.sh --headless --script res://tests/smoke_save_manager.gd`; confirm the new assertions fail before implementation.
- [ ] **Step 3: Implement `SaveManager`** with same-directory temporary writes, JSON parse validation, `.bak` retention, schema checks, safe IDs, and recoverable result dictionaries.
- [ ] **Step 4: Run the same smoke script** and confirm every assertion passes.

### Task 2: Stable IDs and Streamed World Registry

**Files:**
- Modify: `scripts/world/island_generator.gd`
- Modify: `scripts/world/harvestable.gd`
- Modify: `scripts/fauna/animal.gd`
- Create: `tests/smoke_world_save_registry.gd`

**Interfaces:**
- `IslandGenerator.capture_persistent_state() -> Dictionary` returns `resources` and `animals` records keyed by stable ID, including animal transforms captured before chunk unload.
- `IslandGenerator.apply_persistent_state(state: Dictionary) -> void` loads records before or during chunk creation.
- `Harvestable.get_save_state() -> Dictionary` and `Harvestable.apply_save_state(state: Dictionary) -> void` preserve depletion and remaining respawn time; replace the untracked one-shot timer with a tracked timer/remaining-time value.
- `Animal.get_save_state() -> Dictionary` and `Animal.apply_save_state(state: Dictionary) -> void` preserve transform, health, species/behavior, domestication, and removed/dead state.
- Generator spawn methods assign IDs using world generator version, island index, spawn category, and stable spawn ordinal.

- [ ] **Step 1: Write smoke assertions** that identical seeds produce identical IDs, unload/reload retains harvested-resource and tamed-animal records, and restored objects are not duplicated.
- [ ] **Step 2: Run the world-registry smoke script** and confirm the assertions fail before implementation.
- [ ] **Step 3: Add stable IDs and persistent registry hooks**; capture changed state before chunk free and apply records after generated nodes initialize.
- [ ] **Step 4: Run the world-registry smoke script** and confirm state survives unload/reload and restored depletion timers.

### Task 3: Player, Inventory, Research, and Building Snapshots

**Files:**
- Modify: `scripts/core/main.gd`
- Modify: `scripts/player/player.gd`
- Modify: `scripts/inventory/inventory.gd`
- Modify: `scripts/progression/research_system.gd`
- Modify: `scripts/building/building_system.gd`
- Modify: `scripts/building/build_piece.gd`
- Modify: `scripts/world/island_generator.gd`
- Modify: `scenes/main.tscn`
- Create: `tests/smoke_save_round_trip.gd`

**Interfaces:**
- `Main.capture_save_snapshot() -> Dictionary` returns the complete world snapshot consumed by `SaveManager`.
- `Main.start_new_world(config: Dictionary) -> bool` applies name/description/seed/difficulty/character, activates generation, and starts a fresh world.
- `Main.start_world_from_save(snapshot: Dictionary) -> bool` applies seed/configuration, activates generation, restores all records, and only then resumes gameplay.
- `Main.return_to_title() -> void` deactivates world simulation and returns to the title scene after the caller has saved.
- `Player.get_save_state() -> Dictionary` and `Player.apply_save_state(state: Dictionary) -> void` include transform, camera mode/angles, attributes, active tool, and character choice.
- `Inventory.get_save_state() -> Array[Dictionary]` and `Inventory.apply_save_state(state: Array[Dictionary]) -> void` preserve ordered slots, quantities, and serializable item metadata while leaving unknown IDs intact.
- `ResearchSystem.get_save_state() -> Dictionary` and `ResearchSystem.apply_save_state(state: Dictionary) -> void` cover level, experience, points, and unlocks.
- `BuildingSystem.get_save_state() -> Array[Dictionary]` and `BuildingSystem.apply_save_state(state: Array[Dictionary]) -> void` cover transforms, type, health, improvement, stress, and removals.

- [ ] **Step 1: Write round-trip smoke assertions** for player/camera state, ordered inventory and unknown IDs, research, and damaged/upgraded/removed buildings.
- [ ] **Step 2: Run the round-trip smoke script** and confirm the assertions fail before implementation.
- [ ] **Step 3: Implement component capture/restore APIs** and have `Main` coordinate seed-first generation and post-initialization restoration; prevent `IslandGenerator` from spawning title-screen chunks before a world is activated.
- [ ] **Step 4: Add a load-failure assertion** proving the menu remains active and the save file is unchanged when parsing or restoration fails.
- [ ] **Step 5: Run the round-trip smoke script** and confirm all snapshot values match after load.

### Task 4: Autosave Lifecycle and Compatibility Handling

**Files:**
- Modify: `scripts/core/save_manager.gd`
- Modify: `scripts/core/main.gd`
- Modify: `scenes/main.tscn`
- Create: `tests/smoke_autosave_lifecycle.gd`

**Interfaces:**
- `SaveManager.set_active_world(world_id: String) -> void` selects the only world eligible for autosave.
- `SaveManager.save_active_world() -> bool` asks `Main.capture_save_snapshot()` for the active snapshot and writes it.
- `SaveManager.handle_world_generator_version(saved_version: int) -> Dictionary` reports supported, migrated, or incompatible state without replacing source files.

- [ ] **Step 1: Write lifecycle assertions** for periodic active-world saves, no autosaves on the title menu, explicit save on normal shutdown/menu return, and generator-version mismatch preservation.
- [ ] **Step 2: Run the lifecycle smoke script** and confirm the assertions fail before implementation.
- [ ] **Step 3: Add the 120-second autosave timer and lifecycle hooks**; keep writes isolated to the selected world and expose status/errors to UI consumers.
- [ ] **Step 4: Run the lifecycle smoke script** and confirm save lifecycle and compatibility handling pass.

## Integration Order

Complete Task 1 before Task 2, then Task 3, then Task 4. The menu plan consumes the exact SaveManager CRUD and load interfaces defined in Task 1 and Task 3.

## Change Safety

The current checkout already contains unrelated modified and untracked project files. Do not reset, revert, bulk-format, or stage unrelated files. Review `git status --short` before and after implementation; do not create a commit that includes existing user changes.
