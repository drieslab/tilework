# Get and set metadata

`[[` can be used to get the table of metadata for a specific tile.

## Usage

``` r
# S4 method for class 'tilePlan,numeric,missing'
x[[i, j, ...]]

# S4 method for class 'tilePlan,missing,missing'
x[[i, j, ...]]

# S4 method for class 'tilePlan,missing,character'
x[[i, j, ...]]

# S4 method for class 'tilePlan,numeric,character'
x[[i, j, ...]]

# S4 method for class 'tilePlan,numeric,character'
x[[i, j, ...]] <- value

# S4 method for class 'tilePlan,missing,character'
x[[i, j, ...]] <- value
```

## Arguments

- x:

  `tilePlan`

- i:

  `integer-like`. tile vector index

- j:

  `character`. Name of metadata information to get

- ...:

  not used.

- value:

  `ANY` value to set

## Value

`data.frame`

## See also

[dollar](https://drieslab.github.io/tilework/reference/dollar.md)

Other tile\* methods:
[`arith`](https://drieslab.github.io/tilework/reference/arith.md),
[`as.polygons()`](https://drieslab.github.io/tilework/reference/as.polygons.md),
[`bracket`](https://drieslab.github.io/tilework/reference/bracket.md),
[`centroids()`](https://drieslab.github.io/tilework/reference/centroids.md),
[`dim()`](https://drieslab.github.io/tilework/reference/dim.md),
[`dollar`](https://drieslab.github.io/tilework/reference/dollar.md),
[`ext()`](https://drieslab.github.io/tilework/reference/ext.md),
[`intersect()`](https://drieslab.github.io/tilework/reference/intersect.md),
[`plot()`](https://drieslab.github.io/tilework/reference/plot.md)

## Examples

``` r
spat <- tilePlan("spatial")
ext(spat) <- c(0, 1000, 0, 1000)
length(spat) <- 9
spat[[1]]
#>   tile
#> 1    1
```
