#' @include generics.R

# docs ####

#' @name getTile
#' @title Get Tile
#' @description
#' Get a specific tile from the data.
#' @param x data
#' @param tiles `tile*` object
#' @param i tile vector or row index if `j` is also provided
#' @param j tile col index
#' @param lyr if provided, which layers/channels to include
#' @param extend logical (default = FALSE) whether to extend tile data to reach
#' expected tile dimensions
#' @param fill numeric. if `extend = TRUE`, what value to fill with
#' @param advance logical (default = TRUE). Whether to advance the iterator.
#' @returns `list` of tile data
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

# TODO getTile methods for spatialTilePlan

#' @rdname getTile
#' @param ext `numeric` or `SpatExtent` (optional) Set an extent before extracting
#' tiles.
#' @export
setMethod("getTile", signature("character", "pixelTilePlan"),
    function(x, tiles, ext = NULL, ...) {
    checkmate::assert_file_exists(x)
    x <- .create_terra_spatraster(x)
    if (!is.null(ext)) ext(x) <- ext
    getTile(x, tiles, ...)
})

#' @rdname getTile
#' @export
setMethod("getTile", signature("SpatRaster", "pixelTilePlan"),
    function(x, tiles, i = NULL, j, lyr = NULL, extend = FALSE, fill = NA, ...) {
    checkmate::assert_integerish(i)
    checkmate::assert_integerish(lyr, null.ok = TRUE)
    checkmate::assert_logical(extend)
    if (!is.null(lyr)) x <- x[[lyr]]
    if (missing(j)) bounds_list <- tiles[i, ...]
    else bounds_list <- tiles[i, j, ...]

    lapply(bounds_list, function(b) {
        .px_get_tile(x, tiles, b, extend, fill)
    })
})

#' @rdname getTile
#' @export
setMethod("getTile", signature("SpatRaster", "tileGroup"),
    function(x, tiles, i, j, lyr = NULL, ...) {
    checkmate::assert_integerish(j)
    checkmate::assert_integerish(lyr, null.ok = TRUE)
    if (!is.null(lyr)) x <- x[[lyr]]
    if (missing(i)) {
        if (!.has_active(tiles)) {
            stop("getTile: tileGroup `i` may only be omitted when an active group is set.\n", call. = FALSE)
        }
        i <- tiles@active
    }
    g <- tiles@groups[[i]]
    if (!.is_ij_group(g)) {
        # g is vector index
        getTile(x, tiles[], i = g[j])
    } else {
        # expand to ij pairlist then get indices of interest
        ij <- .g_index(g, j)
        getTile(x, tiles[], i = ij[[1L]], j = ij[[2L]], expand_grid = FALSE)
    }
})

#' @rdname getTile
#' @export
setMethod("getTile", signature("SpatRaster", "tileIterator"),
    function(x, tiles, lyr = NULL, advance = TRUE, ...) {
    checkmate::assert_integerish(lyr, null.ok = TRUE)
    if (!is.null(lyr)) x <- x[[lyr]]
    if (inherits(tiles[], "tileGroup")) {
        return(getTile(x, tiles[], j = tiles$next_indices(advance = advance), ...))
    }
    getTile(x, tiles[], i = tiles$next_indices(advance = advance), ...)
})

# helpers ####

# Directly get a tile without the overhead
# x: SpatRaster
# tiles: tile* object
# b: px bound indices
.px_get_tile <- function(x, tiles, b, extend = FALSE, fill = NA) {
    # get px tile from x as r
    r <- x[b[[3]]:min(nrow(x), b[[4]]), # rows (y)
           b[[1]]:min(ncol(x), b[[2]]), # cols (x)
           drop = FALSE]

    # handle extend and masking
    pad <- 2 * tiles@buffer # since buffer is added on both sides
    expected_dim <- c(tiles@tile_dims[[1L]] + pad, tiles@tile_dims[[2L]] + pad)
    if (nrow(r) != expected_dim[[1L]] ||
        ncol(r) != expected_dim[[2L]]) {
        if (extend) {
            bottom_rows <- expected_dim[[1L]] - nrow(r)
            right_cols <- expected_dim[[2L]] - ncol(r)
            r <- terra::extend(r,
                # left, right, bottom, top
                c(0, right_cols, bottom_rows, 0),
                fill = fill
            )
        }
    }
    r
}
