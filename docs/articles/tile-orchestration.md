# Selecting, Grouping, and Iterating Tiles

``` r
library(tilework)
library(terra)
#> terra 1.9.11

f <- system.file("ex/elev.tif", package = "terra")
r <- rast(f)

tp <- pixelTilePlan(pxdims = dim(r)[1:2], nrows = 20L, ncols = 20L)
```

## Overview

A `tilePlan` defines the geometry of a tiling. Three higher-level
structures control *which* tiles get processed and *how*:

| Class | Purpose | Parallelization |
|----|----|----|
| `tileSelection` | Lazy index subset of a plan | Same as underlying `tilePlan` |
| `tileGroup` | Named groups of tiles | Across groups **or** within groups |
| `tileIterator` | Stateful streaming in batches | Batches distributed across workers |

These are not mutually exclusive — a `tileGroup` can be wrapped in a
`tileIterator`, and a `tileGroup` itself wraps a `tilePlan`.

------------------------------------------------------------------------

## Basic tile processing

Before introducing the higher-level structures, it helps to see what
`tileApply` looks like on a plain `tilePlan`. This is the baseline that
`tileSelection`, `tileGroup`, and `tileIterator` all build on.

``` r
results <- tileApply(r, tiles = tp, FUN = function(x, .I, .R, .C) {
    list(
        mean = terra::global(x, "mean", na.rm = TRUE)[[1L]],
        tile = .I,
        row  = .R,
        col  = .C
    )
})
#> Warning: Your code is running sequentially. For better performance, consider using a
#>  parallel plan like:
#>   future::plan(future::multisession)
#>   To silence this warning, set options("tilework.warn_sequential" = FALSE)

str(results[[1L]])
#> List of 4
#>  $ mean: num 476
#>  $ tile: int 1
#>  $ row : num 1
#>  $ col : int 1
```

`FUN` receives the extracted tile data as its first argument. Four
special parameters are available and injected automatically when present
in `formals(FUN)`:

| Injectable | Type                         | Value                   |
|------------|------------------------------|-------------------------|
| `.I`       | `integer`                    | Flat tile index         |
| `.R`       | `integer`                    | Tile row in the grid    |
| `.C`       | `integer`                    | Tile column in the grid |
| `.TILE`    | `SpatExtent` or `integer[4]` | Tile bounds object      |

Every tile is processed independently. When a `future` plan with
multiple workers is active, tiles are distributed across workers
automatically. The higher-level structures below give you control over
*which* tiles are processed, in *what order*, and with *what per-worker
state*.

------------------------------------------------------------------------

## `tileSelection`

`tileSelection` is the result of `drop = FALSE` indexing on a
`tilePlan`. It stores a subset of tile indices without computing any
bounds, and is passed directly to `tileApply` like a plan.

``` r
# Select specific tiles without materialising bounds
sel <- tp[c(1, 5, 9, 13), drop = FALSE]
sel
#> <tileSelection>: pixelTilePlan
#> 4 tiles
length(sel)
#> [1] 4
```

``` r
results <- tileApply(r, tiles = sel, FUN = function(x, .I) {
    terra::global(x, "mean", na.rm = TRUE)[[1L]]
})
#> Warning: Your code is running sequentially. For better performance, consider using a
#>  parallel plan like:
#>   future::plan(future::multisession)
#>   To silence this warning, set options("tilework.warn_sequential" = FALSE)
str(results)
#> List of 4
#>  $ : num 476
#>  $ : num NaN
#>  $ : num 265
#>  $ : num 314
```

**When to use:** You have a plan but only want to process a known subset
— for example, tiles that intersect a region of interest, tiles flagged
in metadata, or a manual quality-control subset. It avoids rebuilding
the plan and keeps the original tile indices as identifiers.

------------------------------------------------------------------------

## `tileGroup`

`tileGroup` organises tiles from a plan into named groups. Each group is
a logical partition — groups can overlap, and not all tiles need to be
assigned to a group.

``` r
nr <- nrow(tp)
nc <- ncol(tp)

tg <- tileGroup(tp, groups = list(
    interior = list(2:(nr - 1L), 2:(nc - 1L)),  # ij indexing
    border   = c(                                 # vector indexing
        # top and bottom rows
        seq_len(nc),
        seq(length(tp) - nc + 1L, length(tp)),
        # left and right columns (excluding corners)
        seq(nc + 1L, length(tp) - nc, by = nc),
        seq(nc + nc, length(tp) - 1L, by = nc)
    )
))

tg
#> <tileGroup>: pixelTilePlan
#> groups-------------------------
#>   interior : 9 tiles
#>   border   : 16 tiles
```

Groups accept the same indexing styles as the underlying plan, and they
can be mixed within the same `tileGroup`:

- **Vector indexing** — a flat integer vector of tile indices.
- **ij indexing** — a `list(rows, cols)` that selects by grid position,
  expanding all row × col combinations. `list(2:(nr-1), 2:(nc-1))` means
  all interior rows × all interior cols.

### Parallelization strategies

`tileApply` on a `tileGroup` accepts a `parallel_strategy` argument:

**`"groups"` (default)** — groups are distributed across workers. Each
worker processes all tiles in its assigned group sequentially. This is
the right choice when:

- Groups have meaningfully different processing logic
- Per-worker setup cost is significant (model loading, DB connection) —
  use `setup_FUN` which runs once per group/worker
- Groups are large enough to keep workers busy

``` r
results_groups <- tileApply(r,
    tiles = tg,
    parallel_strategy = "groups",
    setup_FUN = function(.GROUP) {
        # Runs once per group — expensive setup goes here
        list(group_name = .GROUP, initialized_at = Sys.time())
    },
    FUN = function(x, .I, .GROUP, .SETUP_OUT) {
        list(
            tile  = .I,
            group = .GROUP,
            mean  = terra::global(x, "mean", na.rm = TRUE)[[1L]]
        )
    }
)
#> Warning: Your code is running sequentially. For better performance, consider using a
#>  parallel plan like:
#>   future::plan(future::multisession)
#>   To silence this warning, set options("tilework.warn_sequential" = FALSE)

# Results are a named list with one element per group
names(results_groups)
#> [1] "interior" "border"
length(results_groups$interior)
#> [1] 9
```

**`"tiles"`** — groups are processed sequentially, but tiles *within*
each group are distributed across workers. This is the right choice
when:

- Each tile is expensive and independent
- Groups are few but tiles per group are many
- Per-worker setup cost is low (no `setup_FUN` available here)

``` r
results_tiles <- tileApply(r,
    tiles = tg,
    parallel_strategy = "tiles",
    FUN = function(x, .I, .GROUP) {
        terra::global(x, "mean", na.rm = TRUE)[[1L]]
    }
)
#> Warning: Your code is running sequentially. For better performance, consider using a
#>  parallel plan like:
#>   future::plan(future::multisession)
#>   To silence this warning, set options("tilework.warn_sequential" = FALSE)

names(results_tiles)
#> [1] "interior" "border"
```

### `group_FUN`

An optional `group_FUN` is applied to each group’s result list after all
tiles in that group are processed. This is a convenient hook for
within-group aggregation, avoiding a separate post-processing pass.

``` r
results_agg <- tileApply(r,
    tiles = tg,
    FUN = function(x, .I) {
        terra::global(x, "mean", na.rm = TRUE)[[1L]]
    },
    group_FUN = function(group_results, .GROUP) {
        vals <- unlist(group_results)
        list(
            group  = .GROUP,
            n      = length(vals),
            mean   = mean(vals, na.rm = TRUE),
            range  = range(vals, na.rm = TRUE)
        )
    }
)
#> Warning: Your code is running sequentially. For better performance, consider using a
#>  parallel plan like:
#>   future::plan(future::multisession)
#>   To silence this warning, set options("tilework.warn_sequential" = FALSE)

str(results_agg, max.level = 2)
#> List of 2
#>  $ interior:List of 4
#>   ..$ group: chr "interior"
#>   ..$ n    : int 9
#>   ..$ mean : num 323
#>   ..$ range: num [1:2] 265 411
#>  $ border  :List of 4
#>   ..$ group: chr "border"
#>   ..$ n    : int 16
#>   ..$ mean : num 356
#>   ..$ range: num [1:2] 222 476
```

**When to use:** Any time tiles have a natural logical partition —
different tissue regions, different processing requirements, edge
vs. interior tiles (as in the [ML
vignette](https://drieslab.github.io/tilework/articles/patch-feature-extraction.md)),
or simply grouping tiles for separate output files.

------------------------------------------------------------------------

## `tileIterator`

`tileIterator` wraps any `tilePlan` or `tileGroup` (with `$active` set)
and adds stateful position tracking. Instead of processing all tiles at
once, it yields batches of a fixed size on demand.

``` r
iter <- tileIterator(tp, batch_size = 5L)
iter
#> Object of class tileIterator
#> tiles      : pixelTilePlan
#> position   : 0
#> bound      : [1, 25]
#> batch_size : 5
#> progress   : 0%
#> remaining  : 25
```

### Manual streaming

For full control, iterate manually with `$has_next` and `$next_batch()`:

``` r
iter$reset()

while (iter$has_next) {
    batch <- getTile(r, iter)
    # process batch...
}

iter$progress  # 100%
#> [1] 100
```

### With `tileApply`

Passing a `tileIterator` to `tileApply` triggers the streaming dispatch
path.
[`iterSplit()`](https://drieslab.github.io/tilework/reference/iterSplit.md)
partitions the iterator’s remaining range across
[`future::nbrOfWorkers()`](https://future.futureverse.org/reference/nbrOfWorkers.html)
sub-iterators. Each worker independently streams through its assigned
tiles in batches.

``` r
iter$reset()

results <- tileApply(r,
    tiles = iter,
    FUN = function(batch, .I, .BATCH, .POSITION) {
        # batch is a list of SpatRaster tiles
        # .I    — tile indices in this batch
        # .BATCH — batch number within this worker
        # .POSITION — c(start_index, end_index) of this batch
        lapply(batch, function(tile) {
            terra::global(tile, "mean", na.rm = TRUE)[[1L]]
        })
    }
)
#> Warning: Your code is running sequentially. For better performance, consider using a
#>  parallel plan like:
#>   future::plan(future::multisession)
#>   To silence this warning, set options("tilework.warn_sequential" = FALSE)
```

### `setup_FUN` for per-worker initialization

When `tileApply` distributes work across workers, `setup_FUN` runs once
on each worker before batch processing begins. Its output is passed to
every `FUN` call as `.SETUP_OUT`. This is the mechanism for loading a
model, opening a database connection, or any other expensive per-worker
setup.

``` r
iter$reset()

results <- tileApply(r,
    tiles = iter,
    setup_FUN = function(.W, .X) {
        # .W — worker index
        # .X — the input data object
        list(worker = .W, nrow = nrow(.X), ncol = ncol(.X))
    },
    FUN = function(batch, .SETUP_OUT) {
        worker_info <- .SETUP_OUT
        lapply(batch, function(tile) {
            terra::global(tile, "mean", na.rm = TRUE)[[1L]]
        })
    }
)
#> Warning: Your code is running sequentially. For better performance, consider using a
#>  parallel plan like:
#>   future::plan(future::multisession)
#>   To silence this warning, set options("tilework.warn_sequential" = FALSE)
```

### Iterator splitting

[`iterSplit()`](https://drieslab.github.io/tilework/reference/iterSplit.md)
divides an iterator’s remaining range into `n` independent sub-iterators
with no shared state. This is what `tileApply` calls internally, but it
is also available directly for custom parallel workflows.

``` r
iter$reset()
sub_iters <- iterSplit(iter, n = 3L)

# Each sub-iterator covers a non-overlapping range
sapply(sub_iters, function(x) x$bound)
#>      [,1] [,2] [,3]
#> [1,]    1   10   18
#> [2,]    9   17   25
sapply(sub_iters, function(x) x$remaining)
#> [1] 9 8 8
```

**When to use:** Large datasets where loading all tile data
simultaneously would exhaust memory; workflows requiring checkpointing
(serialize the iterator mid-run and resume later); ML inference
pipelines where batch size must match the model’s expected input count.
See the [ML feature extraction
vignette](https://drieslab.github.io/tilework/articles/patch-feature-extraction.md)
for a full worked example.

------------------------------------------------------------------------

## Choosing between them

| Situation | Recommended |
|----|----|
| Process a fixed known subset of tiles | `tileSelection` |
| Tiles have distinct logical groupings with different logic | `tileGroup` |
| Few groups, many tiles per group, tile processing is expensive | `tileGroup`, `parallel_strategy = "tiles"` |
| Many groups, tiles per group is small, setup cost per group matters | `tileGroup`, `parallel_strategy = "groups"` with `setup_FUN` |
| Dataset too large to hold all tile data in memory at once | `tileIterator` |
| Worker warmup is expensive (model loading) and batching is needed | `tileIterator` with `setup_FUN` |
| Checkpoint and resume a long-running job | `tileIterator` (serialize and restore) |

------------------------------------------------------------------------

## Parallelization backends

All `tileApply` methods delegate to
[`future.apply::future_lapply`](https://future.apply.futureverse.org/reference/future_lapply.html).
The active `future` plan controls how work is distributed.

``` r
library(future)

# Sequential (default, no parallelism)
plan(sequential)

# Local multicore (forking, fast on Linux/macOS)
plan(multicore, workers = 4L)

# Local multisession (separate R processes, works everywhere)
plan(multisession, workers = 4L)

# Mirai backend (lower overhead, faster for many workers)
plan(future.mirai::mirai_multisession, workers = 4L)

# Reset to sequential when done
plan(sequential)
```

`tileGroup` with `parallel_strategy = "groups"` parallelizes at the
group level — each `future` worker handles one group. With
`parallel_strategy = "tiles"`, each worker handles one tile within the
current group.

`tileIterator` always parallelizes at the worker level: `iterSplit`
divides the tile range across
[`nbrOfWorkers()`](https://future.futureverse.org/reference/nbrOfWorkers.html)
sub-iterators, and each worker streams through its assigned range
independently.
