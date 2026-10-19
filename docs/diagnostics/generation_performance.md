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
