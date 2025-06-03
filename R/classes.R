
setClassUnion(".index", c("numeric", "character", "logical", "integer"))

#' @keywords internal
#' @noRd
setClass("giottoTile", contains = "VIRTUAL")

#' @name tilePlan-class
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
#' @exportClass tilePlan
#' @seealso [spatialTilePlan-class] and [pixelTilePlan-class] for
#' concrete classes dealing with spatial and pixel-exact tiling respectively.
#' [tilePlan()] for creation of these objects.
setClass(
    "tilePlan",
    contains = c("VIRTUAL", "giottoTile"),
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

#' @rdname spatialTilePlan-class
#' @slot extent numeric. Spatial extent to tile across.
#' @slot n numeric. Number of tiles to create.
#' @slot dims numeric. Number of rows/cols in the array of tiles
#' @slot tile_dims numeric. Row/col dimensions of each tile
#' @slot buffer numeric. Tile padding/buffering
#' @slot metadata data.frame. Metadata per tile
#' @exportClass spatialTilePlan
setClass(
    "spatialTilePlan",
    contains = "tilePlan",
    slots = list(
        extent = "numeric"
    )
)

#' @rdname pixelTilePlan-class
#' @slot pxdims pixel dimensions to iterate across
#' @slot n numeric. Number of tiles to create.
#' @slot dims numeric. Number of rows/cols in the array of tiles
#' @slot tile_dims numeric. Row/col dimensions of each tile
#' @slot buffer numeric. Tile padding/buffering
#' @slot metadata data.frame. Metadata per tile
#' @exportClass pixelTilePlan
setClass(
    "pixelTilePlan",
    contains = "tilePlan",
    slots = list(
        pxdims = "numeric"
    )
)

#' @name tileGroup-class
#' @title Tile Group
#' @description
#' Class for organizing tiles into hierarchical groups for batch processing.
#' Groups can represent spatial regions, processing stages, or any logical
#' organization of tiles.
#' @slot tp tilePlan. The underlying tile iterator
#' @slot groups list. Named list where each element contains tile indices for that group
#' @slot active character. Name of a group to set as active for `[, j]` indexing and
#' `length()`.
#' @slot metadata data.frame. Metadata about each group
#' @exportClass tileGroup
setClass("tileGroup",
    contains = "giottoTile",
    slots = list(
        tp = "tilePlan",
        groups = "list",
        active = "character",
        metadata = "data.frame"
    )
)

#' @name tileIterator-class
#' @title tileIterator
#' @description
#' A stateful iterator that progresses through tiles of an underlying `tilePlan`
#' (or `tileGroup` if `$active` is set) object upon every call to `$next_batch()`
#'
#' The closures that power this functionality are stored in `@funs`. The stateful
#' position handling is also internalized within.
#' @slot funs list of closure methods
#' @seealso [tileGroupIterator-class]
#' @exportClass tileIterator
setClass("tileIterator",
    contains = "giottoTile",
    slots = list(
        funs = "list"
    )
)
