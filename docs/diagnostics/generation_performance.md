# Generation performance checkpoint

Measured with Godot 4.3 headless, seed `12345`, one central chunk, and a fresh process for each run. Command: `SURVIVE_TEST_SEED=12345 SURVIVE_GENERATOR_VERSION=2 godot --headless --path . --script res://tools/benchmark_world_generation.gd` (use version `1` for the legacy comparison).

| Generator | Initial load (ms) | Reload after unload (ms) |
| --- | ---: | ---: |
| v1 | 315, 317, 317 | 283, 285, 285 |
| v2 with bounded cache | 963, 951, 959 | 64, 63, 64 |
| v2 after first load CPU optimization | 808, 807, 806, 803, 802 | 60, 60, 60, 60, 60 |

The latest measurements used the same seed and headless command in five fresh processes. Median initial load fell from 971 ms in the immediately preceding local baseline (989, 966, 971) to 806 ms (808, 807, 806, 803, 802), about 17%. The generator now reuses noise fields through per-island dictionaries instead of formatting a composite string on every lookup, and appends terrain triangle indices directly instead of allocating a packed array for each cell. The version 2 world fingerprint remained `39106f69ed120928de2de2ed7aa1e2d85160b16c4f69d0dcbdb5847aebbcc243` before and after the change.

The v2 cache retains the terrain `ArrayMesh` and four surface decoration `MultiMesh` resources for at most two recently used islands. The small `CaveFormations` group is rebuilt on each load. Resource and animal nodes are rebuilt and restored from persistent state on each load. The cache is cleared when the layout is rebuilt, including a seed change. Its effect is on revisiting an island; first generation still runs on the main thread and remains slower than v1 because v2 creates more geography and decoration.

In one separate v2 measurement, process static memory rose by 19,810,196 bytes when loading the central chunk and was 1,405,280 bytes above its pre-load value after the generator was freed. This is process-level memory, not an isolated measurement of the cache. Headless execution cannot provide representative FPS or GPU draw-call counts.

## Visual quality profiles

Version 2 exposes `decoration_quality` on the island generator as `low`, `medium`, or `high` (default). It can be changed while a world is running. The profile changes `MultiMesh.visible_instance_count` for decorative trees, ground cover, and stones. Tree trunks and canopies use the same fraction, so they remain paired. All generated transforms stay in the same order; switching profiles or revisiting a cached island does not regenerate the world. Terrain, caves, collectible resources, animals, and save identifiers are unaffected. Version 1 keeps its existing rendering behavior.

For seed `12345`, the headless benchmark reported these visible instance counts in the central island:

| Profile | Forest trees | Ground cover | Decorative stones |
| --- | ---: | ---: | ---: |
| Low | 190 | 170 | 27 |
| Medium | 304 | 315 | 39 |
| High | 380 | 485 | 49 |

The profiles limit rendered decorative instances. They do not reduce first-generation CPU work or the memory used to hold the complete instance sets. GPU and frame-rate gains still need measurement in a graphical build.

## Progressive island streaming

Version 2 now loads the player's current chunk and any island whose terrain reaches the player immediately. Empty nearby chunks also load immediately. Other island chunks enter a nearest-first queue; the default budget is one distant chunk per frame through `max_distant_chunks_per_frame`. Moving away removes obsolete requests, and deactivating the world clears the queue. Diagnostics expose `pending_chunks` so stalls and incomplete streaming can be observed.

This prevents several distant islands from being generated in one frame. Each individual island still builds its mesh, collision, resources, and decoration synchronously on the main thread when its queued turn arrives. This stage is progressive scheduling, not background-thread generation, so the worst single-island stall remains.
