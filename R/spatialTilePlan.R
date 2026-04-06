#' @include package_imports.R
#' @include classes.R
#' @include tilePlan.R

# spatialTilePlan ####
# * docs ####
#' @name spatialTilePlan-class
#' @title Spatial Tile Plan
#' @aliases spatialTilePlan
#' @description
#' Utility class that simplifies the setup of tiles across a spatial extent.
#' Tiles are stored in a lightweight format safe to be passed to child
#' processes. Tile `SpatExtent` objects can be extracted on-demand.
#'
#' @section setup and basic characteristics:
#' A `spatialTilePlan` needs both a spatial extent to tile across and also a
#' request for a certain number of tiles.
#'
#' * `spatialTilePlan()` is used to create a `spatialTilePlan` instance.
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
#' `ext()` and `ext()<-`. Each bound will be expanded by the padding value.

#' To avoid having to use `terra::extend()` when padded tiles exceed raster
#' extent, you can decrease the extent by the same size as the padding.
#'
#' @section previewing tiles:
#' `plot()` can be used to check the layout of the tiles.
#'
#' @section metadata:
#' The `spatialTilePlan` object can contain metadata. By default after extent and
#' tiles setup, a column called `"tile"` will be set up that simply records
#' which tile it is.
#'
#' * `$` can be used to view a specific type of metadata and the padding value
#' * `$<-` can be used to set additional metadata items and the padding value
#' * `[[i]]` selection will pull specific metadata rows corresponding to the
#' selected tiles.
#'
#' @examples
#' x <- tilePlan()
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
#' plot(ext(x), border = "red")
#' plot(y, alpha = 0.3, add = TRUE)
#' # this is now larger than the original space
#' ext(y) <- ext(y) - 10
#' plot(y, alpha = 0.3)
#' plot(ext(x), add = TRUE, border = "red")
#' # now this does not exceed the image
#'
#' # negative padding
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


setMethod("initialize", signature("spatialTilePlan"), \(.Object, ...) {
    .Object <- callNextMethod(.Object, ...)

    # initialize n tiles
    if (length(.Object@n) == 0L) {
        .Object@n <- 0L
    }
    if (length(.Object@dims) == 0L) .Object@dims <- c(0L, 0L)
    if (length(.Object@tile_dims) == 0L) .Object@tile_dims <- c(0, 0)

    # return early if extent not provided
    if (length(.Object@extent) == 0L) {
        return(.Object)
    }

    # check extent validity
    if (length(.Object@extent) != 4L) {
        stop("spatialTilePlan: invalid extent information", call. = FALSE)
    }

    # return early if n tiles = 0
    if (.Object@n == 0) {
        return(.Object)
    }

    # generate tile extent array
    n_desired <- .Object@n
    e <- terra::ext(.Object@extent)
    .Object@dims <- as.integer(.get_dim_n_chunks(n = n_desired, e = e))
    .Object@tile_dims <- .calc_tile_dims(extent = e, array_dims = .Object@dims)
    .Object@n <- length(.Object)

    # initialize metadata
    if (nrow(.Object@metadata) == 0L || nrow(.Object@metadata) != .Object@n) {
        .Object@metadata <- data.frame(tile = seq_len(.Object@n))
    }

    return(.Object)
})

#' @rdname hidden_docs
#' @export
setMethod("show", signature("spatialTilePlan"), function(object) {
    cat("Object of class", class(object), "\n")

    # no extent, return early
    e <- object@extent
    if (length(e) == 0L) {
        cat("<empty>")
        return(invisible())
    }

    plist <- list(
        extent = sprintf(
            "%s (xmin, xmax, ymin, ymax)",
            paste(.ext_to_num_vec(e), collapse = ", ")
        ),
        dim = paste(dim(object), collapse = " "),
        pad = object@pad
    )
    .print_list(plist)
})

#' @rdname dim
#' @export
setMethod("length<-", signature("spatialTilePlan"), function(x, value) {
    x@n <- value
    return(initialize(x))
})

#' @rdname ext
#' @export
setMethod("ext", signature("spatialTilePlan"), function(x, ...) {
    if (length(x@extent) == 0L) {
        stop("[spatialTilePlan] No extent set", call. = FALSE)
    }
    ext(x@extent, ...)
})

#' @rdname ext
#' @export
setMethod("ext<-", signature("spatialTilePlan"), function(x, value) {
    x@extent <- .ext_to_num_vec(ext(value))
    return(initialize(x))
})

#' @rdname bracket
#' @export
setMethod("[", signature(x = "spatialTilePlan", i = "numeric", j = "numeric", drop = "missing"), function(x, i, j, ...) {
    callNextMethod(x, i, j, fun = ext, zero = FALSE, ...)
})

#' @rdname centroids
#' @export
setMethod(
    "centroids", signature("spatialTilePlan"),
    function(x, zero = FALSE, ...) {
        a <- .get_args_list(...)
        a$fun <- vect
        e <- ext(x)
        a$offset <- c(terra::ymin(e), terra::xmin(e))
        do.call(callNextMethod, a)
    }
)


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

.calc_tile_dims <- function(extent, array_dims) {
    checkmate::assert_integerish(array_dims)
    e <- ext(extent)
    er <- range(e)
    c(er[["y"]] / array_dims[[1L]], er[["x"]] / array_dims[[2L]])
}
