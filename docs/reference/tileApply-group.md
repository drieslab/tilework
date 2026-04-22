# Hierarchical Tile Group Processing

Apply functions across tileGroup objects with control over
parallelization strategy. Useful when tiles are organized into logical
groups that need different processing or aggregation.

**`token`** is a stand-in for any input data class (e.g. `SpatRaster`,
`SpatExtent`, filpath, etc). See
[redispatch_tileapply](https://drieslab.github.io/tilework/reference/redispatch_tileapply.md)
and
[extending_tilework](https://drieslab.github.io/tilework/reference/extending_tilework.md)
for further information.

## Usage

``` r
# S4 method for class 'token,missing,tileGroup'
tileApply(
  x,
  tiles,
  FUN,
  get_params_x = list(),
  parallel_strategy = c("groups", "tiles"),
  setup_FUN = NULL,
  group_FUN = NULL,
  callback_x = NULL,
  log = FALSE,
  logpath = getTileworkLogDir(),
  simplify = FALSE,
  parallel_params = list(),
  verbose = NULL,
  ...
)

# S4 method for class 'token,token,tileGroup'
tileApply(
  x,
  y,
  tiles,
  FUN,
  get_params_x = list(),
  get_params_y = list(),
  pad_y = NULL,
  parallel_strategy = c("groups", "tiles"),
  setup_FUN = NULL,
  group_FUN = NULL,
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

  `tileGroup` object

- FUN:

  function to apply to each tile

- get_params_x:

  named list. Additional params to pass to
  [`getTile()`](https://drieslab.github.io/tilework/reference/getTile.md)
  for `x`

- parallel_strategy:

  character. `"groups"` to parallelize across groups, or `"tiles"` to
  parallelize within groups

- setup_FUN:

  function. Optional per-group initialization function when
  `parallel_strategy = "groups"`. Output is accessible within `FUN` as
  `.SETUP_OUT`

- group_FUN:

  function. Optional function to apply to each group's results

- callback_x:

  function. Optional preprocessing function for `x` per worker when
  `parallel_strategy = "groups"`

- log:

  logical. Whether to log processing steps

- logpath:

  character. Log file path (if log = `TRUE`)

- simplify:

  logical. Whether to flatten group results into single list. Group
  names will not be retained.

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

  function. Optional preprocessing function for `y` per worker when
  `parallel_strategy = "groups"`

## Parallelization Strategies

- `"groups"` - Process groups in parallel, tiles within groups
  sequentially

- `"tiles"` - Process groups sequentially, tiles within groups in
  parallel

## Special Function Parameters

Your `FUN` can optionally include these special parameters:

- `.I` - tile number (integer)

- `.TILE` - tile bounds/metadata

- `.R` - tile row number

- `.C` - tile column number

- `.GROUP` - current group name (character)

- `.SETUP_OUT` - the output of `setup_FUN`

Your `setup_FUN` can optionally include these special parameters:

- `.GROUP` - current group name (character)

- `.X` - the input `x` object

- `.Y` - the input `y` object (when provided)

## See also

[tileApply](https://drieslab.github.io/tilework/reference/tileApply.md),
[`tileGroup()`](https://drieslab.github.io/tilework/reference/tileGroup.md),
[tileGroup](https://drieslab.github.io/tilework/reference/tileGroup-class.md)

Other tile processing:
[`getBoundedData()`](https://drieslab.github.io/tilework/reference/getBoundedData.md),
[`getTile()`](https://drieslab.github.io/tilework/reference/getTile.md),
[`tileApply()`](https://drieslab.github.io/tilework/reference/tileApply.md),
[`tileApply-iterator`](https://drieslab.github.io/tilework/reference/tileApply-iterator.md),
[`tileApply-plan`](https://drieslab.github.io/tilework/reference/tileApply-plan.md)

## Examples

``` r
f <- system.file("ex/elev.tif", package = "terra")
r <- terra::rast(f)

# Create tile plan
tp <- tilePlan("spatial")
ext(tp) <- ext(r)
length(tp) <- 16

# Organize into groups (e.g., by geographic region)
tg <- tileGroup(tp, groups = list(
    "north" = 1:8, # northern tiles
    "south" = 9:16, # southern tiles
    "corners" = c(1, 4, 13, 16) # corner tiles
))

# Process groups in parallel, with group-level aggregation
results <- tileApply(r,
    tiles = tg,
    parallel_strategy = "groups",
    FUN = function(tile, .I, .GROUP) {
        # Process individual tile
        list(
            tile_id = .I,
            group = .GROUP,
            stats = terra::global(tile, c("mean", "sd"), na.rm = TRUE)
        )
    },
    group_FUN = function(group_results, .GROUP) {
        # Aggregate results within each group
        means <- sapply(group_results, function(x) x$stats$mean)
        list(
            group = .GROUP,
            n_tiles = length(group_results),
            group_mean = mean(means),
            group_range = range(means)
        )
    }
)
#> Warning: Your code is running sequentially. For better performance, consider using a
#>  parallel plan like:
#>   options("tilework.bpparam" = BiocParallel::SnowParam())
#>   To silence this warning, set options("tilework.warn_sequential" = FALSE)

# Results organized by group
str(results)
#> List of 3
#>  $ north  :List of 4
#>   ..$ group      : chr "north"
#>   ..$ n_tiles    : int 8
#>   ..$ group_mean : num 301
#>   ..$ group_range: num [1:2] 216 338
#>  $ south  :List of 4
#>   ..$ group      : chr "south"
#>   ..$ n_tiles    : int 8
#>   ..$ group_mean : num NaN
#>   ..$ group_range: num [1:2] NaN NaN
#>  $ corners:List of 4
#>   ..$ group      : chr "corners"
#>   ..$ n_tiles    : int 4
#>   ..$ group_mean : num NaN
#>   ..$ group_range: num [1:2] NaN NaN
```
