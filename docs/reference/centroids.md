# Get Tile Centroids

Get the centroids of the tiles. For spatialTilePlan, these will be
returned as `SpatVector` centroids. For non-spatial plans like
pixelTileGrid, this will be returne as a `matrix`.

## Usage

``` r
# S4 method for class 'tilePlan'
centroids(x, fun = function(x) x, offset = c(0, 0), zero = FALSE, ...)

# S4 method for class 'freeTilePlan'
centroids(x, ...)

# S4 method for class 'pointTilePlan'
centroids(x, ...)

# S4 method for class 'pixelTilePlan'
centroids(x, fun = function(x) x, zero = TRUE, ...)

# S4 method for class 'spatialTilePlan'
centroids(x, zero = FALSE, ...)
```

## Arguments

- x:

  `tilePlan`

- fun:

  (internal) post-processing function used to convert centroids to
  expected output. Such as
  [`vect()`](https://rspatial.github.io/terra/reference/vect.html) for
  `spatialTilePlan`

- offset:

  numeric of length 2. x and y values to offset by. Default is c(0, 0).

- zero:

  logical. Whether to zero out padding effects. (used by default with
  `pixelTilePlan`)

- ...:

  additional params to pass.

## See also

Other tile\* methods:
[`arith`](https://drieslab.github.io/tilework/reference/arith.md),
[`as.polygons()`](https://drieslab.github.io/tilework/reference/as.polygons.md),
[`bracket`](https://drieslab.github.io/tilework/reference/bracket.md),
[`dim()`](https://drieslab.github.io/tilework/reference/dim.md),
[`dollar`](https://drieslab.github.io/tilework/reference/dollar.md),
[`double_bracket`](https://drieslab.github.io/tilework/reference/double_bracket.md),
[`ext()`](https://drieslab.github.io/tilework/reference/ext.md),
[`intersect()`](https://drieslab.github.io/tilework/reference/intersect.md),
[`plot()`](https://drieslab.github.io/tilework/reference/plot.md)

## Examples

``` r
x <- tilePlan()
ext(x) <- c(0, 100, 0, 100)
length(x) <- 9
centroids(x)
#>  class       : SpatVector 
#>  geometry    : points 
#>  dimensions  : 9, 0  (geometries, attributes)
#>  extent      : 16.66667, 83.33333, 16.66667, 83.33333  (xmin, xmax, ymin, ymax)
#>  coord. ref. :  
```
