# tilework — Claude Code Context

## Package overview

`tilework` is an R package (S4 OOP) for tile/patch-based processing of large spatial and raster datasets. Tiles are planned lazily — bounds are computed on demand from stored plan parameters, never as a stored list. All tile plan classes extend the virtual `tilePlan` base class.

Full architecture is documented in `vignettes/articles/design.Rmd`.

## File structure

```
R/
  classes.R                   # All S4 class definitions
  generics.R                  # Generic function declarations
  tilePlan.R                  # Abstract tilePlan methods, shared helpers, factory
  spatialTilePlan.R           # CRS-extent-based uniform grid tiling
  pixelTilePlan.R             # Pixel-exact uniform grid tiling
  pointTilePlan.R             # Arbitrary-center tiling with input/output toggles
  freeTilePlan.R              # Explicit per-tile bounds, variable sizes
  tileGroup.R                 # Hierarchical grouping of tiles
  tileIterator.R              # Stateful closure-based iterator + iterSplit()
  tileSelection.R             # Lazy selection wrapper (drop = FALSE indexing)
  intersect.R                 # Spatial tile selection via intersect()
  getTile.R                   # Data + tile* interaction layer
  getBoundedData.R            # Low-level data extraction by bounds
  tileApply.R                 # Parallel processing framework + token dispatch
  tileApply_tilePlan.R
  tileApply_tileGroup.R
  tileApply_tileIterator.R
  tileApply_tileSelection.R
  parallel.R                  # future/BiocParallel backend wrappers
  utils.R                     # Coordinate math helpers, printing
  utils-logging.R
```

## Class hierarchy

```
tilePlan (virtual)
├── spatialTilePlan   — uniform grid, CRS-aware, returns SpatExtent from [i]
├── pixelTilePlan     — uniform grid, pixel-exact, returns integer[4] from [i]
├── pointTilePlan     — arbitrary centers, uniform tile dims, input/output toggles
└── freeTilePlan      — explicit per-tile bounds, variable sizes

tilework (virtual, parent of all)
├── tilePlan (+ above subclasses)
├── tileGroup
├── tileIterator
└── tileSelection
```

`token` is a separate internal dispatch sentinel class, not in the `tilework` hierarchy.

## Constructors

Each concrete `tilePlan` subclass has a dedicated constructor that accepts key setup params directly, applying them via their `$<-` setters after `new()`:

| Constructor | Key params | File |
|---|---|---|
| `spatialTilePlan(ext, n, ...)` | `ext` → `ext(x)<-`, `n` → `length(x)<-` | `spatialTilePlan.R` |
| `pixelTilePlan(pxdims, ncols, nrows, ...)` | applied via `$pxdims<-`, `$ncols<-`, `$nrows<-` | `pixelTilePlan.R` |
| `pointTilePlan(input, output, coords, width, height, ...)` | applied via `$coords<-`, `$width<-`, `$height<-` | `pointTilePlan.R` |
| `freeTilePlan(...)` | no extra params; populate via `$bounds<-` | `freeTilePlan.R` |

`tilePlan(type, ...)` is a factory that dispatches to the appropriate constructor. `type` is one of `"spatial"`, `"pixel"`, `"point"`, `"free"`.

## Key slots (`tilePlan` base)

| Slot | Type | Meaning |
|---|---|---|
| `n` | numeric | Total tile count |
| `dims` | integer[2] | `c(nrows, ncols)` in tile grid |
| `tile_dims` | numeric[2] | Per-tile `c(height, width)` |
| `pad` | numeric | Uniform expansion on all 4 sides at extraction time |
| `metadata` | data.frame | Per-tile metadata; always has a `"tile"` column |

`$stride<-` is a computed setter on any `tilePlan` with `tile_dims` populated: sets `@pad` via `pad = mean((tile_dims - stride) / 2)`. Accepts scalar or length-2 value. `$stride` reads back the effective stride as `tile_dims - 2 * pad`. Not applicable to `freeTilePlan` (no `tile_dims`).

`spatialTilePlan` adds `@extent` (numeric[4]). `pixelTilePlan` adds `@pxdims` (numeric[2]).

`pointTilePlan` adds `@coords` (n×2 matrix), `@input` ("spatial"|"pixel"), `@output` ("spatial"|"pixel"), `@rast_dims` (numeric[2], optional), `@extent` (numeric[4], optional). `@dims` is always `c(n, 1L)`. `@tile_dims` is in the input coordinate space.

`freeTilePlan` adds `@bounds` (n×4 matrix: xmin, xmax, ymin, ymax). `@tile_dims` is intentionally not populated.

## How tile bounds are computed

`[tilePlan, numeric, missing]` converts flat index → `(i, j)` via `.tile_idx_to_ij()`, then dispatches to `[tilePlan, numeric, numeric]`, which calls `.extract_ij_tile()`.

`.extract_ij_tile()` accepts three pluggable arguments forwarded from the concrete class `[` method:

| Arg | `spatialTilePlan` | `pixelTilePlan` | `pointTilePlan` |
|---|---|---|---|
| `tile_fun` | `.spat_tile_bounds` | `.px_tile_bounds` | one of `_s2s`, `_s2p`, `_p2p`, `_p2s` (driven by `@input`/`@output`) |
| `fun` | `ext` | `as.integer` | `ext` or `as.integer` (driven by `@output`) |
| `zero` | `FALSE` | `TRUE` | `FALSE` |

`zero = TRUE` calls `.tile_pad_zero()` after `.do_tile_pad()` — for pixel plans this shifts bounds so tile (1,1) does not go below index 1. Padding is always applied by `.do_tile_pad()`.

The `fun` return type drives `getBoundedData` dispatch: `SpatExtent` → spatial windowing, `integer[4]` → pixel indexing.

### `pointTilePlan` input/output model

`[i]` returns bounds in the **input** coordinate space. `@output` is not consulted at `[i]` time — it is resolved later by `getTile()`. The four `tile_fun` helpers (`.point_tile_bounds_s2s`, `_s2p`, `_p2p`, `_p2s`) handle cross-mode conversion. Cross-mode helpers require `@rast_dims` and `@extent`; `getTile(SpatRaster, pointTilePlan)` injects these automatically from the raster.

## Spatial methods

### `as.polygons(tilePlan)`

Converts any tile plan to a `SpatVector` of padded rectangles (one per tile). Implemented in each subclass for performance; falls back to `x[]` loop on the base class.

- `spatialTilePlan` / `freeTilePlan`: vectorized bounds matrix → `.tile_bounds_to_sv()` (single `terra::vect()` call)
- `pointTilePlan`: center ± half-dims in output coordinate space
- `.tile_bounds_to_sv(bounds, ids)` in `utils.R` is the shared constructor; takes an n×4 matrix and builds 5-point closed rings

### `intersect(tilePlan, y)` → `tileSelection`

Returns a `tileSelection` of tiles whose padded bounds overlap the query region `y` (`SpatExtent` or `SpatVector`). Implemented in `intersect.R`.

- `spatialTilePlan`: analytic O(1) range formula — computes `[j_min, j_max]` × `[i_min, i_max]` directly
- `freeTilePlan`: vectorized AABB comparison across `@bounds` rows
- Base fallback: `as.polygons()` + `terra::relate(..., "intersects")`
- `SpatVector` queries: AABB pre-cull first, then exact `terra::relate()` on candidates

Touching edges count as intersection (inclusive `>=`/`<=`).

## `tileSelection` — lazy index wrapper

Stores `@tp` (a `tilePlan`) and `@indices` (integer vector). Key behaviors:

- `[i]` → actual bounds via `tp[indices[i]]`
- `[i, drop=FALSE]` → new `tileSelection` with `indices <- indices[i]`
- `$name` → `tp@metadata[indices, name]` (metadata passthrough)
- `$name<-` → writes back to `tp@metadata[indices, name]`
- `length()` → `length(indices)`
- `+` / `-` delegate to the underlying `tp`

## Adding a new tilePlan class — pattern

1. Define the class in `classes.R` extending `"tilePlan"`.
2. Create `R/<ClassName>.R` with `@include classes.R` and `@include tilePlan.R`.
3. Write `initialize` to populate `@dims`, `@n`, and `@metadata`.
4. Write a `tile_fun`: `function(x, i, j)` returning `c(xmin, xmax, ymin, ymax)`.
5. Implement `[` dispatching to `callNextMethod(x, i, j, tile_fun = ..., fun = ..., zero = ...)`.
6. Implement `show`, `plot`, and any class-specific `$`/`$<-` methods.
7. Write a dedicated constructor. Apply setup params via `$<-` setters after `new()`.
8. Register the constructor in the `tilePlan()` factory in `tilePlan.R`.

`getTile` and `tileApply` require no changes as long as `[i]` returns `SpatExtent` or `integer[4]`.

## Data flow

```
tileApply(x, tp, FUN)
  └── redispatch_tileapply()           # token sentinel preprocessing
        └── tileApply(token, token, tp)
              └── getTile(x, tp, i)    # get_params_x/y spread as flat named args
                    └── getBoundedData(x, bound)   # dispatches on (data class, bound class)
```

Special params injected into `FUN` if present in `formals()`: `.I` (flat index), `.R` (row), `.C` (col), `.TILE` (bounds object).

### `tileApply` param routing

`get_params_x`/`get_params_y` are spread as **flat named args** in the `getTile` call. Each layer consumes its own:

- `getTile(character, tilePlan)` consumes `prefer`, `ext`
- `getTile(SpatRaster, tilePlan)` consumes `lyr`, `extend`, `fill`
- `getBoundedData` receives whatever remains in `...`

`sel_params` (a named list) is the dedicated channel for `[` selection params such as `expand_grid`. `default_get_params` in `redispatch_tileapply` should only contain params for the `getTile` chain — not params with static defaults in `getTile` signatures.

### Debugging dispatch

Set `options("tilework.verbose" = "debug")` (or pass `verbose = "debug"` to `tileApply`) to trace each step of the `redispatch_tileapply` chain, including which method matched and what `...` params were present.

## Coordinate conventions

- Flat ↔ (i, j): `.tile_idx_to_ij(x, i)` and `.ij_to_tile_idx(x, i, j)`. Row-major, 1-based.
- `dims = c(nrows, ncols)`. `i` = row, `j` = col.
- Bounds always `c(xmin, xmax, ymin, ymax)` internally before `fun` post-processing.
- Spatial offsets: `offset = c(ymin, xmin)` of the plan extent.
