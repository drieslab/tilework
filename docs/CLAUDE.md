# tilework — Claude Code Context

## Package overview

`tilework` is an R package (S4 OOP) for tile/patch-based processing of
large spatial and raster datasets. Tiles are planned lazily — bounds are
computed on demand from stored plan parameters, never as a stored list.
All tile plan classes extend the virtual `tilePlan` base class.

## File structure

    R/
      classes.R                   # All S4 class definitions
      generics.R                  # Generic function declarations
      tilePlan.R                  # Abstract tilePlan methods, shared helpers, factory
      spatialTilePlan.R           # CRS-extent-based uniform grid tiling
      pixelTilePlan.R             # Pixel-exact uniform grid tiling
      pointTilePlan.R             # Arbitrary-center tiling with input/output toggles
      tileGroup.R                 # Hierarchical grouping of tiles
      tileIterator.R              # Stateful closure-based iterator + iterSplit()
      tileSelection.R             # Lazy selection wrapper (drop = FALSE indexing)
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

## Class hierarchy

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

`token` is a separate internal dispatch sentinel class, not in the
`tilework` hierarchy.

## Constructors

Each concrete `tilePlan` subclass has a dedicated constructor that
accepts key setup params directly, applying them via their `$<-` setters
after `new()`:

| Constructor | Key params | File |
|----|----|----|
| `spatialTilePlan(ext, n, ...)` | `ext` → `ext(x)<-`, `n` → `length(x)<-` | `spatialTilePlan.R` |
| `pixelTilePlan(pxdims, ncols, nrows, ...)` | applied via `$pxdims<-`, `$ncols<-`, `$nrows<-` | `pixelTilePlan.R` |
| `pointTilePlan(input, output, coords, width, height, ...)` | applied via `$coords<-`, `$width<-`, `$height<-` | `tilePlan.R` |
| `freeTilePlan(...)` | no extra params; populate via `$bounds<-` | `freeTilePlan.R` |

`tilePlan(type, ...)` is a factory that dispatches to the appropriate
constructor. `type` is one of `"spatial"`, `"pixel"`, `"point"`,
`"free"`.

## Key slots (`tilePlan` base)

| Slot | Type | Meaning |
|----|----|----|
| `n` | numeric | Total tile count |
| `dims` | integer\[2\] | `c(nrows, ncols)` in tile grid |
| `tile_dims` | numeric\[2\] | Per-tile `c(height, width)` |
| `pad` | numeric | Uniform expansion on all 4 sides at extraction time |
| `metadata` | data.frame | Per-tile metadata; always has a `"tile"` column |

`$stride<-` is a computed setter on any `tilePlan` with `tile_dims`
populated: sets `@pad` via `pad = mean((tile_dims - stride) / 2)`.
Accepts scalar or length-2 value. `$stride` reads back the effective
stride as `tile_dims - 2 * pad`. Not applicable to `freeTilePlan` (no
`tile_dims`).

`spatialTilePlan` adds `@extent` (numeric\[4\]). `pixelTilePlan` adds
`@pxdims` (numeric\[2\]).

`pointTilePlan` adds `@coords` (n×2 matrix), `@input`
(“spatial”\|“pixel”), `@output` (“spatial”\|“pixel”), `@rast_dims`
(numeric\[2\], optional), `@extent` (numeric\[4\], optional). `@dims` is
always `c(n, 1L)`. `@tile_dims` is in the input coordinate space.

## How tile bounds are computed

`[tilePlan, numeric, missing]` converts flat index → `(i, j)` via
`.tile_idx_to_ij()`, then dispatches to `[tilePlan, numeric, numeric]`,
which calls `.extract_ij_tile()`.

`.extract_ij_tile()` accepts three pluggable arguments forwarded from
the concrete class `[` method:

| Arg | `spatialTilePlan` | `pixelTilePlan` | `pointTilePlan` |
|----|----|----|----|
| `tile_fun` | `.spat_tile_bounds` (default) | `.px_tile_bounds` | one of `_s2s`, `_s2p`, `_p2p`, `_p2s` (driven by `@input`/`@output`) |
| `fun` | `ext` | `as.integer` | `ext` or `as.integer` (driven by `@output`) |
| `zero` | `FALSE` | `TRUE` | `FALSE` |

`zero = TRUE` calls `.tile_pad_zero()` after `.do_tile_pad()` — for
pixel plans this shifts bounds so tile (1,1) does not go below index 1.
Padding is always applied by `.do_tile_pad()`.

The `fun` return type is what drives `getBoundedData` dispatch
downstream: `SpatExtent` routes to spatial windowing, `integer[4]`
routes to pixel indexing.

### `pointTilePlan` input/output model

`[i]` returns bounds in the **output** coordinate space (`@output`),
driven by both `@input` and `@output`. The four `tile_fun` helpers
(`.point_tile_bounds_s2s`, `_s2p`, `_p2p`, `_p2s`) handle the
conversion. Cross-mode helpers (`_s2p`, `_p2s`) require `@rast_dims` and
`@extent` to be populated.

A dedicated `getTile(SpatRaster, pointTilePlan)` method handles the
common case where a raster is available: when `input != output`, it
injects `@rast_dims` and `@extent` from the raster before `[i]` runs, so
users do not need to set these slots manually.

| Scenario | `@rast_dims` | `@extent` | Notes |
|----|----|----|----|
| `input = "spatial"`, `output = "spatial"` | not needed | not needed |  |
| `input = "pixel"`, `output = "pixel"` | for [`plot()`](https://drieslab.github.io/tilework/reference/plot.md) reference rect | not needed |  |
| `input = "pixel"`, `output = "spatial"` | standalone `[i]` only | standalone `[i]` only | injected from raster at `getTile` time |
| `input = "spatial"`, `output = "pixel"` | standalone `[i]` only | standalone `[i]` only | injected from raster at `getTile` time |

## Adding a new tilePlan class — pattern

1.  Define the class in `classes.R` extending `"tilePlan"`.
2.  Create `R/<ClassName>.R` with `@include classes.R` and
    `@include tilePlan.R`.
3.  Write an `initialize` method that populates `@dims`, `@n`, and
    `@metadata`. Use prototype entries in the class definition for
    static defaults; use explicit `if (length(...) == 0L)` checks only
    for slots whose defaults depend on other slots.
4.  Write a `tile_fun` helper: `function(x, i, j)` returning
    `c(xmin, xmax, ymin, ymax)`.
5.  Implement `[` dispatching to
    `callNextMethod(x, i, j, tile_fun = ..., fun = ..., zero = ...)`.
6.  Implement `show`, `plot`, and any class-specific `$`/`$<-` methods.
7.  Write a dedicated constructor function
    (e.g. `fooTilePlan <- function(...)`) in the class file. Expose key
    setup params directly (anything that would otherwise require a `$<-`
    setter call after construction). Apply them via their setters after
    `new()` so validation logic is not duplicated.
8.  Register the constructor in the
    [`tilePlan()`](https://drieslab.github.io/tilework/reference/tilePlan.md)
    factory in `tilePlan.R`.

`getTile` and `tileApply` require no changes as long as `[i]` returns
`SpatExtent` or `integer[4]` — `getBoundedData` dispatch handles the
rest. A dedicated `getTile` method is only needed when
pre/post-processing is required (e.g., layer selection, coordinate-space
conversion).

## Data flow

    tileApply(x, tp, FUN)
      └── redispatch_tileapply()           # token sentinel preprocessing
            └── tileApply(token, token, tp)
                  └── getTile(x, tp, i)    # get_params_x/y spread as flat named args
                        └── getBoundedData(x, bound)   # dispatches on (data class, bound class)

Special params injected into `FUN` if present in
[`formals()`](https://rdrr.io/r/base/formals.html): `.I` (flat index),
`.R` (row), `.C` (col), `.TILE` (bounds object).

### `tileApply` param routing

`get_params_x`/`get_params_y` are spread as **flat named args** in the
`getTile` call (not wrapped in a `get_params` list). This means each
layer of the `getTile` dispatch chain consumes its own named params
naturally:

- `getTile(character, tilePlan)` consumes `prefer`, `ext`
- `getTile(SpatRaster, tilePlan)` consumes `lyr`, `extend`, `fill`
- `getBoundedData` receives whatever remains in `...`

`sel_params` (a named list) is the dedicated channel for `[` selection
params such as `expand_grid`. The `...` in `getTile(ANY, tilePlan)`
flows to `getBoundedData`, not to `[`.

`default_get_params` in `redispatch_tileapply` methods should only
contain params intended for the `getTile` chain — typically `prefer` and
`ext`. Do not include params that already have static defaults in
`getTile` signatures (`lyr`, `extend`, `fill`).

## Coordinate conventions

- Flat ↔︎ (i, j): `.tile_idx_to_ij(x, i)` and `.ij_to_tile_idx(x, i, j)`.
  Row-major, 1-based.
- `dims = c(nrows, ncols)`. `i` = row, `j` = col.
- Bounds always `c(xmin, xmax, ymin, ymax)` internally before `fun`
  post-processing.
- Spatial offsets: `offset = c(ymin, xmin)` of the plan extent.

------------------------------------------------------------------------

## `freeTilePlan` and `quadtreePlan`

### `freeTilePlan` class

Tiles defined by explicit per-tile bounds with no required uniformity in
size or spacing. The bounds matrix is the canonical representation —
tile positions are not computed from a formula.

**Slots** (beyond `tilePlan` base):

| Slot     | Type   | Meaning                                          |
|----------|--------|--------------------------------------------------|
| `bounds` | matrix | n × 4: xmin, xmax, ymin, ymax (one row per tile) |

`@tile_dims` is intentionally not populated. `@dims` is `c(n, 1L)`.
Always returns `SpatExtent` from `[i]` (via `ext`, `zero = FALSE`).

`$bounds<-` calls `initialize()` to recompute `@n`, `@dims`, and
`@metadata`.
[`nrow()`](https://drieslab.github.io/tilework/reference/dim.md) returns
`n`, [`ncol()`](https://drieslab.github.io/tilework/reference/dim.md)
returns `1`,
[`length()`](https://drieslab.github.io/tilework/reference/dim.md)
returns `n`.

### `quadtreePlan()` workflow

1.  Start from a coarse `tilePlan`; collect its tile extents as
    `pending`.
2.  Each iteration: build a `freeTilePlan` from `pending`, run
    `tileApply(x, fp, FUN, ...)`, classify each tile as leaf (≤
    threshold or too small) or split into four equal quadrants.
3.  When `max_depth` is reached, remaining `pending` tiles receive one
    final `tileApply` pass to fill their `n_records`.
4.  **Merge pass**: greedily merge pairs of leaf tiles that share a
    complete edge and whose combined `FUN` value stays ≤ threshold.
    Repeats until no further merges are possible.
5.  Return a `freeTilePlan` with `$n_records` set to the last measured
    `FUN` value per leaf (summed across merged tiles).

The merge pass reduces tile count in sparse regions where sibling
quadrants all fall below threshold — they collapse back toward their
parent rectangle.

### Differences between `pointTilePlan` and `freeTilePlan`

|  | `pointTilePlan` | `freeTilePlan` |
|----|----|----|
| Primary data | Center coords (`@coords`) | Explicit bounds (`@bounds`) |
| Tile sizes | Uniform (`@tile_dims`, in input coord space) | Variable (per row of `@bounds`) |
| Coordinate space | `@input`: “spatial” or “pixel” | Inherent to `@bounds` values |
| Output type | `@output` resolved at `getTile` time | Always `SpatExtent` |
| Center info | Preserved and meaningful | Not stored |
| Main use case | Sampling at known locations | Quadtree / adaptive decomposition |
| `@tile_dims` | Used (input coord space units) | Not populated |
| `n_records` metadata | Not set | Set by [`quadtreePlan()`](https://drieslab.github.io/tilework/reference/quadtreePlan.md) |

------------------------------------------------------------------------

## Planned: spatial selection for `tileSelection`

### Goal

`tp[some_extent]` or `tp[some_spatvector]` → `tileSelection` containing
only tiles whose **padded** bounds intersect the query.

### Implementation (not yet done)

Two new `[` methods on `spatialTilePlan` (not the base `tilePlan` —
pixel plans have no CRS context):

``` r
[spatialTilePlan, SpatExtent, missing, missing]
[spatialTilePlan, SpatVector, missing, missing]  # delegates via terra::ext()
```

Both always return a `tileSelection` — no `drop` parameter needed.

**Arithmetic shortcut** — avoid materializing all tiles. Given the
uniform grid layout of `spatialTilePlan`:

    tile (i=row, j=col) padded bounds:
      xmin = xmin_e + (j-1)*tile_w - pad
      xmax = xmin_e + j*tile_w     + pad
      ymin = ymin_e + (i-1)*tile_h - pad
      ymax = ymin_e + i*tile_h     + pad

For a query `[qxmin, qxmax, qymin, qymax]`, intersecting column range:

``` r
j_min <- max(1L, ceiling((qxmin - xmin_e - pad) / tile_w))
j_max <- min(ncol(x), floor((qxmax - xmin_e + pad) / tile_w) + 1L)
```

And row range (i):

``` r
i_min <- max(1L, ceiling((qymin - ymin_e - pad) / tile_h))
i_max <- min(nrow(x), floor((qymax - ymin_e + pad) / tile_h) + 1L)
```

If `j_min > j_max` or `i_min > i_max`, return empty `tileSelection`.
Otherwise convert the `(i_min:i_max, j_min:j_max)` grid to flat indices
via `.ij_to_tile_idx(x, i, j)` with `expand_grid = TRUE`.

**`>=`/`<=` inclusive** — touching edges count as intersection
(important for adjacent tiles in a grid).

Helper lives in `utils.R`. Methods go in `spatialTilePlan.R`.
