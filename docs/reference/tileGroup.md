# Create a Tile Group

Organize tiles from a tilePlan into hierarchical groups for batch
processing. Groups can represent spatial regions, processing stages, or
any logical organization of tiles.

## Usage

``` r
tileGroup(tp, groups = list())
```

## Arguments

- tp:

  A tilePlan object

- groups:

  Named list where each element contains tile indices for that group

- metadata:

  Optional data.frame with group metadata

## See also

Other tile orchestration:
[`iterSplit()`](https://drieslab.github.io/tilework/reference/iterSplit.md),
[`tileGroup-class`](https://drieslab.github.io/tilework/reference/tileGroup-class.md),
[`tileIterator`](https://drieslab.github.io/tilework/reference/tileIterator.md),
[`tileIterator-class`](https://drieslab.github.io/tilework/reference/tileIterator-class.md)

## Examples

``` r
tp <- tilePlan("spatial")
ext(tp) <- c(0, 100, 0, 100)
length(tp) <- 16

# Create groups
tg <- tileGroup(tp, groups = list(
    "g1" = 1:4, # vector indexing
    "g2" = list(2, 1:4), # ij indexing
    "g3" = list(2:4, 1:2) # selection overlaps are allowed
    # (not all tiles need to be selected)
))

# length() returns number of groups
length(tg)
#> [1] 3

# Get group bounds:
tg[, "g1"] # first 4
#> [[1]]
#> SpatExtent : 0, 25, 0, 25 (xmin, xmax, ymin, ymax)
#> 
#> [[2]]
#> SpatExtent : 25, 50, 0, 25 (xmin, xmax, ymin, ymax)
#> 
#> [[3]]
#> SpatExtent : 50, 75, 0, 25 (xmin, xmax, ymin, ymax)
#> 
#> [[4]]
#> SpatExtent : 75, 100, 0, 25 (xmin, xmax, ymin, ymax)
#> 
tg[, "g2"] # next 4
#> [[1]]
#> SpatExtent : 0, 25, 25, 50 (xmin, xmax, ymin, ymax)
#> 
#> [[2]]
#> SpatExtent : 25, 50, 25, 50 (xmin, xmax, ymin, ymax)
#> 
#> [[3]]
#> SpatExtent : 50, 75, 25, 50 (xmin, xmax, ymin, ymax)
#> 
#> [[4]]
#> SpatExtent : 75, 100, 25, 50 (xmin, xmax, ymin, ymax)
#> 
tg[, "g3"] # specific 6
#> [[1]]
#> SpatExtent : 0, 25, 25, 50 (xmin, xmax, ymin, ymax)
#> 
#> [[2]]
#> SpatExtent : 25, 50, 25, 50 (xmin, xmax, ymin, ymax)
#> 
#> [[3]]
#> SpatExtent : 0, 25, 50, 75 (xmin, xmax, ymin, ymax)
#> 
#> [[4]]
#> SpatExtent : 25, 50, 50, 75 (xmin, xmax, ymin, ymax)
#> 
#> [[5]]
#> SpatExtent : 0, 25, 75, 100 (xmin, xmax, ymin, ymax)
#> 
#> [[6]]
#> SpatExtent : 25, 50, 75, 100 (xmin, xmax, ymin, ymax)
#> 
# not recommended for large groups

tg[c(3, 1), "g3"] # get nth item in group
#> [[1]]
#> SpatExtent : 0, 25, 50, 75 (xmin, xmax, ymin, ymax)
#> 
#> [[2]]
#> SpatExtent : 0, 25, 25, 50 (xmin, xmax, ymin, ymax)
#> 

# Set active group for shorthand indexing
tg$active <- "g1"

# length() is based on group length when active is set
length(tg)
#> [1] 4

tg[2] # Position 2 from g1
#> [[1]]
#> SpatExtent : 25, 50, 0, 25 (xmin, xmax, ymin, ymax)
#> 

# iterator can be created when active group is set
iter <- tileIterator(tg, batch_size = 2)
iter$next_batch()
#> [[1]]
#> SpatExtent : 0, 25, 0, 25 (xmin, xmax, ymin, ymax)
#> 
#> [[2]]
#> SpatExtent : 25, 50, 0, 25 (xmin, xmax, ymin, ymax)
#> 
#> attr(,"batch_start")
#> [1] 1
#> attr(,"batch_end")
#> [1] 2
#> attr(,"batch_size")
#> [1] 2
#> attr(,"iterator_position")
#> [1] 2
iter$next_batch()
#> [[1]]
#> SpatExtent : 50, 75, 0, 25 (xmin, xmax, ymin, ymax)
#> 
#> [[2]]
#> SpatExtent : 75, 100, 0, 25 (xmin, xmax, ymin, ymax)
#> 
#> attr(,"batch_start")
#> [1] 3
#> attr(,"batch_end")
#> [1] 4
#> attr(,"batch_size")
#> [1] 2
#> attr(,"iterator_position")
#> [1] 4
iter$next_batch() # no more items
#> list()

tg$active <- NULL # Clear active group by setting NULL
```
