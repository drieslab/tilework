# Tile Plan

Virtual parent class for tile planning objects. These objects are for
planning tiles/patches of data to be operated over. Objects are
indexable across rows/columns of tiles and as a vector of tiles
(similarly to a matrix).

`[` indexing returns a set of bounds information for selection of the
data. Tiles and bounds information are generated in a lazy fashion based
on plan parameters, avoiding overhead with large amounts of tiles.

## Slots

- `n`:

  numeric. Number of tiles to create.

- `dims`:

  numeric. Number of rows/cols in the array of tiles

- `tile_dims`:

  numeric. Row/col dimensions of each tile

- `pad`:

  numeric. Tile padding

- `metadata`:

  data.frame. Metadata per tile

## See also

[spatialTilePlan](https://drieslab.github.io/tilework/reference/spatialTilePlan-class.md)
and
[pixelTilePlan](https://drieslab.github.io/tilework/reference/pixelTilePlan-class.md)
for concrete classes dealing with spatial and pixel-exact tiling
respectively.
[`tilePlan()`](https://drieslab.github.io/tilework/reference/tilePlan.md)
for creation of these objects.

Other tile plans:
[`freeTilePlan`](https://drieslab.github.io/tilework/reference/freeTilePlan.md),
[`freeTilePlan-class`](https://drieslab.github.io/tilework/reference/freeTilePlan-class.md),
[`pixelTilePlan-class`](https://drieslab.github.io/tilework/reference/pixelTilePlan-class.md),
[`pointTilePlan-class`](https://drieslab.github.io/tilework/reference/pointTilePlan-class.md),
[`quadtreePlan()`](https://drieslab.github.io/tilework/reference/quadtreePlan.md),
[`spatialTilePlan-class`](https://drieslab.github.io/tilework/reference/spatialTilePlan-class.md),
[`tilePlan`](https://drieslab.github.io/tilework/reference/tilePlan.md),
[`tilework-class`](https://drieslab.github.io/tilework/reference/tilework-class.md)
