# Get Data Within Bounds

Subset or otherwise make available only the data that is within the
provided bounds. Accepted bounds types depends on the data.

A related lower-level function is
[`getTile()`](https://drieslab.github.io/tilework/reference/getTile.md)
which handles data/`tile*` interactions and bound info collection.
[`getTile()`](https://drieslab.github.io/tilework/reference/getTile.md)
calls this generic for its data selection capabilities.

## Usage

``` r
# S4 method for class 'SpatRaster,numeric'
getBoundedData(x, bound, extend = FALSE, fill = NA)

# S4 method for class 'SpatRaster,SpatExtent'
getBoundedData(x, bound, extend = FALSE, fill = NA)

# S4 method for class 'SpatVectorProxy,SpatExtent'
getBoundedData(x, bound)
```

## Arguments

- x:

  data

- bound:

  bounds to filter with

- extend:

  logical (default = `FALSE`) whether to extend tile data to reach
  expected tile dimensions

- fill:

  numeric. if `extend = TRUE`, what value to fill with

## Bounds types

Depending on the method, different bound types are used. Current
expected patterns are:

- `numeric` of length 4 (xmin, xmax, ymin, ymax)

- `SpatExtent`

## `SpatRaster` snapping

`getBoundedData()` is implemented for `SpatRaster`, `SpatExtent` using
[`terra::window()`](https://rspatial.github.io/terra/reference/window.html).
This uses terra's default snapping behavior (equivalent to
`snap = "near"` in
[`terra::crop()`](https://rspatial.github.io/terra/reference/crop.html)),
with no way to set another strategy.

**For more precise boundary control:**

- Use pixel-based indexing via the `SpatRaster`, `numeric` method

- Use
  [`pixelTilePlan()`](https://drieslab.github.io/tilework/reference/pixelTilePlan-class.md)
  for exact pixel-level tiling

- Add padding with `tiles + pad_value` to ensure spatial context

- Use
  [`terra::crop()`](https://rspatial.github.io/terra/reference/crop.html)
  directly if you need `snap = "out"` or `snap = "in"`

## Boundary Inclusivity

Adjacent tiles share exact boundaries. Since {tilework} does not know
the format or representation of the underlying data, it does not enforce
whether those boundaries are inclusive or exclusive. It is up to the
`getBoundedData()` implementation to decide how features on shared edges
are handled.

The existing {terra} methods do not implement inclusive/exclusive
boundary control because raster pixel snapping and padding make exact
boundary behavior largely irrelevant for that format. For point or
tabular data, features on a shared boundary may appear in multiple tiles
unless the implementation applies its own filtering (e.g. `>=` vs `>`
comparisons). The tile's grid position can be passed via `get_params`
from
[`getTile()`](https://drieslab.github.io/tilework/reference/getTile.md)
to inform which edges are interior.

## See also

[`getTile()`](https://drieslab.github.io/tilework/reference/getTile.md)

Other tile processing:
[`getTile()`](https://drieslab.github.io/tilework/reference/getTile.md),
[`tileApply()`](https://drieslab.github.io/tilework/reference/tileApply.md),
[`tileApply-group`](https://drieslab.github.io/tilework/reference/tileApply-group.md),
[`tileApply-iterator`](https://drieslab.github.io/tilework/reference/tileApply-iterator.md),
[`tileApply-plan`](https://drieslab.github.io/tilework/reference/tileApply-plan.md)

## Examples

``` r
f <- system.file("ex/elev.tif", package = "terra")
r <- terra::rast(f)

pixel_selection <- getBoundedData(r, c(10, 50, 30, 40))
plot(pixel_selection)


extent_selection <- getBoundedData(r, ext(6, 6.5, 49.7, 50))
plot(extent_selection)

```
