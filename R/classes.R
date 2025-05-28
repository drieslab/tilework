#' @name tileIterator-class
#' @title Tile Iterator
#' @description
#' Virtual parent class for tile iterator objects. These objects are for demarcating
#' tiles/patches of data to be operated over. Objects are intended for easy
#' traversal either across either rows or columns of tiles or as a vector of
#' tiles. They are also lightweight and self-contained to aid with
#' parallelization.
#' @slot n numeric. Number of tiles to create.
#' @slot dims numeric. Number of rows/cols in the array of tiles
#' @slot tile_dims numeric. Row/col dimensions of each tile
#' @slot buffer numeric. Tile padding/buffering
#' @slot metadata data.frame. Metadata per tile
#' @exportClass tileIterator
#' @seealso [spatialTileIterator-class] and [pixelTileIterator-class] for
#' concrete classes dealing with spatial and pixel-exact tiling respectively.
#' [tileIterator()] for creation of these objects.
setClass(
    "tileIterator",
    contains = "VIRTUAL",
    slots = list(
        n = "numeric",
        dims = "numeric",
        tile_dims = "numeric",
        buffer = "numeric",
        metadata = "data.frame"
    ),
    prototype = list(
        buffer = 0
    )
)

#' @rdname spatialTileIterator-class
#' @slot extent numeric. Spatial extent to tile across.
#' @slot n numeric. Number of tiles to create.
#' @slot dims numeric. Number of rows/cols in the array of tiles
#' @slot tile_dims numeric. Row/col dimensions of each tile
#' @slot buffer numeric. Tile padding/buffering
#' @slot metadata data.frame. Metadata per tile
#' @exportClass spatialTileIterator
setClass(
    "spatialTileIterator",
    contains = "tileIterator",
    slots = list(
        extent = "numeric"
    )
)

#' @rdname pixelTileIterator-class
#' @slot pxdims pixel dimensions to iterate across
#' @slot n numeric. Number of tiles to create.
#' @slot dims numeric. Number of rows/cols in the array of tiles
#' @slot tile_dims numeric. Row/col dimensions of each tile
#' @slot buffer numeric. Tile padding/buffering
#' @slot metadata data.frame. Metadata per tile
#' @exportClass pixelTileIterator
setClass(
    "pixelTileIterator",
    contains = "tileIterator",
    slots = list(
        pxdims = "numeric"
    )
)
