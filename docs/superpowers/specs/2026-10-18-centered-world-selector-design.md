# Centered Main Menu and World Selector Design

## Goal

Center every secondary screen opened from the main menu and replace the
Singleplayer save list with a Terraria-inspired world selector. Each world
shows its most recent gameplay view, name, difficulty, a play icon, and a trash
icon.

## User-approved design

- Center the Singleplayer selector, world-creation form, and settings panel in
  the viewport. Keep them centered when the window is resized. The title screen
  artwork and its left-side buttons remain in place.
- Display worlds as a scrollable list of horizontal cards. Each card has a
  16:9 preview on the left, world name and difficulty in the middle, and
  distinct play and trash icon buttons on the right.
- Keep the existing New World and Back actions. An empty save list offers a
  clear New World action.
- Play loads that card's world directly. Deletion remains protected by a
  confirmation dialog. Saves that cannot be loaded remain visible and
  deletable, but their play button is disabled.
- Center the world-creation form and settings panel using the same responsive
  layout behavior as the selector.

## Thumbnail lifecycle and storage

- Capture the player's current gameplay view only when leaving a world for the
  title screen or closing the game; normal manual and automatic saves do not
  refresh the thumbnail.
- The thumbnail preserves the active gameplay camera view without the pause
  or title-menu overlays. The gameplay HUD remains as part of the player's
  view.
- Downsample the image to 480x270 and store it as a separate JPEG at
  `user://saves/<world_id>.jpg`. The UUID-based filename is derived from the
  existing world ID; the JSON save format and version remain unchanged.
- Existing saves without thumbnails, and missing or unreadable image files,
  use a built-in placeholder. A failed thumbnail capture or write must not
  block a successful world save or prevent returning to the title screen; keep
  any previous valid thumbnail.
- Deleting a world removes its JSON, backup, temporary save file, and
  thumbnail. It must not affect another world's files.

## UI behavior and accessibility

- Icon buttons have independent hitboxes, keyboard focus, and tooltips/labels
  identifying Play and Delete. The delete confirmation identifies the world
  by name.
- Selecting or activating a card must use its stable world ID, never a list
  index as persistent identity.
- Keep current visual language: warm dark panels, low-poly sunset background,
  restrained bronze border/highlight, and readable text.
- Preview images use a consistent 16:9 crop and fall back cleanly if they fail
  to load.

## Compatibility and failure handling

- Thumbnail metadata is optional. Existing version-1 saves remain valid and
  loadable without migration.
- Image failure is independent from save failure. Save/load/delete behavior
  remains functional if a preview is unavailable.
- If saving the world itself fails during an exit-to-title action, preserve
  the current behavior: remain in the world and report the save error.

## Verification criteria

- Main menu secondary panels are centered at common aspect ratios and remain
  centered after a viewport resize.
- The selector renders one card per save with the correct name, difficulty,
  thumbnail or placeholder, and play/delete actions.
- Activating Play loads the matching world; canceling deletion preserves the
  world and confirming deletion removes only that world's save and thumbnail.
- Thumbnail capture is refreshed on world exit, not on manual or autosave;
  older saves show the placeholder and remain loadable.
- A failed/missing thumbnail does not break the selector or save lifecycle.
- Existing save manager, save round-trip, main menu flow, and pause-save tests
  continue to pass.

## Out of scope

- Multiplayer menu behavior.
- Changing world generation, save contents, or save format version.
- Capturing screenshots during gameplay for purposes other than the world
  selection preview.
