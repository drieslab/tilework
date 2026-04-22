# Get and Set Tile Metadata and Params

Get and set tile metadata. Some params can also be modified with this
operator, for example the `$pad` value or `$pxdims`, `$ncols`, or
`$nrows` for `pixelTilePlan`.

`$tile` is a default created piece of metadata.

## Usage

``` r
# S4 method for class 'tilePlan'
x$name <- value

# S4 method for class 'tilePlan'
x$name

# S4 method for class 'freeTilePlan'
x$name <- value

# S4 method for class 'freeTilePlan'
x$name

# S4 method for class 'pointTilePlan'
x$name <- value

# S4 method for class 'pointTilePlan'
x$name

# S4 method for class 'pixelTilePlan'
x$name <- value

# S4 method for class 'pixelTilePlan'
x$name

# S4 method for class 'tileGroup'
x$name <- value

# S4 method for class 'tileGroup'
x$name

# S4 method for class 'tileSelection'
x$name

# S4 method for class 'tileSelection'
x$name <- value
```

## Arguments

- x:

  `tilePlan`

- name:

  name of item to get or set

- value:

  value to set

## Value

metadata value when using getter or `tile*` object when using the setter
function.

## See also

Other tile\* methods:
[`arith`](https://drieslab.github.io/tilework/reference/arith.md),
[`as.polygons()`](https://drieslab.github.io/tilework/reference/as.polygons.md),
[`bracket`](https://drieslab.github.io/tilework/reference/bracket.md),
[`centroids()`](https://drieslab.github.io/tilework/reference/centroids.md),
[`dim()`](https://drieslab.github.io/tilework/reference/dim.md),
[`double_bracket`](https://drieslab.github.io/tilework/reference/double_bracket.md),
[`ext()`](https://drieslab.github.io/tilework/reference/ext.md),
[`intersect()`](https://drieslab.github.io/tilework/reference/intersect.md),
[`plot()`](https://drieslab.github.io/tilework/reference/plot.md)

## Examples

``` r
x <- tilePlan()
ext(x) <- c(0, 100, 0, 100)
length(x) <- 9
x$test <- sprintf("test_value_%d", x$tile)
x$test
#> [1] "test_value_1" "test_value_2" "test_value_3" "test_value_4" "test_value_5"
#> [6] "test_value_6" "test_value_7" "test_value_8" "test_value_9"
tile_ext <- x[5][[1]]
attr(tile_ext, "test")
#> [1] "test_value_5"
```
