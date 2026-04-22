# Tile Plan Array Characteristics

Get dimension characteristics of the `tilePlan` tiling plan. These
produce information on how the tiles are arrayed in rows `nrow()`, cols
`ncol()`, and total number of tiles `length()`.

`length<-()` is a special case and currently only used with
`spatialTilePlan`, where it is used to request a minimum number of tiles
to generate.

## Usage

``` r
# S4 method for class 'tilePlan'
nrow(x)

# S4 method for class 'tilePlan'
ncol(x)

# S4 method for class 'tilePlan'
length(x)

# S4 method for class 'tilePlan'
dim(x)

# S4 method for class 'spatialTilePlan'
length(x) <- value

# S4 method for class 'tileIterator'
length(x)
```

## Arguments

- x:

  `tilePlan` object

- value:

  number of tiles to request

## Value

numeric or `spatialTilePlan` object when using `length<-()`

## See also

Other tile\* methods:
[`arith`](https://drieslab.github.io/tilework/reference/arith.md),
[`as.polygons()`](https://drieslab.github.io/tilework/reference/as.polygons.md),
[`bracket`](https://drieslab.github.io/tilework/reference/bracket.md),
[`centroids()`](https://drieslab.github.io/tilework/reference/centroids.md),
[`dollar`](https://drieslab.github.io/tilework/reference/dollar.md),
[`double_bracket`](https://drieslab.github.io/tilework/reference/double_bracket.md),
[`ext()`](https://drieslab.github.io/tilework/reference/ext.md),
[`intersect()`](https://drieslab.github.io/tilework/reference/intersect.md),
[`plot()`](https://drieslab.github.io/tilework/reference/plot.md)

## Examples

``` r
x <- tilePlan()
ext(x) <- c(0, 100, 0, 100)
length(x)
#> [1] 0
length(x) <- 9
length(x)
#> [1] 9
dim(x)
#> [1] 3 3
nrow(x)
#> [1] 3
ncol(x)
#> [1] 3
```
