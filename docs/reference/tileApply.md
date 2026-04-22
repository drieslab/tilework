# Apply Functions Across Spatial Tiles

**For more useful params info and examples, see the Tile Processing
Methods section.**

Apply a function across spatial tiles to speed up processing and manage
memory usage for large data operations. This is a landing page for the
generic. `tileApply()` dispatches to different processing methods based
on the tile type.

`character` inputs to `x` and `y` are assumed to be {terra} readable.
`SpatRaster` and `SpatVector` must first be written to file. If
provided, they are traced to their filepaths with
[`terra::sources()`](https://rspatial.github.io/terra/reference/sources.html)
and then processed via their filepaths for memory efficiency.

For other data types, see
[extending_tilework](https://drieslab.github.io/tilework/reference/extending_tilework.md)

## Usage

``` r
# S4 method for class 'ANY,missing,ANY'
tileApply(x, tiles, verbose = NULL, ...)

# S4 method for class 'ANY,ANY,ANY'
tileApply(x, y, tiles, verbose = NULL, ...)

# S4 method for class 'token,ANY,ANY'
tileApply(x, y, tiles, verbose = NULL, ...)
```

## Arguments

- x:

  input data 1

- tiles:

  tile\* object (`tilePlan`, `tileGroup`, or `tileIterator`)

- verbose:

  verbosity. `TRUE`, `FALSE` or `"debug"` for more info on stack
  tracing.

- ...:

  additional arguments passed to specific methods (one of which is the
  `FUN` function applied across the tiles.)

- y:

  input data 2 (optional)

## Tile Processing Methods

- **Basic tiling**: See
  [tileApply-plan](https://drieslab.github.io/tilework/reference/tileApply-plan.md)
  for `spatialTilePlan` and `pixelTilePlan`

- **Group processing**: See
  [tileApply-group](https://drieslab.github.io/tilework/reference/tileApply-group.md)
  for `tileGroup` hierarchical processing

- **Iterator processing**: See
  [tileApply-iterator](https://drieslab.github.io/tilework/reference/tileApply-iterator.md)
  for `tileIterator` streaming/batch processing

## Boundary Inclusivity

Adjacent tiles share exact boundaries. Since {tilework} does not know
the format or representation of the underlying data, it provides tile
bounds as windows but does not enforce whether those boundaries are
inclusive or exclusive — that is determined by the
[`getBoundedData()`](https://drieslab.github.io/tilework/reference/getBoundedData.md)
method for the data type being processed.

For raster data this is generally not an issue (pixel snapping assigns
each cell unambiguously). For point or tabular data, features sitting
exactly on a shared tile boundary may appear in multiple tiles unless
the
[`getBoundedData()`](https://drieslab.github.io/tilework/reference/getBoundedData.md)
implementation applies its own inclusive/exclusive filtering.
Implementing packages can use the tile grid position (available via
[`getTile()`](https://drieslab.github.io/tilework/reference/getTile.md)'s
`get_params`) to determine which edges are shared and filter
accordingly.

## See also

[tileApply-plan](https://drieslab.github.io/tilework/reference/tileApply-plan.md),
[tileApply-group](https://drieslab.github.io/tilework/reference/tileApply-group.md),
[tileApply-iterator](https://drieslab.github.io/tilework/reference/tileApply-iterator.md)

Other tile processing:
[`getBoundedData()`](https://drieslab.github.io/tilework/reference/getBoundedData.md),
[`getTile()`](https://drieslab.github.io/tilework/reference/getTile.md),
[`tileApply-group`](https://drieslab.github.io/tilework/reference/tileApply-group.md),
[`tileApply-iterator`](https://drieslab.github.io/tilework/reference/tileApply-iterator.md),
[`tileApply-plan`](https://drieslab.github.io/tilework/reference/tileApply-plan.md)

## Examples

``` r
# See specific help pages for detailed examples:
# ?`tileApply-plan`     # Basic spatial/pixel tiling
# ?`tileApply-group`    # Hierarchical tile groups
# ?`tileApply-iterator` # Streaming batch processing
```
