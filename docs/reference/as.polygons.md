# Coerce a tile plan to polygons

Convert a `tilePlan`-inheriting object to a `SpatVector` of rectangle
polygons, one per tile, with a `tile` attribute column holding the tile
index. Padding is included in the polygon bounds.

Accelerated vectorized methods are provided for `spatialTilePlan`,
`freeTilePlan`, and `pointTilePlan`. All other `tilePlan` subclasses
fall back to extracting bounds via `x[]`.

## Usage

``` r
# S4 method for class 'tilePlan'
as.polygons(x, ...)

# S4 method for class 'freeTilePlan'
as.polygons(x, ...)

# S4 method for class 'pointTilePlan'
as.polygons(x, ...)

# S4 method for class 'spatialTilePlan'
as.polygons(x, ...)
```

## Arguments

- x:

  `tilePlan`-inheriting object

- ...:

  additional arguments (ignored)

## Value

`SpatVector` of polygons

## See also

Other tile\* methods:
[`arith`](https://drieslab.github.io/tilework/reference/arith.md),
[`bracket`](https://drieslab.github.io/tilework/reference/bracket.md),
[`centroids()`](https://drieslab.github.io/tilework/reference/centroids.md),
[`dim()`](https://drieslab.github.io/tilework/reference/dim.md),
[`dollar`](https://drieslab.github.io/tilework/reference/dollar.md),
[`double_bracket`](https://drieslab.github.io/tilework/reference/double_bracket.md),
[`ext()`](https://drieslab.github.io/tilework/reference/ext.md),
[`intersect()`](https://drieslab.github.io/tilework/reference/intersect.md),
[`plot()`](https://drieslab.github.io/tilework/reference/plot.md)
