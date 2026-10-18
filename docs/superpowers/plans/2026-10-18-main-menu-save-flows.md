# Main Menu and Save Flows Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the title screen with the supplied artwork and provide working single-player world selection, pause/save, and basic settings flows.

**Architecture:** Keep the supplied image as an intact full-screen background and position accessible controls over its baked-in buttons. Delegate world file operations and load orchestration to the SaveManager/Main APIs from the persistence plan; keep user settings separate from world data.

**Tech Stack:** Godot 4.3, GDScript, `Control`/`TextureRect`, `ConfigFile`, existing `SceneTree` smoke scripts.

**Spec:** `docs/superpowers/specs/2026-10-18-save-system-main-menu-and-player-models-design.md`

## Global Constraints

- Use `/home/dream/Downloads/Survive_ Tropical Island Sunset Menu.png` as the full-screen background and preserve its embedded English labels.
- Controls must support mouse and keyboard focus/navigation and align to the displayed image bounds.
- “Multiplayer” remains disabled and marked “Em breve”; do not implement networking.
- “Configs” includes master volume and window mode/resolution saved independently from world saves.
- Autosave every 120 seconds during play; save on return to menu and normal shutdown; expose manual save through `Esc` pause.
- Preserve the current gameplay bindings and all pre-existing working-tree changes.

## Review Focus

- Window aspect/size changes must not offset click areas from baked-in labels; pin in Task 1's menu geometry assertions.
- Keyboard-only navigation must reach every enabled main-menu and save-list action; pin in Task 1's focus assertions.
- A disabled multiplayer button must not start or mutate a world; pin in Task 1's interaction assertions.
- Delete confirmation cancel must preserve the selected save; pin in Task 2's world-list assertions.
- Returning to the title screen must save the active world before unloading and must not leave the game paused behind the menu; pin in Task 3's lifecycle assertions.

---

### Task 1: Image-Based Title Menu and World Selection Screen

**Files:**
- Copy: supplied image into `assets/ui/main_menu_sunset.png`
- Modify: `scenes/ui/main_menu.tscn`
- Modify: `scripts/ui/main_menu.gd`
- Create: `tests/smoke_main_menu_save_flows.gd`

**Interfaces:**
- Consumes `SaveManager.list_saves() -> Array[Dictionary]`, `create_save(snapshot: Dictionary) -> String`, `read_save(world_id: String) -> Dictionary`, and `delete_save(world_id: String) -> bool` from the persistence plan.
- Consumes `SaveManager.set_active_world(world_id: String) -> void` when a new world is created or an existing world is loaded.
- Consumes `Main.start_world_from_save(snapshot: Dictionary) -> bool` and `Main.start_new_world(config: Dictionary) -> bool` from the persistence plan.
- Produces menu panels for title, world list, new world creation, delete confirmation, settings, and feedback/error display.

- [ ] **Step 1: Write smoke assertions** for image resource, visible artwork, button hit areas, keyboard focus order, save list actions, disabled multiplayer, and responsive bounds at 1280×720 plus a 16:10 test size.
- [ ] **Step 2: Run the menu smoke script** and confirm required image and behavior assertions fail before implementation.
- [ ] **Step 3: Copy the supplied image and implement responsive controls** over its normalized button regions; ensure focus/hover feedback does not obscure the image labels.
- [ ] **Step 4: Implement save-list/new-world/load/delete-confirmation flows** using only the SaveManager/Main interfaces; include name, seed, difficulty, and character choice fields, then create the initial save snapshot for a new world.
- [ ] **Step 5: Run the menu smoke script** and confirm all title and world-selection assertions pass.

### Task 2: Settings Persistence

**Files:**
- Create: `scripts/core/settings_manager.gd`
- Modify: `project.godot` (register `SettingsManager` autoload)
- Modify: `scenes/ui/main_menu.tscn`
- Modify: `scripts/ui/main_menu.gd`
- Create: `tests/smoke_settings.gd`

**Interfaces:**
- Produces `SettingsManager.load_settings() -> Dictionary`, `save_settings(settings: Dictionary) -> bool`, and `apply_settings(settings: Dictionary) -> void`.
- Stores master volume, window mode, and supported resolution in `user://settings.cfg`.
- Invalid or missing settings fall back to safe defaults and do not affect world saves.

- [ ] **Step 1: Write smoke assertions** for default settings, saved/reloaded volume and display mode, and invalid config fallback.
- [ ] **Step 2: Run the settings smoke script** and confirm assertions fail before implementation.
- [ ] **Step 3: Implement ConfigFile load/save/apply behavior** and connect settings controls to it.
- [ ] **Step 4: Run the settings smoke script** and confirm settings persist independently of world slots.

### Task 3: Pause, Manual Save, and Return-to-Menu Flow

**Files:**
- Create: `scenes/ui/pause_menu.tscn`
- Create: `scripts/ui/pause_menu.gd`
- Modify: `scripts/player/player.gd`
- Modify: `scenes/main.tscn`
- Create: `tests/smoke_pause_save_flow.gd`

**Interfaces:**
- Consumes `SaveManager.save_active_world() -> bool` and active-world selection from the persistence plan.
- Produces pause menu actions `continue_game`, `save_now`, and `return_to_title`.
- `Esc` opens the pause overlay only while a world is active; while paused, it does not also toggle mouse capture.

- [ ] **Step 1: Write smoke assertions** for pause/resume state, manual save, return-menu save-before-transition, failure feedback, and title-menu input mode.
- [ ] **Step 2: Run the pause-flow smoke script** and confirm assertions fail before implementation.
- [ ] **Step 3: Add pause menu scene/actions and route `Esc`** without changing existing inventory/interact bindings.
- [ ] **Step 4: Run the pause-flow smoke script** and confirm the world is saved before its state is unloaded and the title menu becomes interactive.

## Integration Order

Implement after the persistence plan's Tasks 1, 3, and 4 so the UI uses stable storage, loading, and active-world lifecycle interfaces. Tasks 1 and 2 can then proceed independently; Task 3 consumes the active-world lifecycle from the persistence plan.

## Change Safety

The current title scene is already modified in the working tree. Integrate with its current controls and styles rather than replacing the scene wholesale. Review `git status --short` and preserve all pre-existing changes.
