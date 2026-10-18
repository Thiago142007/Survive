# Character Models and First-Person Hands Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add male/female character selection and animated, visible first-person hands that present held tools and gameplay actions.

**Architecture:** Import the CC0 full-body character pack and the accepted CC BY 4.0 arms asset, record attribution, and keep gameplay interaction logic separate from presentation. A character presentation controller selects the full-body model for third person and the camera-attached arms viewmodel for first person.

**Tech Stack:** Godot 4.3, GDScript, imported glTF/FBX assets, `AnimationPlayer`/`AnimationTree`, existing player scene and input actions.

**Spec:** `docs/superpowers/specs/2026-10-18-save-system-main-menu-and-player-models-design.md`

## Global Constraints

- Use Quaternius Universal Base Characters (CC0) and PSX FPS Arms Free (CC BY 4.0); retain required attribution in project credits.
- Character choice is selected during new-world creation and persisted per world.
- First-person arms are camera-attached; third-person/camera-toggle views show the selected full-body character.
- Presentation animations must not bypass or duplicate authoritative harvest/combat/interact gameplay logic.
- Keep `C` as the interaction binding and preserve existing working-tree changes.

## Review Focus

- Both character choices must resolve valid imported scenes and render after a clean import; pin in Task 1's import smoke check.
- First-person arms must not be visible from third person and full body must not block first-person view; pin in Task 2's camera-mode assertions.
- Switching selected character must update both body and arms; pin in Task 2's character-selection assertions.
- Interaction animation must only play when the existing `C` action is accepted; pin in Task 3's action-signal assertions.
- Missing/unsupported imported animation names must fall back safely instead of breaking gameplay; pin in Task 3's animation fallback assertions.

---

### Task 1: Import Character and Arm Assets with Attribution

**Files:**
- Create: `assets/characters/quaternius/` (selected male/female source scenes and textures)
- Create: `assets/characters/psx_fps_arms/` (arms scene, animation resources, required source assets)
- Create: `CREDITS.md`
- Create: `tests/smoke_character_assets.gd`

**Interfaces:**
- Produces stable project-owned scene references for male, female, and first-person arms rigs.
- Records source URL, creator, license, and required attribution text for each imported asset.
- Use the asset source pages listed in the approved spec; do not import unrelated sample scenes or large unused packs.

- [ ] **Step 1: Inspect the downloaded archive layouts and write import assertions** for expected scene, mesh, skeleton, and animation resources.
- [ ] **Step 2: Run the asset smoke script after import** and confirm it reports the missing expected resources before scene integration.
- [ ] **Step 3: Import only required source files** into the character asset folders and add license/attribution entries to `CREDITS.md`.
- [ ] **Step 4: Run the asset smoke script** and confirm both character rigs and the arms rig load in Godot 4.3.

### Task 2: Character Selection and Camera-Aware Presentation

**Files:**
- Create: `scripts/player/character_presentation.gd`
- Modify: `scenes/player/player.tscn`
- Modify: `scripts/player/player.gd`
- Modify: `scripts/ui/main_menu.gd`
- Modify: `scripts/core/main.gd`
- Create: `tests/smoke_character_presentation.gd`

**Interfaces:**
- `CharacterPresentation.configure_character(character_id: String) -> void` accepts `male` or `female`, defaulting safely to `male` for invalid values.
- `CharacterPresentation.set_camera_mode(mode: int) -> void` shows the full-body model in third person and camera-attached arms in first person.
- `Player.get_save_state()`/`apply_save_state()` from the persistence plan include `character_id`.
- New-world UI stores the choice in world configuration before the world starts.

- [ ] **Step 1: Write smoke assertions** for male/female selection, first-person arms visibility, third-person body visibility, and restored character selection.
- [ ] **Step 2: Run the presentation smoke script** and confirm required nodes/behavior fail before implementation.
- [ ] **Step 3: Implement the presentation controller** and connect it to camera-mode and new-world selection changes.
- [ ] **Step 4: Run the presentation smoke script** and confirm both choices display correctly in first and third person.

### Task 3: Item-Aware First-Person Animation Hooks

**Files:**
- Modify: `scripts/player/character_presentation.gd`
- Modify: `scripts/player/player.gd`
- Modify: `scripts/player/interaction.gd`
- Modify: `scripts/inventory/inventory.gd`
- Create: `tests/smoke_first_person_actions.gd`

**Interfaces:**
- `CharacterPresentation.play_action(action: StringName, item_id: StringName = &"") -> void` maps idle/equip/interact/harvest/attack events to supported arm animations and has a safe fallback.
- `Player` emits a presentation event after existing attack/interact requests are accepted; `Interaction` continues to own `C` interaction outcomes.
- Active tool/item identity comes from existing player/inventory APIs; animation selection never mutates inventory or resource state.

- [ ] **Step 1: Write smoke assertions** that accepted interaction, harvest, and attack trigger the expected available action; rejected actions do not trigger effects; missing animation names fall back safely.
- [ ] **Step 2: Run the first-person action smoke script** and confirm assertions fail before implementation.
- [ ] **Step 3: Connect existing gameplay outcomes to `play_action`** and map the chosen tool/item to available animation clips without changing action authority.
- [ ] **Step 4: Run the first-person action smoke script** and confirm visual action hooks work without changing inventory, collection, or damage results.

## Integration Order

Implement after the persistence plan's player snapshot API and the menu plan's new-world character-choice control are available. Task 1 must finish before Tasks 2 and 3; Task 2 must finish before Task 3.

## Change Safety

Current player and scene files already contain user changes. Integrate narrowly, preserve current camera toggle and gameplay controls, and do not stage or commit unrelated user changes.
