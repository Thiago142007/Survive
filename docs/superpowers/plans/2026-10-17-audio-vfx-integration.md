# Audio and VFX Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add licensed, lightweight audio and particle feedback to Survive's existing movement, collection, combat, building, ambience, and UI flows.

**Architecture:** A global `Effects` autoload owns the effect catalog, bounded audio pools, ambience players, and bounded VFX instances. Gameplay and UI code request semantic effect IDs and never load asset paths directly; reusable `CPUParticles3D` scenes supply Compatibility-safe bursts.

**Tech Stack:** Godot 4.3, GDScript, `AudioStreamPlayer`, `AudioStreamPlayer3D`, `CPUParticles3D`, OGG Vorbis, PNG particle textures.

**Spec:** `docs/superpowers/specs/2026-10-17-audio-vfx-integration-design.md`

## Global Constraints

- Use only free CC0 or MIT content and record source, license, and selected files.
- Support Godot 4.3 with `gl_compatibility`; do not use Forward+ features.
- Use low-count, short-lived `CPUParticles3D` effects and bounded pools.
- Do not change gameplay rules while adding presentation feedback.
- Preserve unrelated dirty-worktree changes and stage only files owned by each task.
- Do not add music, advanced weather/fire/explosions, or a complete surface-detection system.

## Review Focus

- An unknown effect ID returns `false`, logs a warning, and never crashes the caller; Task 2 tests this.
- Bursts beyond the configured pool limits recycle the oldest eligible instance instead of growing the tree; Tasks 2 and 3 test this.
- Headless execution can load the catalog and particle scenes without requiring a visible renderer; Tasks 1 and 3 test this.
- Gameplay events requested while `Effects` is unavailable remain mechanically valid; Task 4 tests the guarded request helper.
- UI sounds continue while the game tree is paused, while world sounds and ambience obey their intended buses; Tasks 2 and 5 test this.

---

## File Structure

- `assets/audio/{sfx,ui,ambience}/`: only the curated OGG files used by the game.
- `assets/vfx/textures/`: four curated transparent Kenney particle sprites.
- `docs/THIRD_PARTY_ASSETS.md`: source URL, CC0 status, original filename, and renamed project path for every imported file.
- `default_bus_layout.tres`: `Master`, `SFX`, `Ambience`, and `UI` bus definitions.
- `scripts/effects/effects_manager.gd`: catalog, sound pools, ambience, VFX limits, and public playback API.
- `scripts/effects/burst_effect.gd`: one-shot particle lifetime and pool-reset behavior.
- `scenes/effects/*.tscn`: five reusable Compatibility-safe particle bursts.
- `tests/smoke_effect_assets.gd`: asset, license, and audio-bus preflight.
- `tests/smoke_effects_manager.gd`: catalog, safe failure, and bounded pool behavior.
- `tests/smoke_vfx.gd`: particle scene loading, one-shot lifecycle, and VFX cap.
- `tests/smoke_effect_integrations.gd`: gameplay, UI, pause-mode, and ambience requests.

### Task 1: Curate CC0 Assets and Audio Buses

**Files:**
- Create: `assets/audio/sfx/*.ogg`
- Create: `assets/audio/ui/*.ogg`
- Create: `assets/audio/ambience/*.ogg`
- Create: `assets/vfx/textures/{dirt_01.png,smoke_03.png,spark_05.png,slash_03.png}`
- Create: `docs/THIRD_PARTY_ASSETS.md`
- Create: `default_bus_layout.tres`
- Create: `tests/smoke_effect_assets.gd`

**Interfaces:**
- Consumes: direct ZIP URLs recorded in the approved spec and source filename mapping below.
- Produces: stable `res://assets/...` paths and buses consumed by Tasks 2–5.

- [ ] **Step 1: Write the failing asset preflight**

Create `tests/smoke_effect_assets.gd` as a `SceneTree` test. Assert that every curated path below exists and loads as `AudioStream` or `Texture2D`, that `docs/THIRD_PARTY_ASSETS.md` exists, and that `AudioServer.get_bus_index()` finds `SFX`, `Ambience`, and `UI`.

- [ ] **Step 2: Run the preflight and verify it fails**

Run: `/tmp/Godot_v4.3-stable_linux.x86_64 --headless --path . --script tests/smoke_effect_assets.gd`

Expected: FAIL because the curated paths and buses do not yet exist.

- [ ] **Step 3: Download the five approved source archives into a temporary directory**

Use the direct Kenney URLs for Particle Pack, Impact Sounds, RPG Audio, and Interface Sounds plus `https://opengameart.org/sites/default/files/sfx_100_v2.zip`. Do not commit source ZIPs or Unity samples.

- [ ] **Step 4: Extract and rename only the selected files**

Use this exact mapping:

- Particle Pack: `dirt_01.png`, `smoke_03.png`, `spark_05.png`, `slash_03.png` from `PNG (Transparent)/` to `assets/vfx/textures/`.
- Impact Sounds: `impactWood_medium_000..002.ogg` → `wood_hit_01..03.ogg`; `impactMining_000..002.ogg` → `stone_hit_01..03.ogg`; `impactSoft_medium_000..002.ogg` → `animal_hit_01..03.ogg`; `footstep_grass_000..003.ogg` → `footstep_grass_01..04.ogg`; `impactPlank_medium_000..001.ogg` → `build_place_01..02.ogg`; `impactWood_heavy_000..001.ogg` → `build_remove_01..02.ogg`; `impactPunch_medium_000..001.ogg` → `player_hurt_01..02.ogg`; `impactSoft_heavy_000.ogg` → `player_down.ogg`; `impactSoft_heavy_001.ogg` → `animal_death.ogg`.
- RPG Audio: `knifeSlice.ogg`, `knifeSlice2.ogg` → `attack_swing_01.ogg`, `attack_swing_02.ogg`; `chop.ogg` → `repair.ogg`; `metalClick.ogg` → `upgrade.ogg`; `handleSmallLeather.ogg` → `collect.ogg`.
- Interface Sounds: `click_001.ogg` → `ui_click.ogg`; `confirmation_001.ogg` → `ui_confirm.ogg`; `error_001.ogg` → `ui_error.ogg`.
- 100 CC0 SFX #2: `sfx100v2_loop_water_01.ogg` → `ocean_loop.ogg`; `sfx100v2_loop_ambient_02.ogg` → `wind_loop.ogg`.

- [ ] **Step 5: Add provenance and bus configuration**

Document package title, author/publisher, source URL, CC0 license URL, original filename, renamed path, and retrieval date `2026-10-17` in `docs/THIRD_PARTY_ASSETS.md`. Create `default_bus_layout.tres` with bus order `Master`, `SFX`, `Ambience`, `UI`, each enabled and initially at `0 dB`.

- [ ] **Step 6: Import and rerun the preflight**

Run: `/tmp/Godot_v4.3-stable_linux.x86_64 --headless --editor --path . --quit-after 3`

Then run: `/tmp/Godot_v4.3-stable_linux.x86_64 --headless --path . --script tests/smoke_effect_assets.gd`

Expected: exit `0` and `Effect asset preflight: PASS`.

- [ ] **Step 7: Commit the curated assets**

```bash
git add assets/audio assets/vfx/textures docs/THIRD_PARTY_ASSETS.md default_bus_layout.tres tests/smoke_effect_assets.gd
git commit -m "assets: add curated CC0 audio and particle textures"
```

### Task 2: Build the Bounded Effects Manager

**Files:**
- Create: `scripts/effects/effects_manager.gd`
- Create: `tests/smoke_effects_manager.gd`
- Modify: `project.godot`

**Interfaces:**
- Consumes: stable asset paths and audio buses from Task 1.
- Produces: autoload `/root/Effects`; `play_world(effect_id: StringName, position: Vector3) -> bool`; `play_ui(effect_id: StringName) -> bool`; `start_ambience(effect_id: StringName) -> bool`; `stop_ambience(effect_id: StringName = &"") -> void`; `spawn_vfx(vfx_id: StringName, position: Vector3) -> bool`; `effect_requested(effect_id: StringName, position: Vector3, spatial: bool)`.

- [ ] **Step 1: Write the failing manager test**

Create `tests/smoke_effects_manager.gd`. Assert that `/root/Effects` exists, all IDs below return `true` from `has_effect(effect_id: StringName) -> bool`, `play_world(&"missing", Vector3.ZERO)` returns `false`, `play_ui(&"ui_click")` emits `effect_requested` with `spatial == false`, and 20 rapid world requests leave exactly `12` world players.

Required sound IDs: `attack_swing`, `footstep_grass`, `wood_hit`, `stone_hit`, `animal_hit`, `animal_death`, `build_place`, `build_remove`, `build_repair`, `build_upgrade`, `player_hurt`, `player_down`, `collect`, `ui_click`, `ui_confirm`, `ui_error`, `ocean`, `wind`.

- [ ] **Step 2: Run the manager test and verify it fails**

Run: `/tmp/Godot_v4.3-stable_linux.x86_64 --headless --path . --script tests/smoke_effects_manager.gd`

Expected: FAIL because `/root/Effects` and its API do not exist.

- [ ] **Step 3: Implement `EffectsManager` and register the autoload**

Add `Effects="*res://scripts/effects/effects_manager.gd"` under `[autoload]`. Implement the exact public signatures above plus `has_effect(effect_id: StringName) -> bool`, `get_world_pool_size() -> int`, `get_ui_pool_size() -> int`, `get_ambience_count() -> int`, and `get_active_vfx_count() -> int` for tests. Use constants `MAX_WORLD_PLAYERS := 12`, `MAX_UI_PLAYERS := 4`, and `MAX_VFX := 24`; pool nodes must use `process_mode = Node.PROCESS_MODE_ALWAYS`, route to their named buses, and recycle the oldest busy player when every slot is active.

Catalog values are arrays of preloaded Task 1 streams. Apply randomized pitch in `[0.94, 1.06]` and volume in `[-1.5, 0.5] dB` only to short SFX; ambience and UI keep pitch `1.0`. Unknown IDs call `push_warning()` and return `false`.

- [ ] **Step 4: Run manager and asset tests**

Run both `tests/smoke_effect_assets.gd` and `tests/smoke_effects_manager.gd` with the Godot command above.

Expected: both exit `0`; manager output includes `Effects manager smoke test: PASS`.

- [ ] **Step 5: Commit the effects manager**

```bash
git add project.godot scripts/effects/effects_manager.gd tests/smoke_effects_manager.gd
git commit -m "feat: add pooled audio effects manager"
```

### Task 3: Add Compatibility-Safe Particle Bursts

**Files:**
- Create: `scripts/effects/burst_effect.gd`
- Create: `scenes/effects/{dust_burst,wood_splinters,stone_sparks,damage_burst,slash_burst}.tscn`
- Create: `tests/smoke_vfx.gd`
- Modify: `scripts/effects/effects_manager.gd`

**Interfaces:**
- Consumes: `Effects.spawn_vfx(vfx_id, position)` and `MAX_VFX` from Task 2; Task 1 textures.
- Produces: VFX IDs `dust`, `wood_splinters`, `stone_sparks`, `damage`, and `slash`; `BurstEffect.restart_at(world_position: Vector3) -> void`; signal `burst_finished(effect: Node3D)`.

- [ ] **Step 1: Write the failing VFX test**

Create `tests/smoke_vfx.gd`. For each scene, assert it loads and its root script is `BurstEffect`, it contains only `CPUParticles3D` particle emitters, total particle `amount` is at most `16`, and maximum `lifetime` is at most `0.8`. Request 30 dust bursts and assert `Effects.get_active_vfx_count() <= 24`; after `1.0` second assert the count returns to `0`.

- [ ] **Step 2: Run the VFX test and verify it fails**

Run: `/tmp/Godot_v4.3-stable_linux.x86_64 --headless --path . --script tests/smoke_vfx.gd`

Expected: FAIL because the scenes and VFX catalog do not exist.

- [ ] **Step 3: Implement `BurstEffect`**

Implement `class_name BurstEffect`, `restart_at(world_position: Vector3) -> void`, and `deactivate() -> void`. A restart positions the node, makes it visible, restarts every child `CPUParticles3D`, and schedules deactivation using the longest child lifetime; deactivation stops emission, hides the node, and emits `burst_finished` without freeing the pooled node.

- [ ] **Step 4: Author the five particle scenes**

Use billboard `QuadMesh` draw passes with unshaded transparent materials and the corresponding Task 1 texture. Exact budgets: dust `12 × 0.65 s`, wood splinters `10 × 0.50 s`, stone sparks `8 × 0.35 s`, damage `8 × 0.30 s`, slash `4 × 0.25 s`. Disable particle collision, trails, shadows, and lighting-dependent materials.

- [ ] **Step 5: Add bounded VFX pooling to `EffectsManager`**

Map the five VFX IDs to preloaded scenes. Reuse inactive nodes by ID; when 24 are active, recycle the oldest active node. Attach bursts to `get_tree().current_scene` when available and to the root viewport as a headless-test fallback. `spawn_vfx()` emits `effect_requested(vfx_id, position, true)` and returns `false` only for unknown IDs or when neither host is available.

- [ ] **Step 6: Run VFX and manager tests**

Run `tests/smoke_vfx.gd` and `tests/smoke_effects_manager.gd` headlessly.

Expected: both exit `0`; VFX output includes `VFX smoke test: PASS`.

- [ ] **Step 7: Commit the particle layer**

```bash
git add scripts/effects/effects_manager.gd scripts/effects/burst_effect.gd scenes/effects tests/smoke_vfx.gd
git commit -m "feat: add pooled compatibility particle bursts"
```

### Task 4: Integrate Gameplay Feedback

**Files:**
- Create: `tests/smoke_effect_integrations.gd`
- Modify: `scripts/player/player.gd`
- Modify: `scripts/player/interaction.gd`
- Modify: `scripts/world/harvestable.gd`
- Modify: `scripts/fauna/animal.gd`
- Modify: `scripts/building/building_system.gd`

**Interfaces:**
- Consumes: Task 2 playback methods and Task 3 VFX IDs.
- Produces: guarded helper `_request_effect(effect_id: StringName, position: Vector3, vfx_id: StringName = &"") -> void` in each gameplay script that needs effects; player signal `respawned(position: Vector3)`.

- [ ] **Step 1: Write failing gameplay integration tests**

Create `tests/smoke_effect_integrations.gd`, connect to `Effects.effect_requested`, and assert:

- harvesting wood requests `wood_hit`, `collect`, and `wood_splinters` before visuals are hidden;
- harvesting stone requests `stone_hit`, `collect`, and `stone_sparks`;
- `Animal.receive_hit()` requests `animal_hit` and `damage`, while death requests `animal_death` and `dust`;
- `BuildingSystem.place_piece()`, `remove_piece()`, repair, and upgrade request their matching IDs and a dust/wood burst where specified;
- `Player.take_damage()` requests `player_hurt` and `damage`, and respawn requests `player_down` without changing reset values;
- calling the guarded helper with no `/root/Effects` equivalent returns without changing the gameplay result.

- [ ] **Step 2: Run the integration test and verify it fails**

Run: `/tmp/Godot_v4.3-stable_linux.x86_64 --headless --path . --script tests/smoke_effect_integrations.gd`

Expected: FAIL because gameplay does not request effects.

- [ ] **Step 3: Integrate player combat, damage, respawn, and footsteps**

In `_perform_attack()`, request `attack_swing` plus `slash` at the ray origin before resolving the hit. Keep creature impact in `Animal.receive_hit()` to prevent duplicate hit feedback. In `take_damage()`, request `player_hurt` and `damage`; emit `respawned` and request `player_down` in `_respawn()`.

Add `_footstep_elapsed: float`, reset it while airborne or stationary, and request `footstep_grass` at the player's position every `0.50 s` when walking or `0.32 s` when sprinting. Do not add raycast-based surface detection in this delivery.

- [ ] **Step 4: Integrate collection and fauna**

`Harvestable.harvest()` requests the resource-specific hit and VFX at its global position before disabling visuals; `Interaction.register_resource()` requests `collect` after inventory and research updates. `Animal.receive_hit()` requests `animal_hit` and `damage` only for positive final damage; `_die()` requests `animal_death` and `dust` before `queue_free()`.

- [ ] **Step 5: Integrate building feedback**

Extract `upgrade_piece(piece: Node3D) -> bool` and `repair_piece(piece: Node3D) -> bool` from the existing look-at wrappers so tests can exercise those state transitions without camera input. After successful state changes, request: `build_place + dust`, `build_remove + wood_splinters`, `build_repair + dust`, and `build_upgrade + stone_sparks`. Invalid placement requests no world VFX; UI error feedback is owned by Task 5.

- [ ] **Step 6: Run integration and regression tests**

Run `tests/smoke_effect_integrations.gd`, `tests/smoke_building.gd`, `tests/smoke_fauna.gd`, `tests/smoke_phase2.gd`, and `tests/smoke_world.gd` headlessly.

Expected: all exit `0` with their existing PASS messages and `Effect integration smoke test: PASS`.

- [ ] **Step 7: Commit gameplay integration**

```bash
git add scripts/player/player.gd scripts/player/interaction.gd scripts/world/harvestable.gd scripts/fauna/animal.gd scripts/building/building_system.gd tests/smoke_effect_integrations.gd
git commit -m "feat: connect effects to gameplay events"
```

### Task 5: Integrate UI and Ambience, Then Validate the Game

**Files:**
- Modify: `scripts/core/main.gd`
- Modify: `scripts/ui/main_menu.gd`
- Modify: `scripts/ui/crafting_ui.gd`
- Modify: `scripts/ui/research_ui.gd`
- Modify: `tests/smoke_effect_integrations.gd`

**Interfaces:**
- Consumes: Task 2 `play_ui()`, `start_ambience()`, and `stop_ambience()`.
- Produces: UI feedback on primary actions and two simultaneous looping ambience layers on the `Ambience` bus.

- [ ] **Step 1: Extend the failing integration test**

Assert `play_ui()` players have `PROCESS_MODE_ALWAYS`; starting `ocean` then `wind` creates exactly two looping ambience players on the `Ambience` bus; opening/back actions request `ui_click`; successful world creation/crafting/research request `ui_confirm`; failed crafting/research and invalid placement request `ui_error`.

- [ ] **Step 2: Run the extended test and verify it fails**

Run: `/tmp/Godot_v4.3-stable_linux.x86_64 --headless --path . --script tests/smoke_effect_integrations.gd`

Expected: FAIL on UI and ambience assertions.

- [ ] **Step 3: Start ambience with the world lifecycle**

In the autoload instance of `scripts/core/main.gd`, start `ocean` and `wind` only after `configure_world()` marks `game_started = true`. Guard calls so the same script attached to the current scene root does not start duplicate layers. Stop both ambience layers when returning to a non-started state or during test teardown.

- [ ] **Step 4: Add UI feedback**

Request `ui_click` when opening/closing menu panels, `ui_confirm` only after successful world creation/crafting/research, and `ui_error` after failed crafting/research or `BuildingSystem.invalid_placement`. Preserve `PROCESS_MODE_ALWAYS` so menu sounds play while paused.

- [ ] **Step 5: Run the complete headless suite**

Run every `tests/smoke_*.gd` file individually with `/tmp/Godot_v4.3-stable_linux.x86_64 --headless --path . --script <test>`.

Expected: every test exits `0`; no parser errors, missing-resource errors, or orphan-node warnings attributable to the new layer.

- [ ] **Step 6: Run graphical Compatibility validation**

First import with the graphical renderer, then launch the main scene using:

`timeout 30s /tmp/Godot_v4.3-stable_linux.x86_64 --path . --rendering-method gl_compatibility --windowed`

Exercise: create a world; walk/run; harvest wood and stone; attack and receive damage from fauna; place, repair, upgrade, and remove a structure; open crafting and research; trigger one valid and one invalid UI action. Inspect stdout/stderr for resource, audio, shader, and particle errors and inspect the remote scene tree for no more than 12 world audio players and 24 active VFX nodes. Any failure returns to the owning task, is fixed, and repeats that task's test plus this validation.

- [ ] **Step 7: Commit UI and ambience integration**

```bash
git add scripts/core/main.gd scripts/ui/main_menu.gd scripts/ui/crafting_ui.gd scripts/ui/research_ui.gd tests/smoke_effect_integrations.gd
git commit -m "feat: add interface and island ambience feedback"
```

## Final Verification

- Run `git diff --check`.
- Run the complete headless suite again after the final graphical fix, if any.
- Run `git status --short` and confirm unrelated pre-existing changes remain unstaged and uncommitted.
- Compare `docs/THIRD_PARTY_ASSETS.md` against the committed asset filenames and remove any unreferenced imported file.
- Report exact passing commands, remaining pre-existing changes, total added asset size, and any intentionally deferred effect from the spec.
