# Streaming Tile Processing with Iterators

Apply functions using tileIterator objects for memory-constrained batch
processing. Ideal for very large datasets or when you need fine control
over processing workflow.

**`token`** is a stand-in for any input data class (e.g. `SpatRaster`,
`SpatExtent`, filpath, etc). See
[redispatch_tileapply](https://drieslab.github.io/tilework/reference/redispatch_tileapply.md)
and
[extending_tilework](https://drieslab.github.io/tilework/reference/extending_tilework.md)
for further information.

## Usage

``` r
# S4 method for class 'token,missing,tileIterator'
tileApply(
  x,
  tiles,
  FUN,
  get_params_x = list(),
  setup_FUN = NULL,
  callback_x = NULL,
  log = FALSE,
  logpath = getTileworkLogDir(),
  simplify = FALSE,
  parallel_params = list(),
  verbose = NULL,
  ...
)

# S4 method for class 'token,token,tileIterator'
tileApply(
  x,
  y,
  tiles,
  FUN,
  get_params_x = list(),
  get_params_y = list(),
  pad_y = NULL,
  setup_FUN = NULL,
  callback_x = NULL,
  callback_y = NULL,
  log = FALSE,
  logpath = getTileworkLogDir(),
  simplify = FALSE,
  parallel_params = list(),
  verbose = NULL,
  ...
)
```

## Arguments

- x:

  input data 1

- tiles:

  `tileIterator` object

- FUN:

  function to apply to each batch of tiles

- get_params_x:

  named list. Additional params to pass to
  [`getTile()`](https://drieslab.github.io/tilework/reference/getTile.md)
  for `x`

- setup_FUN:

  function. Optional per-worker initialization function. Output is
  accessible within `FUN` as `.SETUP_OUT`

- callback_x:

  function, (advanced). If provided, programmatic escape hatch for
  preprocessing `x` per worker before `setup_FUN` and batch streamed
  processing of `FUN` begins.

- log:

  logical. Whether to log processing steps

- logpath:

  character. Log file path (if log = `TRUE`)

- simplify:

  logical. Whether to flatten results

- parallel_params:

  named param list. See
  [parallel_params](https://drieslab.github.io/tilework/reference/parallel_params.md)

- verbose:

  verbosity. `TRUE`, `FALSE` or `"debug"` for more info on stack
  tracing.

- ...:

  additional params to pass to
  [`[`](https://drieslab.github.io/tilework/reference/bracket.md)

- y:

  input data 2 (optional)

- get_params_y:

  named list. Additional params to pass to
  [`getTile()`](https://drieslab.github.io/tilework/reference/getTile.md)
  for `y`

- pad_y:

  numeric. Additional padding applied to `y` tiling so `x` has full
  spatial context of `y`

- callback_y:

  function, (advanced). If provided, programmatic escape hatch for
  preprocessing `y` per worker before `setup_FUN` and batch streamed
  processing of `FUN` begins.

## Worker Distribution

[`iterSplit()`](https://drieslab.github.io/tilework/reference/iterSplit.md)
is run with `n =`
[`future::nbrOfWorkers()`](https://future.futureverse.org/reference/nbrOfWorkers.html)
to distribute the tiles to process across the expected number of
workers, with each worker processing its assigned tiles in batches.

## Special Function Parameters

Your `FUN` can optionally include these special parameters:

- `.I` - tile number (integer)

- `.TILE` - tile bounds/metadata

- `.R` - tile row number

- `.C` - tile column number

- `.POSITION` - batch position range (start, end)

- `.BATCH` - batch number within worker

- `.SETUP_OUT` - the output of `setup_FUN`

Your `setup_FUN` can optionally include these special parameters:

- `.W` - worker number

- `.X` - the input `x` object.

- `.Y` - the input `y` object (when provided)

## See also

[tileApply](https://drieslab.github.io/tilework/reference/tileApply.md),
[`tileIterator()`](https://drieslab.github.io/tilework/reference/tileIterator.md),
[tileIterator](https://drieslab.github.io/tilework/reference/tileIterator-class.md)

Other tile processing:
[`getBoundedData()`](https://drieslab.github.io/tilework/reference/getBoundedData.md),
[`getTile()`](https://drieslab.github.io/tilework/reference/getTile.md),
[`tileApply()`](https://drieslab.github.io/tilework/reference/tileApply.md),
[`tileApply-group`](https://drieslab.github.io/tilework/reference/tileApply-group.md),
[`tileApply-plan`](https://drieslab.github.io/tilework/reference/tileApply-plan.md)

## Examples

``` r
f <- system.file("ex/elev.tif", package = "terra")
r <- terra::rast(f)

# Create pixel tile plan
tp <- tilePlan("pixel")
tp$pxdims <- dim(r)[1:2]
tp$nrows <- 30
tp$ncols <- 30

# Create iterator for batch processing
iter <- tileIterator(tp, batch_size = 5)

# Process with worker initialization
results <- tileApply(r,
    tiles = iter,
    setup_FUN = function(.W, .X) {
        # Initialize per-worker state
        list(
            worker_id = .W,
            start_time = Sys.time(),
            raster_info = list(nrow = nrow(.X), ncol = ncol(.X))
        )
    },
    FUN = function(batch, .BATCH, .POSITION, .SETUP_OUT) {
        # Process batch of tiles
        batch_stats <- lapply(batch, function(tile) {
            terra::global(tile, "mean", na.rm = TRUE)[[1]]
        })

        list(
            worker = .SETUP_OUT$worker_id,
            batch_num = .BATCH,
            tiles_processed = .POSITION,
            batch_mean = mean(unlist(batch_stats))
        )
    }
)
#> Warning: Your code is running sequentially. For better performance, consider using a
#>  parallel plan like:
#>   options("tilework.bpparam" = BiocParallel::SnowParam())
#>   To silence this warning, set options("tilework.warn_sequential" = FALSE)

# Check results structure
str(results)
#> List of 3
#>  $ :List of 4
#>   ..$ worker         : int 1
#>   ..$ batch_num      : int 1
#>   ..$ tiles_processed: int [1:2] 1 5
#>   ..$ batch_mean     : num NaN
#>  $ :List of 4
#>   ..$ worker         : int 1
#>   ..$ batch_num      : int 2
#>   ..$ tiles_processed: int [1:2] 6 10
#>   ..$ batch_mean     : num 301
#>  $ :List of 4
#>   ..$ worker         : int 1
#>   ..$ batch_num      : int 3
#>   ..$ tiles_processed: int [1:2] 11 12
#>   ..$ batch_mean     : num NaN

# Example: Streaming processing for memory management
large_iter <- tileIterator(tp, batch_size = 3)
processed_count <- 0

while (large_iter$has_next) {
    batch <- getTile(r, large_iter)

    # Process batch
    batch_results <- lapply(batch, function(tile) {
        # Your processing here
        terra::global(tile, "mean")
    })

    processed_count <- processed_count + length(batch)
    cat("Processed", processed_count, "of", length(tp), "tiles\n")
}
#> Processed 3 of 12 tiles
#> Processed 6 of 12 tiles
#> Processed 9 of 12 tiles
#> Processed 12 of 12 tiles
```
