# `token` Class

Utility class for flagging a piece of data as being ready for
processing. This is internal machinery that is mainly useful for forcing
S4 dispatch to progress in the expected order and should not be
interacted with by end users.

This class and related methods are exported so developers are able to
write extending methods for
[`tileApply()`](https://drieslab.github.io/tilework/reference/tileApply.md)
where this utility class is used.

## Usage

``` r
# S4 method for class 'token,missing,missing,missing'
x[i, j, ..., drop = TRUE]
```

## Slots

- `data`:

  ANY. The wrapped data object.

## See also

Other tilework extension:
[`extending_tilework`](https://drieslab.github.io/tilework/reference/extending_tilework.md),
[`redispatch_tileapply,SpatRaster,freeTilePlan-method`](https://drieslab.github.io/tilework/reference/redispatch_tileapply.md)

## Examples

``` r
# Flag as being ready for processing
x <- as(letters, "token")

# Retrieve wrapped data
x[]
#>  [1] "a" "b" "c" "d" "e" "f" "g" "h" "i" "j" "k" "l" "m" "n" "o" "p" "q" "r" "s"
#> [20] "t" "u" "v" "w" "x" "y" "z"
```
