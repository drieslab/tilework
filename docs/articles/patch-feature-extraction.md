# Patch-Based Feature Extraction for Machine Learning

``` r
library(tilework)
library(terra)
#> terra 1.9.11
```

## Overview

A common machine learning preprocessing step for large images is to
split them into fixed-size patches, run each patch through a feature
extractor (e.g. a pretrained CNN), and collect the resulting embeddings
for downstream analysis.

The naive approach — loading a model inside `FUN`, once per patch — is
prohibitively slow. Model initialization typically takes several
seconds, so for an image with 10,000 patches this overhead dominates all
other costs.

tilework solves this through two mechanisms:

1.  **`setup_FUN`** — runs once per worker before batch processing
    begins. Its output is passed into every `FUN` call via `.SETUP_OUT`.
2.  **Batched iteration** — `tileIterator` groups patches into batches,
    so the model processes many patches per forward pass rather than one
    at a time.

## The image and tile plan

We start with a `SpatRaster`. Tile size and padding are the only inputs
needed to define the full plan — the grid dimensions are derived
automatically.

``` r
f <- system.file("ex/elev.tif", package = "terra")
r <- rast(f)

tile_size <- 10L  # pixels per tile side
pad       <- 2L   # overlap on each side

tp <- pixelTilePlan(pxdims = dim(r)[1:2], nrows = tile_size, ncols = tile_size)
tp$pad <- pad

dim(tp)    # rows x cols of the tile grid
#> [1]  9 10
length(tp) # total number of tiles
#> [1] 90
```

## Why tile groups? Edge tiles differ in size

Interior tiles are always `tile_size × tile_size` pixels. But tiles on
the bottom row or right column may be smaller if the image dimensions
are not exact multiples of `tile_size`. Running all tiles through the
same model configuration would require the model to accept variable
input shapes.

The cleaner solution is to split the plan into four groups — interior,
bottom edge, right edge, and corner — and process each group separately
with a model sized for that group’s expected dimensions.

``` r
nr <- nrow(tp)
nc <- ncol(tp)

tg <- tileGroup(tp, groups = list(
    uniform = list(1:(nr - 1L), 1:(nc - 1L)),
    bottom  = list(nr,          1:(nc - 1L)),
    right   = list(1:(nr - 1L), nc),
    corner  = list(nr,          nc)
))

tg
#> <tileGroup>: pixelTilePlan
#> groups-------------------------
#>   uniform : 72 tiles
#>   bottom  : 9 tiles
#>   right   : 8 tiles
#>   corner  : 1 tiles
```

The `list(rows, cols)` syntax selects tiles by grid position (ij
indexing). For example, `list(1:(nr-1), 1:(nc-1))` selects all tiles
that are not in the last row or last column.

## Per-worker model initialization

`setup_FUN` runs once on each worker when parallelization is active, or
once total in sequential mode. The `.X` injectable gives access to the
input data so the worker can inspect it before processing begins.

Here we use a mock feature extractor in place of a real model. In
practice this would be something like `keras::application_resnet50()`.

``` r
# Stand-in for a real feature extractor.
# Accepts an array of shape (batch, height, width, channels)
# and returns a (n_features x batch) matrix.
mock_feature_extractor <- function(input_shape, n_features = 32L) {
    force(input_shape)
    force(n_features)
    list(
        input_shape = input_shape,
        predict = function(arr) {
            n_tiles <- dim(arr)[[1L]]
            matrix(runif(n_features * n_tiles), nrow = n_features, ncol = n_tiles)
        }
    )
}
```

## Running inference on one group

The full pipeline for one tile group is:

1.  Create a `tileIterator` over that group.
2.  Call
    [`tileApply()`](https://drieslab.github.io/tilework/reference/tileApply.md)
    with a `setup_FUN` that builds the model and a `FUN` that runs
    inference on each batch.

``` r
.predict_group <- function(x, tg, batch_size, group) {
    iter <- tileIterator(tg, batch_size = batch_size, active_group = group)

    tileApply(
        x,
        tiles = iter,
        setup_FUN = function(.X) {
            # Peek at the first tile to learn the expected input shape
            # without advancing the iterator position.
            first_tile <- getTile(.X, iter, advance = FALSE)[[1L]]
            input_shape <- c(dim(first_tile)[1:2], terra::nlyr(.X))
            mock_feature_extractor(input_shape)
        },
        FUN = function(batch, .I, .SETUP_OUT) {
            model <- .SETUP_OUT

            # Convert batch to (n, h, w, c) array
            arr <- do.call(
                abind::abind,
                c(lapply(batch, terra::as.array), along = 4L)
            )
            arr <- aperm(arr, c(4L, 1L, 2L, 3L))

            # Run inference
            p <- model$predict(arr)   # n_features x n_tiles
            colnames(p) <- .I         # label each column with its tile index
            p
        }
    )
}
```

The `.I` injectable carries the flat tile index for each tile in the
batch. Storing it as the column name makes reassembly straightforward
regardless of the order in which workers return results.

## Processing all groups and reassembling

``` r
batch_size <- 4L

uniform_res <- .predict_group(r, tg, batch_size, "uniform")
#> Warning: Your code is running sequentially. For better performance, consider using a
#>  parallel plan like:
#>   future::plan(future::multisession)
#>   To silence this warning, set options("tilework.warn_sequential" = FALSE)
bottom_res  <- .predict_group(r, tg, batch_size, "bottom")
#> Warning: Your code is running sequentially. For better performance, consider using a
#>  parallel plan like:
#>   future::plan(future::multisession)
#>   To silence this warning, set options("tilework.warn_sequential" = FALSE)
right_res   <- .predict_group(r, tg, batch_size, "right")
#> Warning: Your code is running sequentially. For better performance, consider using a
#>  parallel plan like:
#>   future::plan(future::multisession)
#>   To silence this warning, set options("tilework.warn_sequential" = FALSE)
corner_res  <- .predict_group(r, tg, batch_size, "corner")
#> Warning: tileIterator: `bound` is at default = c(1, 1). Set a different one
#> with `$bound <-`
#> Warning: tileIterator: `bound` is at default = c(1, 1). Set a different one
#> with `$bound <-`
#> Warning: Your code is running sequentially. For better performance, consider using a
#>  parallel plan like:
#>   future::plan(future::multisession)
#>   To silence this warning, set options("tilework.warn_sequential" = FALSE)

# Combine and sort columns by tile index
all_features <- do.call(cbind, c(uniform_res, bottom_res, right_res, corner_res))
all_features <- all_features[, order(as.integer(colnames(all_features))), drop = FALSE]

dim(all_features) # n_features x n_tiles
#> [1] 32 90
```

The result is a feature matrix with one column per tile, in spatial
order. `attr(, "tilePlan")` can be attached to carry the plan alongside
the features for later use (e.g. reassembling a feature map or plotting
embeddings spatially).

``` r
attr(all_features, "tilePlan") <- tp
```

## Parallelization

The pipeline above runs sequentially. To distribute across workers, set
a `future` plan before calling
[`tileApply()`](https://drieslab.github.io/tilework/reference/tileApply.md).
[`iterSplit()`](https://drieslab.github.io/tilework/reference/iterSplit.md)
handles partitioning the iterator across workers automatically — no
changes to the pipeline are needed.

``` r
future::plan(future::multisession, workers = 4L)

uniform_res <- .predict_group(r, tg, batch_size, "uniform")
# ...

future::plan(future::sequential)
```

With a mirai backend (faster for many workers):

``` r
future::plan(future.mirai::mirai_multisession, workers = 4L)
```

Each worker loads the model once via `setup_FUN`, then processes all of
its assigned batches with that model. The overhead of model
initialization is paid once per worker, not once per tile.

## Summary

| Component | Role |
|----|----|
| `tilePlan("pixel")` | Define the patch grid from image dimensions and tile size |
| `tileGroup` | Separate edge/corner tiles from interior tiles |
| `tileIterator(..., batch_size)` | Control how many patches are sent to the model per forward pass |
| `setup_FUN` | Initialize the model once per worker |
| `.SETUP_OUT` | Access the pre-initialized model inside `FUN` |
| `.I` | Tile index injectable for result reassembly |
