# Plot a `tilePlan`

Plot and preview the tile plan. This is likely to be very slow if there
are a lot of tiles (in the neighborhood of \>10,000)

## Usage

``` r
# S4 method for class 'tilePlan,missing'
plot(x, values = "tile", color_as_factor = FALSE, ...)

# S4 method for class 'freeTilePlan,missing'
plot(x, y, ...)

# S4 method for class 'pointTilePlan,missing'
plot(x, y, ...)

# S4 method for class 'pixelTilePlan,missing'
plot(x, y, ...)
```

## Arguments

- x:

  `tilePlan` to plot

- values:

  character. Metadata item to color tiles as. Default is `"tile"` which
  produces the tile index.

- color_as_factor:

  logical (default = `FALSE`). Whether to convert `value` to a factor to
  plot as categorical.

- ...:

  additional params to pass

- y:

  not used.

## See also

Other tile\* methods:
[`arith`](https://drieslab.github.io/tilework/reference/arith.md),
[`as.polygons()`](https://drieslab.github.io/tilework/reference/as.polygons.md),
[`bracket`](https://drieslab.github.io/tilework/reference/bracket.md),
[`centroids()`](https://drieslab.github.io/tilework/reference/centroids.md),
[`dim()`](https://drieslab.github.io/tilework/reference/dim.md),
[`dollar`](https://drieslab.github.io/tilework/reference/dollar.md),
[`double_bracket`](https://drieslab.github.io/tilework/reference/double_bracket.md),
[`ext()`](https://drieslab.github.io/tilework/reference/ext.md),
[`intersect()`](https://drieslab.github.io/tilework/reference/intersect.md)

## Examples

``` r
x <- tilePlan()
ext(x) <- c(0, 100, 0, 100)
length(x) <- 9
plot(x)


x$new_meta <- rev(head(letters, 9))
plot(x, value = "new_meta")
```
