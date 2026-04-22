# tileIterator

A stateful iterator that progresses through tiles of an underlying
`tilePlan` (or `tileGroup` if `$active` is set) object upon every call
to `$next_batch()`

The closures that power this functionality are stored in `@funs`. The
stateful position handling is also internalized within.

## Slots

- `funs`:

  list of closure methods

## See also

[tileIterator](https://drieslab.github.io/tilework/reference/tileIterator.md)

Other tile orchestration:
[`iterSplit()`](https://drieslab.github.io/tilework/reference/iterSplit.md),
[`tileGroup`](https://drieslab.github.io/tilework/reference/tileGroup.md),
[`tileGroup-class`](https://drieslab.github.io/tilework/reference/tileGroup-class.md),
[`tileIterator`](https://drieslab.github.io/tilework/reference/tileIterator.md)
