# Basic Tile Processing

Apply functions across `tilePlan`-inheriting objects.

**`token`** is a stand-in for any input data class (e.g. `SpatRaster`,
`SpatExtent`, filpath, etc). See
[redispatch_tileapply](https://drieslab.github.io/tilework/reference/redispatch_tileapply.md)
and
[extending_tilework](https://drieslab.github.io/tilework/reference/extending_tilework.md)
for further information.

## Usage

``` r
# S4 method for class 'token,missing,tilePlan'
tileApply(
  x,
  tiles,
  FUN,
  get_params_x = list(),
  log = FALSE,
  logpath = getTileworkLogDir(),
  parallel_params = list(),
  verbose = NULL,
  ...
)

# S4 method for class 'token,token,tilePlan'
tileApply(
  x,
  y,
  tiles,
  FUN,
  get_params_x = list(),
  get_params_y = list(),
  pad_y = NULL,
  log = FALSE,
  logpath = getTileworkLogDir(),
  parallel_params = list(),
  verbose = NULL,
  ...
)

# S4 method for class 'token,missing,tileSelection'
tileApply(
  x,
  tiles,
  FUN,
  get_params_x = list(),
  log = FALSE,
  logpath = getTileworkLogDir(),
  parallel_params = list(),
  verbose = NULL,
  ...
)

# S4 method for class 'token,token,tileSelection'
tileApply(
  x,
  y,
  tiles,
  FUN,
  get_params_x = list(),
  get_params_y = list(),
  pad_y = NULL,
  log = FALSE,
  logpath = getTileworkLogDir(),
  parallel_params = list(),
  verbose = NULL,
  ...
)
```

## Arguments

- x:

  input data 1

- tiles:

  `tilePlan` inheriting object (`spatialTilePlan` or `pixelTilePlan`)

- FUN:

  function to apply to each tile

- get_params_x:

  named list. Additional params to pass to
  [`getTile()`](https://drieslab.github.io/tilework/reference/getTile.md)
  for `x`

- log:

  logical. Whether to log processing steps

- logpath:

  character. Log file path (if log = `TRUE`)

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

## Special Function Parameters

Your `FUN` can optionally include these special parameters:

- `.I` - tile number (integer)

- `.TILE` - tile bounds/metadata

- `.R` - tile row number

- `.C` - tile column number

## See also

[tileApply](https://drieslab.github.io/tilework/reference/tileApply.md),
[`tilePlan()`](https://drieslab.github.io/tilework/reference/tilePlan.md),
[spatialTilePlan](https://drieslab.github.io/tilework/reference/spatialTilePlan-class.md),
[pixelTilePlan](https://drieslab.github.io/tilework/reference/pixelTilePlan-class.md)

Other tile processing:
[`getBoundedData()`](https://drieslab.github.io/tilework/reference/getBoundedData.md),
[`getTile()`](https://drieslab.github.io/tilework/reference/getTile.md),
[`tileApply()`](https://drieslab.github.io/tilework/reference/tileApply.md),
[`tileApply-group`](https://drieslab.github.io/tilework/reference/tileApply-group.md),
[`tileApply-iterator`](https://drieslab.github.io/tilework/reference/tileApply-iterator.md)

## Examples

``` r
f <- system.file("ex/elev.tif", package = "terra")
r <- terra::rast(f)

# Spatial tiling example
tp_spatial <- tilePlan("spatial")
ext(tp_spatial) <- ext(r)
length(tp_spatial) <- 4

# Apply function with tile metadata
results <- tileApply(r, tiles = tp_spatial, FUN = function(tile, .I, .R, .C) {
    list(
        tile_id = .I,
        position = paste0("row_", .R, "_col_", .C),
        mean_value = terra::global(tile, "mean", na.rm = TRUE)[[1]]
    )
})
#> Warning: Your code is running sequentially. For better performance, consider using a
#>  parallel plan like:
#>   options("tilework.bpparam" = BiocParallel::SnowParam())
#>   To silence this warning, set options("tilework.warn_sequential" = FALSE)
force(results)
#> [[1]]
#> [[1]]$tile_id
#> [1] 1
#> 
#> [[1]]$position
#> [1] "row_1_col_1"
#> 
#> [[1]]$mean_value
#> [1] 317.038
#> 
#> 
#> [[2]]
#> [[2]]$tile_id
#> [1] 2
#> 
#> [[2]]$position
#> [1] "row_1_col_2"
#> 
#> [[2]]$mean_value
#> [1] 297.1293
#> 
#> 
#> [[3]]
#> [[3]]$tile_id
#> [1] 3
#> 
#> [[3]]$position
#> [1] "row_2_col_1"
#> 
#> [[3]]$mean_value
#> [1] 431.2923
#> 
#> 
#> [[4]]
#> [[4]]$tile_id
#> [1] 4
#> 
#> [[4]]$position
#> [1] "row_2_col_2"
#> 
#> [[4]]$mean_value
#> [1] 319.1541
#> 
#> 

# Pixel tiling example
tp_pixel <- tilePlan("pixel")
tp_pixel$pxdims <- dim(r)[1:2]
tp_pixel$nrows <- 50
tp_pixel$ncols <- 50

# Save tiles to disk
outdir <- file.path(tempdir(), "tiles")
dir.create(outdir, showWarnings = FALSE)

tileApply(r, tiles = tp_pixel, FUN = function(tile, .I) {
    filename <- file.path(outdir, sprintf("tile_%03d.tif", .I))
    terra::writeRaster(tile, filename, overwrite = TRUE)
    return(filename)
})
#> Warning: Your code is running sequentially. For better performance, consider using a
#>  parallel plan like:
#>   options("tilework.bpparam" = BiocParallel::SnowParam())
#>   To silence this warning, set options("tilework.warn_sequential" = FALSE)
#> [[1]]
#> [1] "/var/folders/1q/p0kr6d017wv4d6_39pcpt18w0000gn/T//RtmpBdqglv/tiles/tile_001.tif"
#> 
#> [[2]]
#> [1] "/var/folders/1q/p0kr6d017wv4d6_39pcpt18w0000gn/T//RtmpBdqglv/tiles/tile_002.tif"
#> 
#> [[3]]
#> [1] "/var/folders/1q/p0kr6d017wv4d6_39pcpt18w0000gn/T//RtmpBdqglv/tiles/tile_003.tif"
#> 
#> [[4]]
#> [1] "/var/folders/1q/p0kr6d017wv4d6_39pcpt18w0000gn/T//RtmpBdqglv/tiles/tile_004.tif"
#> 

list.files(outdir)
#> [1] "tile_001.tif" "tile_002.tif" "tile_003.tif" "tile_004.tif"
unlink(outdir, recursive = TRUE)
```
