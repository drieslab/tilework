# Tile Group

Class for organizing tiles into hierarchical groups for batch
processing. Groups can represent spatial regions, processing stages, or
any logical organization of tiles.

## Slots

- `tp`:

  `tilePlan.` The underlying `tilePlan`-inheriting object

- `groups`:

  list. Named list where each element contains tile indices for that
  group

- `active`:

  character. Name of a group to set as active for `[i]` shorthand
  indexing and
  [`length()`](https://drieslab.github.io/tilework/reference/dim.md).

- `metadata`:

  data.frame. Metadata about each group

## See also

Other tile orchestration:
[`iterSplit()`](https://drieslab.github.io/tilework/reference/iterSplit.md),
[`tileGroup`](https://drieslab.github.io/tilework/reference/tileGroup.md),
[`tileIterator`](https://drieslab.github.io/tilework/reference/tileIterator.md),
[`tileIterator-class`](https://drieslab.github.io/tilework/reference/tileIterator-class.md)
