# Free Tile Plan

Tile plan defined by explicit per-tile bounds with no required
uniformity in size or spacing. The bounds matrix is the canonical
representation — there is no center-plus-dims formula. Always returns
`SpatExtent` from `[i]`. Primary use case is as the output of adaptive
spatial decomposition algorithms such as quadtrees on vector/point data.

Tile plan defined by explicit per-tile bounds with no required
uniformity in size or spacing. Unlike grid-based plans, the bounds
matrix is the canonical representation — tile positions are not computed
from a formula.

The primary use case is adaptive spatial decomposition of vector/point
data, where high-density regions require small tiles and sparse regions
can use large tiles. See
[`quadtreePlan()`](https://drieslab.github.io/tilework/reference/quadtreePlan.md)
for the iterative construction workflow.

## Slots

- `bounds`:

  matrix. n x 4 matrix: xmin, xmax, ymin, ymax (one row per tile).

## Note

`@tile_dims` is intentionally not populated. Any method that requires
uniform tile dimensions will not work with `freeTilePlan`.

## Setup

- [`freeTilePlan()`](https://drieslab.github.io/tilework/reference/freeTilePlan.md)
  creates an empty instance.

- `$bounds<-` sets the n x 4 bounds matrix (`xmin, xmax, ymin, ymax`).
  Setting bounds triggers reinitialization of `@n`, `@dims`, and
  `@metadata`.

- `$pad` / `+` / `-` add spatial padding as with other plans.

## Notes

- `@tile_dims` is intentionally not populated. Operations that require
  uniform tile dimensions (e.g. `extend = TRUE` in
  [`getTile()`](https://drieslab.github.io/tilework/reference/getTile.md))
  are not supported.

- [`nrow()`](https://drieslab.github.io/tilework/reference/dim.md)
  returns `n`,
  [`ncol()`](https://drieslab.github.io/tilework/reference/dim.md)
  returns `1`,
  [`length()`](https://drieslab.github.io/tilework/reference/dim.md)
  returns `n`.

- [`plot()`](https://drieslab.github.io/tilework/reference/plot.md)
  works via the existing spatial extent preview.

## See also

Other tile plans:
[`freeTilePlan`](https://drieslab.github.io/tilework/reference/freeTilePlan.md),
[`pixelTilePlan-class`](https://drieslab.github.io/tilework/reference/pixelTilePlan-class.md),
[`pointTilePlan-class`](https://drieslab.github.io/tilework/reference/pointTilePlan-class.md),
[`quadtreePlan()`](https://drieslab.github.io/tilework/reference/quadtreePlan.md),
[`spatialTilePlan-class`](https://drieslab.github.io/tilework/reference/spatialTilePlan-class.md),
[`tilePlan`](https://drieslab.github.io/tilework/reference/tilePlan.md),
[`tilePlan-class`](https://drieslab.github.io/tilework/reference/tilePlan-class.md),
[`tilework-class`](https://drieslab.github.io/tilework/reference/tilework-class.md)

Other tile plans:
[`freeTilePlan`](https://drieslab.github.io/tilework/reference/freeTilePlan.md),
[`pixelTilePlan-class`](https://drieslab.github.io/tilework/reference/pixelTilePlan-class.md),
[`pointTilePlan-class`](https://drieslab.github.io/tilework/reference/pointTilePlan-class.md),
[`quadtreePlan()`](https://drieslab.github.io/tilework/reference/quadtreePlan.md),
[`spatialTilePlan-class`](https://drieslab.github.io/tilework/reference/spatialTilePlan-class.md),
[`tilePlan`](https://drieslab.github.io/tilework/reference/tilePlan.md),
[`tilePlan-class`](https://drieslab.github.io/tilework/reference/tilePlan-class.md),
[`tilework-class`](https://drieslab.github.io/tilework/reference/tilework-class.md)

## Examples

``` r
tp <- freeTilePlan()
tp$bounds <- rbind(
    c(0,  50,  0,  50),
    c(50, 100, 0,  50),
    c(0,  50,  50, 100),
    c(50, 100, 50, 100)
)
length(tp)
#> [1] 4
tp[2]
#> [[1]]
#> SpatExtent : 50, 100, 0, 50 (xmin, xmax, ymin, ymax)
#> 
plot(tp)
```
