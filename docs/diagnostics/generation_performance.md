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

## Staged main-thread attachment

Version 2 now attaches a background result across three frames: first the terrain mesh and decorative MultiMeshes, then the unchanged terrain collision shape, then collectible resources and animals. Player physics remains gated until all three stages finish. Cached islands with a complete terrain/collision/details entry still reload immediately. A seed change, unload or deactivation removes unfinished attachment work. Existing version 1 saves continue through the synchronous path.

Three fresh Godot 4.3 headless processes measured seed `12345` with `SURVIVE_ASYNC_GENERATION=1` after this stage:

| Initial load wall time (ms) | Largest observed process-frame interval (ms) | Mesh/decor attachment (ms) | Collision stage (ms) | Resource/animal stage (ms) | Cache reload (ms) |
| --- | --- | --- | --- | --- | --- |
| 821, 815, 807 | 60.8, 61.6, 61.1 | 4, 4, 4 | 61, 61, 60 | 28, 28, 28 | 28, 28, 28 |

The largest observed interval is now the terrain collision stage. The underlying collision geometry is unchanged, so this stage addresses scheduling rather than collision fidelity. A roughly 61 ms headless frame is still too long for a smooth 60 FPS target. Graphical FPS, draw calls and frame pacing remain unmeasured.

## Background collision triangle preparation

The background worker now expands the terrain's indexed triangles into the face array used by a `ConcavePolygonShape3D`. The main thread still creates and attaches the physics shape; synchronous generation and cached reloads retain their existing paths. The worker result is discarded on seed change, chunk unload or world deactivation. A geometry test compares all 103,386 generated face vertices against the terrain mesh for seed `12345`; the largest conversion difference observed was about 0.0001 world units, with identical triangle count and order.

Three fresh Godot 4.3 headless processes, seed `12345`, `SURVIVE_ASYNC_GENERATION=1`:

| Initial load wall time (ms) | Largest observed process-frame interval (ms) | Mesh/decor attachment (ms) | Collision stage (ms) | Resource/animal stage (ms) | Background sampling including collision faces (ms) | Cache reload (ms) |
| --- | --- | --- | --- | --- | --- | --- |
| 798, 792, 799 | 31.4, 31.1, 31.4 | 4, 4, 4 | 31, 31, 31 | 29, 28, 28 | 639, 636, 643 | 28, 28, 28 |

The collision-stage interval fell from about 61 ms to 31 ms in this headless setup. Resource/animal creation is now close to the collision stage in cost. The observed interval still exceeds a 16.7 ms frame budget, and graphical FPS, draw calls and frame pacing remain unmeasured.

## Collision attachment across frames

Version 2 now installs the prepared terrain triangles as four `ConcavePolygonShape3D` children of the same static island body, one part per frame. The player remains gated until all four parts and the resources/animals are attached. A complete set of four shapes is cached and reused on island reload; the synchronous path, including version 1, keeps its single terrain shape. The staged test verifies that the four shapes preserve the full face order and count, that physics rays hit each part, that cached reload reuses all four shape resources, and that a seed change cancels partial attachment.

A local shape-only probe on seed `12345` measured about 30.6 ms to set all 103,386 face vertices in one shape, versus a maximum of 6.5 ms for each of four shapes. Three fresh Godot 4.3 headless processes with `SURVIVE_ASYNC_GENERATION=1` measured the complete generator:

| Initial load wall time (ms) | Largest observed process-frame interval (ms) | Collision total across four frames (ms) | Largest collision-part frame (ms) | Resource/animal stage (ms) | Cache reload (ms) |
| --- | --- | --- | --- | --- | --- |
| 795, 795, 794 | 29.9, 29.9, 29.3 | 27, 25, 26 | 7, 7, 7 | 29, 29, 28 | 28, 28, 28 |

The resource/animal stage now determines the largest observed interval. The terrain still has 34,462 triangles. Four physics shapes may have different contact behavior at their boundaries than one shape, so representative gameplay and graphical profiling remain necessary. The headless interval remains above a 16.7 ms frame budget.

## Background resource placement planning

The version 2 worker now calculates collectible tree and rock placements alongside terrain, collision faces and decoration. The main thread still creates resource nodes and restores their saved state after collision is ready. Synchronous generation and cached reloads calculate the same plan on demand. Plans are discarded when their chunk unloads or a build is cancelled. Frozen resource fingerprints cover two seeds, the first outer island and the coastline mode used by older version 2 saves; the async test also checks the resulting starting island.

Three fresh Godot 4.3 headless processes measured seed `12345` with `SURVIVE_ASYNC_GENERATION=1`:

| Initial load wall time (ms) | Largest observed process-frame interval (ms) | Resource/animal attachment (ms) | Background sampling including resources (ms) | Cache reload (ms) |
| --- | --- | --- | --- | --- |
| 831, 821, 824 | 28.9, 29.1, 29.4 | 17, 17, 17 | 670, 667, 665 | 28, 28, 28 |

Resource and animal attachment fell from roughly 28–29 ms at the preceding checkpoint to 17 ms here. The largest observed process-frame interval remained near 29 ms, so this change alone does not meet a 16.7 ms frame budget. Initial readiness stayed around 0.8 seconds, and cached reloads still calculate placements synchronously. These headless CPU measurements are not graphical FPS or GPU timings.
