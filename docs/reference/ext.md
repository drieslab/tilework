# Get and Set Spatial Extent

Get and set a spatial extent.

## Usage

``` r
# S4 method for class 'pointTilePlan'
ext(x, ...)

# S4 method for class 'pointTilePlan,ANY'
ext(x) <- value

# S4 method for class 'spatialTilePlan'
ext(x, ...)

# S4 method for class 'spatialTilePlan,ANY'
ext(x) <- value
```

## Arguments

- x:

  `tilePlan`

- ...:

  addtional params to pass (none implemented)

- value:

  `numeric` of length 4 or `SpatExtent` defining spatial extent.

## Value

tilePlan if `ext<-()` and `SpatExtent` if `ext()`

## See also

Other tile\* methods:
[`arith`](https://drieslab.github.io/tilework/reference/arith.md),
[`as.polygons()`](https://drieslab.github.io/tilework/reference/as.polygons.md),
[`bracket`](https://drieslab.github.io/tilework/reference/bracket.md),
[`centroids()`](https://drieslab.github.io/tilework/reference/centroids.md),
[`dim()`](https://drieslab.github.io/tilework/reference/dim.md),
[`dollar`](https://drieslab.github.io/tilework/reference/dollar.md),
[`double_bracket`](https://drieslab.github.io/tilework/reference/double_bracket.md),
[`intersect()`](https://drieslab.github.io/tilework/reference/intersect.md),
[`plot()`](https://drieslab.github.io/tilework/reference/plot.md)
