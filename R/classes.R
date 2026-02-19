setClassUnion(".index", c("numeric", "character", "logical", "integer"))

#' @name tilework-class
#' @title Virtual Class `tilework`
#' @description
#' The `tilework` class is a class contained by all actual classes in the
#' \pkg{tilework} package. It is a "virtual" class.
#' @exportClass tilework
setClass("tilework", contains = "VIRTUAL")

#' @name token-class
#' @title `token` Class
#' @description
#' Utility class for flagging a piece of data as being ready for processing.
#' This is internal machinery that is mainly useful for forcing S4 dispatch to
#' progress in the expected order and should not be interacted with by end
#' users.
#'
#' This class and related methods are exported so developers are able to write
#' extending methods for `tileApply()` where this utility class is used.
#' @slot data ANY. The wrapped data object.
#' @exportClass token
setClass("token",
    slots = list(
        data = "ANY"
    )
)

#' @name tilePlan-class
#' @title Tile Plan
#' @description
#' Virtual parent class for tile planning objects. These objects are for planning
#' tiles/patches of data to be operated over. Objects are indexable across
#' rows/columns of tiles and as a vector of tiles (similarly to a matrix).
#'
#' `[` indexing returns a set of bounds information for selection of the
#' data. Tiles and bounds information are generated in a lazy fashion based on
#' plan parameters, avoiding overhead with large amounts of tiles.
#' @slot n numeric. Number of tiles to create.
#' @slot dims numeric. Number of rows/cols in the array of tiles
#' @slot tile_dims numeric. Row/col dimensions of each tile
#' @slot pad numeric. Tile padding
#' @slot metadata data.frame. Metadata per tile
#' @exportClass tilePlan
#' @seealso [spatialTilePlan-class] and [pixelTilePlan-class] for
#' concrete classes dealing with spatial and pixel-exact tiling respectively.
#' [tilePlan()] for creation of these objects.
setClass(
    "tilePlan",
    contains = c("VIRTUAL", "tilework"),
    slots = list(
        n = "numeric",
        dims = "integer",
        tile_dims = "numeric",
        pad = "numeric",
        metadata = "data.frame"
    ),
    prototype = list(
        pad = 0
    )
)

setClass(
    "tileSelection",
    slots = list(
        tp = "tilePlan",
        indices = "integer"
    )
)

#' @rdname spatialTilePlan-class
#' @slot extent numeric. Spatial extent to tile across.
#' @slot n numeric. Number of tiles to create.
#' @slot dims numeric. Number of rows/cols in the array of tiles
#' @slot tile_dims numeric. Row/col dimensions of each tile
#' @slot pad numeric. Tile padding
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
#' @slot pad numeric. Tile padding
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
#' @slot tp `tilePlan.` The underlying `tilePlan`-inheriting object
#' @slot groups list. Named list where each element contains tile indices for that group
#' @slot active character. Name of a group to set as active for `[i]` shorthand
#' indexing and `length()`.
#' @slot metadata data.frame. Metadata about each group
#' @exportClass tileGroup
setClass("tileGroup",
    contains = "tilework",
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
#' @seealso [tileIterator]
#' @exportClass tileIterator
setClass("tileIterator",
    contains = "tilework",
    slots = list(
        funs = "list"
    )
)
