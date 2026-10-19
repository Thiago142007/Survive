# Generation performance checkpoint

Measured with Godot 4.3 headless, seed `12345`, one central chunk, and a fresh process for each run. Command: `SURVIVE_TEST_SEED=12345 SURVIVE_GENERATOR_VERSION=2 godot --headless --path . --script res://tools/benchmark_world_generation.gd` (use version `1` for the legacy comparison).

| Generator | Initial load (ms) | Reload after unload (ms) |
| --- | ---: | ---: |
| v1 | 315, 317, 317 | 283, 285, 285 |
| v2 with bounded cache | 963, 951, 959 | 64, 63, 64 |
| v2 after first load CPU optimization | 808, 807, 806, 803, 802 | 60, 60, 60, 60, 60 |
| v2 with cached terrain collision | 819, 808, 810, 802, 810 | 27, 28, 27, 27, 27 |

The first-load CPU optimization measurements used the same seed and headless command in five fresh processes. Median initial load fell from 971 ms in the immediately preceding local baseline (989, 966, 971) to 806 ms (808, 807, 806, 803, 802), about 17%. The generator now reuses noise fields through per-island dictionaries instead of formatting a composite string on every lookup, and appends terrain triangle indices directly instead of allocating a packed array for each cell. The version 2 world fingerprint remained `39106f69ed120928de2de2ed7aa1e2d85160b16c4f69d0dcbdb5847aebbcc243` before and after the change.

The v2 cache retains the terrain `ArrayMesh`, its trimesh collision `Shape3D`, and four surface decoration `MultiMesh` resources for at most two recently used islands. The small `CaveFormations` group is rebuilt on each load. Resource and animal nodes are rebuilt and restored from persistent state on each load. The cache is cleared when the layout is rebuilt, including a seed change. Its effect is on revisiting an island; first generation still runs on the main thread and remains slower than v1 because v2 creates more geography and decoration. In five fresh headless processes immediately before adding collision caching, reloads took 60, 60, 65, 60, and 60 ms (median 60 ms); with collision caching they took 27, 28, 27, 27, and 27 ms (median 27 ms). Collision construction still costs about 60 ms on the first load.

In one separate v2 measurement, process static memory rose by 19,810,196 bytes when loading the central chunk and was 1,405,280 bytes above its pre-load value after the generator was freed. A measurement after collision caching showed a 19,807,996-byte increase while loaded and 1,406,960 bytes remaining after freeing the generator. These are process-level measurements, not an isolated measurement of cache memory. Headless execution cannot provide representative FPS or GPU draw-call counts.

## Visual quality profiles

Version 2 exposes `decoration_quality` on the island generator as `low`, `medium`, or `high` (default). It can be changed while a world is running. The profile changes `MultiMesh.visible_instance_count` for decorative trees, ground cover, and stones. Tree trunks and canopies use the same fraction, so they remain paired. All generated transforms stay in the same order; switching profiles or revisiting a cached island does not regenerate the world. Terrain, caves, collectible resources, animals, and save identifiers are unaffected. Version 1 keeps its existing rendering behavior.

For seed `12345`, the headless benchmark reported these visible instance counts in the central island:

| Profile | Forest trees | Ground cover | Decorative stones |
| --- | ---: | ---: | ---: |
| Low | 190 | 170 | 27 |
| Medium | 304 | 315 | 39 |
| High | 380 | 485 | 49 |

The profiles limit rendered decorative instances. They do not reduce first-generation CPU work or the memory used to hold the complete instance sets. GPU and frame-rate gains still need measurement in a graphical build.

## Distance-based decoration LOD

Version 2 also reduces the visible instance count as the player moves away from an island's conservative terrain radius. Ground cover thins between 120 and 420 meters beyond that radius, decorative stones between 200 and 500 meters, and paired trunks and canopies between 380 and 700 meters. The count follows a smooth curve and is refreshed after roughly 10 meters of player movement. Profile scaling and distance scaling multiply, while the original transforms remain available for approaching the island again or reloading it. Collectible trees and rocks, animals, caves, terrain, and collision do not use this cosmetic LOD.

The project's Compatibility renderer does not provide the same smooth visibility-range fade as Forward+ ([Godot 4.3 GeometryInstance3D documentation](https://docs.godotengine.org/en/4.3/classes/class_geometryinstance3d.html)), so the implementation uses gradual instance-count changes rather than a visibility-range fade. Headless tests verify counts, return-to-near behavior, quality-profile interaction, and deterministic transforms; visual transitions and FPS still need inspection in a graphical build.

## Progressive island streaming

Version 2 now loads the player's current chunk and any island whose terrain reaches the player immediately. Empty nearby chunks also load immediately. Other island chunks enter a nearest-first queue; the default budget is one distant chunk per frame through `max_distant_chunks_per_frame`. Moving away removes obsolete requests, and deactivating the world clears the queue. Diagnostics expose `pending_chunks` so stalls and incomplete streaming can be observed.

This prevents several distant islands from being generated in one frame. At this checkpoint, each island still built its mesh, collision, resources, and decoration synchronously on the main thread. The background sampling stage below addresses the largest part of that stall.

## Background CPU sampling

The game scene now enables background generation for version 2. One worker at a time samples terrain vertex arrays and decorative instance transforms using an isolated generator outside the active scene tree. The main thread creates the terrain mesh, collision shape, nodes, resources, animals and MultiMeshes after sampling finishes. A direct synchronous path remains available for tests and cached reloads. Changing seeds or leaving the world discards obsolete results. The player waits for the initial terrain collision before physics starts, so it cannot fall through the unfinished island.

Three fresh Godot 4.3 headless processes per mode measured seed `12345` with `SURVIVE_ASYNC_GENERATION=0` or `1` in `tools/benchmark_world_generation.gd`:

| Mode | Initial load wall time (ms) | Largest observed process-frame interval (ms) | Cache reload (ms) |
| --- | --- | --- | --- |
| Synchronous | 809, 805, 805 | 749.5, 746.3, 744.5 | 27, 28, 27 |
| Background sampling | 816, 814, 814 | 120.6, 120.0, 118.8 | 28, 29, 29 |

The background worker spent about 625–627 ms sampling terrain and decoration. Main-thread attachment still took 93–94 ms, including collision creation (about 60 ms) and gameplay node creation. This substantially reduces the single-frame stall but does not yet meet a smooth-frame target. The headless process-frame interval is a CPU scheduling observation, not representative graphical FPS or GPU frame time. The total time until the initial island is ready is essentially unchanged. The game still needs graphical profiling, and collision/resource attachment needs another reduction pass.
