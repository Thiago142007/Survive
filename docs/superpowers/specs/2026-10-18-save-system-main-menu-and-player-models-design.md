# Save System, Main Menu, and Player Presentation — Design Spec

## Status

Approved by the user for detailed design review. Implementation must not begin until the user approves this specification and the resulting implementation plan.

## Goals

- Replace the current main menu with the user-provided tropical sunset image while preserving functional controls.
- Add independent single-player world saves that preserve as much game state as the current game supports.
- Allow the player to choose a male or female character and show animated first-person arms/hands while playing.
- Preserve all pre-existing user changes in the working tree; this work must be additive and carefully integrated.

## Out of scope

- Multiplayer networking. The menu entry is visible but disabled with an “Em breve” indicator.
- Saving momentary animation frames, animal AI targets/cooldowns, or other ephemeral simulation internals. Persistent animal state is saved and AI resumes from an idle/wander state.
- Saving an in-game clock or weather cycle: neither currently exists. Playtime can be recorded as metadata.

## User experience

### Main menu

- Use `/home/dream/Downloads/Survive_ Tropical Island Sunset Menu.png` as the full-screen menu backdrop, copied into the project’s UI assets.
- Preserve the artwork and its embedded English labels. Place invisible interactive controls over the pictured buttons so the artwork is not duplicated or obscured. Controls must support mouse and keyboard focus/navigation; hover/focus may use a subtle outline/highlight.
- “Singleplayer” opens a world list. The list supports creating a world, loading a selected world, and deleting a world only after confirmation. Each entry shows name, seed, difficulty, and last-saved time.
- New-world flow includes world name/description, optional seed, difficulty, male/female character choice, and a confirmation/start action.
- “Configs” opens a small settings panel for master volume and window mode/resolution, persisted independently from world saves.
- “Multiplayer” remains disabled and visibly marked “Em breve”. “Quit” exits the game.
- Keep the menu and pause flows usable at the project’s 1280×720 base viewport and adapt the image and hit areas to the actual displayed image bounds.

### In-game pause and save

- `Esc` opens a paused overlay with “Continuar”, “Salvar agora”, and “Voltar ao menu”. Returning to menu saves first and then shows the title screen.
- Autosave every 120 seconds while a world is active. Also save when returning to the menu and on normal application shutdown. Manual save remains available from the pause menu.
- Indicate save-in-progress/completion/failure in the UI without freezing gameplay for the duration of a normal save.

## Save architecture

Use deterministic procedural generation as the base world and overlay a versioned snapshot of persistent changes. Do not serialize the live scene tree: the project streams chunks and its generated nodes are not a stable scene format.

- Add a save manager as an autoload/service that owns listing, creating, loading, deleting, autosave scheduling, version checks, and disk I/O.
- Store each world independently under `user://saves/<world-id>.json`; use a stable UUID-like ID, not the display name, as the filename.
- Write a temporary file in the same directory, validate the serialized payload, retain a previous `.bak`, and replace the active file only after a successful write. A corrupt or unsupported save is reported and never silently overwritten.
- Include `save_format_version` and `world_generation_version`. Support a migration hook for known schema changes; if the world generator version cannot be reconciled, keep the file intact and explain the limitation.
- Save settings separately from world data.

## Persisted world data

Each snapshot includes:

- Metadata: world ID, name, description, created/saved timestamps, elapsed playtime, seed, difficulty, selected character, and format/generator versions.
- Player: global position and body yaw, camera pitch and camera mode, health, hunger, thirst, energy, active tool, hotbar selection/configuration, and other persistent player progression already represented in code.
- Inventory: ordered slots with item ID, quantity, and serializable item-specific state. Rebuild `ItemData` references from the item catalog on load; never serialize live Resource objects. Preserve unknown IDs in the save and report them rather than deleting them.
- Research: level, remaining experience, research points, and unlocked nodes.
- Buildings: piece type, transform, health, improvement level, stress, and material state. Removed pieces remain absent; transient ghost pieces are not saved.
- Harvestable resources: stable generated ID, type, depleted/available state, and remaining respawn time. Preserve modifications for both loaded and unloaded chunks.
- Animals: stable generated ID, species/behavior, alive/dead/removed state, transform, health, and domestication state. Save modified animals across chunk unloads and restore them when their saved position enters a streamed area. AI target, cooldown, and wander timer may reset.
- Extensibility: a versioned world-state registry for future persistent systems (for example crops or containers), so future changes can join the save without changing the base-world strategy.

Resource and animal IDs must be deterministic from the world seed/generator version and their island/spawn index. The current resource and fauna spawn routines are deterministic per island; implementation should retain that property and assign explicit IDs. Any later generator change that alters ID ordering must increment the generator version and provide migration/recovery behavior.

## Character and first-person presentation

- Offer male/female character selection during new-world setup and persist that selection in the world save.
- Use the Quaternius Universal Base Characters pack for full-body character choices (CC0) and the PSX FPS Arms asset for first-person arms/animations (CC BY 4.0, with required attribution recorded in project credits). Source pages: [Quaternius Universal Base Characters](https://quaternius.com/packs/universalbasecharacters.html) and [PSX FPS Arms Free](https://heyheythere.itch.io/psx-fps-arms-free).
- The full-body model supports third-person/camera-toggle views. A camera-attached arms rig supplies visible hands in first person, with idle, equipped-item, interaction/harvest, and attack presentation as supported by the chosen animations. Gameplay interactions remain authoritative in existing systems; visual animations must not duplicate or bypass them.
- Keep gameplay input bindings already used by the project, including `C` for interaction, intact.

## Loading sequence

1. Validate and parse the selected save without mutating live world state.
2. Apply metadata/configuration and seed before the generator builds descriptors or streams chunks.
3. Generate the deterministic base world and attach the loaded persistent-state registry.
4. Restore persistent changes as chunks are created, including resource depletion and saved animal overlays; restore global constructions.
5. Restore player transform, character choice, attributes, inventory, active tool, and research after the player and item catalog are ready.
6. Unpause, capture the mouse, and show the HUD only after restoration finishes. On failure, remain in the menu and keep the save file unchanged.

## Acceptance criteria

- A new world can be created, closed/reopened through the menu, and loaded as a distinct save without changing other worlds.
- Loading restores the same seed/difficulty, character, player position/view, survival stats, ordered inventory/tool state, research, constructions/upgrades/damage, harvest/depletion timer, and living/tamed/dead animal records.
- Re-entering streamed chunks does not duplicate saved animals or resurrect harvested resources before their saved respawn time.
- Autosave, manual save, return-to-menu save, and save deletion operate on the selected world only.
- Corrupt/unsupported save files remain untouched and produce a recoverable UI error.
- The provided image is the main menu backdrop; visible entries respond to mouse and keyboard; multiplayer is disabled; settings persist independently.
- Male and female choices load in first and third person, with first-person hands visible and appropriate to the chosen/equipped item.
- Required third-party attribution is present in project documentation/credits.

## Self-review notes

- Current resource depletion respawns after a timer, so the save records remaining respawn time rather than making collection permanent by accident.
- Current chunk unload frees spawned nodes. The save registry must capture changed resources/animals before freeing chunks and must restore state by stable ID when chunks reload.
- Existing building pieces are instantiated outside the generator and are tracked by `BuildingSystem`; load must recreate them as global world entities before resuming play.
- Existing `Player._ready()` resets survival values, `Harvestable._ready()` resets visuals, and `Animal._ready()` resets health. Load application must run after these initializers, and generator-created objects need a restore hook after their initial state is established.
- Existing world seeds initialize layout, but descriptor generation and spawn identity are coupled to generator code. The generator version is therefore necessary to prevent silent mismatches after future changes.
- The project already has many user modifications in the worktree. Changes must avoid reverting or reformatting unrelated files and should be reviewed against `git status` before each integration step.
