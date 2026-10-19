# Survive procedural islands v2

## Existing system and compatibility

Godot 4.3 / GDScript. `IslandGenerator` owns the heightfield mesh, island descriptors, chunk streaming, water, resource and animal placement. The save stores a seed, generator version and persistent object overlays. Version 1 uses a fixed central radius, an almost regular outer ring and index-selected biomes. Keep the version 1 script for existing saves and make the scene use a version 2 subclass. On load, select the saved version before applying the seed. Never rewrite a version 1 snapshot as version 2.

## Implementation

1. Add a stable seed parser for signed integers and text; show and persist the original entered seed. Test zero, negative, text and blank seed behavior.
2. Add version 2 layout with seed-derived island count, irregular placement with separation, varied aspect and coast fields. Keep starter land and resources near spawn. Test identical/different seeds, overlap and island shape.
3. Add cached seeded noise for coastline warp, ridges, macro elevation, valleys and local climate. Use these for height, colors and ecological placement. Test terrain diversity and determinism.
4. Add biome-aware collectible placement and GPU-instanced decorative forest, undergrowth and rock cover. Keep decorative placements separate from persistent gameplay resources. Test deterministic transforms, terrain contact and basic counts.
5. Add navigable cave meshes with terrain openings and trimesh collision. Test entry openings, interior clearance and deterministic locations.
6. Preserve generator versions through saves; test v1 loading and v2 round trip. Run the relevant Godot smoke tests and report any environment limitation accurately.

## Constraints

No new third-party runtime dependency. Retain the low-poly materials and existing resource scenes. Limit costly generation to streamed islands. Graphic quality must not change gameplay placements or save identities.
