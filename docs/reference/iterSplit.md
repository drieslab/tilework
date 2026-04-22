# Create multiple walkers from a single iterator

Utility function to create multiple independent walkers for parallel
processing. Each iterator will have the same underlying iterator but
independent state.

## Usage

``` r
# S4 method for class 'tileIterator'
iterSplit(tiles, n, batch_size = NULL, distribute = TRUE, ...)
```

## Arguments

- tiles:

  tileIterator object

- n:

  integer. Number of iterators to create

- batch_size:

  integer (optional). Assign a batch size for each iterator. If not
  provided, inherits same `batch_size` as source `tiles`.

- distribute:

  logical (default = `TRUE`). If `TRUE`, distribute tiles evenly across
  iterators. Otherwise return multiple true copies.

## See also

Other tile orchestration:
[`tileGroup`](https://drieslab.github.io/tilework/reference/tileGroup.md),
[`tileGroup-class`](https://drieslab.github.io/tilework/reference/tileGroup-class.md),
[`tileIterator`](https://drieslab.github.io/tilework/reference/tileIterator.md),
[`tileIterator-class`](https://drieslab.github.io/tilework/reference/tileIterator-class.md)
