#' @include generics.R

# docs ####

#' @name getTile
#' @title Get Tile
#' @description
#' Get a specific tile from the data.
#' @param x data
#' @param ti `tileIterator`
#' @param i tile vector or row index if `j` is also provided
#' @param j tile col index
#' @param lyr if provided, which layers/channels to include
#' @param extend logical (default = FALSE) whether to extend tile data to reach
#' expected tile dimensions
#' @param fill numeric. if `extend = TRUE`, what value to fill with
#' @returns `list` of tile data
#' @examples
#' f <- system.file("ex/elev.tif", package="terra")
#' ti <- tileIterator("pixel")
#' ti$pxdims <- dim(r)[1:2]
#' ti$nrows <- 10
#' ti$ncols <- 10
#'
#' tile_list <- getTile(f, ti, i = 3, j = 5)
#' force(tile_list)
#' plot(tile_list[[1]])
NULL

#' @rdname getTile
#' @param ext `numeric` or `SpatExtent` (optional) Set an extent before extracting
#' tiles.
#' @export
setMethod("getTile", signature("character", "pixelTileIterator"),
    function(x, ti, ext = NULL, ...) {
    checkmate::assert_file_exists(x)
    x <- .create_terra_spatraster(x)
    if (!is.null(ext)) ext(x) <- ext
    getTile(x, ti, ...)
})

#' @rdname getTile
#' @export
setMethod("getTile", signature("SpatRaster", "pixelTileIterator"),
    function(x, ti, i = NULL, j, lyr = NULL, extend = FALSE, fill = NA, ...) {
    checkmate::assert_integerish(i)
    checkmate::assert_integerish(lyr, null.ok = TRUE)
    checkmate::assert_logical(extend)
    if (!is.null(lyr)) x <- x[[lyr]]
    if (missing(j)) bounds_list <- ti[i]
    else bounds_list <- ti[i, j]

    lapply(bounds_list, function(b) {
        .px_get_tile(x, ti, b, extend, fill)
    })
})

# helpers ####

# Directly get a tile without the overhead
# x: SpatRaster
# ti: tileIterator
# b: px bound indices
.px_get_tile <- function(x, ti, b, extend = FALSE, fill = NA) {
    # get px tile from x as r
    r <- x[b[[3]]:min(nrow(x), b[[4]]), # rows (y)
           b[[1]]:min(ncol(x), b[[2]]), # cols (x)
           drop = FALSE]

    # handle extend and masking
    pad <- 2 * ti@buffer # since buffer is added on both sides
    expected_dim <- c(ti@tile_dims[[1L]] + pad, ti@tile_dims[[2L]] + pad)
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
