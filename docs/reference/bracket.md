# Extract Bounds from Tile Object

Get a set of tile bounds from a `tile*` object. Values are always
returned as a `list`, even when length one to reduce surprises with
[`lapply()`](https://rdrr.io/r/base/lapply.html) usage.

## Usage

``` r
# S4 method for class 'tilePlan,numeric,missing,missing'
x[i, j, ..., drop = TRUE]

# S4 method for class 'tilePlan,missing,numeric,missing'
x[i, j, ..., drop = TRUE]

# S4 method for class 'tilePlan,numeric,numeric,missing'
`[`(
  x,
  i,
  j,
  tile_fun = .spat_tile_bounds,
  fun = function(x) x,
  zero = FALSE,
  expand_grid = TRUE,
  drop
)

## S4 method for signature 'tilePlan,missing,missing,missing'
x[]

# S4 method for class 'tilePlan,numeric,missing,logical'
x[i, j, ..., drop = TRUE]

# S4 method for class 'tilePlan,missing,numeric,logical'
x[i, j, ..., drop = TRUE]

# S4 method for class 'tilePlan,numeric,numeric,logical'
x[i, j, expand_grid = TRUE, ..., drop]

# S4 method for class 'tilePlan,missing,missing,logical'
x[i, j, drop]

# S4 method for class 'freeTilePlan,numeric,numeric,missing'
x[i, j, ..., drop = TRUE]

# S4 method for class 'pointTilePlan,numeric,missing,missing'
x[i, j, ..., drop = TRUE]

# S4 method for class 'pixelTilePlan,numeric,numeric,missing'
x[i, j, ..., drop = TRUE]

# S4 method for class 'spatialTilePlan,numeric,numeric,missing'
x[i, j, ..., drop = TRUE]

# S4 method for class 'tileGroup,missing,missing,missing'
x[i, j, ..., drop = TRUE]

# S4 method for class 'tileGroup,.index,missing,missing'
x[i, j, ..., drop = TRUE]

# S4 method for class 'tileGroup,missing,.index,missing'
x[i, j, ..., drop = TRUE]

# S4 method for class 'tileGroup,numeric,.index,missing'
x[i, j, ..., drop = TRUE]

# S4 method for class 'tileIterator,missing,missing,missing'
x[i, j, ..., drop = TRUE]

# S4 method for class 'tileIterator,missing,missing'
x[i, j, ...] <- value

# S4 method for class 'tileSelection,numeric,missing,missing'
x[i, j, ..., drop = TRUE]

# S4 method for class 'tileSelection,numeric,missing,logical'
x[i, j, ..., drop = TRUE]
```

## Arguments

- x:

  `tile*` object

- i:

  numeric vector index if `j` is not given. Row index if `j` is also
  present. Works like `matrix-like` indexing.

- j:

  numeric. Column index

- ...:

  addtional params to pass (not used).

- drop:

  not used.

- tile_fun:

  (internal) function used to define tile bounds based on the iterator
  object and ij indices.

- fun:

  (internal) post-processing function used to convert bounds to expected
  output. Such as
  [`ext()`](https://drieslab.github.io/tilework/reference/ext.md) for
  `spatialTilePlan`

- zero:

  logical. Whether to zero out padding effects. (used by default with
  `pixelTilePlan`)

- expand_grid:

  logical (internal) whether to use
  [`expand.grid()`](https://rdrr.io/r/base/expand.grid.html) on ij
  indices.

## Value

`list` of `numeric` or `SpatExtent` depending on underlying `tilePlan`

## See also

Other tile\* methods:
[`arith`](https://drieslab.github.io/tilework/reference/arith.md),
[`as.polygons()`](https://drieslab.github.io/tilework/reference/as.polygons.md),
[`centroids()`](https://drieslab.github.io/tilework/reference/centroids.md),
[`dim()`](https://drieslab.github.io/tilework/reference/dim.md),
[`dollar`](https://drieslab.github.io/tilework/reference/dollar.md),
[`double_bracket`](https://drieslab.github.io/tilework/reference/double_bracket.md),
[`ext()`](https://drieslab.github.io/tilework/reference/ext.md),
[`intersect()`](https://drieslab.github.io/tilework/reference/intersect.md),
[`plot()`](https://drieslab.github.io/tilework/reference/plot.md)

## Examples

``` r
spat <- tilePlan("spatial")
ext(spat) <- c(0, 1000, 0, 1000)
length(spat) <- 9
spat[1]
#> [[1]]
#> SpatExtent : 0, 333.333333333333, 0, 333.333333333333 (xmin, xmax, ymin, ymax)
#> 
spat[1, 2:3]
#> [[1]]
#> SpatExtent : 333.333333333333, 666.666666666667, 0, 333.333333333333 (xmin, xmax, ymin, ymax)
#> 
#> [[2]]
#> SpatExtent : 666.666666666667, 1000, 0, 333.333333333333 (xmin, xmax, ymin, ymax)
#> 
spat[]
#> [[1]]
#> SpatExtent : 0, 333.333333333333, 0, 333.333333333333 (xmin, xmax, ymin, ymax)
#> 
#> [[2]]
#> SpatExtent : 333.333333333333, 666.666666666667, 0, 333.333333333333 (xmin, xmax, ymin, ymax)
#> 
#> [[3]]
#> SpatExtent : 666.666666666667, 1000, 0, 333.333333333333 (xmin, xmax, ymin, ymax)
#> 
#> [[4]]
#> SpatExtent : 0, 333.333333333333, 333.333333333333, 666.666666666667 (xmin, xmax, ymin, ymax)
#> 
#> [[5]]
#> SpatExtent : 333.333333333333, 666.666666666667, 333.333333333333, 666.666666666667 (xmin, xmax, ymin, ymax)
#> 
#> [[6]]
#> SpatExtent : 666.666666666667, 1000, 333.333333333333, 666.666666666667 (xmin, xmax, ymin, ymax)
#> 
#> [[7]]
#> SpatExtent : 0, 333.333333333333, 666.666666666667, 1000 (xmin, xmax, ymin, ymax)
#> 
#> [[8]]
#> SpatExtent : 333.333333333333, 666.666666666667, 666.666666666667, 1000 (xmin, xmax, ymin, ymax)
#> 
#> [[9]]
#> SpatExtent : 666.666666666667, 1000, 666.666666666667, 1000 (xmin, xmax, ymin, ymax)
#> 

px <- tilePlan("pixel")
px$pxdims <- c(1000, 1000)
px$ncols <- 200
px$nrows <- 200
px[1]
#> [[1]]
#> [1]   1 200   1 200
#> attr(,"tile")
#> [1] 1
#> 
px[2, 2:3]
#> [[1]]
#> [1] 201 400 201 400
#> attr(,"tile")
#> [1] 7
#> 
#> [[2]]
#> [1] 401 600 201 400
#> attr(,"tile")
#> [1] 8
#> 
px[]
#> [[1]]
#> [1]   1 200   1 200
#> attr(,"tile")
#> [1] 1
#> 
#> [[2]]
#> [1] 201 400   1 200
#> attr(,"tile")
#> [1] 2
#> 
#> [[3]]
#> [1] 401 600   1 200
#> attr(,"tile")
#> [1] 3
#> 
#> [[4]]
#> [1] 601 800   1 200
#> attr(,"tile")
#> [1] 4
#> 
#> [[5]]
#> [1]  801 1000    1  200
#> attr(,"tile")
#> [1] 5
#> 
#> [[6]]
#> [1]   1 200 201 400
#> attr(,"tile")
#> [1] 6
#> 
#> [[7]]
#> [1] 201 400 201 400
#> attr(,"tile")
#> [1] 7
#> 
#> [[8]]
#> [1] 401 600 201 400
#> attr(,"tile")
#> [1] 8
#> 
#> [[9]]
#> [1] 601 800 201 400
#> attr(,"tile")
#> [1] 9
#> 
#> [[10]]
#> [1]  801 1000  201  400
#> attr(,"tile")
#> [1] 10
#> 
#> [[11]]
#> [1]   1 200 401 600
#> attr(,"tile")
#> [1] 11
#> 
#> [[12]]
#> [1] 201 400 401 600
#> attr(,"tile")
#> [1] 12
#> 
#> [[13]]
#> [1] 401 600 401 600
#> attr(,"tile")
#> [1] 13
#> 
#> [[14]]
#> [1] 601 800 401 600
#> attr(,"tile")
#> [1] 14
#> 
#> [[15]]
#> [1]  801 1000  401  600
#> attr(,"tile")
#> [1] 15
#> 
#> [[16]]
#> [1]   1 200 601 800
#> attr(,"tile")
#> [1] 16
#> 
#> [[17]]
#> [1] 201 400 601 800
#> attr(,"tile")
#> [1] 17
#> 
#> [[18]]
#> [1] 401 600 601 800
#> attr(,"tile")
#> [1] 18
#> 
#> [[19]]
#> [1] 601 800 601 800
#> attr(,"tile")
#> [1] 19
#> 
#> [[20]]
#> [1]  801 1000  601  800
#> attr(,"tile")
#> [1] 20
#> 
#> [[21]]
#> [1]    1  200  801 1000
#> attr(,"tile")
#> [1] 21
#> 
#> [[22]]
#> [1]  201  400  801 1000
#> attr(,"tile")
#> [1] 22
#> 
#> [[23]]
#> [1]  401  600  801 1000
#> attr(,"tile")
#> [1] 23
#> 
#> [[24]]
#> [1]  601  800  801 1000
#> attr(,"tile")
#> [1] 24
#> 
#> [[25]]
#> [1]  801 1000  801 1000
#> attr(,"tile")
#> [1] 25
#> 
```
