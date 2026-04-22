# Extending {tilework}

{tilework} provides an extensible framework for:

- [tile
  planning](https://drieslab.github.io/tilework/reference/tilePlan-class.md)

- [tile
  selection](https://drieslab.github.io/tilework/reference/tileGroup-class.md)

- [batch
  iteration](https://drieslab.github.io/tilework/reference/tileIterator-class.md)

- [parallelized data
  processing](https://drieslab.github.io/tilework/reference/tileApply.md)

## Data flow

The framework accesses and processes data according to the following
flow:

1.  `tileApply(x, tiles, ...)` \# operate across tiles

2.  `getTile(x, tiles, ..., get_params)` \# get data for tiles

    1.  `bounds <- tiles[...]` \# generate bounds info

    2.  `getBoundedData(x, bounds, get_params)` \# data extraction

Expanded roles:

- [`tileApply()`](https://drieslab.github.io/tilework/reference/tileApply.md)-
  handles the function parallelization strategy and logic.

- [`getTile()`](https://drieslab.github.io/tilework/reference/getTile.md) -
  deals with any interactions between the data type and the tile
  indexing. Operations that should be performed before extraction of the
  actual data by tile bounds should happen at this level.

- [`getBoundedData()`](https://drieslab.github.io/tilework/reference/getBoundedData.md) -
  performs the low-level data extraction from the data source, provided
  with a set of bounds information (commonly a `SpatExtent` or `numeric`
  of `c(xmin, xmax, ymin, ymax)`)

## Adding new data type support

{tilework} functionalities can be extended to work with other data
types/backends by creating a
[`getBoundedData()`](https://drieslab.github.io/tilework/reference/getBoundedData.md)
method for the data type. Optional additional steps:

- Method for
  [`tileApply()`](https://drieslab.github.io/tilework/reference/tileApply.md)
  should also be added if there are pre-run validation/data collection
  steps needed.

- Method for
  [`getTile()`](https://drieslab.github.io/tilework/reference/getTile.md)
  should be added if there are operations that affect data/tile
  interactions.

## See also

Other tilework extension:
[`redispatch_tileapply,SpatRaster,freeTilePlan-method`](https://drieslab.github.io/tilework/reference/redispatch_tileapply.md),
[`token-class`](https://drieslab.github.io/tilework/reference/token-class.md)

## Examples

``` r
if (FALSE) {
    # Extending for a custom data type:
    setMethod(
        "getBoundedData", signature("MyDataType", "SpatExtent"),
        function(x, bound) {
            # Your data extraction logic here
            my_extract_function(x, bound)
        }
    )
}
```
