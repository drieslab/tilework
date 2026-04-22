# Create a Tiling Plan

Create a Tiling Plan

## Usage

``` r
tilePlan(type = c("spatial", "pixel", "point", "free"), ...)
```

## Arguments

- type:

  character. One of `"spatial"`, `"pixel"`, `"point"`, `"free"`. Type of
  plan to create.

- ...:

  additional params passed to the specific constructor:
  [`spatialTilePlan()`](https://drieslab.github.io/tilework/reference/spatialTilePlan-class.md),
  [`pixelTilePlan()`](https://drieslab.github.io/tilework/reference/pixelTilePlan-class.md),
  [`pointTilePlan()`](https://drieslab.github.io/tilework/reference/pointTilePlan-class.md),
  or
  [`freeTilePlan()`](https://drieslab.github.io/tilework/reference/freeTilePlan.md).

## See also

[spatialTilePlan](https://drieslab.github.io/tilework/reference/spatialTilePlan-class.md),
[pixelTilePlan](https://drieslab.github.io/tilework/reference/pixelTilePlan-class.md),
[pointTilePlan](https://drieslab.github.io/tilework/reference/pointTilePlan-class.md),
[freeTilePlan](https://drieslab.github.io/tilework/reference/freeTilePlan-class.md)

Other tile plans:
[`freeTilePlan`](https://drieslab.github.io/tilework/reference/freeTilePlan.md),
[`freeTilePlan-class`](https://drieslab.github.io/tilework/reference/freeTilePlan-class.md),
[`pixelTilePlan-class`](https://drieslab.github.io/tilework/reference/pixelTilePlan-class.md),
[`pointTilePlan-class`](https://drieslab.github.io/tilework/reference/pointTilePlan-class.md),
[`quadtreePlan()`](https://drieslab.github.io/tilework/reference/quadtreePlan.md),
[`spatialTilePlan-class`](https://drieslab.github.io/tilework/reference/spatialTilePlan-class.md),
[`tilePlan-class`](https://drieslab.github.io/tilework/reference/tilePlan-class.md),
[`tilework-class`](https://drieslab.github.io/tilework/reference/tilework-class.md)

## Examples

``` r
tilePlan("spatial")
#> Object of class spatialTilePlan 
#> <empty>
tilePlan("pixel")
#> Object of class pixelTilePlan 
#> tiles  : 0
#> pxdim  : 
#> pxrows : 0
#> pxcol  : 0
#> dim    : 0, 0
#> pad    : 0
tilePlan("point")
#> Object of class pointTilePlan 
#> <empty>
tilePlan("free")
#> Object of class freeTilePlan 
#> <empty>
```
