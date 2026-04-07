setClassUnion(".index", c("numeric", "character", "logical", "integer"))

#' @name tilework-class
#' @title Virtual Class `tilework`
#' @description
#' The `tilework` class is a class contained by all tile* classes in the
#' \pkg{tilework} package. It is a "virtual" class.
#' @exportClass tilework
#' @family tile plans
setClass("tilework", contains = "VIRTUAL")

#' @name token-class
#' @title `token` Class
#' @family tilework extension
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
#' @family tile plans
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

#' @name pointTilePlan-class
#' @title Point Tile Plan
#' @family tile plans
#' @description
#' Tile plan where each tile is centered on a user-supplied (x, y) coordinate
#' with a uniform tile size. The center coordinates are primary — for use cases
#' like survey sampling, object detection patches, or site-centered extractions
#' where the point location is semantically meaningful.
#' @slot coords matrix. n x 2 matrix of tile center coordinates (columns: x, y).
#' @slot input character. Coordinate space of coords, dims, and padding:
#' `"spatial"` for CRS units, `"pixel"` for pixel indices.
#' @slot output character. Bound type returned by [getTile()]: `"spatial"` or
#' `"pixel"`. Defaults to `input`. Evaluated at [getTile()] time, not `[i]`.
#' @slot rast_dims numeric. `c(nrow, ncol)` of the reference raster. Required
#' for `plot()` when `input = "pixel"` and for cross-mode conversion without a
#' raster.
#' @slot extent numeric. `c(xmin, xmax, ymin, ymax)` of the reference raster.
#' Required for pixel → CRS conversion without a raster.
#' @slot n numeric. Number of tiles (equals number of input points).
#' @slot dims integer. Always `c(n, 1L)`.
#' @slot tile_dims numeric. Uniform `c(height, width)` in input coordinate units.
#' @slot pad numeric. Tile padding in input coordinate units.
#' @slot metadata data.frame. Per-tile metadata; always has `"tile"`, `"x"`,
#' and `"y"` columns.
#' @exportClass pointTilePlan
setClass(
    "pointTilePlan",
    contains = "tilePlan",
    slots = list(
        coords    = "matrix",    # n × 2: x, y in input coordinate space
        input     = "character", # "spatial" | "pixel"
        output    = "character", # "spatial" | "pixel" — getTile concern only
        rast_dims = "numeric",   # c(nrow, ncol) — for pixel input plotting / cross-mode
        extent    = "numeric"    # c(xmin, xmax, ymin, ymax) — for px->CRS conversion
    ),
    prototype = list(
        n         = 0,
        dims      = c(0L, 1L),
        tile_dims = c(0, 0),
        metadata  = data.frame(),
        coords    = matrix(numeric(0), ncol = 2L),
        rast_dims = numeric(0),
        extent    = numeric(0)
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

#' @name freeTilePlan-class
#' @title Free Tile Plan
#' @family tile plans
#' @description
#' Tile plan defined by explicit per-tile bounds with no required uniformity
#' in size or spacing. The bounds matrix is the canonical representation —
#' there is no center-plus-dims formula. Always returns `SpatExtent` from
#' `[i]`. Primary use case is as the output of adaptive spatial decomposition
#' algorithms such as quadtrees on vector/point data.
#' @slot bounds matrix. n x 4 matrix: xmin, xmax, ymin, ymax (one row per tile).
#' @note `@tile_dims` is intentionally not populated. Any method that requires
#'   uniform tile dimensions will not work with `freeTilePlan`.
#' @exportClass freeTilePlan
setClass(
    "freeTilePlan",
    contains = "tilePlan",
    slots = list(
        bounds = "matrix"
    ),
    prototype = list(
        bounds = matrix(numeric(0), ncol = 4L)
    )
)

#' @name tileGroup-class
#' @title Tile Group
#' @family tile orchestration
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
#' @family tile orchestration
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
