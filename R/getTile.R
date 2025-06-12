#' @include generics.R

# docs ####

#' @name getTile
#' @title Get Tile
#' @description
#' Get specific tile(s) from the data based on a `tile*` object. Indexing via
#' `i` and `j` params is used to select the tile(s) to get, in a manner similar
#' to `[` extraction of bounds from `tile*` objects.
#'
#' **All params are usable with any method except when otherwise stated.**
#'
#' This generic handles data/`tile*` object interactions. For simple selection
#' of data based on a set of bounds, see the low-level generic [getBoundedData()].
#'
#' The `character` method only works for filetypes readable by \{terra\}.
#'
#' New `x` data types should automatically work with this generic as long as a
#' `getBoundedData()` method is created for it. A specific `getTile()` method
#' is only needed if additional params/operations should be performed before
#' the tile selection, (for example layer selection with raster data).
#'
#' @param x data
#' @param tiles `tile*` object
#' @param i **ANY except tileIterator** tile vector index or row index if `j` is also provided
#' @param j **ANY except tileIterator** tile col index
#' @param pad (optional) additional padding to apply before tile retrieval.
#'   Useful for temporarily increasing padding without affecting `tile*` object.
#' @param get_params list of named params to pass to underlying [getBoundedData()]
#'   call.
#' @param advance **`tileIterator` only** logical (default = TRUE). Whether to
#'   advance the iterator.
#' @param lyr **`SpatRaster` only** if provided, which layers/channels to include
#' @param extend **`pixelTilePlan` only** logical (default = FALSE). Whether to
#'   extend tile data to reach expected tile dimensions
#' @param fill **`pixelTilePlan` only** numeric. if `extend = TRUE`, what value to
#'   fill with
#' @param \dots additional params to pass to [`[`][bracket] `tilePlan` indexing
#' @returns `list` of tile data
#' @seealso [getBoundedData()]
#' @examples
#' f <- system.file("ex/elev.tif", package="terra")
#' r <- terra::rast(f)
#' tp <- tilePlan("pixel")
#' tp$pxdims <- dim(r)[1:2]
#' tp$nrows <- 10
#' tp$ncols <- 10
#'
#' # get tiles from specific array grid indices.
#' tile_list <- getTile(f, tp, i = 3, j = 5)
#' force(tile_list)
#' plot(tile_list[[1]])
#'
#' # get tiles via iteration
#' iter <- tileIterator(tp, batch_size = 3)
#' b1 <- getTile(r, iter) # get first batch of 3...
#' b2 <- getTile(r, iter) # get second batch of 3...
NULL


# methods ####

## tilePlan ####

#' @rdname getTile
#' @export
setMethod("getTile", signature("token", "tilePlan"),
    function(x, tiles, ...) {
        getTile(x[], tiles, ...) # unwrap and re-call.
    }
)

#' @rdname getTile
#' @export
setMethod("getTile", signature("ANY", "tilePlan"),
    function(x, tiles, i = NULL, j, pad = NULL, get_params = list(), ...) {
    checkmate::assert_integerish(i)
    checkmate::assert_list(get_params)
    if (!is.null(pad)) {
        checkmate::assert_numeric(pad)
        tiles <- tiles + pad
    }
    if (missing(j)) bounds_list <- tiles[i, ...]
    else bounds_list <- tiles[i, j, ...]
    lapply(bounds_list, function(b) {
        a <- c(list(x, b), get_params)
        do.call(getBoundedData, a)
    })
})

#' @rdname getTile
#' @param ext **`SpatRaster` or raster filepath (`character`) only** `numeric`
#'   or `SpatExtent` (optional) Set an extent before extracting tiles from raster.
#' @param prefer **`character` filepath only** character. Hint for file reading
#' (`"raster"` or `"vector"`). If provided, skips automatic type detection.
#' @export
setMethod("getTile", signature("character", "tilePlan"),
    function(x, tiles, prefer = NULL, ext = NULL, ...) {
    checkmate::assert_file_exists(x)
    x <- .terra_read(x, prefer = prefer)
    if (!is.null(ext)) ext(x) <- ext
    getTile(x, tiles, ...)
})

## pixelTilePlan ####

#' @rdname getTile
#' @export
setMethod("getTile", signature("SpatRaster", "pixelTilePlan"),
    function(x, tiles, lyr = NULL, extend = FALSE, fill = NA, get_params = list(), ...) {
    checkmate::assert_integerish(lyr, null.ok = TRUE)
    checkmate::assert_logical(extend)
    if (!is.null(lyr)) x <- x[[lyr]]
    get_params$extend <- extend
    get_params$fill <- fill
    get_params$tiles <- tiles
    callNextMethod(x, tiles, get_params = get_params, ...)
})

## spatialTilePlan ####

#' @rdname getTile
#' @export
setMethod("getTile", signature("SpatRaster", "spatialTilePlan"),
    function(x, tiles, lyr = NULL, ...) {
    if (!is.null(lyr)) x <- x[[lyr]]
    callNextMethod(x, tiles, ...)
})

## tileGroup ####

setMethod("getTile", signature("SpatRaster", "tileGroup"),
    function(x, tiles, i, j, lyr = NULL, ...) {
    checkmate::assert_integerish(lyr, null.ok = TRUE)
    if (!is.null(lyr)) x <- x[[lyr]]
    if (missing(j)) callNextMethod(x, tiles, i = i, ...)
    else callNextMethod(x, tiles, i = i, j = j, ...)
})

#' @rdname getTile
#' @export
setMethod("getTile", signature("ANY", "tileGroup"),
    function(x, tiles, i, j, ...) {
    checkmate::assert_integerish(i)
    if (missing(j)) {
        if (!.has_active(tiles)) {
            stop("getTile: tileGroup `j` may only be omitted when an active group is set.\n", call. = FALSE)
        }
        j <- tiles@active
    }
    g <- tiles@groups[[j]]

    # dispatch to getTile() tilePlan methods
    if (!.is_ij_group(g)) {
        # g is vector index
        getTile(x, tiles[], i = g[i], ...)
    } else {
        # expand to ij pairlist then get indices of interest
        ij <- .g_index(g, i)
        getTile(x, tiles[], i = ij[[1L]], j = ij[[2L]], expand_grid = FALSE, ...)
    }
})

## tileIterator ####

#' @rdname getTile
#' @export
setMethod("getTile", signature("ANY", "tileIterator"),
    function(x, tiles, advance = TRUE, ...) {
    dots <- list(...)
    if (any(names(dots) %in% c("i", "j"))) {
        stop("i and j indexing are not used with `tileIterator`\n", call. = FALSE)
    }
    getTile(x, tiles[], i = tiles$next_indices(advance = advance), ...)
})
