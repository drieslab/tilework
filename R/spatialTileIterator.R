#' @include package_imports.R
#' @include classes.R
#' @include tileIterator.R

# spatialTileIterator ####
# * docs ####
#' @name spatialTileIterator-class
#' @title Spatial Tile Iterator
#' @aliases spatialTileIterator
#' @description
#' Utility class that simplifies the setup of tiles across a spatial extent.
#' Tiles are stored in a lightweight format safe to be passed to child
#' processes. Tile `SpatExtent` objects can be extracted on-demand.
#'
#' @section setup and basic characteristics:
#' A `spatialTileIterator` needs both a spatial extent to tile across and also a
#' request for a certain number of tiles.
#'
#' * `spatialTileIterator()` is used to create a `spatialTileIterator` instance.
#' * `ext()<-` can be used to set up the spatial extent.
#' * `ext()` is used to check extent.
#' * `length()<-` is used to request a number of tiles.
#' * `length()` can be used to find out how many tiles there are.
#' * `dim()`/`nrow()`/`ncol()` basic generics are implemented and return
#' information about how the tiles are arranged.
#'
#' Note that the number of requested tiles may not be the actual length, since
#' a grid pattern must be followed. However, the number of generated tiles will
#' be AT LEAST the number that is requested. Generated tiles will have as square
#' a shape as possible.
#'
#' @section Getting tile extent:
#' `[i]` and `[i, j]` indexing can be used to select tiles, similarly to a
#' matrix. `[]` without any indexing will return the entire set of extents
#' as a list. Extracted extents will have metadata attached via `attr()`.
#' See metadata section below.
#'
#' @section padding:
#' `+`/`-` can be used to add or subtract padding to each of the tiles. Note
#' that this value does not affect the setting or retrieval of extent info via
#' `ext()` and `ext()<-`. Each bound will be expanded by the buffer value.

#' To avoid having to use `terra::extend()` when buffered tiles exceed raster
#' extent, you can decrease the extent by the same size as the buffer.
#'
#' @section previewing tiles:
#' `plot()` can be used to check the layout of the tiles.
#'
#' @section metadata:
#' The `spatialTileIterator` object can contain metadata. By default after extent and
#' tiles setup, a column called `"tile"` will be set up that simply records
#' which tile it is.
#'
#' * `$` can be used to view a specific type of metadata
#' * `$<-` can be used to set additional metadata items
#' * `[[i]]` selection will pull specific metadata rows corresponding to the
#' selected tiles.
#'
#' @examples
#' x <- tileIterator()
#' force(x)
#' ext(x) <- c(0, 100, 0, 100)
#' length(x) <- 8 # generated tiles will be AT LEAST this value
#' force(x)
#'
#' length(x) # how many were actually generated?
#' dim(x)
#' nrow(x)
#' ncol(x)
#'
#' # previewing
#' plot(x)
#'
#' # tile padding
#' y <- x + 10
#' plot(y, alpha = 0.3)
#' plot(ext(x), add = TRUE, border = "red")
#' # this is now larger than the original space
#' ext(y) <- ext(y) - 10
#' plot(y, alpha = 0.3)
#' plot(ext(x), add = TRUE, border = "red")
#' # now this does not exceed the image
#'
#' # negative buffer
#' z <- x - 5
#' plot(ext(x), border = "red")
#' plot(z, add = TRUE)
#'
#' # tile selection
#' x[5]
#' x[1, 2:3]
#'
#' # metadata
#' x$tile
#' x$fname <- sprintf("tile_%03d.tif", x$tile)
#' x[[5]]
#' x[[1:3]]$fname
#'
#' # selected tiles carry metadata as attributes
#' attr(x[4][[1]], "tile")
#' attr(x[4][[1]], "fname")
NULL


setMethod("initialize", signature("spatialTileIterator"), \(.Object, ...) {
    .Object <- callNextMethod(.Object, ...)

    # initialize n tiles
    if (length(.Object@n) == 0L) {
        .Object@n <- 0
    }

    # return early if extent not provided
    if (length(.Object@extent) == 0L) {
        return(.Object)
    }

    # check extent validity
    if (length(.Object@extent) != 4L) {
        stop("spatialTileIterator: invalid extent information", call. = FALSE)
    }

    # return early if n tiles = 0
    if (.Object@n == 0) {
        return(.Object)
    }

    # generate tile extent array
    n_desired <- .Object@n
    e <- terra::ext(.Object@extent)
    .Object@tiles <- .chunk_plan(e, min_chunks = n_desired)
    .Object@n <- length(.Object)

    # initialize metadata
    if (nrow(.Object@metadata) == 0L || nrow(.Object@metadata) != .Object@n) {
        .Object@metadata <- data.frame(tile = seq_len(.Object@n))
    }

    return(.Object)
})

#' @export
setMethod("show", signature("spatialTileIterator"), function(object) {
    cat("Object of class", class(object), "\n")

    # no extent, return early
    e <- object@extent
    if (length(e) == 0L) {
        cat("<empty>")
        return(invisible())
    }

    d <- dim(object)
    plist <- list(
        extent = sprintf(
            "%s (xmin, xmax, ymin, ymax)",
            paste(.ext_to_num_vec(e), collapse = ", ")
        ),
        dim = paste(dim(x), collapse = " "),
        buffer = object@buffer
    )
    print_list(plist)
})

#' @export
setMethod("length<-", signature("spatialTileIterator"), function(x, value) {
    x@n <- value
    return(initialize(x))
})

#' @export
setMethod("ext", signature("spatialTileIterator"), function(x, ...) {
    if (length(x@extent) == 0L) {
        stop("spatialTileIterator: No extent set", call. = FALSE)
    }
    ext(x@extent, ...)
})

#' @export
setMethod("ext<-", signature("spatialTileIterator"), function(x, value) {
    x@extent <- .ext_to_num_vec(ext(value))
    return(initialize(x))
})

#' @export
setMethod("[", signature(x = "spatialTileIterator", i = "numeric", j = "numeric", drop = "missing"), function(x, i, j) {
    callNextMethod(x, i, j, fun = ext)
})

# helpers ####

.get_dim_n_chunks <- function(n, e) {
    # find x to y ratio as 'r'
    e <- e[]
    r <- (e[["xmax"]] - e[["xmin"]]) / (e[["ymax"]] - e[["ymin"]])

    # x * y = n = ... ry^2 = n
    y <- ceiling(sqrt(n / r))
    x <- ceiling(n / y)

    return(c(y, x))
}

.chunk_plan <- function(extent, min_chunks = NULL, nrows = NULL, ncols = NULL) {
    checkmate::assert_class(extent, "SpatExtent")
    if (!is.null(nrows)) {
        checkmate::assert_true(length(c(nrows, ncols)) == 2L)
    } else {
        checkmate::assert_numeric(min_chunks)
        res <- .get_dim_n_chunks(n = min_chunks, e = extent)
        nrows <- res[1L]
        ncols <- res[2L]
    }

    x_stops <- seq(
        from = terra::xmin(extent),
        to = terra::xmax(extent),
        length.out = ncols + 1L
    )
    y_stops <- seq(
        from = terra::ymin(extent),
        to = terra::ymax(extent),
        length.out = nrows + 1L
    )

    # vector of extent values
    e_vec <- c()
    for (i in seq_len(nrows)) {
        for (j in seq_len(ncols)) {
            e_vec <- c(
                e_vec,
                x_stops[j],
                x_stops[j + 1L],
                y_stops[i],
                y_stops[i + 1L]
            )
        }
    }

    a <- array(e_vec, dim = c(4, ncols, nrows))
    a <- aperm(a, perm = c(3, 2, 1))
    # reverse order of rows so tiles count from top to bottom
    a <- a[seq(from = nrow(a), to = 1), , , drop = FALSE]

    # validate array output
    if (!length(dim(a)) == 3) {
        stop("in .chunk_plan() output: invalid dims", call. = FALSE)
    }

    return(a)
}
