# Spatial Tile Plan

Utility class that simplifies the setup of tiles across a spatial
extent. Tiles are stored in a lightweight format safe to be passed to
child processes. Tile `SpatExtent` objects can be extracted on-demand.

## Usage

``` r
spatialTilePlan(ext = NULL, n = NULL, ...)
```

## Arguments

- ext:

  numeric or `SpatExtent`. Spatial extent to tile across. Equivalent to
  calling `ext(x) <- value` after construction.

- n:

  numeric. Desired number of tiles. Equivalent to calling
  `length(x) <- value` after construction.

- ...:

  additional params passed to
  [`new()`](https://rdrr.io/r/methods/new.html).

## Slots

- `extent`:

  numeric. Spatial extent to tile across.

- `n`:

  numeric. Number of tiles to create.

- `dims`:

  numeric. Number of rows/cols in the array of tiles

- `tile_dims`:

  numeric. Row/col dimensions of each tile

- `pad`:

  numeric. Tile padding

- `metadata`:

  data.frame. Metadata per tile

## setup and basic characteristics

A `spatialTilePlan` needs both a spatial extent to tile across and also
a request for a certain number of tiles.

- `spatialTilePlan(ext, n)` is used to create a `spatialTilePlan`
  instance. `ext` and `n` can also be supplied after construction via
  `ext()<-` and `length()<-`.

- [`ext()`](https://drieslab.github.io/tilework/reference/ext.md) is
  used to check extent.

- [`length()`](https://drieslab.github.io/tilework/reference/dim.md) can
  be used to find out how many tiles there are.

- [`dim()`](https://drieslab.github.io/tilework/reference/dim.md)/[`nrow()`](https://drieslab.github.io/tilework/reference/dim.md)/[`ncol()`](https://drieslab.github.io/tilework/reference/dim.md)
  basic generics are implemented and return information about how the
  tiles are arranged.

Note that the number of requested tiles may not be the actual length,
since a grid pattern must be followed. However, the number of generated
tiles will be AT LEAST the number that is requested. Generated tiles
will have as square a shape as possible.

## Getting tile extent

`[i]` and `[i, j]` indexing can be used to select tiles, similarly to a
matrix. `[]` without any indexing will return the entire set of extents
as a list. Extracted extents will have metadata attached via
[`attr()`](https://rdrr.io/r/base/attr.html). See metadata section
below.

## padding

`+`/`-` can be used to add or subtract padding to each of the tiles.
Note that this value does not affect the setting or retrieval of extent
info via [`ext()`](https://drieslab.github.io/tilework/reference/ext.md)
and `ext()<-`. Each bound will be expanded by the padding value. To
avoid having to use
[`terra::extend()`](https://rspatial.github.io/terra/reference/extend.html)
when padded tiles exceed raster extent, you can decrease the extent by
the same size as the padding.

## previewing tiles

[`plot()`](https://drieslab.github.io/tilework/reference/plot.md) can be
used to check the layout of the tiles.

## metadata

The `spatialTilePlan` object can contain metadata. By default after
extent and tiles setup, a column called `"tile"` will be set up that
simply records which tile it is.

- `$` can be used to view a specific type of metadata and the padding
  value

- `$<-` can be used to set additional metadata items and the padding
  value

- `[[i]]` selection will pull specific metadata rows corresponding to
  the selected tiles.

## See also

Other tile plans:
[`freeTilePlan`](https://drieslab.github.io/tilework/reference/freeTilePlan.md),
[`freeTilePlan-class`](https://drieslab.github.io/tilework/reference/freeTilePlan-class.md),
[`pixelTilePlan-class`](https://drieslab.github.io/tilework/reference/pixelTilePlan-class.md),
[`pointTilePlan-class`](https://drieslab.github.io/tilework/reference/pointTilePlan-class.md),
[`quadtreePlan()`](https://drieslab.github.io/tilework/reference/quadtreePlan.md),
[`tilePlan`](https://drieslab.github.io/tilework/reference/tilePlan.md),
[`tilePlan-class`](https://drieslab.github.io/tilework/reference/tilePlan-class.md),
[`tilework-class`](https://drieslab.github.io/tilework/reference/tilework-class.md)

## Examples

``` r
x <- spatialTilePlan(ext = c(0, 100, 0, 100), n = 8)
force(x)
#> Object of class spatialTilePlan 
#> extent : 0, 100, 0, 100 (xmin, xmax, ymin, ymax)
#> dim    : 3 3
#> pad    : 0

length(x) # how many were actually generated? AT LEAST n
#> [1] 9
dim(x)
#> [1] 3 3
nrow(x)
#> [1] 3
ncol(x)
#> [1] 3

# previewing
plot(x)


# tile padding
y <- x + 10
plot(ext(x), border = "red")
plot(y, alpha = 0.3, add = TRUE)

# this is now larger than the original space
ext(y) <- ext(y) - 10
plot(y, alpha = 0.3)
plot(ext(x), add = TRUE, border = "red")

# now this does not exceed the image

# negative padding
z <- x - 5
plot(ext(x), border = "red")
plot(z, add = TRUE)


# tile selection
x[5]
#> [[1]]
#> SpatExtent : 33.3333333333333, 66.6666666666667, 33.3333333333333, 66.6666666666667 (xmin, xmax, ymin, ymax)
#> 
x[1, 2:3]
#> [[1]]
#> SpatExtent : 33.3333333333333, 66.6666666666667, 0, 33.3333333333333 (xmin, xmax, ymin, ymax)
#> 
#> [[2]]
#> SpatExtent : 66.6666666666667, 100, 0, 33.3333333333333 (xmin, xmax, ymin, ymax)
#> 

# metadata
x$tile
#> [1] 1 2 3 4 5 6 7 8 9
x$fname <- sprintf("tile_%03d.tif", x$tile)
x[[5]]
#>   tile        fname
#> 5    5 tile_005.tif
x[[1:3]]$fname
#> [1] "tile_001.tif" "tile_002.tif" "tile_003.tif"

# selected tiles carry metadata as attributes
attr(x[4][[1]], "tile")
#> [1] 4
attr(x[4][[1]], "fname")
#> [1] "tile_004.tif"
```
